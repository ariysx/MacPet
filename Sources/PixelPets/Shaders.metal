// Pixel Pets: the whole scene in one fragment shader.
// Swift owns every bit of state; this only draws what SceneUniforms and SceneItem describe.
// Compiled at runtime from the app bundle, so building needs only swiftc.

#include <metal_stdlib>
using namespace metal;

// Must match SceneTypes.swift exactly (96 and 80 bytes; uint3 takes 16).
struct SceneUniforms {
    float2 resolution;   // drawable size in real pixels
    float2 grid;         // virtual grid size, e.g. 480 x 300
    float  time;         // seconds, wraps every 6 h
    float  dayPhase;     // 0..1, local midnight to midnight
    float  rain;         // 0..1
    float  playMode;     // 0 or 1
    uint   itemCount;
    uint3  background;   // x: 1 image, 2 aurora tonight; y, z: image size
    float  flash;        // 0..1 lightning brightness
    float2 shake;        // grid px the scene is nudged by
    float  bolt;         // design-unit x of a lightning bolt, < 0 = none
    float  wet;          // 0..1 how much water lies on the ground: puddles
    float  season;       // 0 spring, 1 summer, 2 autumn, 3 winter
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

// The play-mode UI layer (UI.swift), drawn at half resolution.
struct UIUniforms {
    float4 primary;      // colours for a pet portrait in the UI
    float4 secondary;
    uint   enabled;
    uint3  pad;
};

constant uint kMaxItems = 32;
constant uint kAtlasColumns = 16;
constant float kTile = 64.0;

constant uint kFlipX = 1;
constant uint kHurt = 2;
constant uint kBlinkHealth = 4;
constant uint kEggBar = 8;
constant uint kMonsterBar = 16;
constant uint kWhiteFlash = 32;

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

// The landscape is painted like the references: hue-shifted ramps (cool shadows, warm lights),
// clustered shapes with lit top-left edges, selective dithering at tone seams, and layers that
// fade toward the sky with distance. Shapes are designed in 480-wide units and sampled at the
// grid's full resolution.

/// Wind gust strength (0...1) at design x: bands that roll right to left across the scene.
static float gust(float x, float t) {
    return smoothstep(0.55, 0.95, noise1(x * 0.011 + t * 0.32));
}

/// Picks one of five tones from `l` (about -1...1), dithering a narrow seam between each pair.
static float3 ramp5(float l, float2 pixel, float3 t0, float3 t1, float3 t2, float3 t3, float3 t4) {
    float d = checker(pixel) ? 0.06 : -0.06;
    float x = l + d * step(0.0, 1.0);
    if (x > 0.62) return t4;
    if (x > 0.25) return t3;
    if (x > -0.15) return t2;
    if (x > -0.5) return t1;
    return t0;
}

/// A cumulus cloud: bumpy circles lit from the top left, cool blue in shadow, flat underneath.
static bool cumulus(float2 p, float2 pixel, float2 base, float scale, float seed, thread float3& col) {
    float best = -9.0;
    bool hit = false;
    for (int i = 0; i < 12; i++) {
        float fi = float(i) + seed * 17.0;
        float row = i < 4 ? 0.0 : i < 9 ? 1.0 : 2.0;
        float2 c = base + float2((hash11(fi) - 0.5) * (row == 0.0 ? 90.0 : row == 1.0 ? 66.0 : 38.0),
                                 row * 13.0 + hash11(fi + 3.1) * 8.0) * scale;
        float r = (9.0 + hash11(fi + 7.7) * 9.0 - row * 1.5) * scale;
        float2 d = (p - c) / r;
        float a = atan2(d.y, d.x);
        float bump = 1.0 + 0.07 * sin(a * 7.0 + fi) + 0.04 * sin(a * 13.0 + fi * 2.0);
        float len = length(d);
        if (len < bump && p.y > base.y - 3.0 * scale) {
            hit = true;
            // Lit as one mass: mostly by height in the cloud, a little by each puff's shape.
            float height = (p.y - base.y) / (34.0 * scale);
            float light = height * 1.25 - 0.45 + dot(d, float2(-0.55, 0.75)) * 0.4 + (noise2(p * 0.12 + seed) - 0.5) * 0.35;
            best = max(best, light);
        }
    }
    if (!hit) return false;
    // Flatten and cool the underside.
    if (p.y < base.y + 3.0 * scale) best = min(best, -0.35);
    col = ramp5(best, pixel, float3(0.47, 0.63, 0.84), float3(0.62, 0.75, 0.90), float3(0.78, 0.87, 0.95),
                float3(0.92, 0.95, 0.98), float3(1.0, 1.0, 0.97));
    return true;
}

/// Height of the distant mountain range.
static float ridgeHeight(float x, float groundTop, float skyH) {
    float rx = x * 0.0085;
    float peaks = 0.6 * (1.0 - abs(noise1(rx) * 2.0 - 1.0)) + 0.4 * noise1(rx * 2.3 + 4.0);
    return groundTop + skyH * 0.08 + skyH * 0.42 * peaks * peaks + 4.0 * noise1(x * 0.09);
}

/// A tiered pine at (`x`, `base`): jagged layers, lit on the left.
/// Recolours plant and ground colours for the season: fresh in spring, warm in summer, gold and
/// rust in autumn, and under snow in winter (keeping the light and shade of what lies beneath).
static float3 seasonal(float3 c, float s) {
    if (s < 0.5) return c * float3(1.0, 1.06, 0.92) + float3(0.02, 0.03, 0.0);
    if (s < 1.5) return c * float3(1.03, 0.99, 0.88);
    float green = max(0.0, c.y - max(c.x, c.z));
    if (s < 2.5) return c + float3(green * 1.3, -green * 0.38, -green * 0.25);
    float l = dot(c, float3(0.3, 0.55, 0.15));
    return l > 0.55 ? float3(0.97, 0.98, 1.0) : l > 0.4 ? float3(0.87, 0.91, 0.98) : float3(0.73, 0.79, 0.91);
}

static bool pine(float2 p, float2 pixel, float x, float base, float h, float3 dark, float3 mid, float3 light, thread float3& col) {
    float up = p.y - base;
    if (up < -2.0 || up > h) return false;
    if (up < 0.0) {
        if (abs(p.x - x) < 1.2) { col = float3(0.30, 0.21, 0.17); return true; }
        return false;
    }
    float tierH = h / 4.5;
    float tier = fract(up / tierH);
    float halfW = (h - up) * 0.38 * (0.7 + 0.45 * tier) + 1.0;
    halfW += (noise1(p.y * 1.7 + x) - 0.5) * 1.6;
    float dx = p.x - x;
    if (abs(dx) > halfW) return false;
    float l = -dx / halfW * 0.8 + (tier - 0.5) * 0.5;
    col = l > 0.35 ? light : l > -0.25 ? mid : dark;
    if (l > 0.2 && l <= 0.35 && checker(pixel)) col = mid;
    return true;
}

static float3 landscape(float2 pixel, constant SceneUniforms& u, texture2d<float, access::sample> image) {
    float k = u.grid.x / 480.0;
    float2 p = (pixel + 0.5) / k;          // design units, full-resolution sampling
    float2 g = floor(pixel / k);           // design cell, for hashing
    DayBlend d = dayBlend(u.dayPhase);
    float3 tint = mix(kTint[d.a], kTint[d.b], d.t);
    float night = mix(kNight[d.a], kNight[d.b], d.t);
    float walk = floor(u.grid.y * 0.22 / k);
    float groundTop = floor(u.grid.y * 0.34 / k); // the horizon
    float skyH = max(1.0, u.grid.y / k - groundTop);
    float width = u.grid.x / k;
    float3 top = mix(kSkyTop[d.a], kSkyTop[d.b], d.t);
    float3 bottom = mix(kSkyBottom[d.a], kSkyBottom[d.b], d.t);
    float v = clamp((p.y - groundTop) / skyH, 0.0, 1.0);
    float3 col;
    bool clouded = false; // anything solid in front of the sky: no stars there
    bool land = false;    // mountains, hills and trees: lightning passes behind these

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
        clouded = true;
    } else {
        // Sky: five bands from the hazy horizon up, with a dithered seam at each step.
        // Sky: nine soft bands, lighter at the horizon, each seam dithered.
        float b = sqrt(v) * 9.0;
        float band = floor(b);
        if (fract(b) > 0.8 && checker(pixel)) band += 1.0;
        col = mix(bottom, top, min(band / 8.0, 1.0));

        // Cumulus clouds drifting slowly left.
        float span = width + 300.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float speed = 0.4 + hash11(fi * 3.1) * 0.4;
            float x = span - pmod(u.time * speed + (fi / 3.0 + hash11(fi * 7.7) * 0.2) * span, span) - 150.0;
            float y = groundTop + skyH * (0.40 + 0.22 * hash11(fi * 5.3));
            float scale = 1.0 + hash11(fi * 2.3) * 0.6;
            float3 c;
            if (cumulus(p, pixel, float2(x, y), scale, fi, c)) {
                col = mix(c * mix(float3(1.0), tint, 0.85), top * 1.25, night * 0.55);
                clouded = true;
            }
        }

