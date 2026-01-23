precision highp float;

uniform vec2 u_resolution;
uniform vec3 u_camPos;

uniform vec3 u_lookDir;
uniform vec3 u_rightDir;
uniform vec3 u_upDir;

uniform sampler2D u_texSpace2;
uniform sampler2D u_texSpace1;

uniform float u_tubeLength;
uniform float u_radie;
uniform float u_distance;
uniform float u_outerCurvature;

varying vec2 vUv;

const float PI = 3.14159265358979323846;
const float skuggaMulti = 1.2;

vec3 rotateAround(vec3 a, vec3 b, float theta){
    b = normalize(b);             
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    
    return a * cosTheta + cross(b, a) * sinTheta + b * dot(b, a) * (1.0 - cosTheta);
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

bool goesThroughHole(
    vec3 hitPos,
    vec3 worldDir,
    vec3 center,
    float rs,
    float R_outer
){
    vec3 toC = center - hitPos;
    float dist = length(toC);

    float baseAngle = atan(skuggaMulti * rs / dist);
    //t kvadraten en billig enklen skit som gör interpoleringens derivata lite mer sammanhänande
    float t = clamp((R_outer - dist) / max(R_outer - 0.5 * R_outer, 1e-6), 0.0, 1.0);
    float angleLimit = mix(baseAngle, 0.5 * PI, t*t);

    float angle = acos(dot(normalize(worldDir), normalize(toC)));

    return angle <= angleLimit;
}
float deflection_DL(
    vec3 pos,
    vec3 dir,
    vec3 center,
    float rs,
    float R_outer,
    out vec3 newStart,
    out vec3 newDir
){
    vec3 toC = center - pos;

    vec3 oc = pos - center;
    float b = dot(dir, oc);
    float c = dot(oc, oc) - R_outer*R_outer;
    float h = b*b - c;
    float tExit = -b + sqrt(max(h, 0.0));

    vec3 noDefPos = pos + dir * tExit;
    vec3 offset = noDefPos - center;
    vec3 inOffset = pos - center;

    float dist = length(toC);

    float baseMin = atan(skuggaMulti * rs / dist);
    float baseMax = 0.5 * PI;

    float t = clamp((R_outer - dist) / max(R_outer - 0.5 * R_outer, 1e-6), 0.0, 1.0);

    //t kvadraten en billig enklen skit som gör interpoleringens derivata lite mer sammanhänande
    float angleMin = mix(baseMin, 0.5 * PI, t*t);
    float angleMax = mix(baseMax, PI, t);

    float angle = acos(dot(normalize(dir), normalize(toC)));

    float defPerc = 0.0;
    if(angle < angleMin){
        defPerc = angle / angleMin;
    }else if(angle < angleMax){
        defPerc = 1.0 - (angle - angleMin) / (angleMax - angleMin);
    }else{
        newStart = pos + dir * tExit;
        newDir = dir;
        return 0.0;
    }

    defPerc = clamp(defPerc, 0.0, 1.0);
    //defPerc = pow(defPerc, 3.0);
    float f = ((((-log(-defPerc +1.0)/(defPerc*3.0)) )) - 0.3330669073875)*(defPerc*defPerc*0.25)*15.0;
    
    vec3 axis = normalize(cross(dir, normalize(toC)));

    if(angle < angleMin){
        vec3 otherWH = center;
        otherWH.z *= -1.0;
        vec3 toOtherWh = normalize(otherWH - center);

        float angleTT = acos(clamp(dot(dir, toOtherWh), -1.0, 1.0));
        vec3 axisKUK = normalize(cross(dir, toOtherWh));
        dir = normalize(rotateAround(dir, axisKUK, 2.0*angleTT));
        inOffset = normalize(rotateAround(-inOffset, axisKUK, 2.0*angleTT));
        
        vec3 AxisOff2kuk = normalize(cross(dir, inOffset));
        
        newDir = normalize(rotateAround(dir, AxisOff2kuk, f));
        newStart = otherWH + rotateAround(inOffset , AxisOff2kuk , f) * R_outer;

    }else{
        offset = rotateAround(offset, axis, f);
        dir = rotateAround(dir, axis, f);
        newStart = center +  (offset * 1.001);
        newDir = dir;
    }
    return abs(f);
}

/*

        vec3 otherWH = center;
        otherWH.z *= -1.0;
        vec3 toOtherWh = normalize(otherWH - center);
        float angleTT = acos(clamp(dot(dir, toOtherWh), -1.0, 1.0));
        vec3 axisKUK = normalize(cross(dir, toOtherWh));
        dir = normalize(rotateAround(dir, axisKUK, 2.0*angleTT));
        vec3 axis2KUK = normalize(cross(dir, normalize(inOffset)));

        newDir = rotateAround(dir, axis2KUK, f);
        newStart = otherWH + rotateAround(inOffset, axis2KUK, f)*(1.001);
*/
void main(){
    vec3 wh1pos = vec3(0.0, 0.0, -u_distance * 0.5);
    vec3 wh2pos = vec3(0.0, 0.0, u_distance * 0.5);

    float whSr = u_radie;
    float sphereRadie = 6.0;

    vec3 wh1sA = vec3(u_radie*4.0, 0.0, -u_distance * 0.5);
    vec3 wh1sB = vec3(0.0, u_radie*4.0, -u_distance * 0.5);

    vec3 wh2sA = vec3(-u_radie*4.0, 0.0, u_distance * 0.5);
    vec3 wh2sB = vec3(0.0, -u_radie*4.0, u_distance * 0.5);

    float ofac =2.5;

    vec3 centers[6] = vec3[6](wh1pos, wh2pos, wh1sA, wh1sB, wh2sA, wh2sB);
    float radies[6] = float[6](u_radie*ofac, u_radie*ofac, sphereRadie, sphereRadie, sphereRadie, sphereRadie);
    float colorsR[6] = float[6](0.0, 0.0, 1.0, 1.0, 0.0, 0.5);
    float colorsG[6] = float[6](0.0, 0.0, 0.0, 0.3, 0.5, 0.0);
    float colorsB[6] = float[6](0.0, 0.0, 0.3, 0.0, 1.0, 1.0);

    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;
    vec3 worldDir = normalize(ndc.x * u_rightDir * aspect - ndc.y * u_upDir + u_lookDir);    
  
    const float almostZero = 1e-3;
    const int bounces = 4;

    vec3 start = u_camPos;
    vec3 acc = vec3(0.0);
    vec3 strength = vec3(1.0);

    vec3 lightDir = normalize(vec3(0.53, 0.2, 0.5));
    bool firstInside = true; 
    for(int b = 0; b < bounces; b++){

        float minDist = 1e9;
        int hitIndex = -1;
        vec3 hitPos;
        vec3 hitNormal;

        for(int i = 0; i < 6; i++){
            float t = intersectSphere(start, worldDir, centers[i], radies[i]);
            if(t > almostZero && t < minDist){
                minDist = t;
                hitIndex = i;
            }
        }

        if(hitIndex == -1){
            float u = (atan(worldDir.z, worldDir.x) + PI) / (2.0 * PI);
            float v = (asin(clamp(worldDir.y, -1.0, 1.0)) + PI/2.0) / PI;
            vec3 env = texture2D(u_texSpace2, vec2(u, v)).rgb;
            acc += strength * env;
            break;
        }

        hitPos = start + worldDir * minDist;
        hitNormal = normalize(hitPos - centers[hitIndex]);        

        if(hitIndex == 0 || hitIndex == 1){
            vec3 center = centers[hitIndex];
            vec3 toHit = hitPos - center;
            vec3 hitNormal = normalize(toHit);

            bool inside = dot(hitNormal, worldDir) > 0.0;
            if(inside){
                hitNormal = -hitNormal;
                hitPos = u_camPos;
            }

            if(goesThroughHole(
                hitPos,
                worldDir,
                center,
                u_radie,
                u_radie * ofac
            )){
              //  acc += vec3(0.0, 0.0, 0.2);
            }

            vec3 tmpStart;
            vec3 tmpDir;

            float defPerc = deflection_DL(hitPos, worldDir, center, u_radie, u_radie*ofac, tmpStart, tmpDir);
            start = tmpStart;
            worldDir = tmpDir;

         //   acc += vec3(defPerc);
        //    break;
        }else{
            vec3 color = vec3(colorsR[hitIndex], colorsG[hitIndex], colorsB[hitIndex]);
            float bright = max(dot(hitNormal, lightDir), 0.0);
            vec3 finalCol = color * 0.75 + color * 0.25 * bright;
            acc += strength * finalCol;
            strength *= 0.5;
            worldDir = reflect(worldDir, hitNormal);
            start = hitPos + worldDir * almostZero;
        }
    }

    gl_FragColor = vec4(clamp(acc, 0.0, 1.0), 1.0);
}