// Pixel Pets: the whole scene in one fragment shader.
// Swift owns every bit of state; this only draws what SceneUniforms and SceneItem describe.
// Compiled at runtime from the app bundle, so building needs only swiftc.

#include <metal_stdlib>
using namespace metal;

// Must match SceneTypes.swift exactly (64 and 80 bytes).
struct SceneUniforms {
    float2 resolution;   // drawable size in real pixels
    float2 grid;         // virtual grid size, e.g. 480 x 300
    float  time;         // seconds, wraps every 6 h
    float  dayPhase;     // 0..1, local midnight to midnight
    float  rain;         // 0..1
    float  playMode;     // 0 or 1
    uint   itemCount;
    uint3  background;   // x: 1 image, 2 aurora tonight; y, z: image size
};

struct SceneItem {
    float2 position;     // grid px, bottom-centre of the sprite
    uint   tile;
    uint   tileSpan;     // 1 = 64x64, 2 = 128x128
    float4 primary;
    float4 secondary;
    float4 bars;         // health, hunger, happiness; negative = hidden
    int    icon;         // icon tile, -1 = none
    uint   flags;        // 1 flipX, 2 hurt flash, 4 blink health, 8 egg bar, 16 monster bar
    float  barLift;      // where the bars start above position; 0 = sprite top
    float  shadow;       // ground shadow half-width; 0 = none
};

constant uint kMaxItems = 24;
constant uint kAtlasColumns = 16;
constant float kTile = 64.0;

constant uint kFlipX = 1;
constant uint kHurt = 2;
constant uint kBlinkHealth = 4;
constant uint kEggBar = 8;
constant uint kMonsterBar = 16;

constant uint kBackgroundImage = 1;
constant uint kAurora = 2;

// Ramps 2...11 (0 and 1 are the item's primary and secondary colours).
constant float3 kRamp[12] = {
    float3(0.0), float3(0.0),
    float3(0.97, 0.78, 0.30),  // gold
    float3(0.86, 0.26, 0.30),  // red
    float3(0.42, 0.72, 0.34),  // green
    float3(0.56, 0.56, 0.63),  // stone
    float3(0.95, 0.94, 0.92),  // white
    float3(0.20, 0.17, 0.24),  // dark
    float3(0.96, 0.58, 0.66),  // pink
    float3(0.62, 0.42, 0.85),  // purple
    float3(0.62, 0.40, 0.22),  // wood
    float3(0.40, 0.62, 0.93),  // blue
};

// MARK: - Helpers

static float hash11(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

static float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// GLSL-style mod that stays positive.
static float pmod(float x, float y) {
    return x - y * floor(x / y);
}

static float noise1(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash11(i), hash11(i + 1.0), f);
}