        // Small flocks of birds crossing by day.
        if (night < 0.5) {
            for (int f = 0; f < 2; f++) {
                float ff = float(f);
                float fspan = width + 160.0;
                float fx = fspan - pmod(u.time * (9.0 + ff * 4.0) + ff * 271.0, fspan) - 80.0;
                float fy = groundTop + skyH * (0.55 + ff * 0.18) + sin(u.time * 0.4 + ff) * 4.0;
                for (int bI = 0; bI < 4; bI++) {
                    float fb = float(bI);
                    float2 bp = float2(fx + fb * 6.0 + hash11(fb + ff * 9.0) * 3.0, fy - abs(fb - 1.5) * 2.5 + hash11(fb * 3.0 + ff) * 2.0);
                    float2 q = p - bp;
                    float flap = sin(u.time * 9.0 + fb * 1.7) > 0.0 ? 1.0 : -0.4;
                    if (abs(q.x) < 2.0 && abs(q.y - abs(q.x) * 0.55 * flap) < 0.45) {
                        col = mix(float3(0.22, 0.26, 0.36), col, 0.25);
                        clouded = true;
                    }
                }
            }
        }

        // Distant mountains: planar faces, snow above a ragged line, forest on the lower slopes.
        float ridge = ridgeHeight(p.x, groundTop, skyH);
        if (p.y < ridge) {
            float sx = p.x + (ridge - p.y) * 0.6;
            float slope = ridgeHeight(sx + 2.5, groundTop, skyH) - ridgeHeight(sx - 2.5, groundTop, skyH);
            float face = slope > 0.0 ? 1.0 : 0.0;
            float strata = noise2(float2(p.x * 0.05, p.y * 0.35));
            float3 rock = face > 0.5 ? (strata > 0.62 ? float3(0.72, 0.76, 0.88) : float3(0.62, 0.68, 0.84))
                                     : (strata > 0.62 ? float3(0.52, 0.58, 0.78) : float3(0.44, 0.51, 0.72));
            float snowShift = u.season > 2.5 ? -0.17 : u.season > 1.5 ? -0.03 : u.season > 0.5 ? 0.06 : -0.05;
            float snowLine = groundTop + skyH * (0.30 + snowShift) + (noise1(p.x * 0.15) - 0.5) * 10.0 + (noise1(p.x * 0.6) - 0.5) * 4.0;
            if (p.y > snowLine) rock = face > 0.5 ? float3(0.96, 0.97, 1.0) : float3(0.72, 0.80, 0.94);
            float forest = groundTop + skyH * 0.1 + noise1(p.x * 0.04) * skyH * 0.08 + (hash11(floor(p.x / 2.5)) - 0.5) * 2.5;
            if (p.y < forest) rock = seasonal(face > 0.5 ? float3(0.36, 0.55, 0.56) : float3(0.28, 0.45, 0.50), u.season);
            col = mix(rock, bottom, 0.38) * tint;
            clouded = true;
            land = true;
        }

