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

vec3 rotateAround(vec3 a, vec3 b, float theta) {
    b = normalize(b);             
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    
    return a * cosTheta + cross(b, a) * sinTheta + b * dot(b, a) * (1.0 - cosTheta);
}

//temp
float approxV1(float angleToWHprocent, float dist){
    float eps = 1e-6;
    float x = clamp(angleToWHprocent, 0.0, 0.9999);

    float n = 0.25;
    float k =0.0;

    float del = 2.0 * PI * exp(-k * x) / pow(1.0 - x*x, n);
    return del;
}

bool willHitSphere(vec3 rayOrigin, vec3 rayDir, vec3 center, float radius)
{
    vec3 L = rayOrigin - center;

    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, L);
    float c = dot(L, L) - radius * radius;

    float disc = b*b - 4.0*a*c;

    return disc >= 0.0;
}

float SHRAngle(float dist){

    //if (intersectSphere)

    float xs = -dist / 1.0;
    //ska egentligen kanse vara sqrt(x) för skuggan 
    //Och 3*sqrt(3)/x
    //Det är hur proportionerna ändras för skuggan och eisteinringen
    return (PI/2.0) + (PI/2.0) * (xs / sqrt(1.0 + xs*xs));
}

float ESR2Angle(float dist){
    float xs = -dist / u_tubeLength;
    return (PI/2.0) + (PI/2.0) * (xs / sqrt(1.0 + xs*xs));
}

float intersectSphere(vec3 rayOrigin, vec3 rayDir, vec3 center, float radius)
{
    vec3 L = rayOrigin - center;

    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, L);
    float c = dot(L, L) - radius * radius;

    float disc = b*b - 4.0*a*c;
    if (disc < 0.0) return -1.0;

    float s = sqrt(disc);

    float t1 = (-b - s) / (2.0 * a);
    float t2 = (-b + s) / (2.0 * a);

    // pick smallest positive t
    float t = t1;
    if (t < 0.0) t = t2;
    if (t < 0.0) return -1.0;

    return t;
}



void main() {
    //ska bli uniforms
    vec3 u_wh1pos = vec3(0.0, 0.0, -20.0);
    vec3 u_wh2pos = vec3(5.0, 0.0, 0.0);


    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;

    vec3 worldDir = normalize(ndc.x * u_planeDir * aspect - ndc.y * u_upDir + u_lookDir);
    vec3 to_wh = u_wh1pos - u_camPos;
    float distToWH = length(to_wh);
    float angleToWH = acos(dot(worldDir, normalize(to_wh)));

    //assuming worldDir = c = 1.0
    //ignoring special relativistic effects obviously...
    
    float wh1Test = intersectSphere(u_camPos, worldDir, u_wh1pos, u_radie);
    //float passConditionAngle =  SHRAngle(distToWH);

    float deflection = 0.0;
    float percentAngle;
  //How much the velocity vector points into the wormhole.
    float testColor = 0.0;
    if(wh1Test != -1.0){

        vec3 hitPoint = u_camPos + wh1Test * worldDir;
        vec3 n = normalize(u_wh1pos - hitPoint);
        float amplitude = dot(worldDir, n);
        float t_amplitude = length(worldDir - amplitude * n);

        float distRot = (t_amplitude / amplitude) * u_tubeLength;
        
        deflection = (distRot / (u_radie*2.0*PI)) - floor(distRot / (u_radie*2.0*PI));
        
        
        //, amplitude / whDepth);

        testColor = deflection;
    }

    vec3 axis = normalize(cross(worldDir, normalize(u_wh1pos - u_camPos)));
    vec3 rotatedDir = rotateAround(worldDir, axis, -2.0*PI*deflection);

    float u = (atan(rotatedDir.z, rotatedDir.x) + PI) / (2.0 * PI);
    float v = (asin(clamp(rotatedDir.y, -1.0, 1.0)) + PI/2.0) / PI;

    vec4 color = texture2D(u_texSpace2, vec2(u, v));

    if(wh1Test != -1.0){
        color = texture2D(u_texSpace1, vec2(u, v));
        //color += 0.5*vec4(testColor, testColor, testColor, 1.0);
       // color = texture2D(u_texSpace1, vec2(u, v));
    }
  //  gl_FragColor = vec4(rotatedDir, 1.0);
    gl_FragColor = color;
}


/*
void main() {
    //ska bli uniforms
    vec3 u_wh1pos = vec3(0.0, 0.0, -2.0);
    vec3 u_wh2pos = vec3(5.0, 0.0, 0.0);
    float u_radie = 10.0;

    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;

    vec3 worldDir = normalize(ndc.x * u_planeDir * aspect - ndc.y * u_upDir + u_lookDir);
    vec3 to_wh = u_wh1pos - u_camPos;
    float distToWH = length(to_wh);
    float angleToWH = acos(dot(worldDir, normalize(to_wh)));

    //for sphere 
    //float hitConditionAngle = asin(u_radie / distToWH);
    //forWHattempt 
    float passConditionAngle =  SHRAngle(distToWH);
    float bendConditionAngle = ESR2Angle(distToWH);
     
    float deflection = 0.0;
    float percentAngle;

    if(angleToWH >= passConditionAngle){
        percentAngle = (angleToWH - passConditionAngle) / (1.0 - passConditionAngle);
        deflection = approxV1(percentAngle, length(to_wh));
    }

    if(angleToWH < passConditionAngle){
        percentAngle = 1.0 - (angleToWH - passConditionAngle) / (passConditionAngle);
        deflection = approxV1(percentAngle, length(to_wh));
    }

    vec3 axis = normalize(cross(worldDir, normalize(u_wh1pos - u_camPos)));
    vec3 rotatedDir = rotateAround(worldDir, axis, deflection);

    float u = (atan(rotatedDir.z, rotatedDir.x) + PI) / (2.0 * PI);
    float v = (asin(clamp(rotatedDir.y, -1.0, 1.0)) + PI/2.0) / PI;

    //main location?
    vec4 color = texture2D(u_texSpace2, vec2(u, v));

    if(angleToWH <= passConditionAngle){
        //color += vec4(0.0, 0.2, 0.0, 1.0);
        color = texture2D(u_texSpace1, vec2(u, v));
    } else if(angleToWH <= bendConditionAngle){
        //color += vec4(percentAngle, percentAngle, percentAngle, 1.0);
    }


    gl_FragColor = color;
}
*/