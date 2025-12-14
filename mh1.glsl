precision highp float;

uniform vec2 u_resolution;
uniform vec3 u_camPos;

uniform vec3 u_lookDir;
uniform vec3 u_planeDir;
uniform vec3 u_upDir;

uniform sampler2D u_texSpace2;
uniform sampler2D u_texSpace1;

uniform float u_tubeLength;
uniform float u_radie;
uniform float u_distance;
uniform float u_outerCurvature;

varying vec2 vUv;

const float PI = 3.14159265358979323846;

vec3 rotateAround(vec3 a, vec3 b, float theta){
    b = normalize(b);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return a * cosTheta + cross(b, a) * sinTheta + b * dot(b, a) * (1.0 - cosTheta);
}

// temp
float approxV1(float angleToWHprocent, float dist){
    float almostZero = 1e-6;
    float x = clamp(angleToWHprocent, 0.0, 0.9999);

    float n = 0.25;
    float k = 0.0;

    float del = 2.0 * PI * exp(-k * x) / pow(1.0 - x*x + almostZero, n);
    return del;
}

bool willHitSphere(vec3 rayOrigin, vec3 rayDir, vec3 center, float radius){
    vec3 L = rayOrigin - center;

    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, L);
    float c = dot(L, L) - radius * radius;

    float disc = b*b - 4.0*a*c;

    return disc >= 0.0;
}

float SHRAngle(float dist){
    float xs = -dist / 1.0;
    return (PI/2.0) + (PI/2.0) * (xs / sqrt(1.0 + xs*xs));
}

float ESR2Angle(float dist){
    float xs = -dist / u_tubeLength;
    return (PI/2.0) + (PI/2.0) * (xs / sqrt(1.0 + xs*xs));
}

float intersectSphere(vec3 rayOrigin, vec3 rayDir, vec3 center, float radius){
    vec3 L = rayOrigin - center;

    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, L);
    float c = dot(L, L) - radius * radius;

    float disc = b*b - 4.0*a*c;
    if(disc < 0.0) return -1.0;

    float s = sqrt(disc);

    float t1 = (-b - s) / (2.0 * a);
    float t2 = (-b + s) / (2.0 * a);

    float t = t1;
    if(t < 0.0) t = t2;
    if(t < 0.0) return -1.0;

    return t;
}

void main(){
    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;

    vec3 worldDir = normalize(ndc.x * u_planeDir * aspect - ndc.y * u_upDir + u_lookDir);

    vec3 to_wh = -u_camPos;
    float distToWH = length(to_wh);
    vec3 dirToWH = distToWH > 0.0 ? normalize(to_wh) : normalize(u_lookDir);

    float cosAngle = clamp(dot(worldDir, dirToWH), -1.0, 1.0);
    float angleToWH = acos(cosAngle);

    float passConditionAngle = SHRAngle(distToWH);
    float bendConditionAngle = ESR2Angle(distToWH);

    // ensure sensible ordering
    if(bendConditionAngle < passConditionAngle){
        float tmp = bendConditionAngle;
        bendConditionAngle = passConditionAngle;
        passConditionAngle = tmp;
    }

    float deflection = 0.0;
    float percentAngle = 0.0;

    // map angleToWH to [0,1] between passConditionAngle and bendConditionAngle
    if(angleToWH <= passConditionAngle){
        percentAngle = 0.0;
        deflection = 0.0;
    } else if(angleToWH >= bendConditionAngle){
        percentAngle = 1.0;
        deflection = approxV1(percentAngle, distToWH);
    } else {
        float denom = max(1e-6, bendConditionAngle - passConditionAngle);
        percentAngle = clamp((angleToWH - passConditionAngle) / denom, 0.0, 1.0);
        deflection = approxV1(percentAngle, distToWH);
    }

    // compute rotation axis safely
    vec3 axis = cross(worldDir, dirToWH);
    
    axis = normalize(axis);

    vec3 rotatedDir = rotateAround(worldDir, axis, deflection);

    float u = (atan(rotatedDir.z, rotatedDir.x) + PI) / (2.0 * PI);
    float v = (asin(clamp(rotatedDir.y, -1.0, 1.0)) + PI/2.0) / PI;

    vec4 color;
    if(angleToWH <= passConditionAngle){
        color = texture2D(u_texSpace1, vec2(u, v));
    } else {
        color = texture2D(u_texSpace2, vec2(u, v));
    }

    gl_FragColor = color;
}
