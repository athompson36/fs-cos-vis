#!/usr/bin/env python3
"""
Generate macOS AppIcon.appiconset from docs/icon.png with a full-bleed,
rounded liquid-glass treatment (highlights + specular + rim), then emit all
required macOS 1x/2x sizes.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "icon.png"
OUT_DIR = ROOT / "FSDMXVision" / "FSDMXVision" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
MASTER_SIZE = 1024


def _linear_gradient_rgba(
    size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]
) -> Image.Image:
    w, h = size
    grad = Image.new("RGBA", (w, h))
    px = grad.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        a = int(top[3] * (1 - t) + bottom[3] * t)
        for x in range(w):
            px[x, y] = (r, g, b, a)
    return grad


def _radial_specular(size: tuple[int, int], cx: float, cy: float, rx: float, ry: float, rgba: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    r0, g0, b0, a0 = rgba
    for y in range(h):
        for x in range(w):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            d2 = nx * nx + ny * ny
            if d2 > 1.0:
                continue
            falloff = (1.0 - d2) ** 1.8
            a = int(a0 * falloff)
            if a < 2:
                continue
            px[x, y] = (r0, g0, b0, a)
    return im


def _rounded_rectangle_mask(size: tuple[int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m.filter(ImageFilter.GaussianBlur(1.2))


def _trim_near_white_border(im: Image.Image, threshold: int = 248) -> Image.Image:
    """Remove a flat near-white frame if present (keeps interior bright stage light)."""
    im = im.convert("RGBA")
    w, h = im.size
    bg = Image.new("RGB", (w, h), (255, 255, 255))
    rgb = im.convert("RGB")
    diff = ImageChops.difference(rgb, bg)
    extrema = diff.convert("L").getextrema()
    if extrema[1] < 12:
        return im
    bbox = diff.getbbox()
    if bbox and (bbox[0] > 2 or bbox[1] > 2 or bbox[2] < w - 2 or bbox[3] < h - 2):
        return im.crop(bbox)
    return im


def build_master(src: Path) -> Image.Image:
    raw = Image.open(src)
    im = _trim_near_white_border(raw)
    # Full bleed: cover-fit into square (no outer padding).
    im = ImageOps.fit(im, (MASTER_SIZE, MASTER_SIZE), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    im = im.convert("RGBA")

    w, h = im.size
    r = int(min(w, h) * 0.19)
    mask = _rounded_rectangle_mask((w, h), r)

    # Soft bloom (glass body)
    blur = im.filter(ImageFilter.GaussianBlur(2.2))
    bloom = Image.blend(im, blur, 0.22)
    base = Image.composite(bloom, im, mask)

    # Depth: darker toward bottom (3D lift)
    depth_grad = _linear_gradient_rgba(
        (w, h),
        (8, 4, 22, 0),
        (12, 8, 38, 110),
    )
    depth_grad.putalpha(ImageChops.multiply(depth_grad.split()[3], mask))
    out = Image.alpha_composite(base, depth_grad)

    # Top liquid highlight (angled glass sweep)
    hi = _linear_gradient_rgba(
        (w, h),
        (255, 255, 255, 115),
        (200, 230, 255, 0),
    )
    hi.putalpha(ImageChops.multiply(hi.split()[3], mask))
    # Bias highlight to upper third
    hi_alpha = hi.split()[3]
    for y in range(h):
        row_f = max(0.0, 1.0 - (y / (h * 0.55)))
        factor = int(255 * row_f * row_f)
        band = Image.new("L", (w, 1), factor)
        hi_alpha.paste(ImageChops.multiply(hi_alpha.crop((0, y, w, y + 1)), band), (0, y))
    hi.putalpha(hi_alpha)
    out = Image.alpha_composite(out, hi)

    # Specular pool (upper brain region)
    spec = _radial_specular((w, h), w * 0.48, h * 0.30, w * 0.42, h * 0.28, (255, 255, 255, 95))
    spec.putalpha(ImageChops.multiply(spec.split()[3], mask))
    out = Image.alpha_composite(out, spec)

    # Cool rim light (glass edge)
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    inset = 3
    rd.rounded_rectangle(
        (inset, inset, w - 1 - inset, h - 1 - inset),
        radius=r - 2,
        outline=(220, 240, 255, 140),
        width=3,
    )
    rim = rim.filter(ImageFilter.GaussianBlur(0.8))
    rim.putalpha(ImageChops.multiply(rim.split()[3], mask))
    out = Image.alpha_composite(out, rim)

    # Top inner shadow for thickness (stronger in upper band only)
    shade = _linear_gradient_rgba((w, h), (0, 0, 0, 58), (0, 0, 0, 0))
    sa = shade.split()[3]
    band = Image.new("L", (w, h), 0)
    bp = band.load()
    for y in range(h):
        f = max(0.0, 1.0 - y / (h * 0.42))
        row_a = int(255 * f * f)
        for x in range(w):
            bp[x, y] = row_a
    shade.putalpha(ImageChops.multiply(ImageChops.multiply(sa, mask), band))
    out = Image.alpha_composite(out, shade)

    # Final subtle sharpen on luminance
    return out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=130, threshold=2))


def export_set(master: Image.Image, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, dim in specs:
        resized = master.resize((dim, dim), Image.Resampling.LANCZOS)
        resized.save(dest / name, optimize=True)

    images = [
        {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
        {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
        {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
        {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
        {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
        {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
        {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
        {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
        {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
        {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
    ]

    (dest / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    if not SRC.exists():
        print(f"Missing source icon: {SRC}", file=sys.stderr)
        return 1
    master = build_master(SRC)
    master_path = ROOT / "docs" / "app-icon-liquid-glass-1024.png"
    master.save(master_path, optimize=True)
    print(f"Wrote master preview: {master_path}")
    export_set(master, OUT_DIR)
    print(f"Wrote AppIcon set: {OUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
