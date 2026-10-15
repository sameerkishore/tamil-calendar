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
