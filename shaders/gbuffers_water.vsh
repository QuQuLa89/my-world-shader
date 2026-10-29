#version 120

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 normal;
varying vec3 worldPos;
varying vec3 viewPos;

uniform mat4 gbufferModelViewInverse;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    
    vec4 vPos = gl_ModelViewMatrix * gl_Vertex;
    viewPos = vPos.xyz;
    worldPos = (gbufferModelViewInverse * vPos).xyz;
    
    gl_Position = ftransform();
}
