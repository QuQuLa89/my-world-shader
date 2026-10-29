#version 120

/*
 * my-world-shader - Refined Shadows, SSAO & God Rays
 * Designed for QuQuLa89 by Qwen
 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

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

// 画面空間微分による高精度法線復元（縞模様・段差アーティファクトを根絶）
vec3 getNormal(vec3 p) {
    vec3 n = cross(dFdx(p), dFdy(p));
    float l = length(n);
    return l > 0.0001 ? normalize(n) : vec3(0.0, 1.0, 0.0);
}

// 洗練されたSSAO（自己遮蔽バイアス付き）
float computeSSAO(vec2 coord, float depth, vec3 p, vec3 normal) {
    if (depth >= 0.9999) return 1.0;
    
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    float occlusion = 0.0;
    float radius = clamp(15.0 / length(p), 1.2, 4.0);
    
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
        // バイアスを設けてフラットな地面の自己遮蔽（縞模様）を完全防止
        if (d > 0.06 && d < 1.0) {
            float angleFactor = dot(normal, diff) / d;
            if (angleFactor > 0.20) {
                occlusion += (angleFactor - 0.20) * (1.0 - d / 1.0);
            }
        }
    }
    
    return clamp(1.0 - (occlusion / 4.0) * 1.5, 0.35, 1.0);
}

// 安全化された薄明光線（画面反転・帯状アーティファクト防止）
float computeGodRays(vec2 coord, vec3 sunPosView) {
    // 太陽がカメラの前方にあり、かつZ値が安全であること
    if (sunPosView.z >= -2.0) return 0.0;
    
    vec4 sunClip = gbufferProjection * vec4(sunPosView, 1.0);
    if (sunClip.w <= 0.0) return 0.0; // クリップ空間の後方反転を排除
    
    vec2 sunScreen = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
    
    // 太陽が画面近傍にある場合のみ描画
    if (sunScreen.x < -0.2 || sunScreen.x > 1.2 || sunScreen.y < -0.2 || sunScreen.y > 1.2) {
        return 0.0;
    }
    
    vec2 delta = (sunScreen - coord) / 8.0;
    vec2 currentCoord = coord;
    float rays = 0.0;
    
    for (int i = 0; i < 8; i++) {
        currentCoord += delta;
        float d = texture2D(depthtex0, currentCoord).r;
        if (d >= 0.9999) {
            rays += 1.0;
        }
    }
    
    float sunDist = length(sunScreen - coord);
    float falloff = clamp(1.0 - sunDist * 1.1, 0.0, 1.0);
    return (rays / 8.0) * falloff * falloff;
}

float computeCastShadow(vec3 p) {
    vec4 shadowClip = shadowProjection * (shadowModelView * vec4(p, 1.0));
    vec3 shadowScreen = shadowClip.xyz / shadowClip.w;
    vec3 shadowCoord = shadowScreen * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
        shadowCoord.y < 0.0 || shadowCoord.y > 1.0 ||
        shadowCoord.z < 0.0 || shadowCoord.z > 1.0) {
        return 1.0;
    }

    float shadowDepth = texture2D(shadowtex0, shadowCoord.xy).r;
    float bias = 0.002;
    return (shadowCoord.z - bias <= shadowDepth) ? 1.0 : 0.0;
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

    // 4. 自然で重厚な影と光（指向性陰影 & SSAO）
    if (!isSky) {
        vec3 normal = getNormal(viewPos);
        vec3 lightDir = normalize(sunHeight >= 0.0 ? sunPosition : -sunPosition);
        
        // 緩やかでリアルな指向性陰影（極端な階調跳びを排除）
        float NdotL = dot(normal, lightDir);
        float castShadow = computeCastShadow(viewPos);
        float directDiffuse = clamp(NdotL * 0.5 + 0.5, 0.0, 1.0) * mix(0.40, 1.0, castShadow);
        directDiffuse = mix(0.70, 1.15, directDiffuse * envBrightness);
        
        // 角や隙間の自然なオクルージョン影
        float ssao = computeSSAO(texcoord, depth, viewPos, normal);
        
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

    // 6. 薄明光線（安全化された光条 / God Rays）
    float godRays = 0.0;
    if (daylight > 0.15 && rainStrength < 0.7) {
        godRays = computeGodRays(texcoord, sunPosition) * daylight * (1.0 - rainStrength * 0.7) * 0.28;
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

    // 9. 寒色・鉛色のトーン補正 & 暗所引き締め
    color *= vec3(0.80, 0.86, 0.94) * mix(0.70, 1.0, envBrightness);

    // 10. 周辺減光（Vignette）
    float vignette = smoothstep(0.98, 0.55, dist);
    color *= vignette;

    // 11. 蠢くフィルムグレイン（映画的ノイズ）
    float grain = (hash(texcoord * 1000.0 + fract(frameTimeCounter * 12.0)) - 0.5) * 0.05;
    color += grain;

    // 12. 息づく世界（微細な明滅パルス）
    float pulse = 1.0 + sin(frameTimeCounter * 1.5) * 0.015;
    color *= pulse;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
