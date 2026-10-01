// Pixel Pets: the whole scene in one fragment shader.
// Swift owns every bit of state; this only draws what SceneUniforms and SceneItem describe.
// Compiled at runtime from the app bundle, so building needs only swiftc.

#include <metal_stdlib>
using namespace metal;

// Must match SceneTypes.swift exactly (64 and 80 bytes).
struct SceneUniforms {
    float2 resolution;   // drawable size in real pixels
    float2 grid;         // virtual grid size, e.g. 320 x 200
    float  time;         // seconds, wraps every 6 h
    float  dayPhase;     // 0..1, local midnight to midnight
    float  rain;         // 0..1
    float  playMode;     // 0 or 1
    uint   itemCount;
    uint3  pad;
};

struct SceneItem {
    float2 position;     // grid px, bottom-centre of the sprite
    uint   tile;
    uint   tileSpan;     // 1 = 16x16, 2 = 32x32
    float4 primary;
    float4 secondary;
    float4 bars;         // health, hunger, happiness; negative = hidden
    int    icon;         // icon tile, -1 = none
    uint   flags;        // 1 flipX, 2 hurt flash, 4 blink health, 8 egg bar, 16 monster bar
    uint2  pad;
};

constant uint kMaxItems = 24;
constant uint kAtlasColumns = 16;

constant uint kFlipX = 1;
constant uint kHurt = 2;
constant uint kBlinkHealth = 4;
constant uint kEggBar = 8;
constant uint kMonsterBar = 16;

constant float3 kOutline = float3(0.169, 0.133, 0.200);

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

static float3 inkColour(uint ink, float3 primary, float3 secondary) {
    switch (ink) {
        case 1: return kOutline;
        case 2: return primary;
        case 3: return secondary;
        case 4: return float3(0.102, 0.078, 0.125);
        case 5: return float3(1.0, 1.0, 1.0);
        case 6: return float3(0.910, 0.290, 0.373);
        case 7: return float3(0.482, 0.788, 0.314);
        case 8: return float3(0.969, 0.827, 0.345);
        case 9: return float3(0.353, 0.333, 0.400);
        default: return float3(0.0);
    }
}

// MARK: - Sky keyframes: dawn 06:00, day 12:00, dusk 19:00, night 22:00

constant float kKeyTime[4] = { 0.25, 0.5, 0.791667, 0.916667 };
constant float3 kSkyTop[4] = {
    float3(0.40, 0.45, 0.72), float3(0.36, 0.63, 0.95), float3(0.36, 0.28, 0.56), float3(0.05, 0.06, 0.16)
};
constant float3 kSkyBottom[4] = {
    float3(0.99, 0.72, 0.56), float3(0.74, 0.89, 0.99), float3(0.99, 0.56, 0.38), float3(0.13, 0.14, 0.30)
};
constant float3 kTint[4] = {
    float3(0.95, 0.85, 0.82), float3(1.0, 1.0, 1.0), float3(0.92, 0.76, 0.70), float3(0.38, 0.42, 0.62)
};
constant float kStars[4] = { 0.15, 0.0, 0.1, 1.0 };

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

// MARK: - Landscape

