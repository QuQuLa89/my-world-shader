#version 120

/*
 * my-world-shader - Shadows, SSAO & Atmospheric God Rays Edition
 * Designed for QuQuLa89 by Qwen
 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float viewWidth;
uniform float viewHeight;

uniform float frameTimeCounter; // 経過時間（秒）
uniform float rainStrength;      // 雨の強さ (0.0:晴れ ~ 1.0:雨)
uniform float sunAngle;          // 太陽・月の角度 (0.0:日の出, 0.25:正午, 0.5:日没, 0.75:真夜中)
uniform vec3 sunPosition;        // 太陽のビュー空間位置 (長さ100.0)

uniform int heldBlockLightValue;  // メインハンド光源 (0~15)
uniform int heldBlockLightValue2; // オフハンド光源 (0~15)

uniform vec3 fogColor;                  // バニラ環境フォグ色
uniform ivec2 eyeBrightnessSmooth;      // プレイヤーの周囲光度 (x: ブロック光, y: 空の光 0~240)

varying vec2 texcoord;

// 擬似乱数ノイズ関数
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 簡易スムーズノイズ
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ビュー空間位置の復元
vec3 getViewPos(vec2 coord, float depth) {
    vec4 ndc = vec4(coord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * ndc;
    return viewPos.xyz / viewPos.w;
}

// 深度から法線（Normal）を復元
vec3 getNormal(vec2 coord, float depth, vec3 p) {
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    
    float depthR = texture2D(depthtex0, coord + vec2(texel.x, 0.0)).r;
    float depthU = texture2D(depthtex0, coord + vec2(0.0, texel.y)).r;
    
    vec3 pR = getViewPos(coord + vec2(texel.x, 0.0), depthR);
    vec3 pU = getViewPos(coord + vec2(0.0, texel.y), depthU);
    
    vec3 n = cross(pR - p, pU - p);
    float l = length(n);
    return l > 0.0001 ? normalize(n) : vec3(0.0, 1.0, 0.0);
}

// SSAO（Screen Space Ambient Occlusion: 物陰の深い闇）
float computeSSAO(vec2 coord, float depth, vec3 p, vec3 normal) {
    if (depth >= 0.9999) return 1.0;
    
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    float occlusion = 0.0;
    float radius = clamp(18.0 / length(p), 1.5, 5.0);
    
    vec2 offsets[4];
    offsets[0] = vec2( 1.0,  0.5);
    offsets[1] = vec2(-1.0, -0.5);
    offsets[2] = vec2(-0.5,  1.0);
    offsets[3] = vec2( 0.5, -1.0);
    
    for (int i = 0; i < 4; i++) {
        vec2 sampleCoord = coord + offsets[i] * texel * radius;
        float sampleDepth = texture2D(depthtex0, sampleCoord).r;
        vec3 samplePos = getViewPos(sampleCoord, sampleDepth);
        
        vec3 diff = samplePos - p;
        float d = length(diff);
        if (d > 0.04 && d < 1.2) {
            occlusion += clamp(dot(normal, diff) / d, 0.0, 1.0) * (1.0 - d / 1.2);
        }
    }
    
    return clamp(1.0 - (occlusion / 4.0) * 1.6, 0.20, 1.0);
}

// 薄明光線（Crepuscular Rays / God Rays）
float computeGodRays(vec2 coord, vec3 sunPosView) {
    if (sunPosView.z >= 0.0) return 0.0;
    
    vec4 sunClip = gbufferProjection * vec4(sunPosView, 1.0);
    vec2 sunScreen = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
    
    vec2 delta = (sunScreen - coord) / 6.0;
    vec2 currentCoord = coord;
    float rays = 0.0;
    
    for (int i = 0; i < 6; i++) {
        currentCoord += delta;
        float d = texture2D(depthtex0, currentCoord).r;
        if (d >= 0.9999) {
            rays += 1.0;
        }
    }
    
    float sunDist = length(sunScreen - coord);
    float falloff = clamp(1.0 - sunDist * 0.9, 0.0, 1.0);
    return (rays / 6.0) * falloff * falloff;
}

void main() {
    vec2 centeredCoord = texcoord - vec2(0.5);
    float dist = length(centeredCoord);

    // 1. 微細な色収差（Chromatic Aberration）
    float aberration = dist * 0.005;
    float r = texture2D(colortex0, texcoord + vec2(aberration, 0.0)).r;
    float g = texture2D(colortex0, texcoord).g;
    float b = texture2D(colortex0, texcoord - vec2(aberration, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // 2. 深度と位置の復元
    float depth = texture2D(depthtex0, texcoord).r;
    vec3 viewPos = getViewPos(texcoord, depth);
    float linearDist = length(viewPos);
    bool isSky = (depth >= 0.9999);

    // 3. 昼夜・地下の光度連動
    float sunHeight = sin(sunAngle * 6.2831853);
    float daylight = clamp(sunHeight * 2.5, 0.0, 1.0);
    float skyExposure = float(eyeBrightnessSmooth.y) / 240.0;
    float naturalLight = skyExposure * daylight;
    float envBrightness = clamp(naturalLight, 0.035, 1.0);

    // 4. 影と光の調合（指向性ライト & SSAO）
    if (!isSky) {
        // 深度から法線を復元
        vec3 normal = getNormal(texcoord, depth, viewPos);
        
        // 太陽（または月）の方向ベクトル
        vec3 lightDir = normalize(sunHeight >= 0.0 ? sunPosition : -sunPosition);
        
        // 指向性陰影（Lambertian Diffuse + 鋭いコントラスト）
        float NdotL = dot(normal, lightDir);
        float directDiffuse = clamp(NdotL * 0.6 + 0.4, 0.0, 1.0);
        directDiffuse = mix(0.45, 1.25, directDiffuse * envBrightness);
        
        // SSAO（隙間・角・接地面の深い影）
        float ssao = computeSSAO(texcoord, depth, viewPos, normal);
        
        // 陰影の適用
        color *= directDiffuse * ssao;
    }

    // 5. 手持ち光源システム（動的ライト: Dynamic Handheld Light）
    int heldLight = max(heldBlockLightValue, heldBlockLightValue2);
    vec3 dynamicLight = vec3(0.0);
    float torchInFog = 0.0;

    if (heldLight > 0) {
        float flicker = 1.0 + (noise(vec2(frameTimeCounter * 7.5, 1.23)) - 0.5) * 0.14;
        float maxRange = float(heldLight) * 0.85; 
        float lightIntensity = clamp(1.0 - (linearDist / maxRange), 0.0, 1.0);
        lightIntensity = lightIntensity * lightIntensity * flicker;
        vec3 torchWarmth = vec3(1.0, 0.72, 0.40);

        if (!isSky) {
            dynamicLight = color * torchWarmth * (lightIntensity * 1.5);
        }
        torchInFog = lightIntensity * 0.4;
    }

    // 6. 薄明光線（煙霧を貫く冷たい光条 / God Rays）
    float godRays = 0.0;
    if (daylight > 0.1 && rainStrength < 0.8) {
        godRays = computeGodRays(texcoord, sunPosition) * daylight * (1.0 - rainStrength * 0.7) * 0.35;
    }
    vec3 godRayColor = vec3(0.85, 0.90, 0.96) * godRays;

    // 7. 陰鬱とした鈍色の雨煙・霧（昼夜・洞窟完全連動型フォグ）
    vec3 dayFogColor = vec3(0.40, 0.44, 0.48);
    vec3 darkFogColor = vec3(0.012, 0.016, 0.022);
    vec3 currentFog = mix(darkFogColor, dayFogColor, envBrightness);
    
    if (heldLight > 0) {
        currentFog += vec3(1.0, 0.65, 0.35) * torchInFog;
    }

    // 煙の微小な揺らぎ
    vec2 mistCoord = texcoord * 2.5 + vec2(frameTimeCounter * 0.02, frameTimeCounter * 0.01);
    float mist = (noise(mistCoord) - 0.5) * 0.12 * envBrightness;

    // 霧の減衰
    float baseDensity = 0.024 + rainStrength * 0.030;
    float fogFactor = 1.0 - exp(-baseDensity * linearDist);

    if (isSky) {
        fogFactor = 0.88 + rainStrength * 0.10;
    }

    fogFactor = clamp(fogFactor + mist * (1.0 - exp(-0.02 * linearDist)), 0.0, 1.0);

    // 霧と薄明光線の合成
    color = mix(color + dynamicLight, currentFog, fogFactor) + godRayColor;

    // 8. 輝度算出 & 彩度調整
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    float localSaturation = 0.30;
    if (heldLight > 0 && !isSky) {
        float warmArea = clamp(1.0 - (linearDist / 8.0), 0.0, 1.0);
        localSaturation += warmArea * 0.22;
    }
    color = mix(vec3(lum), color, clamp(localSaturation, 0.0, 1.0));

    // 9. 寒色・鉛色のトーン補正 & 夜間・暗所の暗黒引き締め
    color *= vec3(0.80, 0.86, 0.94) * mix(0.70, 1.0, envBrightness);

    // 10. 周辺減光（Vignette）
    float vignette = smoothstep(0.88, 0.32, dist);
    color *= vignette;

    // 11. 蠢くフィルムグレイン（映画的ノイズ）
    float grain = (hash(texcoord * 1000.0 + fract(frameTimeCounter * 12.0)) - 0.5) * 0.05;
    color += grain;

    // 12. 息づく世界（微細な明滅パルス）
    float pulse = 1.0 + sin(frameTimeCounter * 1.5) * 0.015;
    color *= pulse;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
