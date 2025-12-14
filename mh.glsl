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

//temp
float approxV1(float angleToWHprocent, float dist){
    float almostZero = 1e-6;
    float x = clamp(angleToWHprocent, 0.0, 0.9999);

    float n = 0.25;
    float k =0.0;

    float del = 2.0 * PI * exp(-k * x) / pow(1.0 - x*x, n);
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


void threwAngleFromWH(vec3 hitPoint, vec3 worldDir, vec3 objPos, float radius, float extraRotation, out vec3 newDir, out vec3 newStart, out float degT, float procentFromStart){

    vec3 n = normalize(objPos - hitPoint);
    float amplitude = dot(worldDir, n);
    float t_amplitude = length(worldDir - amplitude * n);
    float distRot = (t_amplitude / amplitude) * (u_tubeLength * procentFromStart );
    float deflection = (( distRot) / (radius*2.0*PI)) - floor((distRot) / (radius*2.0*PI));
    //amplitude / whDepth);
    //testColor = deflection;

    vec3 axis = normalize(cross(worldDir, n));
    newDir = rotateAround(worldDir, axis, -2.0*PI*deflection);
    degT = (-2.0*PI*deflection);
    //för h1 : , bör ksk bli också egentligen till en vektor, random i 3d. Ej bara göra detta runt vertikal..
    //denna grej skall också göras i javascripten för character move lixeom...

    //rotated = rotateAround(rotated, vec3(0.0, 1.0, 0.0), extraRotation);

  //  return rotated;
}

void main(){
    //har radie u_radie
    vec3 wh1pos = vec3(0.0, 0.0, -u_distance * 0.5);
    vec3 wh2pos = vec3(0.0, 0.0, u_distance * 0.5);

    float sphereRadie = 6.0;
    //dessa har radie sphereRadie
    //alla dessa arrayer bör egenetligen vara uniforms...
    vec3 wh1sA = vec3(u_radie*9.0, 0.0, -u_distance * 0.5);
    vec3 wh1sB = vec3(0.0, u_radie*6.0, -u_distance * 0.5);

    vec3 wh2sA = vec3(-u_radie*9.0, 0.0, u_distance * 0.5);
    vec3 wh2sB = vec3(0.0, -u_radie*6.0, u_distance * 0.5);

    vec3 centers[6] = vec3[6](wh1pos, wh2pos, wh1sA, wh1sB, wh2sA, wh2sB);
    float radies[6] = float[6](u_radie, u_radie, sphereRadie, sphereRadie, sphereRadie, sphereRadie);
    float colorsR[6] = float[6](0.0, 0.0, 1.0, 1.0, 0.0, 0.5);
    float colorsG[6] = float[6](0.0, 0.0, 0.0, 0.3, 0.5, 0.0);
    float colorsB[6] = float[6](0.0, 0.0, 0.3, 0.0, 1.0, 1.0);
    //
    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;
    vec3 worldDir = normalize(ndc.x * u_planeDir * aspect - ndc.y * u_upDir + u_lookDir);
    
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

        //infinity case
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
            vec3 newDir;
            vec3 newStart;
     
            int exitWhHitIndex = (hitIndex == 0) ? 1 : 0;

            vec3 offset = hitPos - centers[hitIndex];
            offset.z = -offset.z;

            vec3 toHitWH = u_camPos - centers[hitIndex];
            float distToHitWH = length(toHitWH);

            float procentFromStart = 1.0;

            if(distToHitWH < radies[hitIndex] && firstInside){
                firstInside = false;
                vec3 dirToWH = normalize(centers[hitIndex] - u_camPos);
                bool pointsTowardWH = dot(worldDir, dirToWH) > 0.0;

                if(pointsTowardWH){
                    
                    offset = normalize(u_camPos - centers[hitIndex]);
                    offset.z = -offset.z;

                    procentFromStart = ((distToHitWH) / (radies[hitIndex]));
                //    acc =0.34*vec3(procentFromStart, 0.0, 0.0);
                                            
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
                    newDir = rotateAround(worldDir, axis2, deg);

                    newStart = centers[exitWhHitIndex] + rotateAround(offset, axis2, deg)*(u_radie + almostZero) ;
                
                    worldDir = newDir;
                    start = newStart;
                }else{
                    procentFromStart = 1.0 - ((distToHitWH) / (radies[hitIndex]));
                 //   acc =1.0*vec3(0.0, 0.0, procentFromStart);
                        
                    offset = normalize(u_camPos - centers[hitIndex]);
                                            
                    float amplitude = dot(worldDir, -1.0*dirToWH);
                    float t_amplitude = length(worldDir - amplitude * -1.0*dirToWH);
                    float distRot = (t_amplitude / amplitude) * (u_tubeLength * procentFromStart);
                    float deflection = ((distRot) / (u_radie*2.0*PI)) - floor((distRot) / (u_radie*2.0*PI));
                    float deg = (-2.0*PI*deflection);

             /*       vec3 toNextHole = normalize(centers[exitWhHitIndex] - centers[hitIndex]);
                    float angleTT = acos(clamp(dot(worldDir, toNextHole), -1.0, 1.0));
                    vec3 axis = normalize(cross(worldDir, toNextHole));
                    worldDir = normalize(rotateAround(worldDir, axis, 2.0*angleTT));*/

                    vec3 axis2 = normalize(cross(worldDir, normalize(offset)));
                    newDir = rotateAround(worldDir, axis2, deg);

                    newStart = centers[hitIndex] + rotateAround(offset, axis2, deg)*(u_radie + almostZero);
                
                    worldDir = newDir;
                    start = newStart;                
                }
                  // break;
            }else{
                float degT;
                float angle = (hitIndex == 0) ? -0.55 * PI : 0.75 * PI;
                threwAngleFromWH(hitPos, worldDir, centers[hitIndex], radies[hitIndex], angle, newDir, newStart, degT, procentFromStart);

                vec3 toNextHole = normalize(centers[exitWhHitIndex] - centers[hitIndex]);
                float angleTT = acos(clamp(dot(worldDir, toNextHole), -1.0, 1.0));
                vec3 axis = normalize(cross(worldDir, toNextHole));
                worldDir = normalize(rotateAround(worldDir, axis, 2.0*angleTT));

                vec3 axis2 = normalize(cross(worldDir, normalize(offset)));
                newDir = rotateAround(worldDir, axis2, degT);

                newStart = centers[exitWhHitIndex] + rotateAround(offset, axis2, degT)*(1.0 + almostZero) ;
            
                worldDir = newDir;
                start = newStart;
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



/*
void main(){
    //ska bli uniforms
    vec3 = vec3(0.0, 0.0, -2.0);
    vec3 = vec3(5.0, 0.0, 0.0);
    float u_radie = 10.0;

    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;

    vec3 worldDir = normalize(ndc.x * u_planeDir * aspect - ndc.y * u_upDir + u_lookDir);
    vec3 to_wh = - u_camPos;
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

    vec3 axis = normalize(cross(worldDir, normalize(- u_camPos)));
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