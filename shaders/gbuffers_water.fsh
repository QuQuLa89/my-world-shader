#version 120

uniform sampler2D texture;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform float sunAngle;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 normal;
varying vec3 worldPos;
varying vec3 viewPos;

// 深度からビュー空間位置を復元
vec3 getViewPos(vec2 coord, float depth) {
    vec4 ndc = vec4(coord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 vPos = gbufferProjectionInverse * ndc;
    return vPos.xyz / vPos.w;
}

// 簡易スムーズ波紋ノイズ
float waveNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    vec2 p0 = i;
    vec2 p1 = i + vec2(1.0, 0.0);
    vec2 p2 = i + vec2(0.0, 1.0);
    vec2 p3 = i + vec2(1.0, 1.0);
    
    float a = fract(sin(dot(p0, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(p1, vec2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(p2, vec2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(p3, vec2(127.1, 311.7))) * 43758.5453);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    vec4 texColor = texture2D(texture, texcoord) * color;
    
    // 画面座標の取得
    vec2 screenCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    
    // 水面のビュー空間位置
    vec3 surfacePos = getViewPos(screenCoord, gl_FragCoord.z);
    
    // 水底（不透明ブロック）の深度とビュー空間位置
    float opaqueDepth = texture2D(depthtex1, screenCoord).r;
    vec3 floorPos = getViewPos(screenCoord, opaqueDepth);
    
    // 水深（メートル単位）
    float waterDepth = length(surfacePos - floorPos);
    
    // 穏やかな微細波紋（2層合成）
    vec2 waveUV1 = worldPos.xz * 1.5 + vec2(frameTimeCounter * 0.4, frameTimeCounter * 0.2);
    vec2 waveUV2 = worldPos.xz * 2.2 - vec2(frameTimeCounter * 0.3, frameTimeCounter * 0.5);
    float wave1 = waveNoise(waveUV1);
    float wave2 = waveNoise(waveUV2);
    vec2 waveOffset = vec2(wave1 - wave2, (wave1 + wave2) * 0.5 - 0.5) * 0.08;
    vec3 waveNormal = normalize(normal + vec3(waveOffset.x, 0.0, waveOffset.y));
    
    // 濁ったターコイズブルーの吸光カラー設計
    vec3 shallowTurquoise = vec3(0.18, 0.55, 0.60); // 浅瀬の澄んだターコイズブルー
    vec3 deepTurquoise    = vec3(0.03, 0.20, 0.25); // 深淵の暗く沈んだ濁りターコイズ
    
    // 水深に応じた吸光度（Beer-Lambert則）
    float depthAbsorption = 1.0 - exp(-waterDepth * 0.45);
    vec3 waterColor = mix(shallowTurquoise, deepTurquoise, depthAbsorption);
    
    // リアルな透明度（浅瀬は極めて透明、深水は濁る）
    float waterAlpha = clamp(0.15 + depthAbsorption * 0.72, 0.15, 0.88);
    
    // フレネル反射（水面を見下ろすと透き通り、斜めから見ると空光や光沢を反射）
    vec3 viewDir = normalize(-surfacePos);
    float NdotV = clamp(dot(waveNormal, viewDir), 0.0, 1.0);
    float fresnel = 0.04 + 0.96 * pow(1.0 - NdotV, 4.0);
    
    // 太陽光の微細な鏡面反射（スペキュラハイライト）
    float sunHeight = sin(sunAngle * 6.2831853);
    vec3 lightDir = normalize(sunHeight >= 0.0 ? sunPosition : -sunPosition);
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = clamp(dot(waveNormal, halfDir), 0.0, 1.0);
    float specular = pow(NdotH, 64.0) * fresnel * clamp(sunHeight * 2.0, 0.0, 1.0);
    vec3 specColor = vec3(0.85, 0.92, 0.96) * specular;
    
    // フレネルによる反射空色のブレンド
    vec3 skyReflection = vec3(0.40, 0.50, 0.58) * (fresnel * 0.60);
    
    // 最終カラー合成
    vec3 finalColor = waterColor + skyReflection + specColor;
    
    // バニラライトマップの適用
    vec3 lightmapColor = clamp(lmcoord.x * vec3(1.0, 0.9, 0.7) + lmcoord.y * vec3(0.8, 0.85, 0.9), 0.15, 1.0);
    finalColor *= lightmapColor;
    
    gl_FragColor = vec4(finalColor, waterAlpha);
}
