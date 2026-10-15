#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Cheap two-colour calendar press, as SwiftUI shaders.
//
// All positions are divided by `unit` (the card scale) first, so grain, fibres and
// misregistration stay the same physical size on the paper at any zoom level.
// `seed` comes from the date, so each day's sheet has its own, stable print flaws.

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float valueNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * valueNoise(p);
        p = p * 2.03 + 17.0;
        a *= 0.5;
    }
    return v;
}

// Round specks scattered on a grid: 1 inside a speck, 0 elsewhere. `density` = share of cells with one.
static float specks(float2 p, float density) {
    float2 cell = floor(p), f = fract(p);
    if (hash21(cell) > density) return 0.0;
    float2 centre = float2(hash21(cell + 3.1), hash21(cell + 7.7)) * 0.6 + 0.2;
    float radius = 0.12 + 0.22 * hash21(cell + 11.3);
    return 1.0 - smoothstep(radius * 0.6, radius, length(f - centre));
}

// Paper: applied as a colorEffect to a flat paper-coloured rectangle.
// age 0…1 yellows the whole sheet (sheets deeper in the pad are older stock).
[[ stitchable ]] half4 newsprintPaper(float2 position, half4 color,
                                      float2 size, float unit, float seed, float age) {
    float2 p = position / unit;
    float grain = hash21(floor(p * 1.6) + seed) - 0.5;           // fine pulp grain
    float cloud = fbm(p * 0.035 + seed) - 0.5;                    // uneven formation
    float fibre = fbm(float2(p.x * 0.9, p.y * 0.06) + seed * 3.1) - 0.5; // streaky fibres

    float2 uv = position / size;
    float2 d = abs(uv - 0.5) * 2.0;
    float edge = smoothstep(0.6, 1.0, max(d.x, d.y));             // yellowed, handled edges

    half3 c = color.rgb;
    c += half(grain * 0.03 + cloud * 0.045 + fibre * 0.025);
    half3 yellowed = c * half3(0.95, 0.88, 0.72);
    c = mix(c, yellowed, half(clamp(edge * 0.35 + age * 0.35, 0.0, 1.0)));
    return half4(c * color.a, color.a);
}

// How much of a (premultiplied) pixel is red ink rather than black ink.
static half redPlate(half4 s) {
    if (s.a < 0.001h) return 0.0h;
    half3 c = s.rgb / s.a;
    return clamp((c.r - max(c.g, c.b)) * 2.0h, 0.0h, 1.0h) * s.a;
}

static half blackPlate(half4 s) {
    return max(s.a - redPlate(s), 0.0h);
}

// Ink: applied as a layerEffect to the printed content (transparent background), drawn
// with a multiply blend over the paper. Splits the layer into black and red plates, then:
// - offsets the red plate (misregistration),
// - spreads ink slightly into the paper (fattened, soft type),
// - varies ink density and drops out specks where the paper didn't take ink.
// Returns an opaque "print" colour: white = no ink.
[[ stitchable ]] half4 newsprintInk(float2 position, SwiftUI::Layer layer,
                                    float unit, float seed, float2 redOffset) {
    float2 p = position / unit;

    // Black plate with a little ink spread.
    float spread = 0.35 * unit;
    half k = blackPlate(layer.sample(position));
    half around = max(max(blackPlate(layer.sample(position + float2(spread, 0))),
                          blackPlate(layer.sample(position - float2(spread, 0)))),
                      max(blackPlate(layer.sample(position + float2(0, spread))),
                          blackPlate(layer.sample(position - float2(0, spread)))));
    k = max(k, around * 0.18h);

    // Red plate, printed in a separate pass, slightly out of register.
    half r = redPlate(layer.sample(position - redOffset * unit));

    // Uneven inking across the sheet, and white specks where ink didn't take.
    half density = half(0.80 + 0.20 * fbm(p * 0.05 + seed * 1.7));          // broad uneven inking
    half worn = half(1.0 - 0.25 * smoothstep(0.62, 0.8, fbm(p * 0.22 + seed * 2.9))); // softer worn patches
    half dropout = half(1.0 - 0.7 * specks(p * 0.9 + seed * 5.3, 0.07));    // sparse white specks
    k *= density * worn * dropout;
    r *= density * half(1.0 - 0.6 * specks(p * 0.8 + seed * 9.1, 0.06));

    // Overprint the two inks (subtractive), like a real press.
    const half3 blackInk = half3(0.12, 0.11, 0.10);
    const half3 redInk = half3(0.80, 0.11, 0.13);
    half3 out = mix(half3(1.0h), blackInk, k) * mix(half3(1.0h), redInk, r);
    return half4(out, 1.0h);
}