        // Far hills, hazy teal, with a fringe of tiny treetops.
        float farH = groundTop + 16.0 + 9.0 * sin(p.x * 0.014 + 1.3) + 5.0 * sin(p.x * 0.037 + 0.4);
        float fringe = farH + 1.5 + 2.5 * abs(sin(p.x * 0.9)) * step(0.4, hash11(floor(p.x / 3.0) * 1.7));
        if (p.y < fringe) {
            float3 c = p.y > farH - 1.0 ? float3(0.47, 0.72, 0.68) : float3(0.38, 0.63, 0.62);
            if (p.y > farH - 3.0 && p.y <= farH - 1.0 && checker(pixel)) c = float3(0.47, 0.72, 0.68);
            col = mix(seasonal(c, u.season), bottom, 0.25) * tint;
            clouded = true;
            land = true;
        }

        // Mid hills with clumps of pines and round bushes.
        float midH = groundTop + 7.0 + 6.0 * sin(p.x * 0.021 + 2.1) + 3.0 * sin(p.x * 0.055 + 5.0);
        float pineCell = floor(p.x / 13.0);
        for (int kx = -1; kx <= 1; kx++) {
            float cell = pineCell + float(kx);
            if (hash11(cell * 2.7) < 0.45) continue;
            float tx = cell * 13.0 + 6.5 + (hash11(cell * 5.1) - 0.5) * 8.0;
            float baseY = groundTop + 7.0 + 6.0 * sin(tx * 0.021 + 2.1) + 3.0 * sin(tx * 0.055 + 5.0) - 2.0;
            float h = 14.0 + hash11(cell * 3.3) * 16.0;
            float3 c;
            // Pines keep their needles; in winter snow settles on the lit side.
            float3 pineMid = float3(0.22, 0.48, 0.36), pineLight = float3(0.36, 0.62, 0.40);
            if (u.season > 2.5) { pineMid = float3(0.80, 0.86, 0.95); pineLight = float3(0.96, 0.98, 1.0); }
            if (pine(p, pixel, tx, baseY, h, float3(0.15, 0.36, 0.30), pineMid, pineLight, c)) {
                col = mix(c, bottom, 0.12) * tint;
                clouded = true;
                land = true;
            }
        }
        if (p.y < midH) {
            float l = noise2(float2(p.x * 0.05, p.y * 0.2));
            float3 c = l > 0.62 ? float3(0.46, 0.72, 0.44) : l < 0.3 ? float3(0.30, 0.56, 0.38) : float3(0.37, 0.64, 0.41);
            col = mix(seasonal(c, u.season), bottom, 0.1) * tint;
            clouded = true;
            land = true;
        }

