#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying float isLavaFlag;

void main() {
    vec4 texColor = texture2D(texture, texcoord) * color;
    
    // Discard transparent pixels on cutout geometry (grass, flowers, torches, crops, etc.)
    if (texColor.a < 0.1) discard;
    if (isLavaFlag > 0.5) {
        gl_FragColor = vec4(texColor.rgb, 0.85);
        return;
    }
    
    // Apply vanilla lightmap
    vec4 light = texture2D(lightmap, lmcoord);
    texColor.rgb *= light.rgb;
    
    gl_FragColor = vec4(texColor.rgb, 1.0);
}
