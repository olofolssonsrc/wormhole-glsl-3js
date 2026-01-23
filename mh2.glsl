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

vec3 rotateAround(vec3 a, vec3 b, float theta){
    b = normalize(b);             
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    
    return a * cosTheta + cross(b, a) * sinTheta + b * dot(b, a) * (1.0 - cosTheta);
}

//temp
float approxV1(float angleToWHprocent, float dist){
    float almostZero = 1e-6;
    float x = clamp(angleToWHprocent, 0.0, 0.9999);

    float n = 0.25;
    float k =0.0;

    float del = 2.0 * PI * exp(-k * x) / pow(1.0 - x*x, n);
    return del;
}


float SHRAngle(float dist){

    //if(intersectSphere)

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

    // pick smallest positive t
    float t = t1;
    if(t < 0.0) t = t2;
    if(t < 0.0) return -1.0;

    return t;
}


void threwAngleFromWH(vec3 hitPoint, vec3 worldDir, vec3 objPos, float radius, float extraRotation, out float degT, float procentFromStart){

    vec3 n = normalize(objPos - hitPoint);
    float amplitude = dot(worldDir, n);
    float t_amplitude = length(worldDir - amplitude * n);
    float distRot = (t_amplitude / amplitude) * (u_tubeLength * procentFromStart );
    float deflection = (( distRot) / (radius*2.0*PI)) - floor((distRot) / (radius*2.0*PI));
    //amplitude / whDepth);
    //testColor = deflection;

    vec3 axis = normalize(cross(worldDir, n));
  //  newDir = rotateAround(worldDir, axis, -2.0*PI*deflection);
    degT = (-2.0*PI*deflection);
    //för h1 : , bör ksk bli också egentligen till en vektor, random i 3d. Ej bara göra detta runt vertikal..
    //denna grej skall också göras i javascripten för character move lixeom...
    //rotated = rotateAround(rotated, vec3(0.0, 1.0, 0.0), extraRotation);
  //  return rotated;
}
const float litetNummer = 1e-5;

bool goesThroughHole(vec3 pos, vec3 dir, vec3 center, float rs, float R_outer){
    vec3 oc = pos - center;
    float b = dot(oc, dir);
    float c = dot(oc, oc) - rs*rs;
    float h = b*b - c;
    if(h < 0.0) return false;
    float t = -b - sqrt(h);
    return t > 0.0;
}

void deflectionOutr(vec3 pos, vec3 dir, vec3 center, float rs, float R_outer, out vec3 newStart, out vec3 newDir){
    const float FAR = 1e3;
    const float litetNummer = 1e-6;
    vec3 oc = pos - center;
    float b = dot(oc, dir);
    float c = dot(oc, oc) - rs*rs;
    float h = b*b - c;
    if(h <= 0.0){
        newStart = pos + dir * FAR;
        newDir = dir;
        return;
    }
    float s = sqrt(h);
    float t1 = -b - s;
    float t2 = -b + s;
    float t = max(t1, t2);
    if(t <= litetNummer
){
        newStart = pos + dir * FAR;
        newDir = dir;
        return;
    }
    newStart = pos + t * dir*1.1;
    newDir = dir;
}



void spiralinChange(vec3 pos, vec3 dir, vec3 center, float rs, float R_outer, out vec3 newStart, out vec3 newDir){
    vec3 oc = pos - center;
    float b = dot(oc, dir);
    float c_i = dot(oc, oc) - rs*rs;
    float h_i = b*b - c_i;
    float s_i = sqrt(max(h_i, 0.0));
    float ti1 = -b - s_i;
    float ti2 = -b + s_i;
    float ti = min(ti1, ti2);
    if(ti <= litetNummer
    ) ti = max(ti1, ti2);
        if(ti <= litetNummer
    ) ti = litetNummer
    ;
    newStart = pos + ti * dir;
    newDir = dir;
}


