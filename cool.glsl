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
const float skuggaMulti = 1.1;

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

/*

float f(float angleMin, float angle, float conv){
    float f1 = (1.0 / (angleMin - angle) - 1.0 / conv);
    return f1;
}

float k(float angle, float angleMin){
    float conv = 1e30;
    float term = -f(angleMin, angle, conv);
    float k_final = term - 1.0 / (PI - angleMin);
    return k_final;
}

float fVal(float angleMin, float angle, float t_func){
    float f_step = f(angleMin, angle, angleMin);
    return f_step * max(t_func, 0.1);
}

float kVal(float angleMin, float angle, float t_func){
    float k_base = k(angle, angleMin);
    return k_base * max(t_func, 0.1);
}
//a function for crit angle. a
//a function for go through. k
//a function for deflect f
//a system for how f, k change whith a
//connection of f, k when in middle
float deflection_DL(
    vec3 pos, 
    vec3 otherWHPos, 
    vec3 dir, 
    vec3 center, 
    float rs, 
    float R_outer, 
    out vec3 newStart, 
    out vec3 newDir
){
    vec3 toC = center - pos;
    vec3 oc = pos - center;
    float dist = length(toC);
    vec3 nIn = normalize(oc);

    float b = dot(dir, oc);
    float c = dot(oc, oc) - R_outer * R_outer;
    float h = b*b - c;
    float tExit = -b + sqrt(max(h, 0.0));
    vec3 noDefPos = pos + dir * tExit;
    vec3 offset = noDefPos - center;

    float t = clamp((R_outer - dist) / max(R_outer - 0.5 * R_outer, 1e-6), 0.0, 1.0);
    float scale = 5.0;
    float stretch = 1.0;
    float offseta = 1.0;
    float t_scaled = t * scale;
    float t_func = (cosh(t_scaled * stretch) - offseta) / (cosh(scale * stretch) - offseta);

    float baseMin = atan(skuggaMulti * rs / dist);
    float angleMin = mix(baseMin, 0.5 * PI, t);
    float angleMax = PI - angleMin;

    float angle = acos(clamp(dot(normalize(dir), normalize(toC)), -1.0, 1.0));
    vec3 axis = normalize(cross(dir, normalize(toC)));

    if(angle < angleMin){
        float f_final = fVal(angleMin, angle, t);
        offset = R_outer*normalize( rotateAround(offset, axis, -f_final));
        dir = rotateAround(dir, axis, -f_final);
        newStart = otherWHPos + offset * 1.001;
    }else{
        float k_final = kVal(angleMin, angle, t);
        offset =R_outer* normalize(  rotateAround(offset, axis, k_final));
        dir = rotateAround(dir, axis, k_final);
        newStart = center + offset * 1.001;
    }

    newDir = dir;
    return 0.0;
}
*/


//a function for crit angle. a
//a function for go through. k
//a function for deflect f
//a system for how f, k change whith a
//connection of f, k when in middle

//a function that is when at rs and look out.
//a function when at infinity and look out
//a function at infinity and look in
//a function when at rs and look in

// all based on percentage of the wh. 


float f(float angleMin, float angle, float conv){
    float f1 = (1.0 / (angleMin - angle) - 1.0 / conv);
    return f1;
}

float k(float angle, float angleMin){
    float conv = 1e30;
    float term = -f(angleMin, angle, conv);
    float k_final = term - 1.0 / (PI - angleMin);
    return k_final;
}

float fVal(float angleMin, float angle, float t_func){
    float f_step = f(angleMin, angle, angleMin);
    return f_step * max(t_func, 0.1);
}

float fOutInf(float p) {
    float x = 1.0 - p;

    float term = -log(p) / x;
    return (term - 0.3330669073875) * (0.25 * x * x)*1.0;
}

float fOutRs(float p) {
    float x = 1.0 - p;

    float term = -log(p) / x;
    return (term - 0.3330669073875) * (0.25 * x * x)*14.0;
}

float kVal(float t_func, float procentOut) {
    float a = fOutRs(1.0 -procentOut);
    float b = fOutInf(1.0 - procentOut);
    return mix(b, a, t_func);
}

