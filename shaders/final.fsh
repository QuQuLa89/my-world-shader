#version 120

/*
 * Nightmare Prototype Shader - Gloomy Rain Fog Edition
 * Designed for QuQuLa89 by Qwen
 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;

uniform float frameTimeCounter; // 経過時間（秒）
uniform float rainStrength;      // 雨の強さ (0.0:晴れ ~ 1.0:雨)

varying vec2 texcoord;

// 擬似乱数ノイズ関数
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 簡易スムーズノイズ（煙・ミストの揺らぎ用）
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

    // 3. 陰鬱とした鈍色の雨煙・霧（Gloomy Rain Fog）
    // 霧の色: 光を吸い込むような冷たい鈍色（スモーキーな暗い青灰）
    vec3 fogColor = vec3(0.40, 0.44, 0.48);

    // 煙の微小な揺らぎ（ゆっくり漂うミスト）
    vec2 mistCoord = texcoord * 2.5 + vec2(frameTimeCounter * 0.02, frameTimeCounter * 0.01);
    float mist = (noise(mistCoord) - 0.5) * 0.12;

    // 霧の減衰（指数関数的フォグ: 近距離から立ち込め、遠景を閉ざす）
    float baseDensity = 0.024 + rainStrength * 0.030;
    float fogFactor = 1.0 - exp(-baseDensity * linearDist);

    // 空（無限遠）の処理: 空も鈍色の煙幕で包み、太陽の境界を霞ませる
    if (isSky) {
        fogFactor = 0.88 + rainStrength * 0.10;
    }

    // ミストの揺らぎを加算
    fogFactor = clamp(fogFactor + mist * (1.0 - exp(-0.02 * linearDist)), 0.0, 1.0);

    // 霧の合成
    color = mix(color, fogColor, fogFactor);

    // 4. 輝度算出 & 彩度低下（Desaturation: 70%脱色）
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(lum), color, 0.30);

    // 5. 寒色・鉛色のトーン補正（雨の冷気と沈鬱感）
    color *= vec3(0.80, 0.86, 0.94);

    // 6. 周辺減光（Vignette）
    float vignette = smoothstep(0.88, 0.32, dist);
    color *= vignette;

    // 7. 蠢くフィルムグレイン（映画的ノイズ）
    float grain = (hash(texcoord * 1000.0 + fract(frameTimeCounter * 12.0)) - 0.5) * 0.05;
    color += grain;

    // 8. 息づく世界（微細な明滅パルス）
    float pulse = 1.0 + sin(frameTimeCounter * 1.5) * 0.015;
    color *= pulse;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