static float3 landscape(float2 g, constant SceneUniforms& u) {
    DayBlend d = dayBlend(u.dayPhase);
    float3 tint = mix(kTint[d.a], kTint[d.b], d.t);
    float stars = mix(kStars[d.a], kStars[d.b], d.t);
    float groundTop = floor(u.grid.y * 0.25);
    float skyH = max(1.0, u.grid.y - groundTop);

    // Sky: a gradient stepped into 6 bands.
    float v = clamp((g.y - groundTop) / skyH, 0.0, 1.0);
    float band = min(floor(v * 6.0) / 5.0, 1.0);
    float3 top = mix(kSkyTop[d.a], kSkyTop[d.b], d.t);
    float3 bottom = mix(kSkyBottom[d.a], kSkyBottom[d.b], d.t);
    float3 col = mix(bottom, top, band);

    // Stars that twinkle slowly.
    if (stars > 0.01 && v > 0.2) {
        float h = hash21(g);
        if (h > 0.986) {
            float twinkle = 0.55 + 0.45 * sin(u.time * (0.4 + hash21(g + 7.0)) + h * 60.0);
            col = mix(col, float3(1.0, 0.97, 0.86), stars * twinkle);
        }
    }

    // A crescent moon from 20:00 to 06:00, arcing across the sky.
    float mp = pmod(u.dayPhase - 20.0 / 24.0, 1.0) / (10.0 / 24.0);
    if (mp < 1.0) {
        float2 centre = float2(floor(mix(0.12, 0.88, mp) * u.grid.x),
                               floor(groundTop + skyH * (0.45 + 0.4 * sin(mp * M_PI_F))));
        float2 dm = g - centre;
        float2 ds = dm - float2(2.0, 1.0);
        if (dot(dm, dm) <= 25.0 && dot(ds, ds) > 16.0) {
            col = float3(0.98, 0.95, 0.80);
        }
    }

    // Clouds drifting left.
    float3 cloudCol = mix(float3(1.0), top, 0.12) * mix(float3(1.0), tint, 0.7);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float speed = 1.2 + hash11(fi * 3.1) * 1.6;
        float span = u.grid.x + 80.0;
        float cx = floor(span - pmod(u.time * speed + hash11(fi * 7.7) * span, span) - 40.0);
        float cy = floor(groundTop + skyH * (0.5 + 0.4 * hash11(fi * 5.3)));
        float2 p = g - float2(cx, cy);
        bool inCloud = p.y >= 0.0 && (length(p) < 6.5 || length(p - float2(8.0, -1.0)) < 5.0 ||
                                      length(p - float2(-8.0, -1.0)) < 4.5 || length(p - float2(3.0, 4.0)) < 4.5);
        if (inCloud) col = cloudCol;
    }

    // Two layers of hills, each a sum of sines on whole pixels.
    float farH = groundTop + 14.0 + floor(6.0 * sin(g.x * 0.025 + 1.3) + 4.0 * sin(g.x * 0.061 + 0.4) + 2.0 * sin(g.x * 0.13));
    float nearH = groundTop + 5.0 + floor(5.0 * sin(g.x * 0.037 + 2.1) + 3.0 * sin(g.x * 0.083 + 5.0));
    if (g.y < farH) col = float3(0.58, 0.77, 0.58) * tint;
    if (g.y < nearH) col = float3(0.38, 0.63, 0.40) * tint;

    // Ground: a grass line, then a meadow with a little texture.
    float3 grass = float3(0.45, 0.73, 0.36);
    if (g.y < groundTop) {
        float depth = groundTop - 1.0 - g.y;
        float3 c = depth < 1.0 ? grass * 1.18 : grass;
        if (depth >= 1.0 && hash21(g) > 0.9) c *= 0.88;
        if (depth > groundTop * 0.55) c = mix(c, float3(0.55, 0.45, 0.32), 0.35);
        col = c * tint;
    }
    // Tufts poking up from the grass line.
    float tuft = hash11(g.x * 1.7 + 3.0);
    if ((g.y == groundTop && tuft > 0.78) || (g.y == groundTop + 1.0 && tuft > 0.94)) {
        col = grass * 1.18 * tint;
    }

    // Flowers placed by hash, swaying on a 2-frame cycle.
    float cellW = 23.0;
    for (int k = -1; k <= 1; k++) {
        float c = floor(g.x / cellW) + float(k);
        if (hash11(c * 3.7 + 1.0) < 0.45) continue;
        float fx = c * cellW + floor(hash11(c * 9.1) * (cellW - 4.0)) + 2.0;
        float fy = groundTop - 3.0 - floor(hash11(c * 4.3) * max(1.0, groundTop - 8.0));
        float sway = pmod(floor(u.time) + c, 2.0);
        float2 p = g - float2(fx, fy);
        if (p.x == 0.0 && (p.y == 0.0 || p.y == 1.0)) col = float3(0.27, 0.52, 0.25) * tint;
        float2 hp = p - float2(sway, 2.0);
        float petalKind = hash11(c * 2.9);
        float3 petal = petalKind < 0.33 ? float3(0.95, 0.45, 0.55) : petalKind < 0.66 ? float3(1.0, 0.95, 0.9) : float3(0.7, 0.6, 1.0);
        if (abs(hp.x) + abs(hp.y) == 1.0) col = petal * tint;
        if (hp.x == 0.0 && hp.y == 0.0) col = float3(0.97, 0.83, 0.35) * tint;
    }

    // Rain: 1-pixel diagonal streaks.
    if (u.rain > 0.01) {
        col *= mix(1.0, 0.82, u.rain);
        float lane = g.x - g.y;
        float hl = hash11(lane * 0.731);
        if (hl < 0.35 * u.rain) {
            float s = g.y + u.time * 90.0 + hl * 997.0;
            if (pmod(s, 29.0 + floor(hl * 40.0)) < 3.0) {
                col = mix(col, float3(0.78, 0.84, 0.95), 0.6);
            }
        }
    }

    return col;
}