static float noise2(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// Checkerboard dither: true on half the pixels.
static bool checker(float2 g) {
    return pmod(g.x + g.y, 2.0) < 1.0;
}

/// (ramp, tone) -> colour. Tones: light, base, cool shade, dark outline.
static float3 inkColour(uint ink, float3 primary, float3 secondary) {
    uint ramp = (ink - 1u) / 4u;
    uint tone = (ink - 1u) % 4u;
    float3 base = ramp == 0u ? primary : ramp == 1u ? secondary : kRamp[min(ramp, 11u)];
    switch (tone) {
        case 0u: return base + (float3(1.0, 0.96, 0.84) - base) * 0.32;
        case 1u: return base;
        case 2u: return base * float3(0.70, 0.66, 0.80);
        default: return base * float3(0.30, 0.25, 0.36);
    }
}

// MARK: - Time of day: dawn 06:00, day 12:00, dusk 19:00, night 22:00

constant float kKeyTime[4] = { 0.25, 0.5, 0.791667, 0.916667 };
constant float3 kSkyTop[4] = {
    float3(0.42, 0.52, 0.80), float3(0.14, 0.58, 0.84), float3(0.33, 0.30, 0.58), float3(0.04, 0.10, 0.22)
};
constant float3 kSkyBottom[4] = {
    float3(0.99, 0.76, 0.60), float3(0.55, 0.80, 0.93), float3(0.99, 0.60, 0.42), float3(0.08, 0.20, 0.34)
};
constant float3 kTint[4] = {
    float3(0.97, 0.86, 0.82), float3(1.0, 1.0, 1.0), float3(0.95, 0.76, 0.70), float3(0.30, 0.40, 0.58)
};
constant float kNight[4] = { 0.15, 0.0, 0.1, 1.0 };

struct DayBlend {
    int a;
    int b;
    float t;
};

/// Each keyframe holds, then blends into the next over the last 2.4 h before it.
static DayBlend dayBlend(float phase) {
    DayBlend d;
    d.a = 3; d.b = 0; d.t = 0.0;
    for (int i = 0; i < 4; i++) {
        int j = (i + 1) % 4;
        float span = kKeyTime[j] - kKeyTime[i];
        if (span <= 0.0) span += 1.0;
        float p = phase - kKeyTime[i];
        if (p < 0.0) p += 1.0;
        if (p < span) {
            float blend = min(span, 0.1);
            d.a = i; d.b = j;
            d.t = smoothstep(span - blend, span, p);
            return d;
        }
    }
    return d;
}

// MARK: - Landscape pieces

/// A cumulus cloud: a union of circles, lit from the top left in three tones.
static bool cloud(float2 g, float2 base, float scale, float seed, float3 sky, thread float3& col) {
    bool hit = false;
    float best = -2.0;
    for (int i = 0; i < 9; i++) {
        float fi = float(i) + seed * 13.0;
        float2 c = base + float2((hash11(fi) - 0.5) * 70.0, hash11(fi + 3.1) * 22.0 + (i < 3 ? 0.0 : 8.0)) * scale;
        float r = (8.0 + hash11(fi + 7.7) * 12.0) * scale * (i < 3 ? 0.8 : 1.0);
        float2 d = (g - c) / r;
        float len2 = dot(d, d);
        if (len2 < 1.0 && g.y > base.y - 2.0 * scale) {
            hit = true;
            float light = dot(d, float2(-0.55, 0.8)) + (1.0 - len2) * 0.3;
            best = max(best, light);
        }
    }
    if (!hit) return false;
    float3 lit = float3(0.97, 0.97, 0.95);
    float3 mid = mix(float3(0.84, 0.89, 0.94), sky, 0.15);
    float3 shade = mix(float3(0.62, 0.74, 0.88), sky, 0.3);
    col = best > 0.35 ? lit : best > 0.05 ? mid : shade;
    // Dither one band edge so the tones blend like painted pixels.
    if (best > 0.30 && best <= 0.40 && checker(g)) col = mid;
    return true;
}

/// Height of the distant ridge at design x.
static float ridgeHeight(float x, float groundTop, float skyH) {
    float rx = x * 0.011;
    return groundTop + skyH * 0.12 + skyH * 0.32 * (0.55 * abs(noise1(rx) * 2.0 - 1.0) + 0.45 * noise1(rx * 2.7 + 4.0));
}

static float3 landscape(float2 pixel, constant SceneUniforms& u, texture2d<float, access::sample> image) {
    // Shapes are designed on a 480-wide grid; `k` scales them up so they keep their size on
    // finer grids, while dithering and stars stay on real pixels.
    float k = u.grid.x / 480.0;
    float2 g = floor(pixel / k);
    DayBlend d = dayBlend(u.dayPhase);
    float3 tint = mix(kTint[d.a], kTint[d.b], d.t);
    float night = mix(kNight[d.a], kNight[d.b], d.t);
    // Depth layers, back to front: sky, clouds, far ridge, treeline hill, near hill, the back
    // meadow with the oak (from the horizon down to the walking line), the front meadow, and
    // a foreground drawn after the sprites (see `foreground`).
    float walk = floor(u.grid.y * 0.22 / k);
    float groundTop = floor(u.grid.y * 0.34 / k); // the horizon
    float skyH = max(1.0, u.grid.y / k - groundTop);
    float width = u.grid.x / k;
    float3 top = mix(kSkyTop[d.a], kSkyTop[d.b], d.t);
    float3 bottom = mix(kSkyBottom[d.a], kSkyBottom[d.b], d.t);
    float v = clamp((g.y - groundTop) / skyH, 0.0, 1.0);
    float3 col;
    bool clouded = false; // anything solid in front of the sky: no stars there

    if ((u.background.x & kBackgroundImage) != 0u && u.background.y > 0u) {
        // A picture chosen by the user, cropped to fill, lit for the time of day.
        float imageAspect = float(u.background.y) / float(max(u.background.z, 1u));
        float screenAspect = u.grid.x / u.grid.y;
        float2 uv = (pixel + 0.5) / u.grid;
        if (imageAspect > screenAspect) {
            uv.x = 0.5 + (uv.x - 0.5) * screenAspect / imageAspect;
        } else {
            uv.y = 0.5 + (uv.y - 0.5) * imageAspect / screenAspect;
        }
        constexpr sampler nearest(filter::nearest, address::clamp_to_edge);
        col = image.sample(nearest, float2(uv.x, 1.0 - uv.y)).rgb * tint;
    } else {
        // Sky: 7 bands with a dithered seam between each.
        float b = v * 7.0;
        float band = floor(b);
        if (fract(b) > 0.8 && checker(pixel)) band += 1.0;
        col = mix(bottom, top, min(band / 6.0, 1.0));

        // Big clouds drifting slowly left, three tones each.
        float span = width + 260.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float speed = 0.6 + hash11(fi * 3.1) * 0.6;
            float x = span - pmod(u.time * speed + hash11(fi * 7.7) * span, span) - 130.0;
            float y = groundTop + skyH * (0.45 + 0.28 * hash11(fi * 5.3));
            float scale = 0.7 + hash11(fi * 2.3) * 0.6;
            float3 c;
            if (cloud(g, float2(floor(x), floor(y)), scale, fi, top, c)) {
                clouded = true;
                col = mix(c, c * tint, 0.8);
                if (night > 0.5) col = mix(col, top * 1.4, 0.6);
            }
        }

        // A distant ridge: lit slopes face left, snow on the high peaks.
        float ridge = floor(ridgeHeight(g.x, groundTop, skyH));
        if (g.y < ridge) {
            // Sample the slope up and to the side, so light and shade meet along diagonal ridges.
            float sx = g.x + (ridge - g.y) * 0.55;
            float slope = ridgeHeight(sx + 3.0, groundTop, skyH) - ridgeHeight(sx - 3.0, groundTop, skyH);
            bool lit = slope > 0.0;
            float3 rock = lit ? float3(0.62, 0.68, 0.82) : float3(0.47, 0.53, 0.70);
            float snowLine = groundTop + skyH * 0.33 + (noise1(g.x * 0.2) - 0.5) * 6.0;
            if (g.y > snowLine) rock = lit ? float3(0.95, 0.96, 0.99) : float3(0.75, 0.81, 0.92);
            if (abs(slope) < 0.6 && checker(pixel)) rock = mix(rock, float3(0.55, 0.60, 0.76), 0.5);
            col = mix(rock, bottom, 0.35) * tint;
            clouded = true;
        }

        // Far hill with a pine treeline.
        float farH = groundTop + 22.0 + floor(9.0 * sin(g.x * 0.017 + 1.3) + 5.0 * sin(g.x * 0.043 + 0.4));
        float treeCell = floor(g.x / 7.0);
        float treeX = treeCell * 7.0 + 3.5;
        float treeH = hash11(treeCell * 1.7) > 0.35 ? 6.0 + hash11(treeCell * 3.3) * 10.0 : 0.0;
        float treeBase = groundTop + 22.0 + floor(9.0 * sin(treeX * 0.017 + 1.3) + 5.0 * sin(treeX * 0.043 + 0.4));
        float3 farGreen = mix(float3(0.44, 0.66, 0.50), bottom, 0.25);
        if (g.y < treeBase + treeH && g.y >= treeBase - 2.0 && abs(g.x - treeX) < (treeBase + treeH - g.y) * 0.32) {
            col = (g.x < treeX ? farGreen * 0.9 : farGreen * 0.72) * tint;
            clouded = true;
        }
        if (g.y < farH) { col = farGreen * tint; clouded = true; }

        // Near hill with round bushes.
        float nearH = groundTop + 8.0 + floor(6.0 * sin(g.x * 0.023 + 2.1) + 3.0 * sin(g.x * 0.061 + 5.0));
        float3 nearGreen = float3(0.40, 0.66, 0.42);
        float bushCell = floor(g.x / 31.0);
        float2 bush = float2(bushCell * 31.0 + 15.0 + (hash11(bushCell) - 0.5) * 14.0, 0.0);
        bush.y = groundTop + 8.0 + floor(6.0 * sin(bush.x * 0.023 + 2.1) + 3.0 * sin(bush.x * 0.061 + 5.0));
        float br = 5.0 + hash11(bushCell * 2.1) * 4.0;
        float2 bd = (g - bush) / br;
        if (hash11(bushCell * 4.7) > 0.4 && dot(bd, bd) < 1.0) {
            col = (bd.x < -0.1 && bd.y > 0.1 ? nearGreen * 1.12 : bd.y < -0.3 ? nearGreen * 0.78 : nearGreen * 0.94) * tint;
            clouded = true;
        }
        if (g.y < nearH) { col = nearGreen * tint; clouded = true; }

        // A big shaded oak on the right.
        float2 treeAt = float2(floor(width * 0.82), groundTop - 7.0);
        float2 tp = g - treeAt;
        if (abs(tp.x + tp.y * 0.05) < 4.0 + max(0.0, 6.0 - tp.y) * 0.6 && tp.y >= 0.0 && tp.y < 46.0) {
            col = (tp.x < 0.0 ? float3(0.47, 0.33, 0.25) : float3(0.36, 0.25, 0.20)) * tint;
            clouded = true;
        }
        float leaf = -2.0;
        for (int i = 0; i < 11; i++) {
            float fi = float(i);
            float2 c = float2((hash11(fi * 1.9) - 0.5) * 70.0, 40.0 + hash11(fi * 2.7) * 38.0);
            float r = 13.0 + hash11(fi * 3.9) * 10.0;
            float2 dd = (tp - c) / r;
            float len2 = dot(dd, dd);
            if (len2 < 1.0) leaf = max(leaf, dot(dd, float2(-0.5, 0.75)) + (noise2(g * 0.35) - 0.5) * 0.5);
        }
        if (leaf > -2.0) {
            float3 lit = float3(0.62, 0.80, 0.36), mid = float3(0.27, 0.62, 0.38), dark = float3(0.16, 0.42, 0.30);
            float3 c = leaf > 0.45 ? lit : leaf > -0.1 ? mid : dark;
            if (leaf > 0.38 && leaf <= 0.5 && checker(pixel)) c = mid;
            if (leaf > -0.18 && leaf <= -0.05 && checker(pixel)) c = dark;
            col = c * tint;
            clouded = true;
        }
    }

    // Night: twinkling stars, a crescent moon, and an aurora on some nights.
    if (night > 0.01 && v > 0.15) {
        float h = hash21(pixel);
        bool visible = (u.background.x & kBackgroundImage) == 0u || dot(col, float3(0.33)) < 0.25;
        if (h > 0.986 && visible && !clouded) {
            float twinkle = 0.55 + 0.45 * sin(u.time * (0.4 + hash21(pixel + 7.0)) + h * 60.0);
            col = mix(col, float3(1.0, 0.97, 0.86), night * twinkle);
        }
        if ((u.background.x & kAurora) != 0u) {
            float centre = groundTop + skyH * (0.62 + 0.12 * sin(g.x * 0.011 + u.time * 0.03) + 0.05 * sin(g.x * 0.037));
            float above = g.y - centre;
            if (above > -4.0 && above < 34.0) {
                float curtain = 0.6 + 0.4 * hash11(floor(g.x / 2.0)) * (0.7 + 0.3 * sin(u.time * 0.5 + g.x * 0.05));
                float fade = above < 0.0 ? 1.0 : 1.0 - above / 34.0;
                float k = floor(curtain * fade * 4.0) / 4.0;
                col = mix(col, float3(0.25, 0.95, 0.80), k * 0.55 * night);
            }
        }
    }
    float mp = pmod(u.dayPhase - 20.0 / 24.0, 1.0) / (10.0 / 24.0);
    if (mp < 1.0) {
        float2 centre = float2(floor(mix(0.12, 0.88, mp) * width), floor(groundTop + skyH * (0.5 + 0.38 * sin(mp * M_PI_F))));
        float2 dm = g - centre;
        float2 ds = dm - float2(3.0, 1.5);
        if (dot(dm, dm) <= 42.0 && dot(ds, ds) > 30.0) col = float3(0.98, 0.95, 0.80);
    }

    // The meadow: hazy toward the horizon, richer below the walking line.
    float3 grass = float3(0.45, 0.72, 0.36);
    if (g.y < groundTop) {
        float fromHorizon = groundTop - 1.0 - g.y;
        float nearness = clamp(fromHorizon / groundTop, 0.0, 1.0);
        // Grass strokes get longer and thicker toward the viewer.
        float rowH = 1.0 + floor(nearness * 3.0);
        float patch = noise2(float2(g.x * (0.03 - nearness * 0.015) + floor(g.y / rowH) * 7.3, g.y * 0.22));
        float3 c = patch > 0.7 ? float3(0.58, 0.78, 0.38) : patch < 0.22 ? float3(0.39, 0.64, 0.35) : grass;
        if (patch > 0.66 && patch <= 0.7 && checker(pixel)) c = float3(0.58, 0.78, 0.38);
        if (hash21(pixel) > 0.94) c *= 0.9;
        if (g.y < walk) c = mix(c, float3(0.30, 0.55, 0.30), 0.25 + 0.35 * smoothstep(walk, 0.0, g.y));
        c = mix(c, bottom, (1.0 - nearness) * 0.25);
        if (fromHorizon < 1.0) c = mix(float3(0.56, 0.80, 0.40), bottom, 0.2);
        col = c * tint;
    }
    float tuft = hash11(g.x * 1.7 + 3.0);
    if ((g.y == groundTop && tuft > 0.7) || (g.y == groundTop + 1.0 && tuft > 0.9)) col = mix(float3(0.56, 0.80, 0.40), bottom, 0.2) * tint;

    // Flowers swaying on a 2-frame cycle.
    float cellW = 17.0;
    for (int k = -1; k <= 1; k++) {
        float c = floor(g.x / cellW) + float(k);
        if (hash11(c * 3.7 + 1.0) < 0.4) continue;
        float fx = c * cellW + floor(hash11(c * 9.1) * (cellW - 4.0)) + 2.0;
        float fy = groundTop - 4.0 - floor(hash11(c * 4.3) * max(1.0, groundTop - 14.0));
        if (abs(fy - walk) < 4.0) continue; // keep the walking line clear
        float sway = pmod(floor(u.time) + c, 2.0);
        float2 p = g - float2(fx, fy);
        if (p.x == 0.0 && (p.y == 0.0 || p.y == 1.0)) col = float3(0.27, 0.52, 0.25) * tint;
        float2 hp = p - float2(sway, 2.0);
        float petalKind = hash11(c * 2.9);
        float3 petal = petalKind < 0.33 ? float3(0.98, 0.95, 0.88) : petalKind < 0.66 ? float3(0.98, 0.82, 0.30) : float3(0.95, 0.55, 0.65);
        if (abs(hp.x) + abs(hp.y) == 1.0) col = petal * tint;
        if (hp.x == 0.0 && hp.y == 0.0) col = float3(0.97, 0.75, 0.25) * tint;
    }

    // Rain: 1-pixel diagonal streaks.
    if (u.rain > 0.01) {
        col *= mix(1.0, 0.82, u.rain);
        float lane = g.x - g.y;
        float hl = hash11(lane * 0.731);
        if (hl < 0.35 * u.rain) {
            float s = g.y + u.time * 120.0 + hl * 997.0;
            if (pmod(s, 37.0 + floor(hl * 40.0)) < 4.0) col = mix(col, float3(0.78, 0.84, 0.95), 0.6);
        }
    }
    return col;
}

