#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;

void main() {
    vec4 texColor = texture2D(texture, texcoord) * color;
    
    // Discard transparent pixels on cutout geometry (grass, flowers, torches, crops, etc.)
    if (texColor.a < 0.1) discard;
    
    // Apply vanilla lightmap
    vec4 light = texture2D(lightmap, lmcoord);
    texColor.rgb *= light.rgb;
    
    gl_FragColor = texColor;
}
