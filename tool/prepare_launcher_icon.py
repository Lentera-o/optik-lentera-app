from PIL import Image
from pathlib import Path

Path("build").mkdir(parents=True, exist_ok=True)

source = "assets/optik_lentera_app_logo.png"
target = "build/optik_lentera_launcher_zoom.png"

# Use the main black-and-gold Lentera logo for the launcher icon. The tighter
# centered crop enlarges the logo while retaining the full wordmark.
with Image.open(source) as original:
    image = original.convert("RGB")
    width, height = image.size
    crop_w, crop_h = int(width * 0.82), int(height * 0.82)
    left = (width - crop_w) // 2
    top = (height - crop_h) // 2
    image = image.crop((left, top, left + crop_w, top + crop_h))
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    image.save(target, "PNG", optimize=True)
