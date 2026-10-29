#version 120

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
attribute vec4 mc_Entity;
varying float isLavaFlag;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    isLavaFlag = (abs(mc_Entity.x - 10002.0) < 0.5) ? 1.0 : 0.0;
    
    gl_Position = ftransform();
}
