#!/usr/bin/env python3
"""Generates the app icon (WordOfTheDayApp/Assets.xcassets). Requires Pillow."""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "WordOfTheDayApp" / "Assets.xcassets"
ICONSET = CATALOG / "AppIcon.appiconset"
RED = (227, 10, 23)
SIZE = 1024
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"


def draw_star(draw: ImageDraw.ImageDraw, x: float, y: float, outer: float, inner: float) -> None:
    points = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5 - math.pi / 10
        radius = outer if i % 2 == 0 else inner
        points.append((x + radius * math.cos(angle), y + radius * math.sin(angle)))
    draw.polygon(points, fill="white")


def main() -> None:
    image = Image.new("RGB", (SIZE, SIZE), RED)
    draw = ImageDraw.Draw(image)

    cx, cy, r = 420, 330, 170
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill="white")
    inner = 136
    draw.ellipse((cx - inner + 44, cy - inner, cx + inner + 44, cy + inner), fill=RED)
    draw_star(draw, 650, 330, 80, 32)

    font = ImageFont.truetype(FONT, 210)
    text = "kelime"
    draw.text(((SIZE - draw.textlength(text, font=font)) / 2, 590), text, font=font, fill="white")

    ICONSET.mkdir(parents=True, exist_ok=True)
    image.save(ICONSET / "icon-1024.png")
    info = {"author": "xcode", "version": 1}
    (CATALOG / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    (ICONSET / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": info,
    }, indent=2) + "\n")
    print(f"wrote {ICONSET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