static float2 hash22(float2 p) {
    float n = hash21(p);
    return float2(n, hash21(p + n + 19.19));
}

// Voronoi cells: returns the distance to the nearest cell border (0 on a fold line)
// and the id of the cell the point falls in.
static float voronoi(float2 g, float seed, thread float2 &cellId) {
    float2 cell = floor(g), f = fract(g);
    float best = 8.0, second = 8.0;
    cellId = cell;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 o = float2(x, y);
            float dist = length(o + hash22(cell + o + seed) - f);
            if (dist < best) { second = best; best = dist; cellId = cell + o; }
            else if (dist < second) { second = dist; }
        }
    }
    return second - best;
}

// Crumpling a printed sheet into a ball. Applied as a layerEffect to the full sheet face.
// t: 0 = flat sheet … 1 = finished ball. The outline morphs from the rectangle into a lumpy
// ball. Early on the sheet is squeezed as a whole; as it closes up, every small facet shows a
// random scrap from anywhere on the sheet, so like a real paper ball the print is reduced to
// unreadable fragments, half lost in the folds. Facets at three scales give the crinkle.
[[ stitchable ]] half4 crumple(float2 position, SwiftUI::Layer layer, float2 size, float t,
                               float unit, float seed) {
    float e = t * t * (3.0 - 2.0 * t);
    float2 c = size * 0.5;
    float2 q = position - c;
    float2 h = size * 0.5;
    // A small chit makes a small wad: about a quarter of the sheet's width across.
    float ballR = min(size.x, size.y) * 0.12;

    // Outline: rectangle → lumpy, slightly angular ball, with a crinkled edge mid-way.
    float ang = atan2(q.y, q.x);
    float2 dir = float2(cos(ang), sin(ang));
    float lumps = 0.34 * (valueNoise(dir * 1.4 + seed) - 0.5)
                + 0.16 * (valueNoise(dir * 3.6 + seed * 2.0) - 0.5)
                + 0.06 * (valueNoise(dir * 9.0 + seed * 3.0) - 0.5);
    float r = ballR * (1.0 + lumps);
    float2 dq = abs(q) - h;
    float sdRect = length(max(dq, 0.0)) + min(max(dq.x, dq.y), 0.0);
    float sdBall = length(q) - r;
    float d = mix(sdRect, sdBall, e);
    d += (valueNoise(q / unit * 0.12 + seed) - 0.5) * 9.0 * unit * sin(3.14159 * e);
    float alpha = 1.0 - smoothstep(-0.8 * unit, 0.8 * unit, d);
    if (alpha <= 0.0) return half4(0.0h);

    // Three scales of folding, tightening as the paper is squeezed; warped so they don't tile.
    float2 warp = (float2(fbm(q / unit * 0.05 + seed), fbm(q / unit * 0.05 + seed + 7.0)) - 0.5) * 30.0 * unit;
    float bigSize = mix(140.0 * unit, ballR * 0.9, e);
    float midSize = mix(70.0 * unit, ballR * 0.45, e);
    float fineSize = mix(40.0 * unit, ballR * 0.2, e);
    float2 bigId, midId, fineId;
    float bigCrease = voronoi((q + warp) / bigSize, seed, bigId);
    float midCrease = voronoi((q - warp * 0.5) / midSize, seed + 3.7, midId);
    voronoi((q + warp * 0.3) / fineSize, seed + 9.1, fineId);   // texture only, no fold lines
    float2 bigRnd = hash22(bigId + seed * 1.3) - 0.5;
    float2 midRnd = hash22(midId + seed * 2.1) - 0.5;
    float2 fineRnd = hash22(fineId + seed * 4.7) - 0.5;

    // Print: early on, the whole sheet squeezed in; later, each mid facet shows a random scrap.
    float squeeze = mix(1.0, length(h) / ballR * 0.85, e);
    float2 squeezed = c + q * squeeze + bigRnd * bigSize * 2.0 * e;
    float2 scrap = (hash22(midId + seed * 5.3) * 0.9 + 0.05) * size + (q - midId * midSize) * 1.6;
    float2 src = mix(squeezed, scrap, smoothstep(0.3, 0.8, t));
    src = clamp(src, float2(2.0), size - 2.0);
    half4 col = layer.sample(src);
    const half3 paper = half3(0.95h, 0.94h, 0.90h);
    if (col.a < 0.5h) col = half4(paper, 1.0h); // behind torn bits
    // Much of the ink ends up inside the folds or seen edge-on.
    col.rgb = mix(col.rgb, paper, half(0.65 * smoothstep(0.4, 1.0, t)));

    // Light: a rounded body with every facet tilted its own way.
    float2 sp = q / max(r, 1.0);
    float3 body = normalize(float3(sp * 1.15, sqrt(max(0.05, 1.0 - dot(sp, sp) * 0.85))));
    float3 n = body + float3(bigRnd * 1.5 + midRnd * 0.7 + fineRnd * 0.2, 0.0);
    n = normalize(mix(float3(0, 0, 1), normalize(n), e));
    float3 light = normalize(float3(-0.5, -0.65, 0.58));
    float lambert = clamp(dot(n, light), 0.0, 1.0);
    float shade = mix(1.0, 0.66 + 0.48 * lambert, e);
    // Crisp sheen where a facet faces the light, like slightly glossy paper.
    float3 halfway = normalize(light + float3(0, 0, 1));
    shade += 0.18 * e * pow(clamp(dot(n, halfway), 0.0, 1.0), 18.0);
    // Folds: crisp main folds, faint secondary creases.
    shade *= 1.0 - 0.32 * e * (1.0 - smoothstep(0.0, 0.035, bigCrease));
    shade *= 1.0 - 0.12 * e * (1.0 - smoothstep(0.0, 0.04, midCrease));
    shade *= 1.0 - 0.28 * e * smoothstep(0.6, 1.0, length(sp));            // rim turns away

    // Shadows in paper are warm, not grey.
    half3 tint = mix(half3(0.84h, 0.78h, 0.68h), half3(1.0h), half(clamp(shade, 0.0, 1.0)));
    col.rgb *= half(shade) * tint;
    return col * half(alpha);
}