        // The big oak in the back meadow: clustered foliage on a gnarled trunk.
        float2 treeAt = float2(floor(width * 0.8), groundTop - 6.0);
        float2 tp = p - treeAt;
        float trunkHalf = 4.0 + max(0.0, 7.0 - tp.y) * 0.7 + max(0.0, tp.y - 40.0) * 0.15;
        float trunkX = tp.x + sin(tp.y * 0.08) * 1.5;
        if (tp.y >= 0.0 && tp.y < 58.0 && abs(trunkX) < trunkHalf) {
            float bark = noise2(float2(trunkX * 0.9, tp.y * 0.25));
            float3 c = trunkX < -trunkHalf * 0.3 ? float3(0.55, 0.39, 0.28) : trunkX < trunkHalf * 0.4 ? float3(0.42, 0.29, 0.22)
                                                                                                   : float3(0.29, 0.20, 0.17);
            if (bark > 0.7) c *= 0.82;
            col = c * tint;
            clouded = true;
            land = true;
        }
        float best = -9.0, bestZ = -1e9, bestI = 0.0;
        float treeGust = gust(treeAt.x, u.time);
        for (int i = 0; i < 16; i++) {
            float fi = float(i);
            float2 c = float2((hash11(fi * 1.9) - 0.5) * 84.0, 44.0 + hash11(fi * 2.7) * 44.0);
            // Clusters sway, higher ones more, and lean with each gust.
            c.x += (sin(u.time * 0.9 + fi * 1.3) * 0.7 - treeGust * 2.0) * (c.y / 80.0);
            float r = 12.0 + hash11(fi * 3.9) * 10.0;
            float2 dd = (tp - c) / r;
            float edge = 1.0 + (noise2(p * 0.55 + fi) - 0.5) * 0.28;
            float z = -c.y + hash11(fi) * 10.0; // lower clusters sit in front
            if (dot(dd, dd) < edge * edge && z > bestZ - 1e-3) {
                bestZ = z;
                bestI = fi;
                best = dot(dd, float2(-0.55, 0.72)) * 0.85 + (1.0 - length(dd)) * 0.3;
            }
        }
        if (best > -9.0) {
            float dapple = noise2(p * 0.45);
            float l = best + (dapple - 0.5) * 0.45;
            float3 c = ramp5(l, pixel, float3(0.10, 0.30, 0.24), float3(0.16, 0.42, 0.29), float3(0.25, 0.56, 0.32),
                             float3(0.42, 0.70, 0.33), float3(0.64, 0.82, 0.35));
            bool leafy = true;
            if (u.season < 0.5) {
                // Spring blossom.
                float b = hash21(floor(p / 1.5) + 3.0);
                if (b > 0.93) c = b > 0.975 ? float3(1.0, 0.95, 0.97) : float3(0.98, 0.72, 0.82);
            } else if (u.season > 1.5 && u.season < 2.5) {
                // Autumn: each cluster its own mix of gold, orange and rust.
                float hue = hash11(bestI * 7.3);
                c = hue < 0.4 ? ramp5(l, pixel, float3(0.36, 0.14, 0.08), float3(0.56, 0.20, 0.10), float3(0.76, 0.32, 0.12),
                                      float3(0.90, 0.52, 0.18), float3(0.98, 0.74, 0.32))
                              : ramp5(l, pixel, float3(0.40, 0.24, 0.08), float3(0.62, 0.38, 0.10), float3(0.82, 0.56, 0.16),
                                      float3(0.94, 0.74, 0.26), float3(1.0, 0.88, 0.48));
            } else if (u.season > 2.5) {
                leafy = false; // winter: the bare branches are drawn below instead
            }
            if (leafy) {
                col = c * tint;
                clouded = true;
                land = true;
            }
        }

        // Winter: bare branches fanning up from the trunk, each forked, with snow along the top.
        if (u.season > 2.5 && tp.y > 30.0 && tp.y < 100.0 && abs(tp.x) < 50.0) {
            for (int b = 0; b < 7; b++) {
                float fb = float(b);
                float ang = (fb / 6.0 - 0.5) * 2.3 + (hash11(fb * 3.7) - 0.5) * 0.3;
                float2 base = float2(0.0, 34.0 + hash11(fb * 1.3) * 18.0);
                float len = 26.0 + hash11(fb * 2.9) * 22.0;
                float2 dir = float2(sin(ang), cos(ang));
                float2 tip = base + dir * len;
                float2 mid = base + dir * len * 0.55;
                float2 fork = mid + float2(sin(ang + 0.7 * (hash11(fb) > 0.5 ? 1.0 : -1.0)), cos(ang + 0.6)) * len * 0.45;
                for (int seg = 0; seg < 2; seg++) {
                    float2 a0 = seg == 0 ? base : mid;
                    float2 a1 = seg == 0 ? tip : fork;
                    float2 pa = tp - a0, ba = a1 - a0;
                    float hh = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
                    float d = length(pa - ba * hh);
                    float w = (seg == 0 ? 1.8 : 1.1) * (1.0 - hh * 0.65);
                    if (d < w + 0.6) {
                        bool snowTop = (pa - ba * hh).y > w * 0.2;
                        col = (snowTop ? float3(0.95, 0.97, 1.0) : float3(0.32, 0.23, 0.18)) * tint;
                        clouded = true;
                        land = true;
                    }
                }
            }
        }

