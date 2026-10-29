#version 120

/*
 * my-world-shader - Gloomy Rain Fog & Handheld Dynamic Light Edition
 * Designed for QuQuLa89 by Qwen
 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;

uniform float frameTimeCounter; // 経過時間（秒）
uniform float rainStrength;      // 雨の強さ (0.0:晴れ ~ 1.0:雨)

uniform int heldBlockLightValue;  // メインハンド光源 (0~15)
uniform int heldBlockLightValue2; // オフハンド光源 (0~15)

varying vec2 texcoord;

// 擬似乱数ノイズ関数
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 簡易スムーズノイズ（煙・ミスト・炎の揺らぎ用）
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

// カメラからの視線距離（ブロック数/メートル）を算出
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

    // 3. 手持ち光源システム（動的ライト: Dynamic Handheld Light）
    int heldLight = max(heldBlockLightValue, heldBlockLightValue2);
    vec3 dynamicLight = vec3(0.0);

    if (heldLight > 0 && !isSky) {
        // 風雨に揺らめく炎の微細な明滅（Flicker）
        float flicker = 1.0 + (noise(vec2(frameTimeCounter * 7.5, 1.23)) - 0.5) * 0.14;
        
        // 照射限界距離（最大約11〜12ブロック。広げすぎず、闇を引き立てる）
        float maxRange = float(heldLight) * 0.85; 
        
        // 2乗減衰（手元は温かく、数歩離れると急速に闇に溶け込む）
        float lightIntensity = clamp(1.0 - (linearDist / maxRange), 0.0, 1.0);
        lightIntensity = lightIntensity * lightIntensity * flicker;

        // 灯火の色: 鉛色の世界に灯る、哀愁漂う温かな琥珀色
        vec3 torchWarmth = vec3(1.0, 0.72, 0.40);

        // 地面や壁をほんのり照らす加算光
        dynamicLight = color * torchWarmth * (lightIntensity * 1.5);
    }

    // 4. 陰鬱とした鈍色の雨煙・霧（Gloomy Rain Fog）
    vec3 fogColor = vec3(0.40, 0.44, 0.48);

    // 煙の微小な揺らぎ（ゆっくり漂うミスト）
    vec2 mistCoord = texcoord * 2.5 + vec2(frameTimeCounter * 0.02, frameTimeCounter * 0.01);
    float mist = (noise(mistCoord) - 0.5) * 0.12;

    // 霧の減衰（指数関数的フォグ）
    float baseDensity = 0.024 + rainStrength * 0.030;
    float fogFactor = 1.0 - exp(-baseDensity * linearDist);

    // 空（無限遠）の煙幕処理
    if (isSky) {
        fogFactor = 0.88 + rainStrength * 0.10;
    }

    // ミストの揺らぎを加算
    fogFactor = clamp(fogFactor + mist * (1.0 - exp(-0.02 * linearDist)), 0.0, 1.0);

    // 霧の合成（手持ち光源の光も加味した後に霧を被せる）
    color = mix(color + dynamicLight, fogColor, fogFactor);

    // 5. 輝度算出 & 彩度調整
    // 手持ちの灯火が当たっている足元だけは、わずかに色彩が息を吹き返す
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    float localSaturation = 0.30;
    if (heldLight > 0 && !isSky) {
        float warmArea = clamp(1.0 - (linearDist / 8.0), 0.0, 1.0);
        localSaturation += warmArea * 0.22; // 炎の周りだけ彩度を微小回復
    }
    color = mix(vec3(lum), color, clamp(localSaturation, 0.0, 1.0));

    // 6. 寒色・鉛色のトーン補正（雨の冷気と沈鬱感）
    color *= vec3(0.80, 0.86, 0.94);

    // 7. 周辺減光（Vignette）
    float vignette = smoothstep(0.88, 0.32, dist);
    color *= vignette;

    // 8. 蠢くフィルムグレイン（映画的ノイズ）
    float grain = (hash(texcoord * 1000.0 + fract(frameTimeCounter * 12.0)) - 0.5) * 0.05;
    color += grain;

    // 9. 息づく世界（微細な明滅パルス）
    float pulse = 1.0 + sin(frameTimeCounter * 1.5) * 0.015;
    color *= pulse;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
