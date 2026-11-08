#!/usr/bin/env python3
"""Generate Cadence's macOS app icon and asset catalog."""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App" / "Resources" / "Assets.xcassets"
ICONSET = ASSETS / "AppIcon.appiconset"
SCALE = 2
CANVAS = 1024
WORK = CANVAS * SCALE


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    y = np.linspace(0, 1, size, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, size, dtype=np.float32)[None, :]
    blend = np.clip(y * 0.82 + x * 0.18, 0, 1)
    top_arr = np.array(top, dtype=np.float32)
    bottom_arr = np.array(bottom, dtype=np.float32)
    arr = top_arr[None, None, :] * (1 - blend[:, :, None]) + bottom_arr[None, None, :] * blend[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def create_icon() -> Image.Image:
    # Main rounded tile with breathing room around it, like a macOS app icon.
    tile_size = int(WORK * 0.875)
    tile_left = (WORK - tile_size) // 2
    tile_top = (WORK - tile_size) // 2
    radius = int(tile_size * 0.225)

    tile = gradient(WORK, (43, 37, 30), (16, 14, 11)).convert("RGBA")
    aura = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse(
        (WORK * 0.47, WORK * 0.02, WORK * 1.06, WORK * 0.61),
        fill=(243, 111, 77, 54),
    )
    aura_draw.ellipse(
        (WORK * 0.02, WORK * 0.6, WORK * 0.55, WORK * 1.04),
        fill=(157, 201, 169, 22),
    )
    aura = aura.filter(ImageFilter.GaussianBlur(radius=150))
    tile.alpha_composite(aura)

    mask = rounded_mask(WORK, radius)
    shadow = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (tile_left + 12, tile_top + 34, tile_left + tile_size + 12, tile_top + tile_size + 34),
        radius=radius,
        fill=(0, 0, 0, 132),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=42))

    canvas = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    canvas.alpha_composite(shadow)
    canvas.paste(tile, (tile_left, tile_top), mask)

    draw = ImageDraw.Draw(canvas)

    # Fine border around the tile.
    draw.rounded_rectangle(
        (tile_left, tile_top, tile_left + tile_size - 1, tile_top + tile_size - 1),
        radius=radius,
        outline=(255, 255, 255, 30),
        width=3,
    )

    center = (WORK / 2, WORK / 2)
    ring_diameter = tile_size * 0.64
    ring_radius = ring_diameter / 2
    stroke = int(tile_size * 0.035)
    ring_box = (
        center[0] - ring_radius,
        center[1] - ring_radius,
        center[0] + ring_radius,
        center[1] + ring_radius,
    )

    # Arc leaving an intentional opening, with a soft coral tip.
    start_angle = 314
    end_angle = 602
    arc_layer = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    arc_draw = ImageDraw.Draw(arc_layer)
    arc_draw.arc(ring_box, start=start_angle - 90, end=end_angle - 90, fill=(246, 238, 225, 235), width=stroke)
    arc_layer = arc_layer.filter(ImageFilter.GaussianBlur(radius=1))
    canvas.alpha_composite(arc_layer)

    def point_at(angle_deg: float) -> tuple[float, float]:
        # PIL angles are measured clockwise from 3 o'clock.
        rad = math.radians(angle_deg - 90)
        return (center[0] + math.cos(rad) * ring_radius, center[1] + math.sin(rad) * ring_radius)

    for angle in (start_angle, end_angle):
        point = point_at(angle)
        draw.ellipse(
            (
                point[0] - stroke / 2,
                point[1] - stroke / 2,
                point[0] + stroke / 2,
                point[1] + stroke / 2,
            ),
            fill=(246, 238, 225, 235),
        )

    tip = point_at(end_angle)
    tip_r = tile_size * 0.045
    glow_layer = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    glow_draw.ellipse(
        (tip[0] - tip_r * 2.1, tip[1] - tip_r * 2.1, tip[0] + tip_r * 2.1, tip[1] + tip_r * 2.1),
        fill=(243, 111, 77, 155),
    )
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=22))
    canvas.alpha_composite(glow_layer)
    draw.ellipse(
        (tip[0] - tip_r, tip[1] - tip_r, tip[0] + tip_r, tip[1] + tip_r),
        fill=(255, 136, 102, 255),
    )

    # Three rounded bars: sound + cadence.
    bar_width = tile_size * 0.048
    gap = tile_size * 0.035
    heights = [tile_size * 0.10, tile_size * 0.195, tile_size * 0.14]
    total_width = bar_width * 3 + gap * 2
    left = center[0] - total_width / 2
    bar_bottom = center[1] + tile_size * 0.115
    for index, height in enumerate(heights):
        x = left + index * (bar_width + gap)
        y = bar_bottom - height
        draw.rounded_rectangle(
            (x, y, x + bar_width, bar_bottom),
            radius=bar_width / 2,
            fill=(243, 111, 77, 255),
        )

    # A tiny counterpoint dot, like a metronome tick.
    dot_r = tile_size * 0.023
    dot_x = center[0] + tile_size * 0.18
    dot_y = center[1] - tile_size * 0.155
    draw.ellipse(
        (dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r),
        fill=(231, 190, 107, 245),
    )

    # Very subtle top highlight.
    highlight = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle(
        (tile_left + 2, tile_top + 2, tile_left + tile_size - 2, tile_top + tile_size * 0.47),
        radius=radius,
        fill=(255, 255, 255, 9),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=22))
    canvas.alpha_composite(highlight)

    return canvas.resize((CANVAS, CANVAS), Image.Resampling.LANCZOS)


def build_assets(icon: Image.Image) -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for filename, size in sizes.items():
        icon.resize((size, size), Image.Resampling.LANCZOS).save(ICONSET / filename)

    images = []
    specs = [
        (16, 1, "icon_16x16.png"),
        (16, 2, "icon_16x16@2x.png"),
        (32, 1, "icon_32x32.png"),
        (32, 2, "icon_32x32@2x.png"),
        (128, 1, "icon_128x128.png"),
        (128, 2, "icon_128x128@2x.png"),
        (256, 1, "icon_256x256.png"),
        (256, 2, "icon_256x256@2x.png"),
        (512, 1, "icon_512x512.png"),
        (512, 2, "icon_512x512@2x.png"),
    ]
    for size, scale, filename in specs:
        images.append({
            "filename": filename,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{size}x{size}",
        })
    (ICONSET / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    colorset = ASSETS / "AccentColor.colorset"
    colorset.mkdir(parents=True, exist_ok=True)
    color_contents = {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue": "0.302",
                        "green": "0.435",
                        "red": "0.953",
                    },
                },
                "idiom": "universal",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (colorset / "Contents.json").write_text(json.dumps(color_contents, indent=2) + "\n")

    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    # A full-size preview for README screenshots / quick inspection.
    preview = ROOT / "docs" / "icon-preview.png"
    preview.parent.mkdir(parents=True, exist_ok=True)
    icon.save(preview)


if __name__ == "__main__":
    icon = create_icon()
    build_assets(icon)
    print(f"Generated app icon at {ICONSET}")
