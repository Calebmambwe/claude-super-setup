#!/usr/bin/env node
/**
 * OKLCH Color Palette Generator
 * Converts a hex color to OKLCH and generates a full design token palette.
 *
 * Conversion pipeline: hex → sRGB → linear RGB → XYZ D65 → Oklab → OKLCH
 * No external dependencies.
 */

// ---------------------------------------------------------------------------
// 1. Conversion utilities
// ---------------------------------------------------------------------------

/**
 * Parse a hex string into {r, g, b} components in the 0-255 range.
 * Accepts "#rgb", "#rrggbb", with or without the leading '#'.
 */
export function hexToRgb(hex) {
  const clean = hex.replace(/^#/, "");

  if (clean.length === 3) {
    return {
      r: parseInt(clean[0] + clean[0], 16),
      g: parseInt(clean[1] + clean[1], 16),
      b: parseInt(clean[2] + clean[2], 16),
    };
  }

  if (clean.length === 6) {
    return {
      r: parseInt(clean.slice(0, 2), 16),
      g: parseInt(clean.slice(2, 4), 16),
      b: parseInt(clean.slice(4, 6), 16),
    };
  }

  throw new Error(`Invalid hex color: "${hex}"`);
}

/**
 * Apply the sRGB electro-optical transfer function (gamma decode) to a single
 * channel value that is in the 0-1 range.
 */
function srgbToLinearChannel(c) {
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

/**
 * Convert 8-bit sRGB {r, g, b} (0-255) to linear-light sRGB (0-1).
 */
export function rgbToLinear(rgb) {
  return {
    r: srgbToLinearChannel(rgb.r / 255),
    g: srgbToLinearChannel(rgb.g / 255),
    b: srgbToLinearChannel(rgb.b / 255),
  };
}

/**
 * Convert linear-light sRGB to Oklab.
 * Reference: https://bottosson.github.io/posts/oklab/
 *
 * The matrix values are:
 *   M1  (sRGB→LMS)  — Björn Ottosson's published constants
 *   M2  (LMS^(1/3) → Lab)
 */
export function linearToOklab(rgb) {
  const { r, g, b } = rgb;

  // Step 1: linear sRGB → LMS (Oklab cone responses)
  const l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  const m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  const s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  // Step 2: non-linear compression (cube root)
  const l_ = Math.cbrt(l);
  const m_ = Math.cbrt(m);
  const s_ = Math.cbrt(s);

  // Step 3: LMS' → Oklab
  return {
    L: 0.2104542553 * l_ + 0.793617785 * m_ - 0.0040720468 * s_,
    a: 1.9779984951 * l_ - 2.428592205 * m_ + 0.4505937099 * s_,
    b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.808675766 * s_,
  };
}

/**
 * Convert Oklab {L, a, b} to OKLCH {L, C, H}.
 * H is in degrees [0, 360).
 */
export function oklabToOklch(lab) {
  const C = Math.sqrt(lab.a ** 2 + lab.b ** 2);
  let H = (Math.atan2(lab.b, lab.a) * 180) / Math.PI;
  if (H < 0) H += 360;
  return { L: lab.L, C, H };
}

/**
 * Format OKLCH values as a CSS oklch() function string.
 * Rounds to 3 decimal places for compact output.
 */
export function oklchToCss(L, C, H) {
  const fmt = (n, digits = 3) => parseFloat(n.toFixed(digits));
  return `oklch(${fmt(L)} ${fmt(C)} ${fmt(H)})`;
}

// ---------------------------------------------------------------------------
// 2. Scale generation
// ---------------------------------------------------------------------------

/**
 * The 11 standard Tailwind/Radix-style lightness stops.
 * Index 0 = shade 50 (lightest), index 10 = shade 950 (darkest).
 */
const LIGHTNESS_STOPS = [0.98, 0.95, 0.9, 0.82, 0.72, 0.62, 0.52, 0.42, 0.32, 0.22, 0.12];
const SHADE_NAMES = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];

/**
 * Generate an 11-shade primary color scale.
 * Lightness is varied across the scale while chroma and hue are preserved
 * (chroma is slightly compressed at the extremes to stay in gamut).
 *
 * Returns an array of { shade, L, C, H, css } objects.
 */
export function generateScale(L, C, H) {
  return LIGHTNESS_STOPS.map((lightness, i) => {
    // Compress chroma gently at very light and very dark ends
    const chromaScale = lightness > 0.9 ? 0.6 : lightness < 0.15 ? 0.7 : 1.0;
    const c = C * chromaScale;

    return {
      shade: SHADE_NAMES[i],
      L: lightness,
      C: c,
      H,
      css: oklchToCss(lightness, c, H),
    };
  });
}

/**
 * Generate an 11-shade neutral (gray) scale with a subtle brand hue tint.
 * The chroma is kept very low (≈0.005–0.012) to stay visually neutral.
 */
export function generateNeutralScale(H) {
  return LIGHTNESS_STOPS.map((lightness, i) => {
    // Very subtle chroma — just enough to feel "warm" or "cool" vs pure gray
    const C = 0.005 + (lightness * 0.007);

    return {
      shade: SHADE_NAMES[i],
      L: lightness,
      C,
      H,
      css: oklchToCss(lightness, C, H),
    };
  });
}

// ---------------------------------------------------------------------------
// 3. Semantic token mapping
// ---------------------------------------------------------------------------

/**
 * Map primary and neutral scales to the 14 semantic design tokens used by
 * shadcn/ui and most modern design systems.
 *
 * Tokens:
 *   background, foreground, card, card-foreground,
 *   popover, popover-foreground,
 *   primary, primary-foreground,
 *   secondary, secondary-foreground,
 *   muted, muted-foreground,
 *   border, ring
 *
 * @param {Array} primaryScale   - output of generateScale()
 * @param {Array} neutralScale   - output of generateNeutralScale()
 * @returns {{ light: Object, dark: Object }}
 */
export function generateSemanticTokens(primaryScale, neutralScale) {
  const p = (shade) => primaryScale.find((s) => s.shade === shade);
  const n = (shade) => neutralScale.find((s) => s.shade === shade);

  const light = {
    "--background":          n(50).css,
    "--foreground":          n(950).css,
    "--card":                n(50).css,
    "--card-foreground":     n(950).css,
    "--popover":             n(50).css,
    "--popover-foreground":  n(950).css,
    "--primary":             p(600).css,
    "--primary-foreground":  n(50).css,
    "--secondary":           n(100).css,
    "--secondary-foreground":n(900).css,
    "--muted":               n(100).css,
    "--muted-foreground":    n(500).css,
    "--border":              n(200).css,
    "--ring":                p(500).css,
  };

  const dark = {
    "--background":          n(950).css,
    "--foreground":          n(50).css,
    "--card":                n(900).css,
    "--card-foreground":     n(50).css,
    "--popover":             n(900).css,
    "--popover-foreground":  n(50).css,
    "--primary":             p(500).css,
    "--primary-foreground":  n(950).css,
    "--secondary":           n(800).css,
    "--secondary-foreground":n(100).css,
    "--muted":               n(800).css,
    "--muted-foreground":    n(400).css,
    "--border":              n(800).css,
    "--ring":                p(400).css,
  };

  return { light, dark };
}

// ---------------------------------------------------------------------------
// 4. CSS output
// ---------------------------------------------------------------------------

function renderTokenBlock(tokens, indent = "  ") {
  return Object.entries(tokens)
    .map(([k, v]) => `${indent}${k}: ${v};`)
    .join("\n");
}

function renderPaletteComment(scale, label) {
  const header = `/* ${label} scale */`;
  const entries = scale
    .map(({ shade, css }) => `  /* ${label}-${shade}: */ /* ${css} */`)
    .join("\n");
  return `${header}\n${entries}`;
}

/**
 * Full pipeline: hex string → CSS custom property output.
 *
 * @param {string} hexInput  e.g. "#3ECF8E"
 * @returns {string}         complete CSS block
 */
export function main(hexInput) {
  const hex = hexInput.trim();

  // Validate
  if (!/^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(hex)) {
    throw new Error(`"${hexInput}" is not a valid hex color. Expected #RGB or #RRGGBB.`);
  }

  // Conversion pipeline
  const rgb      = hexToRgb(hex);
  const linear   = rgbToLinear(rgb);
  const lab      = linearToOklab(linear);
  const oklch    = oklabToOklch(lab);

  const { L, C, H } = oklch;

  // Handle edge-case: pure black / very low chroma colors
  // Use a tiny synthetic chroma so the scale still looks intentional
  const effectiveC = C < 0.01 ? 0.01 : C;

  const primaryScale = generateScale(L, effectiveC, H);
  const neutralScale = generateNeutralScale(H);
  const { light, dark } = generateSemanticTokens(primaryScale, neutralScale);

  const normalised = hex.startsWith("#") ? hex.toUpperCase() : `#${hex.toUpperCase()}`;

  const lines = [
    `/* Generated from ${normalised} */`,
    `/* Source OKLCH: L=${L.toFixed(3)} C=${C.toFixed(4)} H=${H.toFixed(1)} */`,
    ``,
    `/* ── Semantic tokens ───────────────────────────────────────────── */`,
    `:root {`,
    renderTokenBlock(light),
    `}`,
    ``,
    `.dark {`,
    renderTokenBlock(dark),
    `}`,
    ``,
    `/* ── Full primary palette ──────────────────────────────────────── */`,
    renderPaletteComment(primaryScale, "primary"),
    ``,
    `/* ── Full neutral palette ──────────────────────────────────────── */`,
    renderPaletteComment(neutralScale, "neutral"),
  ];

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// 5. CLI entry-point
// ---------------------------------------------------------------------------

// Run when invoked directly: `node oklch-math.mjs "#3ECF8E"`
if (process.argv[1] === new URL(import.meta.url).pathname) {
  const hex = process.argv[2];

  if (!hex) {
    console.error("Usage: node oklch-math.mjs <hex-color>");
    console.error('Example: node oklch-math.mjs "#3ECF8E"');
    process.exit(1);
  }

  try {
    console.log(main(hex));
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}
