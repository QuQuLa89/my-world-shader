#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 normal;
varying vec3 worldPos;
varying vec3 viewPos;
varying float isWaterFlag;
varying float isLavaFlag;

uniform mat4 gbufferModelViewInverse;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    // block.properties で割り当てた水ブロックを判定します。
    isWaterFlag = (abs(mc_Entity.x - 10001.0) < 0.5) ? 1.0 : 0.0;
    isLavaFlag = (abs(mc_Entity.x - 10002.0) < 0.5) ? 1.0 : 0.0;
    
    vec4 vPos = gl_ModelViewMatrix * gl_Vertex;
    viewPos = vPos.xyz;
    worldPos = (gbufferModelViewInverse * vPos).xyz;
    
    gl_Position = ftransform();
}
