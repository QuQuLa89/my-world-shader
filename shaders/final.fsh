#version 120

/*
 * my-world-shader - Environment-Adaptive Fog & Dynamic Light Edition
 * Designed for QuQuLa89 by Qwen
 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;

uniform float frameTimeCounter; // 経過時間（秒）
uniform float rainStrength;      // 雨の強さ (0.0:晴れ ~ 1.0:雨)

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

// カメラからの視線距離（ブロック数）
float getLinearDistance(vec2 coord, float depth) {
    vec4 ndc = vec4(coord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * ndc;
    viewPos /= viewPos.w;
    return length(viewPos.xyz);
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

    // 2. 深度バッファから距離を算出
    float depth = texture2D(depthtex0, texcoord).r;
    float linearDist = getLinearDistance(texcoord, depth);
    bool isSky = (depth >= 0.9999);

    // 3. 環境の明るさ適応（光度に応じたフォグ調光）
    // プレイヤーの頭上・周囲の空光とブロック光 (0.0 ~ 1.0)
    float skyLight = float(eyeBrightnessSmooth.y) / 240.0;
    float blockLight = float(eyeBrightnessSmooth.x) / 240.0;
    
    // バニラフォグ自体の輝度 (夜や洞窟では 0 に近づく)
    float vanillaFogLum = dot(fogColor, vec3(0.299, 0.587, 0.114));
    
    // 環境光係数（昼の地上なら 1.0、洞窟や夜は 0.04 の暗黒へ沈降）
    float envBrightness = clamp(max(skyLight * 0.85, vanillaFogLum * 0.9), 0.04, 1.0);

    // 4. 手持ち光源システム（動的ライト: Dynamic Handheld Light）
    int heldLight = max(heldBlockLightValue, heldBlockLightValue2);
    vec3 dynamicLight = vec3(0.0);
    float torchInFog = 0.0;

    if (heldLight > 0) {
        // 風雨に揺らめく炎の微細な明滅（Flicker）
        float flicker = 1.0 + (noise(vec2(frameTimeCounter * 7.5, 1.23)) - 0.5) * 0.14;
        
        // 照射限界距離（最大約11〜12ブロック）
        float maxRange = float(heldLight) * 0.85; 
        
        // 2乗減衰
        float lightIntensity = clamp(1.0 - (linearDist / maxRange), 0.0, 1.0);
        lightIntensity = lightIntensity * lightIntensity * flicker;

        // 琥珀色の灯火
        vec3 torchWarmth = vec3(1.0, 0.72, 0.40);

        if (!isSky) {
            dynamicLight = color * torchWarmth * (lightIntensity * 1.5);
        }
        // 手元の霧をほんのり照らすフォグ散乱成分
        torchInFog = lightIntensity * 0.4;
    }

    // 5. 陰鬱とした鈍色の雨煙・霧（環境光連動型フォグ）
    // 昼の煙霧色（冷たい鈍色）
    vec3 dayFogColor = vec3(0.40, 0.44, 0.48);
    // 暗所・洞窟の霧色（底なしの漆黒）
    vec3 darkFogColor = vec3(0.012, 0.015, 0.018);

    // 環境光度に合わせて霧の色をスムーズに変調（暗所では霧も真っ暗に沈む）
    vec3 currentFog = mix(darkFogColor, dayFogColor, envBrightness);
    
    // 手持ち松明の光が手元の霧に当たっている場合、霧自体を微かに琥珀色に照らす
    if (heldLight > 0) {
        currentFog += vec3(1.0, 0.65, 0.35) * torchInFog;
    }

    // 煙の微小な揺らぎ（ゆっくり漂うミスト）
    vec2 mistCoord = texcoord * 2.5 + vec2(frameTimeCounter * 0.02, frameTimeCounter * 0.01);
    float mist = (noise(mistCoord) - 0.5) * 0.12 * envBrightness;

    // 霧の減衰（指数関数的フォグ）
    float baseDensity = 0.024 + rainStrength * 0.030;
    float fogFactor = 1.0 - exp(-baseDensity * linearDist);

    // 空（無限遠）の煙幕処理
    if (isSky) {
        fogFactor = 0.88 + rainStrength * 0.10;
    }

    // ミストの揺らぎを加算
    fogFactor = clamp(fogFactor + mist * (1.0 - exp(-0.02 * linearDist)), 0.0, 1.0);

    // 霧の合成
    color = mix(color + dynamicLight, currentFog, fogFactor);

    // 6. 輝度算出 & 彩度調整
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    float localSaturation = 0.30;
    if (heldLight > 0 && !isSky) {
        float warmArea = clamp(1.0 - (linearDist / 8.0), 0.0, 1.0);
        localSaturation += warmArea * 0.22;
    }
    color = mix(vec3(lum), color, clamp(localSaturation, 0.0, 1.0));

    // 7. 寒色・鉛色のトーン補正
    color *= vec3(0.80, 0.86, 0.94);

    // 8. 周辺減光（Vignette）
    float vignette = smoothstep(0.88, 0.32, dist);
    color *= vignette;

    // 9. 蠢くフィルムグレイン（映画的ノイズ）
    float grain = (hash(texcoord * 1000.0 + fract(frameTimeCounter * 12.0)) - 0.5) * 0.05;
    color += grain;

    // 10. 息づく世界（微細な明滅パルス）
    float pulse = 1.0 + sin(frameTimeCounter * 1.5) * 0.015;
    color *= pulse;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
