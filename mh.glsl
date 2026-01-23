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
const float almostZero = 1e-3;
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


void threwAngleFromWH(vec3 hitPoint, vec3 worldDir, vec3 objPos, float radius, float extraRotation, out float degT, float procentFromStart){

    vec3 n = normalize(objPos - hitPoint);
    float amplitude = dot(worldDir, n);
    float t_amplitude = length(worldDir - amplitude * n);
    float distRot = (t_amplitude / amplitude) * (u_tubeLength * procentFromStart );
    float deflection = (( distRot) / (radius*2.0*PI)) - floor((distRot) / (radius*2.0*PI));

    vec3 axis = normalize(cross(worldDir, n));
    degT = (-2.0*PI*deflection);
}

bool goesThroughHole(vec3 pos, vec3 dir, vec3 center, float rs, float R_outer){

    vec3 toWH = center - pos;
    
    float distToWH = length(toWH);
    float percToRs = (distToWH - rs) / (R_outer - rs);

    float minAngle = atan(rs / distToWH);
    float angleAtR_outer = minAngle * 1.5;
    float angleAtRs = PI;

    //räknar vad som skuggans vinkel går baserat på hur långt in i böjd spacetime skiten...
    float cosLimit = cos(mix(angleAtR_outer, angleAtRs, 1.0 - percToRs));
    float cosAngle = dot(normalize(dir), normalize(toWH));

    /*
    Nu mappas det linjärt med avstånd mellan r_outer och rs, till fallinvinkel. Det borde börja med att ha samma ökning 
    som om jag närmade mig bara ett klot, alltså 0 yttre kurvatur. Sen borde det öka mer i derivatan när kommer närmare rs, och det blir 
    mer kurvarur lixom. Bör ju hänga ihop logiskt på nått sätt med kanske med deflection funktionen lixom ? :/ idk exakt hur atm. 
    Alltså i swartschild fallet ska jag ju ha binary filen aproximation där blir "röd", eller alltså den när aprox som skapade
    för fps-*****. Nu i detta fall bör egentligen hitta nån enkel tracteble funktion iställe - jö.  
    */

    return cosAngle > cosLimit;

}

//Net change in angle = net change in position? assumption
float  deflection_DL(vec3 pos, vec3 dir, vec3 center, float rs, float R_outer, out vec3 newStart, out vec3 newDir){

    vec3 oc = pos - center;
    float b = dot(dir, oc);
    float c = dot(oc, oc) - R_outer*R_outer;
    float h = b*b - c;
    float tExit = -b + sqrt(h);

    vec3 noDefPos = pos + dir * tExit;
    vec3 offset = noDefPos - center;
    vec3 noDefDir = dir;

    vec3 toWH = center - pos;
    
    float distToWH = length(toWH);
    float percToRs = (distToWH - rs) / (R_outer - rs);

    //hade jag blandad ihop tangens med sinus? Det var ju extremt klantigt...

    //the angle of shadow if only nu outer curvature
    float minAngle = atan(rs / distToWH);
    //the shadow angle when at distance R_outer
    float angleAtR_outer = minAngle * 1.5;
    //the angle what light go through when at rs, so like this is pi means that all angles of path co down in to the hole due to outer curvatuere.
    //When going from R_outer to rs the angle increase from minAngle to angleAtRs, this is obiously angle to the "shadow" or whatever
    float angleAtRs = PI;
    //angleMax is like the angle at where there is no effect, this should not exist in real black hole, but this wont make code and math
    //have to deal with overlapping curving spacetimes (unless they overlapp becuase they are very close, but program should just not fucking care about/allow that for now..)
    
    float angleMaxAtR_outer = PI * 0.5;
    float fixedMinAngle = atan(rs / R_outer) * 2.0;
    //Bytte nyss fixedMinAngle mot angleAtR_outer i denna uträkning, känns logiskt. Kom ej ihåg var jag hade fixedMinAngle innan dock :/
    //Så på ett sätt känns det nästan lite "för uppenbart" :/ Men det funkade, så kör med denna istället. Den har dock egenskapen att när jag 
    //Är nere långt nära rs så ser det ut som att procentageBiggerAtR_outer blir 0, alltså ingen yttre deflection alls. Vilket är lite konstigt kanske? 
    
    //S Hmm, det funkar generelt sätt men det är nått som är skumt när jag går förbi R_outer, det blir som en "hopp" i deflectione kanten :/. Kanske 
    //löser sig själv om derivatan ovan fixas, men det känns ändå lite skume som att det ej borde hända... :/
     
    float procentageBiggerAtR_outer = clamp((angleMaxAtR_outer - fixedMinAngle) / (PI - fixedMinAngle), 0.0, 1.0);

    float cosLimit = cos(mix(angleAtR_outer, angleAtRs, 1.0 - percToRs));
    float edgeAngle = acos(cosLimit);
    float maxAngle = mix(edgeAngle, PI, procentageBiggerAtR_outer);

    float cosAngle = dot(normalize(dir), normalize(toWH));
    float Angle = acos(clamp(cosAngle, -1.0, 1.0));

    // defPerc: 1 = closest to hole (fixedMinAngle), 0 = maxAngle
    float defPerc = 1.0 - (Angle - edgeAngle) / (maxAngle - edgeAngle);
    defPerc = clamp(defPerc, 0.0, 1.0);
    //if(acos(cosAngle) > maxAngle){
    // defPerc = 0.0;
    //}
    if(Angle >= maxAngle){
        newDir = dir;
        newStart = noDefPos;
        return 0.0; 
    }
   // float proDefArea = 1.0 - (cosLimit - cosAngle) / (cosLimit + 1.0);
   // return defPerc;
    //temp function
    //float f = PI*2.0*pow((1.0 - percToRs) / percToRs, 4.0);
    //float f = PI * 1.0 * percToRs; //PI*2.0*pow((1.0 - percToRs) / percToRs, 4.0);
    //defPer

    float f = ((((-log(-defPerc +1.0)/(defPerc*3.0)) )) - 0.3330669073875)*(defPerc*defPerc*0.25)*15.0;
  //  return f;
    //float f = pow(x, k) / (1.0 - x);

    vec3 axis = normalize(cross(dir, normalize(toWH)));
    vec3 axis2 = normalize(cross(normalize(toWH), normalize(offset)));

    offset = rotateAround(offset, axis, f);
    noDefDir = rotateAround(noDefDir, axis, f);

    newDir = noDefDir;
    newStart = center + offset;

    return f; //f / (2.0 * PI);
}

