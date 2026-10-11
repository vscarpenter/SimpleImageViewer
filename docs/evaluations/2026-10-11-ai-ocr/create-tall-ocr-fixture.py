#!/usr/bin/env python3
"""Reproduce the separate tall-document OCR stress fixture with bundled Pillow."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

folder = Path(__file__).resolve().parent
image = Image.new("RGB", (1800, 6600), "white")
draw = ImageDraw.Draw(image)
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 32)
lines = ["TALL RECEIPT OCR REGRESSION"] + [
    f"ROW {number:03d} CODE AB-{number:03d} QTY {number % 9 + 1} USD {58 + number:04d}.00"
    for number in range(1, 91)
]
for index, line in enumerate(lines):
    draw.text((90, 80 + index * 70), line, font=font, fill="black")
image.save(folder / "tall-dense-receipt.png")
(folder / "tall-dense-receipt-ground-truth.json").write_text(
    json.dumps(lines, indent=2) + "\n"
)
