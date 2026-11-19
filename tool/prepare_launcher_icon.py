from PIL import Image
from pathlib import Path

Path("build").mkdir(parents=True, exist_ok=True)

source = "assets/optik_lentera_launcher.jpg"
target = "build/optik_lentera_launcher_zoom.png"

# Zoom the existing artwork so its baked-in rounded border does not sit
# inside Android's own adaptive-icon mask and create a second visible gap.
with Image.open(source) as original:
    image = original.convert("RGB")
    width, height = image.size
    crop_w, crop_h = int(width * 0.78), int(height * 0.78)
    left = (width - crop_w) // 2
    top = (height - crop_h) // 2
    image = image.crop((left, top, left + crop_w, top + crop_h))
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    image.save(target, "PNG", optimize=True)
