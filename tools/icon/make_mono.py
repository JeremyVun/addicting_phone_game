"""Derive the Android 13 themed (monochrome) launcher icon from the app icon.

Usage: python3 tools/icon/make_mono.py
       app/assets/icon/icon-1024.png -> app/assets/icon/icon-mono-1024.png

The four-tile mark is the only colourful region of the source art, so the
silhouette is a chroma threshold. HSV saturation would not do: the near-black
grid is a desaturated blue but scores high on relative saturation.
Output is white on transparent, scaled into the adaptive-icon safe zone.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

SIZE = 1024
SAFE_ZONE_FRACTION = 0.60
CHROMA_THRESHOLD = 60

root = Path(__file__).resolve().parents[2]
source = root / "app/assets/icon/icon-1024.png"
target = root / "app/assets/icon/icon-mono-1024.png"

rgb = Image.open(source).convert("RGB")
bands = rgb.split()
brightest = ImageChops.lighter(ImageChops.lighter(*bands[:2]), bands[2])
darkest = ImageChops.darker(ImageChops.darker(*bands[:2]), bands[2])
chroma = ImageChops.subtract(brightest, darkest)
mask = chroma.point(lambda v: 255 if v >= CHROMA_THRESHOLD else 0).convert("L")
mask = mask.filter(ImageFilter.MedianFilter(5))

box = mask.getbbox()
if box is None:
    raise SystemExit(f"no saturated mark found in {source}")

mark = mask.crop(box)
scale = SIZE * SAFE_ZONE_FRACTION / max(mark.size)
mark = mark.resize(
    (round(mark.width * scale), round(mark.height * scale)), Image.LANCZOS
)

out = Image.new("LA", (SIZE, SIZE), (255, 0))
out.paste(
    Image.new("LA", mark.size, (255, 255)),
    ((SIZE - mark.width) // 2, (SIZE - mark.height) // 2),
    mark,
)
out.convert("RGBA").save(target)
print(f"wrote {target}")