// MARK: - Foreground (drawn over the sprites)

static float3 foreground(float2 pixel, constant SceneUniforms& u, float3 col) {
    float k = u.grid.x / 480.0;
    float2 g = floor(pixel / k);
    DayBlend d = dayBlend(u.dayPhase);
    float3 tint = mix(kTint[d.a], kTint[d.b], d.t);
    float walkY = floor(u.grid.y * 0.22 / k) * k;

    // Grass blades along the walking line, in front of the pets' feet, swaying a little.
    float cell = floor(pixel.x / 3.0);
    if (hash11(cell * 1.37) > 0.68) {
        float bx = cell * 3.0 + floor(hash11(cell * 2.1) * 3.0);
        float base = walkY - 3.0 - floor(hash11(cell * 5.3) * 7.0);
        float height = 4.0 + floor(hash11(cell * 7.1) * 7.0);
        float t = (pixel.y - base) / height;
        if (t >= 0.0 && t < 1.0) {
            float lean = (hash11(cell * 3.3) - 0.5) * 4.0 + sin(u.time * 1.3 + cell * 0.37) * 0.8;
            if (abs(pixel.x - bx - lean * t * t) < 0.6) {
                float3 c = t > 0.65 ? float3(0.62, 0.84, 0.42) : t > 0.3 ? float3(0.45, 0.72, 0.36) : float3(0.32, 0.56, 0.30);
                col = c * tint;
            }
        }
    }

    // Big dark grass along the bottom edge, the nearest layer.
    float edge = 9.0 + 7.0 * noise1(g.x * 0.06) + 5.0 * noise1(g.x * 0.19 + 3.0);
    float spike = floor(g.x / 2.0);
    edge += hash11(spike * 1.9) > 0.6 ? floor(hash11(spike * 4.1) * 4.0) : 0.0;
    if (g.y < edge) {
        float3 c = g.y > edge - 2.0 ? float3(0.36, 0.60, 0.32) : float3(0.20, 0.40, 0.25);
        if (g.y <= edge - 2.0 && g.y > edge - 4.0 && checker(pixel)) c = float3(0.28, 0.50, 0.29);
        col = c * tint;
    }
    if (u.playMode > 0.5) col *= 0.85;
    return col;
}