float spiralInChange1(vec3 pos, vec3 dir, vec3 center, float rs, float R_outer, out vec3 newStart, out vec3 newDir){

    vec3 oc = pos - center;
    float b = dot(dir, oc);
    float c = dot(oc, oc) - R_outer*R_outer;
    float h = b*b - c;
    float tExit = -b + sqrt(h);

    vec3 noDefPos = pos + dir * tExit;
    vec3 offset = (noDefPos - center) / (rs * R_outer);
    vec3 noDefDir = dir;

    vec3 toWH = center - pos;
    
    float distToWH = length(toWH);
    //hur långt till rs, från R_outer
    float percToRs = (distToWH - rs) / (R_outer - rs);

    float minAngle = atan(rs / distToWH);
    float angleAtR_outer = minAngle * 1.5;
    float angleAtRs = PI;

    float angleMaxAtR_outer = PI * 0.5;

    float procentageBiggerAtR_outer = clamp((angleMaxAtR_outer - angleAtR_outer) / (PI - angleAtR_outer), 0.0, 1.0);
    float cosLimit = cos(mix(angleAtR_outer, angleAtRs, 1.0 - percToRs));
    float edgeAngle = acos(cosLimit);
    float maxAngle = mix(edgeAngle, 0.0, procentageBiggerAtR_outer);

    float cosAngle = dot(normalize(dir), normalize(toWH));
    float Angle = acos(clamp(cosAngle, -1.0, 1.0));

    // defPerc: 1 = closest to hole (fixedMinAngle), 0 = maxAngle
    float Angle2 = Angle;
    float maxAngle2 = maxAngle;
    float edgeAngle2 = edgeAngle;
    float defPerc = (Angle2 - maxAngle2) / (edgeAngle2 - maxAngle2);
    defPerc = clamp(defPerc, 0.0, 1.0);
    //if(acos(cosAngle) > maxAngle){
    // defPerc = 0.0;
    //}

    newDir = dir;
    newStart = pos;
   if(Angle <= maxAngle){
      //  newDir = dir;
      //  newStart = noDefPos;
        return 0.0; 
    }
   // return defPerc;
   // float proDefArea = 1.0 - (cosLimit - cosAngle) / (cosLimit + 1.0);

    //temp function
    //float f = PI*2.0*pow((1.0 - percToRs) / percToRs, 4.0);
    //float f = PI * 1.0 * percToRs; //PI*2.0*pow((1.0 - percToRs) / percToRs, 4.0);
    //defPer

    float f = ((((-log(-defPerc +1.0)/(defPerc*3.0)) )) - 0.3330669073875)*(defPerc*defPerc*0.25)*15.0;

    return f;
    //float f = pow(x, k) / (1.0 - x);

    vec3 axis = normalize(cross(dir, normalize(toWH)));
    vec3 axis2 = normalize(cross(normalize(toWH), normalize(offset)));

    return 0.0; //f / (2.0 * PI);
}