// MARK: - Items

static uint readAtlas(texture2d<uint, access::read> atlas, uint tile, uint2 local) {
    uint2 origin = uint2((tile % kAtlasColumns) * 16u, (tile / kAtlasColumns) * 16u);
    return atlas.read(origin + local).r;
}

static float3 drawItem(constant SceneItem& it, float2 g, constant SceneUniforms& u,
                       texture2d<uint, access::read> atlas, float3 col) {
    float size = 16.0 * float(max(it.tileSpan, 1u));
    float2 origin = float2(floor(it.position.x - size * 0.5), floor(it.position.y));
    float2 local = g - origin;

    // Sprite
    if (local.x >= 0.0 && local.y >= 0.0 && local.x < size && local.y < size) {
        uint lx = uint(local.x);
        uint ly = uint(size - 1.0 - local.y);
        if ((it.flags & kFlipX) != 0u) lx = uint(size) - 1u - lx;
        uint ink = readAtlas(atlas, it.tile, uint2(lx, ly));
        if (ink != 0u) {
            float3 c = inkColour(ink, it.primary.rgb, it.secondary.rgb);
            if ((it.flags & kHurt) != 0u) c = mix(c, float3(1.0, 0.25, 0.25), 0.6);
            col = c;
        }
    }

    // Bars: 12 x 2 (or the sprite's width for monsters), 1 px outline, 1 px gaps.
    float iconBase = origin.y + size;
    if (it.bars.x >= 0.0) {
        bool single = (it.flags & (kEggBar | kMonsterBar)) != 0u;
        float count = single ? 1.0 : 3.0;
        float inner = (it.flags & kMonsterBar) != 0u ? size * 0.75 : 12.0;
        float blockH = count * 4.0 + (count - 1.0);
        float2 b0 = float2(floor(it.position.x - (inner + 2.0) * 0.5), origin.y + size);
        float2 p = g - b0;
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
                    col = kOutline;
                } else {
                    bool filled = (p.x - 1.0) < round(clamp(value, 0.0, 1.0) * inner);
                    bool blinkOff = (it.flags & kBlinkHealth) != 0u && index == 0 && fract(u.time * 2.0) < 0.5;
                    col = filled && !blinkOff ? fill : float3(0.22, 0.19, 0.26);
                }
            }
        }
        iconBase = b0.y + blockH + 1.0;
    }

    // Feeling icon, 8 x 8, in the top-left of its tile.
    if (it.icon >= 0) {
        float2 ip = g - float2(floor(it.position.x - 4.0), iconBase);
        if (ip.x >= 0.0 && ip.y >= 0.0 && ip.x < 9.0 && ip.y < 9.0) {
            uint ink = readAtlas(atlas, uint(it.icon), uint2(uint(ip.x), 8u - uint(ip.y)));
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
                             texture2d<uint, access::read> atlas [[texture(0)]]) {
    // Snap every screen pixel to its cell on the virtual grid, origin bottom-left.
    float cell = u.resolution.x / u.grid.x;
    float2 frag = float2(in.position.x, u.resolution.y - in.position.y);
    float2 g = floor(frag / cell);

    float3 col = landscape(g, u);
    if (u.playMode > 0.5) col *= 0.85;

    uint count = min(u.itemCount, kMaxItems);
    for (uint i = 0; i < count; i++) {
        col = drawItem(items[i], g, u, atlas, col);
    }
    return float4(saturate(col), 1.0);
}