// MARK: - Items

static uint readAtlas(texture2d<uint, access::read> atlas, uint tile, uint2 local) {
    uint2 origin = uint2((tile % kAtlasColumns) * 64u, (tile / kAtlasColumns) * 64u);
    return atlas.read(origin + local).r;
}

static float3 drawItem(constant SceneItem& it, float2 g, float groundTop, float3 light, constant SceneUniforms& u,
                       texture2d<uint, access::read> atlas, float3 col) {
    float size = kTile * float(max(it.tileSpan, 1u));
    float2 origin = float2(floor(it.position.x - size * 0.5), floor(it.position.y));

    // A soft ground shadow, even under things in the air.
    if (it.shadow > 0.0) {
        float2 e = (g + 0.5 - float2(it.position.x, groundTop + 0.5)) / float2(it.shadow, max(1.5, it.shadow * 0.28));
        if (dot(e, e) < 1.0) col *= dot(e, e) < 0.45 ? 0.68 : 0.8;
    }

    // Sprite
    float2 local = g - origin;
    if (local.x >= 0.0 && local.y >= 0.0 && local.x < size && local.y < size) {
        uint lx = uint(local.x);
        uint ly = uint(size - 1.0 - local.y);
        if ((it.flags & kFlipX) != 0u) lx = uint(size) - 1u - lx;
        uint ink = readAtlas(atlas, it.tile, uint2(lx, ly));
        if (ink != 0u) {
            float3 c = inkColour(ink, it.primary.rgb, it.secondary.rgb);
            if ((it.flags & kHurt) != 0u) c = mix(c, float3(1.0, 0.25, 0.25), 0.55);
            col = c * light;
        }
    }

    // Bars and icons are drawn at 2x, matching the chunkier HUD scale.
    float iconBase = origin.y + (it.barLift > 0.0 ? it.barLift : size);
    float2 hud = floor((g - float2(0.0, iconBase)) / 2.0);
    if (it.bars.x >= 0.0) {
        bool single = (it.flags & (kEggBar | kMonsterBar)) != 0u;
        float count = single ? 1.0 : 3.0;
        float inner = (it.flags & kMonsterBar) != 0u ? size * 0.3 : 14.0;
        float blockH = count * 4.0 + (count - 1.0);
        float2 p = hud - float2(floor(it.position.x / 2.0 - (inner + 2.0) * 0.5), 0.0);
        if (p.x >= 0.0 && p.x < inner + 2.0 && p.y >= 0.0 && p.y < blockH) {
            float row = floor(p.y / 5.0);
            float inY = p.y - row * 5.0;
            if (inY < 4.0) {
                int index = int(count - 1.0 - row); // 0 = top bar
                float value = index == 0 ? it.bars.x : index == 1 ? it.bars.y : it.bars.z;
                float3 fill = index == 0 ? float3(0.91, 0.29, 0.37)
                            : index == 1 ? float3(0.96, 0.62, 0.25) : float3(1.0, 0.56, 0.76);
                if ((it.flags & kEggBar) != 0u) fill = float3(0.97, 0.83, 0.35);
                bool edge = p.x < 1.0 || p.x >= inner + 1.0 || inY < 1.0 || inY >= 3.0;
                if (edge) {
                    col = float3(0.17, 0.13, 0.20);
                } else {
                    bool filled = (p.x - 1.0) < round(clamp(value, 0.0, 1.0) * inner);
                    bool blinkOff = (it.flags & kBlinkHealth) != 0u && index == 0 && fract(u.time * 2.0) < 0.5;
                    float3 lit = inY >= 2.0 ? fill * 1.12 : fill;
                    col = filled && !blinkOff ? lit : float3(0.22, 0.19, 0.26);
                }
            }
        }
        iconBase += (blockH + 1.0) * 2.0;
        hud = floor((g - float2(0.0, iconBase)) / 2.0);
    }

    // Feeling icon, 10 x 10 with its shadow, in the top-left of its tile.
    if (it.icon >= 0) {
        float2 ip = hud - float2(floor(it.position.x / 2.0 - 5.0), 0.0);
        if (ip.x >= 0.0 && ip.y >= 0.0 && ip.x < 11.0 && ip.y < 11.0) {
            uint ink = readAtlas(atlas, uint(it.icon), uint2(uint(ip.x), 10u - uint(ip.y)));
            if (ink != 0u) col = inkColour(ink, it.primary.rgb, it.secondary.rgb);
        }
    }
    return col;
}

