# my-world-shader

> 「悪夢の世界のような、陰鬱で静かな空気を生み出す」Minecraft用GLSLシェーダーパック。

![Version](https://img.shields.io/badge/Minecraft-1.21.1-blue.svg)
![Loader](https://img.shields.io/badge/Loader-Iris%20Shaders%20%2F%20Fabric-green.svg)
![Author](https://img.shields.io/badge/Author-QuQuLa89-darkred.svg)

---

## 概要 (Overview)
`my-world-shader` は、鮮やかで眩しい一般的な影MODの対極に位置する、心理的圧迫感と静寂を追求した独自のシェーダーパックです。
生気を奪い去る彩度低下、光を吸い込むような冷たい鈍色の雨霧、視界の四隅を侵食する周辺減光、そして微細に蠢くフィルムグレインによって、見慣れた立方体の世界を不穏で静謐な悪夢の領域へと変貌させます。

## 主な特徴 (Features)
- **リアルかつ不穏な陰影表現 (Directional Shadows & SSAO)**:
  - 深度バッファから復元した法線ベクトルに基づき、太陽・月の方向から落ちる冷たく鋭い陰影。
  - **SSAO (Screen Space Ambient Occlusion)** による、ブロックの角や隙間、接地面に落ちる墨のような濃密な暗影。
- **煙霧を貫く冷たい薄明光線 (Atmospheric Crepuscular Rays / God Rays)**:
  - 太陽光が遮蔽物の隙間から煙雨を切り裂いて差し込む、不気味で静謐な光条。
- **彩度低下 & 寒色カラーグレーディング (Desaturation & Cold Tint)**:

  - 鮮烈な色彩を70%奪い、冷淡な鉛色と青灰色のトーンへと収束。
- **陰鬱たる鈍色の雨煙・指数関数フォグ (Gloomy Rain Fog)**:
  - 深度バッファから復元した実世界距離に基づき、遠景を閉ざす指数関数フォグ。
  - 時間経過に伴って大気中をゆっくりと漂う煙・ミストの有機的揺らぎ。
  - 空と太陽の輪郭を煙幕で包み込み、天候を問わず立ち込める分厚い大雨の気配。
  - ゲーム内天候（雨・雷雨）と連動し、降雨時には視界がさらに遮断される動的濃度変化。
- **微細な色収差 (Chromatic Aberration)**:
  - 画面周辺部に向かって光線の波長をわずかに乖離させ、焦点の合わない知覚の狂気を演出。
- **周辺減光 (Vignette)**:
  - 視界の四隅を濃い暗黒で締め付け、覗き見ているかのような閉塞感を付与。
- **蠢くフィルムグレイン & 脈動 (Dynamic Grain & Breathing Pulse)**:
  - アナログ映画フィルムのようにざらつく動的ノイズと、世界そのものが呼吸しているかのような極小の明滅。

## 動作要件 (Requirements)
- **Minecraft: Java Edition**: 1.21.1 (Fabric)
- **シェーダーローダー**: [Iris Shaders](https://modrinth.com/mod/iris) (v1.8.14以降推奨)
- **描画最適化**: [Sodium](https://modrinth.com/mod/sodium) (v0.8.13以降推奨)

## 開発・ホットリロード (Development)
本リポジトリは Minecraft の `shaderpacks` フォルダとジャンクション結合して開発されています。
コード（`shaders/final.fsh` 等）を編集・保存後、ゲーム内で **`F3 + R`** を押すことでリアルタイムに描画結果を更新できます。
