#version 330

uniform vec2 resolution;
uniform float currentTime;
uniform vec3 camPos;
uniform vec3 camDir;
uniform vec3 camUp;
uniform sampler2D tex;
uniform bool showStepDepth;

in vec3 pos;

out vec3 color;

#define PI 3.1415926535897932384626433832795
#define RENDER_DEPTH 800
#define CLOSE_ENOUGH 0.00001

#define BACKGROUND -1
#define BALL 0
#define BASE 1

#define GRADIENT(pt, func) vec3( \
    func(vec3(pt.x + 0.0001, pt.y, pt.z)) - func(vec3(pt.x - 0.0001, pt.y, pt.z)), \
    func(vec3(pt.x, pt.y + 0.0001, pt.z)) - func(vec3(pt.x, pt.y - 0.0001, pt.z)), \
    func(vec3(pt.x, pt.y, pt.z + 0.0001)) - func(vec3(pt.x, pt.y, pt.z - 0.0001)))

const vec3 LIGHT_POS[] = vec3[](vec3(5, 18, 10));

///////////////////////////////////////////////////////////////////////////////
// BACKGROUND + RAY DIRECTION
vec3 getBackground(vec3 dir) {
  float u = 0.5 + atan(dir.z, -dir.x) / (2 * PI);
  float v = 0.5 - asin(dir.y) / PI;
  vec4 texColor = texture(tex, vec2(u, v));
  return texColor.rgb;
}

vec3 getRayDir() {
  vec3 xAxis = normalize(cross(camDir, camUp));
  return normalize(pos.x * (resolution.x / resolution.y) * xAxis + pos.y * camUp + 5 * camDir);
}

///////////////////////////////////////////////////////////////////////////////
// SHAPES
// Non - linear
//float cube(vec3 p) {
//return max(max(abs(p.x), abs(p.y)), abs(p.z)) - 1; // 1 = radius
//}

float sdTorus( vec3 p, vec2 t) {
  // torus in xz plane
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float planeSDF(vec3 samplePoint){
    // plane = Y=-1
    return (samplePoint.y + 1);
}

float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

float unionSDF(float distA, float distB) {
    return min(distA, distB);
}

float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}

float blendSDF(float a, float b) {
 float k = 0.2;
 float h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1);

 return mix(b, a, h) - k * h * (1 - h);
}

float oldSceneSDF(vec3 samplePoint) {
    // center (0, 3, 0) major r=3 minor r=1
    float torus = sdTorus( samplePoint - vec3(0,3,0), vec2(3,1));
    return torus;
}

float sceneSDF(vec3 samplePoint) {
    // center (0, 3, 0) major r=3 minor r=1
    float torus = sdTorus( samplePoint - vec3(0,3,0), vec2(3,1));
    float d = min(torus, planeSDF(samplePoint));
    return d;
}

vec3 getNormal(vec3 pt) {
  return normalize(GRADIENT(pt, sceneSDF));}

vec3 getColor(vec3 pt) {
  // if the point is in the plane - colour it else dont
  vec3 colourA = vec3(0.4, 0.4, 1);
  vec3 colourB = (vec3(0.4, 1, 0.4));

  float dist = oldSceneSDF(pt);

  if (planeSDF(pt) <= CLOSE_ENOUGH){
    float d = mod(dist, 1);
    float bound = mod(dist, 5);

    // every 5 units, draw ring of black 0.25 units wide
    if (bound > 4.75){
    return( vec3(0,0,0));
    }

    // else mix the colours in gradient
    return mix(colourB, colourA, d);
    }
  return vec3(1);
}

float min4(float f1, float f2, float f3, float f4){
    // returns minimum of 4 values
    float m;
    m = min(f1, f2);
    m = min(m, f3);
    m = min(m, f4);

    return m;
}

///////////////////////////////////////////////////////////////////////////////
// SHADING AND ILLUMINATION
// added specular lighting
float shade(vec3 eye, vec3 pt, vec3 n) {
  float ambientCoef = 0.1;
  float diffuseCoef = 1.0;
  float specularCoef = 1.0;
  float specularShin = 256;

  float val = 0;

  val += ambientCoef;

  for (int i = 0; i < LIGHT_POS.length(); i++) {
    vec3 l = normalize(LIGHT_POS[i] - pt);
    val += max(dot(n, l), 0);

    // specualr coefficeint of light
    // formula from https://www.shadertoy.com/view/lt33z7
    vec3 N = normalize(n);
    vec3 L = l;
    vec3 V = normalize(eye - pt);
    vec3 R = normalize(reflect(-L, N));

    float dotLN = dot(L,N);
    float dotRV = dot(R,V);

    if (dotLN >= 0 && dotRV >= 0){
      val += dotLN * pow(dotRV, specularShin);
    }

  }
  return val;
}

vec3 illuminate(vec3 camPos, vec3 rayDir, vec3 pt) {
  vec3 c, n;
  n = getNormal(pt);
  c = getColor(pt);
  return shade(camPos, pt, n) * c;
}

/////////////////////////////////////////////////////////////////////////////
// RAYMARCHING
vec3 raymarch(vec3 camPos, vec3 rayDir) {
  int step = 0;
  float t = 0;

  for (float d = 1000; step < RENDER_DEPTH && abs(d) > CLOSE_ENOUGH; t += abs(d)) {
      d = sceneSDF(camPos + t * rayDir);
      step++;
    }

  if (step == RENDER_DEPTH) {
      return getBackground(rayDir);
    } else if (showStepDepth) {
      return vec3(float(step) / RENDER_DEPTH);
    } else {
      return illuminate(camPos, rayDir, camPos + t * rayDir);
    }
}

///////////////////////////////////////////////////////////////////////////////

void main() {
  color = raymarch(camPos, getRayDir());
}