float spiralInChange2(vec3 camLoc, vec3 pos, vec3 dir, vec3 center, float rs, float R_outer, out vec3 newStart, out vec3 newDir){

    vec3 oc = pos - center;
    float b = dot(dir, oc);
    float c = dot(oc, oc) - R_outer*R_outer;
    float h = b*b - c;
    float tExit = -b + sqrt(h);
   // const float almostZero = 1e-3;
    //vec3 noDefPos = pos + dir * tExit;
    //vec3 offset = (noDefPos - center) / (rs * R_outer);
    //vec3 noDefDir = dir;

    vec3 toWH = center - pos;
    
    float distToWH = length(toWH);
    //hur långt till rs, från R_outer
    float percToRs = (distToWH - rs) / (R_outer - rs);

    float minAngle = atan(rs / distToWH);
    float angleAtR_outer = minAngle * 1.5;
    float angleAtRs = PI;

    float angleMaxAtR_outer = PI * 0.5;

    float procentageBiggerAtR_outer = clamp((angleMaxAtR_outer - angleAtR_outer) / (PI - angleAtR_outer), 0.0, 1.0);
    float cosLimit = cos(mix(angleAtR_outer, angleAtRs, 1.0 - percToRs));
    float edgeAngle = acos(cosLimit);
    float maxAngle = mix(edgeAngle, 0.0, procentageBiggerAtR_outer);

    float cosAngle = dot(normalize(dir), normalize(toWH));
    float Angle = acos(clamp(cosAngle, -1.0, 1.0));

    // defPerc: 1 = closest to hole (fixedMinAngle), 0 = maxAngle
    float Angle2 = Angle;
    float maxAngle2 = maxAngle;
    float edgeAngle2 = edgeAngle;
    float defPerc = (Angle2 - maxAngle2) / (edgeAngle2 - maxAngle2);
    defPerc = clamp(defPerc, 0.0, 1.0);

    float percInShadow = Angle / edgeAngle;

    //Går alldrig till 0 när tittar in, vilket det kör man tittar ut, vilket då är en skillnad :/ Vilket det kanske ska/inte vara? idk :/
    //bör tänka på matte symetrin där lite mer noga sen. Bäst vore att undersöka med en numerisk lösning av tex swarschild situationen + lite andra saker.
    //ÄR ju verkligen inte så att jag tror att denna rotation och newDir följer samma f funktion som yttre deflection.... Det används nu bara för att 
    //den typ har rätt egenskaper och jag pallar inte fixa.... Den den rätta rotation bör ju antagligen kanske på nått sätt iaf hänga ihop / vara relaterad till denna f. 
    if(Angle < maxAngle2){
        // newDir = dir;
        // newStart = noDefPos;
        // return 0.0; 
        //return 0.0; 
    }

    float f =  ((((-log(-percInShadow + 1.0)/(percInShadow*3.0)) )) - 0.3330669073875)*(percInShadow*percInShadow*0.25)*15.0;

    vec3 testStartOffsetLOL = normalize(camLoc - center) * rs * (1.0 + almostZero);
   // vec3 testDirLOL = -normalize(testStartOffsetLOL);
    vec3 testDirLOL = normalize(-testStartOffsetLOL);
    vec3 axis = normalize(cross(dir, normalize(toWH)));
    //vec3 axis2 = normalize(cross(normalize(toWH), normalize(offset)));

  //  testStartOffsetLOL = rotateAround(testStartOffsetLOL, axis, f);

    // rotateAround(testDirLOL, axis, -f);

    newDir = rotateAround(dir, axis, -f);
    newStart = center + testStartOffsetLOL;

    return percInShadow;
}


