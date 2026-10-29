# my-world-shader

> A gloomy, silent, and nightmarish GLSL shaderpack for Minecraft.

[**日本語版 (Japanese)**](README_JA.md) | **English**

![Version](https://img.shields.io/badge/Minecraft-1.21.1-blue.svg)
![Loader](https://img.shields.io/badge/Loader-Iris%20Shaders%20%2F%20Fabric-green.svg)
![Author](https://img.shields.io/badge/Author-QuQuLa89-darkred.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

---

## Gallery

![Daytime](assets/screenshot_day.jpg)
*Day: Cold, rain-veiled plains and a quiet, muted turquoise river.*

![Nighttime](assets/screenshot_night.jpg)
*Night: Abyss darkness swallowing all light, with water seamlessly blending into the gloom.*

---

## Overview
`my-world-shader` stands in stark contrast to bright, vibrant shaderpacks. It is designed to evoke psychological oppression, solitude, and silence.
Through desaturated palettes, cold rainy mist, deep vignette framing your vision, and subtle organic film grain, familiar blocky landscapes transform into an unsettling, quiet nightmare.

---

## Features

### 1. Lighting & Shadows
- **Solas-Style Screen Space Shadows (SSS)**:
  - Real-time depth raymarching along the solar vector casts crisp, accurate contact shadows for blocks, trees, and structures without shadow map cascade artifacts or duplication bugs.
  - First-person hand/arm geometry is geometrically culled to prevent detached floating arm shadows on the ground.
- **Directional Shadows & SSAO**:
  - Cold, sharp directional shading derived from depth-reconstructed surface normals.
  - **Screen Space Ambient Occlusion (SSAO)** adds deep, ink-like contact shadows in crevices and corners.
- **Atmospheric Crepuscular Rays (God Rays)**:
  - Quiet, eerie shafts of light piercing through rainy smoke and obstacles.
- **Dynamic Handheld Light**:
  - Torches and light sources held in the main/off hand warmly illuminate the player's immediate surroundings.

### 2. Realistic Water & Abyss Fog
- **Muted Turquoise Water**:
  - Physically-inspired Beer-Lambert wavelength absorption (rapid red-light decay), Fresnel reflections, and gentle dual-layer wave perturbation.
  - Fully synced with the day/night cycle: surfaces naturally darken at night to eliminate artificial glow and white-bleaching.
- **Underwater Abyss Fog**:
  - Visual darkening upon submersion, accompanied by dense dark-turquoise fog starting at close range (1m) to instill deep-sea claustrophobia and solitude.

### 3. Emissive Blocks
- **Boiling Dark-Crimson Lava**:
  - Dedicated emissive pipeline bypassing external shadows and night-time desaturation.
  - Preserves vanilla texture details and fluid animations while re-grading yellow hues into deep crimson. Cooler crusts turn obsidian-red, while hot crevices pulse with gentle, world-anchored thermal surges.

### 4. Atmospheric Post-Processing
- **Desaturation & Cold Color Grading**:
  - Strips vivid colors down to cold slate and pale blue-gray tones.
- **Gloomy Rain Fog**:
  - Exponential fog obscuring distant horizons, drifting with organic smoke turbulence that intensifies during rain and storms.
- **Chromatic Aberration & Vignette**:
  - Subtle wavelength fringing toward screen edges paired with heavy vignette for a claustrophobic, peephole perspective.
- **Film Grain & Breathing Pulse**:
  - Cinematic 35mm film grain and a minute, world-scale breathing pulse.

---

## Requirements
- **Minecraft: Java Edition**: 1.21.1
- **Shader Loader**: [Iris Shaders](https://modrinth.com/mod/iris) (v1.8.14 or newer recommended)
- **Rendering Optimization**: [Sodium](https://modrinth.com/mod/sodium) (v0.8.13 or newer recommended)

---

## Installation
1. Install Fabric, Iris Shaders, and Sodium.
2. Download the latest `my-world-shader.zip` from [Releases](../../releases).
3. Place the `.zip` file into your `.minecraft/shaderpacks` directory.
4. Select `my-world-shader` in **Video Settings -> Shader Packs**.

---

## Development & Hot-Reload
This repository is developed via directory junction directly linked to Minecraft's `shaderpacks` folder.
After editing any file in `shaders/`, press **`F3 + R`** in-game to reload shaders instantly.

---

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
