from PIL import Image
from pathlib import Path

Path("build").mkdir(parents=True, exist_ok=True)

# Exact launcher artwork supplied for OPTIK LENTERA: black background,
# gold triangular frame, white eye symbol, and LENTERA wordmark only.
source = "assets/optik_lentera_launcher_premium.jpg"
target = "build/optik_lentera_launcher_zoom.png"

with Image.open(source) as original:
    image = original.convert("RGB")
    width, height = image.size
    crop_w, crop_h = int(width * 0.90), int(height * 0.90)
    left = (width - crop_w) // 2
    top = (height - crop_h) // 2
    image = image.crop((left, top, left + crop_w, top + crop_h))
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    image.save(target, "PNG", optimize=True)