void main(){
    //har radie u_radie
    vec3 wh1pos = vec3(0.0, 0.0, -u_distance * 0.5);
    vec3 wh2pos = vec3(0.0, 0.0, u_distance * 0.5);

    float whSr = u_radie;
    float sphereRadie = 4.0;
    //dessa har radie sphereRadie
    //alla dessa arrayer bör egenetligen vara uniforms...
    vec3 wh1sA = vec3(u_radie*9.0, 0.0, -u_distance * 0.5);
    vec3 wh1sB = vec3(0.0, u_radie*6.0, -u_distance * 0.5);

    vec3 wh2sA = vec3(-u_radie*9.0, 0.0, u_distance * 0.5);
    vec3 wh2sB = vec3(0.0, -u_radie*6.0, u_distance * 0.5);

    float ofac = 4.0;

    vec3 centers[6] = vec3[6](wh1pos, wh2pos, wh1sA, wh1sB, wh2sA, wh2sB);
    float radies[6] = float[6](u_radie*ofac, u_radie*ofac, sphereRadie, sphereRadie, sphereRadie, sphereRadie);
    float colorsR[6] = float[6](0.0, 0.0, 1.0, 1.0, 0.0, 0.5);
    float colorsG[6] = float[6](0.0, 0.0, 0.0, 0.3, 0.5, 0.0);
    float colorsB[6] = float[6](0.0, 0.0, 0.3, 0.0, 1.0, 1.0);
    
    vec2 ndc = vUv * 2.0 - 1.0;
    float aspect = u_resolution.x / u_resolution.y;
    float scale = tan(radians(100.0) * 0.5);
    vec3 worldDir = normalize(u_rightDir * (ndc.x * aspect * scale) + -u_upDir    * (ndc.y * scale) +u_lookDir);

    //vec3 to_wh = - u_camPos;
    //float distToWH = length(to_wh);
    //float angleToWH = acos(dot(worldDir, normalize(to_wh)));
    //assuming worldDir = c = 1.0
    //ignoring special relativistic effects obviously...
    // small constants
    
   // const float almostZero = 1e-3;
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

           vec3 toHitWH = u_camPos - centers[hitIndex];
           float distToHitWH = length(toHitWH);

            if(distToHitWH < u_radie*ofac ){
                hitPos = u_camPos;
            }

            //Check deflection from the outer effect, if critical, do the tube. Otherwise deflect.             
            if (goesThroughHole(hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac)) {
                
                acc = vec3(0.0);
                break;
               // spiralInChange1 will calculate the total deflection if I pass through a thing with 0 straigt tube. 
               // It does not have implementation of causing correct change in dir and start yet though., I wont use this for now.
               //Although I do think that that regular spiralInChange1 could be really cool, elegant and resemble a surved long in tube type situation or whatever idk
               //Would be cool to investigate. I Ill for now use a spiralInChangae2. That should calculate the rotation caused by the
               // outer curvature of this side of the wormhole, then let the code for tube make their rotation, and then it should be another rotation deflection shit 
               //caused by when going out of the other side. 
                //
                //float test =  spiralinChange(hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac, hitPos, worldDir);

                //denna test2 skall då hitta en hitpos på swarzchild-klotet och en worldDir där vi åker in. Just nu gissar bara en tracteble funktion, 
                //Kör nu med lika dan deflection som i spiralInChange1. Ska sedan idellt sätt derivera exakt lösning baserat på deflection f eller b impact parameter? 
                //Eller testa med numerisk lösning på tex swarszchild sh/wh. 
                float test2 =  spiralInChange2(start, hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac, hitPos, worldDir);
             //   acc += 0.5*  vec3(test2,test2, test2);
                //break;
                //
                //Måste updatera denna och tänka på att nu kommer jag inte
                //növdändigtvis att telerporteras bara för att jag träffar hålet.
               int exitWhHitIndex = (hitIndex == 0) ? 1 : 0;

                vec3 offset = normalize(hitPos - centers[hitIndex]) * u_radie*(1.0 + almostZero);
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

                        worldDir = rotateAround(worldDir, axis2, deg);;
                        start = centers[exitWhHitIndex] + rotateAround(offset, axis2, deg)*(u_radie + almostZero) ;;
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
                        start = centers[hitIndex] + rotateAround(offset, axis2, deg)*(u_radie + almostZero);;                
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

                    worldDir = rotateAround(worldDir, axis2, degT);
                    start = centers[exitWhHitIndex] + rotateAround(offset, axis2, degT) * (1.0);
                }

            }else{
                // acc += vec3(0.25, 0.0, 0.0);
                float val = deflection_DL(hitPos, worldDir, centers[hitIndex], u_radie, u_radie*ofac, start, worldDir);
                //acc = 0.5*vec3(1.0, val, val);
               // break;
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