void main(){
    //har radie u_radie
    vec3 wh1pos = vec3(0.0, 0.0, -u_distance * 0.5);
    vec3 wh2pos = vec3(0.0, 0.0, u_distance * 0.5);

    float whSr = u_radie;
    float sphereRadie = 6.0;
    //dessa har radie sphereRadie
    //alla dessa arrayer bör egenetligen vara uniforms...
    vec3 wh1sA = vec3(u_radie*4.0, 0.0, -u_distance * 0.5);
    vec3 wh1sB = vec3(0.0, u_radie*4.0, -u_distance * 0.5);

    vec3 wh2sA = vec3(-u_radie*4.0, 0.0, u_distance * 0.5);
    vec3 wh2sB = vec3(0.0, -u_radie*4.0, u_distance * 0.5);

    float ofac = 1.0;

    vec3 centers[6] = vec3[6](wh1pos, wh2pos, wh1sA, wh1sB, wh2sA, wh2sB);
    float radies[6] = float[6](u_radie*ofac, u_radie*ofac, sphereRadie, sphereRadie, sphereRadie, sphereRadie);
    float colorsR[6] = float[6](0.0, 0.0, 1.0, 1.0, 0.0, 0.5);
    float colorsG[6] = float[6](0.0, 0.0, 0.0, 0.3, 0.5, 0.0);
    float colorsB[6] = float[6](0.0, 0.0, 0.3, 0.0, 1.0, 1.0);
    //
    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;
    vec3 worldDir = normalize(ndc.x * u_rightDir * aspect - ndc.y * u_upDir + u_lookDir);
    
    //vec3 to_wh = - u_camPos;
    //float distToWH = length(to_wh);
    //float angleToWH = acos(dot(worldDir, normalize(to_wh)));
    //assuming worldDir = c = 1.0
    //ignoring special relativistic effects obviously...
    // small constants
    
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

            vec3 toHitWH = u_camPos - centers[hitIndex];
           float distToHitWH = length(toHitWH);

            //   if(distToHitWH < u_radie*ofac ){
           //     hitPos = u_camPos;
           // }

            //Check deflection from the outer effect, if critical, do the tube. Otherwise deflect.             
            /*    if (goesThroughHole(hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac)) {
                acc += vec3(0.0, 0.0, 0.25);
                spiralinChange(hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac, hitPos, worldDir);

            }else{
                acc += vec3(0.25, 0.0, 0.0);
                deflectionOutr(hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac, start, worldDir);
                continue;
            }*/
            

            //Måste updatera denna och tänka på att nu kommer jag inte 
            //növdändigtvis att telerporteras bara för att jag träffar hålet. 
            int exitWhHitIndex = (hitIndex == 0) ? 1 : 0;

            vec3 offset = hitPos - centers[hitIndex];
            offset.z = -offset.z;

            float procentFromStart = 1.0;

            if(distToHitWH < u_radie && firstInside){
                firstInside = false;
                vec3 dirToWH = normalize(centers[hitIndex] - u_camPos);
                bool pointsTowardWH = dot(worldDir, dirToWH) > 0.0;

                if(pointsTowardWH){
                    
                    offset = normalize(u_camPos - centers[hitIndex]);
                    offset.z = -offset.z;

                    procentFromStart = ((distToHitWH) / (u_radie));
     
                    float amplitude = dot(worldDir, dirToWH);
                    float t_amplitude = length(worldDir - amplitude * dirToWH);
                    float distRot = (t_amplitude / amplitude) * (u_tubeLength * procentFromStart);
                    float deflection = ((distRot) / (u_radie*2.0*PI)) - floor((distRot) / (u_radie*2.0*PI));
                    float deg = (-2.0*PI*deflection);

                    vec3 toNextHole = normalize(centers[exitWhHitIndex] - centers[hitIndex]);
                    float angleTT = acos(dot(worldDir, toNextHole));
                    
                    vec3 axis = normalize(cross(worldDir, toNextHole));
                    worldDir = normalize(rotateAround(worldDir, axis, 2.0*angleTT));
                    vec3 axis2 = normalize(cross(worldDir, normalize(offset)));

                    worldDir = rotateAround(worldDir, axis2, deg);
                    start = centers[exitWhHitIndex] + rotateAround(offset, axis2, deg)*(u_radie + almostZero) ;
                }else{
                    procentFromStart = 1.0 - ((distToHitWH) / (u_radie));
                    offset = normalize(u_camPos - centers[hitIndex]);
                                            
                    float amplitude = dot(worldDir, -1.0*dirToWH);
                    float t_amplitude = length(worldDir - amplitude * -1.0*dirToWH);
                    float distRot = (t_amplitude / amplitude) * (u_tubeLength * procentFromStart);
                    float deflection = ((distRot) / (u_radie*2.0*PI)) - floor((distRot) / (u_radie*2.0*PI));
                    float deg = (-2.0*PI*deflection);
                    vec3 axis2 = normalize(cross(worldDir, normalize(offset)));

                    worldDir = rotateAround(worldDir, axis2, deg);
                    start = centers[hitIndex] + rotateAround(offset, axis2, deg)*(u_radie * 1.0 + almostZero);;                
                }
            }else{
                float degT;
                float angle = (hitIndex == 0) ? -0.55 * PI : 0.75 * PI;
                threwAngleFromWH(hitPos, worldDir, centers[hitIndex], u_radie, angle, degT, procentFromStart);

                vec3 toNextHole = normalize(centers[exitWhHitIndex] - centers[hitIndex]);
                float angleTT = acos(clamp(dot(worldDir, toNextHole), -1.0, 1.0));
                vec3 axis = normalize(cross(worldDir, toNextHole));
                worldDir = normalize(rotateAround(worldDir, axis, 2.0*angleTT));
                vec3 axis2 = normalize(cross(worldDir, normalize(offset)));

                worldDir = rotateAround(worldDir, axis2, degT);;
                start = centers[exitWhHitIndex] + rotateAround(offset, axis2, degT)*(1.0 + almostZero) ;;
            }

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