// MARK: - Entry points

struct VOut {
    float4 position [[position]];
};

vertex VOut petsVertex(uint vid [[vertex_id]]) {
    // One oversized triangle that covers the whole screen.
    float2 p = float2(float((vid << 1) & 2), float(vid & 2));
    VOut o;
    o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

fragment float4 petsFragment(VOut in [[stage_in]],
                             constant SceneUniforms& u [[buffer(0)]],
                             constant SceneItem* items [[buffer(1)]],
                             texture2d<uint, access::read> atlas [[texture(0)]],
                             texture2d<float, access::sample> image [[texture(1)]]) {
    // Snap every screen pixel to its cell on the virtual grid, origin bottom-left.
    float cell = u.resolution.x / u.grid.x;
    float2 frag = float2(in.position.x, u.resolution.y - in.position.y);
    float2 g = floor(frag / cell);
    float k = u.grid.x / 480.0;
    float groundTop = floor(u.grid.y * 0.22 / k) * k; // the walking line
    // Sprites share the scene's light, a little brighter so pets stay readable at night.
    DayBlend d = dayBlend(u.dayPhase);
    float3 light = mix(float3(1.0), mix(kTint[d.a], kTint[d.b], d.t), 0.8) + float3(0.04, 0.04, 0.06);

    float3 col = landscape(g, u, image);
    if (u.playMode > 0.5) col *= 0.85;

    uint count = min(u.itemCount, kMaxItems);
    for (uint i = 0; i < count; i++) {
        col = drawItem(items[i], g, groundTop, light, u, atlas, col);
    }
    if ((u.background.x & kBackgroundImage) == 0u) col = foreground(g, u, col);
    return float4(saturate(col), 1.0);
}