// Ink on dark card stock: the black plate prints cream, the red plate prints the accent colour.
// Same press flaws as newsprintInk; returns ink with alpha, drawn normally over the dark paper.
[[ stitchable ]] half4 darkStockInk(float2 position, SwiftUI::Layer layer,
                                   float unit, float seed, float2 redOffset) {
    float2 p = position / unit;
    float spread = 0.35 * unit;
    half k = blackPlate(layer.sample(position));
    half around = max(max(blackPlate(layer.sample(position + float2(spread, 0))),
                          blackPlate(layer.sample(position - float2(spread, 0)))),
                      max(blackPlate(layer.sample(position + float2(0, spread))),
                          blackPlate(layer.sample(position - float2(0, spread)))));
    k = max(k, around * 0.18h);
    half r = redPlate(layer.sample(position - redOffset * unit));

    half density = half(0.78 + 0.22 * fbm(p * 0.05 + seed * 1.7));
    half dropout = half(1.0 - 0.7 * specks(p * 0.9 + seed * 5.3, 0.07));
    k *= density * dropout;
    r *= density * half(1.0 - 0.6 * specks(p * 0.8 + seed * 9.1, 0.06));

    const half3 creamInk = half3(0.93, 0.89, 0.80);
    const half3 accentInk = half3(0.96, 0.62, 0.20);
    half a = clamp(k + r, 0.0h, 1.0h);
    if (a < 0.001h) return half4(0.0h);
    half3 c = (creamInk * k * (1.0h - r) + accentInk * r) / max(k * (1.0h - r) + r, 0.001h);
    return half4(c * a, a);
}

// Glossy printed card (the backing board): fine print grain and a soft sheen from the top left.
[[ stitchable ]] half4 boardPrint(float2 position, half4 color, float2 size, float unit, float seed) {
    float2 p = position / unit;
    float grain = hash21(floor(p * 1.3) + seed) - 0.5;
    float blotch = fbm(p * 0.02 + seed) - 0.5;
    float2 uv = position / size;
    float sheen = 0.10 * smoothstep(0.9, 0.0, length(uv - float2(0.15, 0.05)));
    half3 c = color.rgb * half(1.0 + grain * 0.06 + blotch * 0.08) + half(sheen);
    return half4(c * color.a, color.a);
}