        // A few leaves drift down from the oak and blow away with the wind.
        int falling = u.season > 2.5 ? 0 : u.season > 1.5 ? 14 : 6;
        for (int i = 0; i < falling; i++) {
            float fi = float(i);
            float period = 9.0 + hash11(fi * 4.1) * 6.0;
            float age = pmod(u.time + hash11(fi * 2.2) * period, period) / period;
            float2 start = treeAt + float2((hash11(fi * 6.3) - 0.5) * 60.0, 50.0 + hash11(fi * 8.1) * 25.0);
            float2 leaf = start + float2(-age * 70.0 + sin(age * 18.0 + fi) * 4.0, -age * (start.y - treeAt.y + 6.0));
            float2 q = p - leaf;
            float spin = sin(age * 25.0 + fi);
            if (abs(q.x) < 1.2 * abs(spin) + 0.4 && abs(q.y) < 0.7) {
                float3 leafCol = hash11(fi) > 0.5 ? float3(0.62, 0.80, 0.30) : float3(0.88, 0.72, 0.30);
                if (u.season < 0.5) leafCol = hash11(fi) > 0.5 ? float3(0.98, 0.74, 0.84) : float3(1.0, 0.94, 0.96); // petals
                if (u.season > 1.5) leafCol = hash11(fi) > 0.6 ? float3(0.86, 0.34, 0.14) : hash11(fi) > 0.3 ? float3(0.94, 0.62, 0.20) : float3(0.70, 0.26, 0.12);
                col = leafCol * tint;
            }
        }
    }

    // Night: twinkling stars, a crescent moon, and an aurora on some nights.
    if (night > 0.01 && v > 0.15) {
        float h = hash21(pixel);
        if (h > 0.9965 && !clouded) {
            float twinkle = 0.55 + 0.45 * sin(u.time * (0.4 + hash21(pixel + 7.0)) + h * 60.0);
            col = mix(col, float3(1.0, 0.97, 0.86), night * twinkle);
        }
        if ((u.background.x & kAurora) != 0u && !clouded) {
            float centre = groundTop + skyH * (0.62 + 0.12 * sin(p.x * 0.011 + u.time * 0.03) + 0.05 * sin(p.x * 0.037));
            float above = p.y - centre;
            if (above > -4.0 && above < 34.0) {
                float curtain = 0.6 + 0.4 * hash11(floor(p.x / 2.0)) * (0.7 + 0.3 * sin(u.time * 0.5 + p.x * 0.05));
                float fade = above < 0.0 ? 1.0 : 1.0 - above / 34.0;
                float kk = floor(curtain * fade * 4.0) / 4.0;
                col = mix(col, float3(0.25, 0.95, 0.80), kk * 0.55 * night);
            }
        }
    }
    float mp = pmod(u.dayPhase - 20.0 / 24.0, 1.0) / (10.0 / 24.0);
    if (mp < 1.0) {
        float2 centre = float2(mix(0.12, 0.88, mp) * width, groundTop + skyH * (0.5 + 0.38 * sin(mp * M_PI_F)));
        float2 dm = p - centre;
        float2 ds = dm - float2(3.0, 1.5);
        if (dot(dm, dm) <= 42.0 && dot(ds, ds) > 30.0) col = float3(0.98, 0.95, 0.80);
    }

    // The meadow: hazy toward the horizon, richer toward the viewer, with jagged light patches.
    if (p.y < groundTop) {
        float fromHorizon = groundTop - p.y;
        float nearness = clamp(fromHorizon / groundTop, 0.0, 1.0);
        float3 base = float3(0.44, 0.71, 0.34);
        float3 dark = float3(0.31, 0.57, 0.30);
        float3 light = float3(0.60, 0.80, 0.35);
        float3 bright = float3(0.74, 0.86, 0.40);
        float sx = p.x * (0.035 - nearness * 0.02);
        float n = noise2(float2(sx, p.y * (0.12 - nearness * 0.06)));
        // Grass-blade edges: the patch threshold jitters per column.
        float blades = (hash11(floor(pixel.x / max(1.0, k * 0.5)) * 1.3) - 0.5) * 0.06;
        float3 c = n + blades > 0.66 ? light : n + blades < 0.28 ? dark : base;
        if (n + blades > 0.8) c = bright;
        if (n + blades > 0.62 && n + blades <= 0.66 && checker(pixel)) c = light;
        // Darker strokes toward the viewer.
        if (nearness > 0.5 && noise2(float2(p.x * 0.3, p.y * 1.4)) > 0.82) c = dark;
        // Wind: gusts bend the grass, flashing its lighter side in short vertical strokes.
        float g2 = gust(p.x + p.y * 0.4, u.time);
        if (g2 > 0.05 && hash21(floor(float2(pixel.x / k, pixel.y / (k * 2.0)))) < g2 * 0.55) c = mix(c, bright, 0.55);
        if (p.y < walk) c = mix(c, float3(0.26, 0.50, 0.28), 0.2 + 0.35 * smoothstep(walk, 0.0, p.y));
        c = mix(c, bottom, (1.0 - nearness) * 0.3);
        if (fromHorizon < 1.0) c = mix(float3(0.58, 0.80, 0.42), bottom, 0.2);
        col = seasonal(c, u.season) * tint;

        // Puddles: they spread as the ground gets wet, mirror the sky, darken the soil
        // around them and ripple while it rains.
        if (u.wet > 0.01 && u.season < 2.5) { // in winter it lies as snow instead
            for (int i = 0; i < 8; i++) {
                float fi = float(i);
                float h1 = hash11(fi * 4.13 + 0.7), h2 = hash11(fi * 9.71 + 2.3);
                float2 c0 = float2(16.0 + h1 * (width - 32.0),
                                   i < 3 ? walk - 1.5 : 4.0 + h2 * max(1.0, walk - 12.0));
                float grow = smoothstep(h2 * 0.5, h2 * 0.5 + 0.45, u.wet);
                float rx = (8.0 + hash11(fi * 2.9) * 13.0) * grow;
                if (rx < 0.8) continue;
                float ry = rx * 0.28;
                float2 q = p - c0;
                if (abs(q.x) > rx * 1.5 || abs(q.y) > ry * 1.6) continue;
                float e = dot(q / float2(rx, ry), q / float2(rx, ry)) + (noise2(p * 0.35 + fi * 7.0) - 0.5) * 0.45;
                if (e < 1.0) {
                    float3 sky = mix(bottom, top, 0.35 + 0.3 * clamp(-q.y / ry, 0.0, 1.0)) * tint;
                    float3 water = mix(sky * 0.82, float3(0.20, 0.27, 0.34) * tint, e > 0.72 ? 0.45 : 0.12);
                    if (e > 0.72 && checker(pixel)) water = mix(water, col * 0.7, 0.4);
                    // A glint across the surface.
                    if (abs(q.y - ry * 0.35) < 0.4 && abs(q.x + rx * 0.2) < rx * 0.35) water = mix(water, float3(0.92, 0.96, 1.0) * tint, 0.55);
                    // Rain rings.
                    if (u.rain > 0.05) {
                        for (int j = 0; j < 3; j++) {
                            float fj = float(j) + fi * 3.0;
                            float phase = fract(u.time * (0.7 + hash11(fj) * 0.6) + hash11(fj * 1.7));
                            float2 rc = c0 + float2((hash11(fj * 5.1) - 0.5) * rx * 1.2, (hash11(fj * 6.3) - 0.5) * ry * 0.9);
                            float2 rq = p - rc;
                            float rr = length(float2(rq.x, rq.y * 3.2));
                            float ring = phase * 3.5;
                            if (abs(rr - ring) < 0.45 && hash11(fj * 8.0) < u.rain + 0.2) water = mix(water, float3(0.85, 0.91, 1.0) * tint, 0.6 * (1.0 - phase));
                        }
                    }
                    col = water;
                    break;
                } else if (e < 1.45) {
                    col *= 0.8; // soaked soil around the edge
                }
            }
        }

        // Grass tufts and flowers that sway in the breeze and lean into each gust.
        float2 cell = floor(p / float2(7.0, 4.0));
        for (int dx = -1; dx <= 1; dx++) {
            float2 cc = cell + float2(float(dx), 0.0);
            float h = hash21(cc + 31.0);
            // Most tufts in spring and fewest in winter, when only dry stalks poke through.
            if (h < (u.season > 2.5 ? 0.8 : 0.55)) continue;
            float2 root = cc * float2(7.0, 4.0) + float2(1.0 + hash21(cc + 3.0) * 5.0, 0.5);
            if (abs(root.y - walk) < 3.0 || root.y > groundTop - 2.0) continue;
            float scale = 0.6 + nearness * 0.9;
            float stemH = (2.5 + hash21(cc + 9.0) * 2.5) * scale;
            float up = p.y - root.y;
            if (up < 0.0 || up > stemH + 1.5 * scale) continue;
            float bend = (sin(u.time * 1.8 + cc.x * 0.7) * 0.35 - gust(root.x, u.time) * 1.6) * scale;
            float f = up / stemH;
            float sx = root.x + bend * f * f;
            float flowerOdds = u.season < 0.5 ? 0.8 : u.season < 1.5 ? 0.88 : u.season < 2.5 ? 0.95 : 2.0;
            bool flower = h > flowerOdds;
            if (up <= stemH && abs(p.x - sx) < 0.28 * max(1.0, scale)) {
                float3 stem = flower ? float3(0.30, 0.56, 0.28) : float3(0.56, 0.80, 0.40);
                if (u.season > 2.5) stem = float3(0.58, 0.50, 0.36);
                else if (u.season > 1.5) stem = seasonal(stem, u.season);
                col = stem * tint;
            }
            if (flower) {
                float2 head = float2(root.x + bend, root.y + stemH);
                float2 q = p - head;
                float r = 1.1 * scale;
                float kind = hash21(cc + 7.0);
                float3 petal = kind < 0.4 ? float3(1.0, 0.98, 0.92) : kind < 0.75 ? float3(0.99, 0.84, 0.32) : float3(0.98, 0.60, 0.70);
                if (u.season > 1.5) petal = kind < 0.5 ? float3(0.96, 0.62, 0.22) : float3(0.82, 0.36, 0.18); // autumn asters
                if (length(q) < r) col = (length(q) < r * 0.4 ? float3(0.97, 0.72, 0.25) : petal) * tint;
            }
        }

        // Cloud shadows sliding across the meadow.
        if (noise2(float2(p.x * 0.006 + u.time * 0.012, p.y * 0.02)) > 0.66) col *= 0.88;
    }

    // Cloud shadows on the hills too.
    if (p.y >= groundTop && p.y < groundTop + 40.0 && clouded && (u.background.x & kBackgroundImage) == 0u &&
        noise2(float2(p.x * 0.006 + u.time * 0.012, p.y * 0.02)) > 0.66) col *= 0.9;

    // Floating motes: pollen by day, fireflies on spring and summer nights. None in winter.
    int motes = u.season > 2.5 ? 0 : night > 0.5 ? (u.season < 1.5 ? 18 : 0) : 10;
    for (int i = 0; i < motes; i++) {
        float fi = float(i);
        float2 m = float2(pmod(hash11(fi * 3.7) * width - u.time * (2.0 + hash11(fi) * 3.0), width),
                          walk + 4.0 + hash11(fi * 5.9) * 40.0 + sin(u.time * 0.7 + fi * 2.3) * 5.0);
        m.x += sin(u.time * 0.9 + fi) * 6.0;
        float2 q = p - m;
        if (night > 0.5) {
            float blink = smoothstep(0.2, 1.0, sin(u.time * (0.8 + hash11(fi * 2.0)) + fi * 4.0));
            float r2 = dot(q, q);
            if (r2 < 1.6) col = mix(col, float3(0.92, 1.0, 0.55), blink);
            else if (r2 < 9.0) col = mix(col, float3(0.60, 0.88, 0.35), blink * 0.3 * (1.0 - r2 / 9.0));
        } else if (dot(q, q) < 0.35) {
            col = mix(col, float3(1.0, 0.98, 0.85), 0.7);
        }
    }

    // Rain clouds: the sky turns grey, heavier the harder it rains.
    if (u.rain > 0.01 && p.y > groundTop && !land) {
        float lum = dot(col, float3(0.30, 0.55, 0.15));
        float3 overcast = float3(lum) * float3(0.86, 0.90, 1.0) * 0.82;
        col = mix(col, overcast, 0.25 * u.rain + 0.45 * smoothstep(0.6, 1.0, u.rain));
    }

    // Lightning: the sky lights up, and a jagged bolt drops to the far hills.
    if (u.flash > 0.0) {
        bool sky = p.y > groundTop && !land;
        col = mix(col, float3(0.86, 0.90, 1.0), u.flash * (sky ? 0.55 : 0.28));
        if (u.bolt >= 0.0 && sky) {
            float seed = floor(u.bolt * 7.0);
            float seg = 14.0;
            float y0 = floor(p.y / seg);
            float t = fract(p.y / seg);
            float a = (hash11(y0 + seed) - 0.5) * 16.0, b = (hash11(y0 + 1.0 + seed) - 0.5) * 16.0;
            float bx = u.bolt + mix(a, b, t);
            float d = abs(p.x - bx);
            if (d < 1.4) col = float3(1.0, 1.0, 0.96);
            else if (d < 3.0) col = mix(col, float3(0.80, 0.86, 1.0), 0.5 * u.flash);
        }
    }

    // Rain: thin diagonal streaks, sparse in a drizzle and dense in a storm, darkening the day.
    if (u.rain > 0.01) {
        col *= 1.0 - 0.10 * u.rain - 0.14 * smoothstep(0.7, 1.0, u.rain);
        // Speed and slant stay fixed: if they followed the intensity, the drops would lurch
        // backward while the rain eased in or out. Time wraps each minute to keep precision.
        float lane = pixel.x - pixel.y * 0.6;
        float hl = hash11(floor(lane) * 0.731);
        bool winter = u.season > 2.5;
        if (winter) {
            // Snow instead of rain: soft flakes drifting down and sideways, in two sizes.
            for (int layer = 0; layer < 2; layer++) {
                float fl = float(layer);
                float size = (layer == 0 ? 1.0 : 0.5) * k;
                float cellS = (layer == 0 ? 14.0 : 9.0) * k;
                float t = pmod(u.time, 120.0);
                float2 fp = pixel + float2(sin(t * 0.6 + pixel.y * 0.02 + fl) * 4.0 * k - t * 6.0 * k, t * (layer == 0 ? 26.0 : 16.0) * k);
                float2 cellF = floor(fp / cellS);
                float hf = hash21(cellF + fl * 17.0);
                if (hf < 0.5 * u.rain) {
                    float2 c = cellF * cellS + floor(float2(hash21(cellF + 4.0), hash21(cellF + 8.0)) * (cellS - 2.0 * k)) + k;
                    float2 q = fp - c;
                    if (q.x >= 0.0 && q.y >= 0.0 && q.x < size * 2.0 && q.y < size * 2.0) col = mix(col, float3(0.97, 0.98, 1.0), layer == 0 ? 0.9 : 0.6);
                }
            }
        }
        if (!winter && hl < 0.13 * u.rain) {
            float s2 = pixel.y + pmod(u.time, 60.0) * 320.0 + hl * 997.0;
            if (pmod(s2, 90.0 + floor(hl * 400.0)) < 3.0 + 5.0 * u.rain) col = mix(col, float3(0.78, 0.84, 0.95), 0.5);
        }

        // Splashes where drops hit the meadow: a dot, then a little crown and a ripple.
        if (!winter && p.y < walk + 26.0) {
            float2 cellSize = float2(11.0, 7.0) * k;
            float2 site = floor(pixel / cellSize);
            float h = hash21(site * 1.37 + 3.1);
            if (h < 0.6 * u.rain) {
                float phase = fract(u.time * (1.1 + h * 0.8) + h * 13.0);
                if (phase < 0.25) {
                    float2 c = site * cellSize + floor(float2(hash21(site + 5.0), hash21(site + 9.0)) * (cellSize - 6.0 * k)) + 3.0 * k;
                    float2 q = floor((pixel - c) / k); // drawn in landscape pixels, like the art
                    float t = phase / 0.25;
                    float r = floor(1.0 + 3.0 * t);
                    float up = floor(2.5 * sin(t * 3.14159));
                    bool hit = false;
                    if (t < 0.2) hit = q.x == 0.0 && q.y == 0.0;
                    else {
                        hit = (abs(q.x) == r && q.y == up) || (abs(q.x) == r - 1.0 && q.y == up + 1.0 && t < 0.6);
                        hit = hit || (q.y == -1.0 && abs(q.x) <= r + 1.0 && abs(q.x) >= r - 1.0 && t > 0.4);
                    }
                    if (hit) col = mix(col, float3(0.86, 0.92, 1.0), 0.8 * (1.0 - 0.5 * t));
                }
            }
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
            float lean = (hash11(cell * 3.3) - 0.5) * 4.0 + sin(u.time * 1.3 + cell * 0.37) * 0.8
                       - gust(g.x, u.time) * 6.0;
            if (abs(pixel.x - bx - lean * t * t) < 0.6) {
                float3 c = t > 0.65 ? float3(0.62, 0.84, 0.42) : t > 0.3 ? float3(0.45, 0.72, 0.36) : float3(0.32, 0.56, 0.30);
                if (u.season > 2.5) c = t > 0.6 ? float3(0.66, 0.58, 0.42) : float3(0.50, 0.42, 0.30); // dry stalks
                else c = seasonal(c, u.season);
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
        col = seasonal(c, u.season) * tint; // a snow bank in winter
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
            // Impact frame: a pure white silhouette for the first instant of a hit.
            if ((it.flags & kWhiteFlash) != 0u) col = float3(1.0, 0.98, 0.94);
        }
    }

    // Bars and icons are drawn at 2x, matching the chunkier HUD scale.
    float iconBase = origin.y + (it.barLift > 0.0 ? it.barLift : size);
    float2 hud = floor((g - float2(0.0, iconBase)) / 2.0); // bars and icons at 2x
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
                             texture2d<float, access::sample> image [[texture(1)]],
                             texture2d<uint, access::read> ui [[texture(2)]],
                             constant UIUniforms& uu [[buffer(2)]]) {
    // Snap every screen pixel to its cell on the virtual grid, origin bottom-left.
    float cell = u.resolution.x / u.grid.x;
    float2 frag = float2(in.position.x, u.resolution.y - in.position.y);
    float2 gUI = floor(frag / cell);
    float2 g = gUI - u.shake; // heavy hits shake the scene, not the UI
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

    if (uu.enabled != 0u) {
        int uw = int(ui.get_width()), uh = int(ui.get_height());
        float s = u.grid.x / float(uw); // grid pixels per UI pixel
        int ux = int(gUI.x / s), uy = uh - 1 - int(gUI.y / s);
        if (ux >= 0 && uy >= 0 && ux < uw && uy < uh) {
            uint ink = ui.read(uint2(uint(ux), uint(uy))).r;
            if (ink == 255u) col = mix(col, float3(0.08, 0.07, 0.12), 0.62);
            else if (ink != 0u) col = inkColour(ink, uu.primary.rgb, uu.secondary.rgb);
        }
    }
    return float4(saturate(col), 1.0);
}