float deflection_DL(
    vec3 pos, 
    vec3 otherWHPos, 
    vec3 dir, 
    vec3 center, 
    float rs, 
    float R_outer, 
    out vec3 newStart, 
    out vec3 newDir
){
    vec3 toC = center - pos;
    vec3 oc = pos - center;
    float dist = length(toC);
    vec3 nIn = normalize(oc);

    float b = dot(dir, oc);
    float c = dot(oc, oc) - R_outer * R_outer;
    float h = b*b - c;
    float tExit = -b + sqrt(max(h, 0.0));
    vec3 noDefPos = pos + dir * tExit;
    vec3 offset = noDefPos - center;

    float t = clamp((R_outer - dist) / max(R_outer - 0.5 * R_outer, 1e-6), 0.0, 1.0);
    t = t*t;

    float baseMin = atan(skuggaMulti * rs / dist);
    float baseMax = 0.5 * PI;
    float angleMin = mix(baseMin, 0.5 * PI, t);
    float angleMax = mix(baseMax, PI, t);

    float angle = acos(clamp(dot(normalize(dir), normalize(toC)), -1.0, 1.0));

    float angleProcentOut = (angle - angleMin)/(PI - angleMin);
    //0 def at angle assumption
    float angleProcentOut_2 = max(0.0, 1.0 - (angle - angleMin) / (angleMax - angleMin));
    float angleProcentIn = (angle)/(angleMin);

    vec3 axis = normalize(cross(dir, normalize(toC)));
    float testtt = 0.0;
    if(angle < angleMin){
        float f_final = 0.0;// fVal(angleMin, angle, t);
        offset = R_outer*normalize( rotateAround(offset, axis, -f_final));
        dir = rotateAround(dir, axis, -f_final);
        newStart = otherWHPos + offset * 1.001;
    //    testtt = 0.001;
    }else{
        float k_final = kVal(t, angleProcentOut_2);



        offset =R_outer* normalize(rotateAround(offset, axis, k_final));
        //todo calculate correct offset and dir;
        dir = rotateAround(dir, axis, k_final);
        newStart = center + offset * 1.001;
    }

    newDir = dir;
    return testtt ;
}

void main(){
    vec3 wh1pos = vec3(0.0, 0.0, -u_distance * 0.5);
    vec3 wh2pos = vec3(0.0, 0.0, u_distance * 0.5);

    float whSr = u_radie;
    float sphereRadie = 6.0;

    vec3 wh1sA = vec3(u_radie*4.0, 0.0, -u_distance * 0.5);
    vec3 wh1sB = vec3(0.0, u_radie*4.0, -u_distance * 0.5);

    vec3 wh2sA = vec3(-u_radie*4.0, 0.0, u_distance * 0.5);
    vec3 wh2sB = vec3(0.0, -u_radie*4.0, u_distance * 0.5);

    float ofac = 2.5;

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

    for(int b = 0; b < bounces; b++){

        float minDist = 1e9;
        int hitIndex = -1;
        vec3 hitPos;
        vec3 hitNormal;

        //hit stuff?
        for(int i = 0; i < 6; i++){
            float t = intersectSphere(start, worldDir, centers[i], radies[i]);
            if(t > almostZero && t < minDist){
                minDist = t;
                hitIndex = i;
            }
        }

        hitPos = start + worldDir * minDist;
        hitNormal = normalize(hitPos - centers[hitIndex]); 

        //if spheres
        if(hitIndex > 1){
            vec3 color = vec3(colorsR[hitIndex], colorsG[hitIndex], colorsB[hitIndex]);
            float bright = max(dot(hitNormal, lightDir), 0.0);
            vec3 finalCol = color * 0.75 + color * 0.25 * bright;
            acc += strength * finalCol;
            strength *= 0.5;
            worldDir = reflect(worldDir, hitNormal);
            start = hitPos + worldDir * almostZero;
            continue;
        }
        //if nothing
        else if(hitIndex == -1){
            float u = (atan(worldDir.z, worldDir.x) + PI) / (2.0 * PI);
            float v = (asin(clamp(worldDir.y, -1.0, 1.0)) + PI/2.0) / PI;
            vec3 env = texture2D(u_texSpace2, vec2(u, v)).rgb;
            acc += strength * env;
            break;
        }

        //else if wh       

        vec3 center = centers[hitIndex];
        vec3 otherWHPos = center;
        otherWHPos.z *=-1.0;

        bool inside = dot(hitNormal, worldDir) > 0.0;
        if(inside){
            hitNormal = -hitNormal;
            hitPos = u_camPos;
        }

        vec3 tmpStart;
        vec3 tmpDir;

        float defPerc = deflection_DL(hitPos, otherWHPos, worldDir, center, u_radie, u_radie*ofac, tmpStart, tmpDir);
        acc += vec3(defPerc);
      //  break;
        start = tmpStart;
        worldDir = tmpDir;
    }

   gl_FragColor = vec4(clamp(acc, 0.0, 1.0), 1.0);
}