from PIL import Image, ImageOps
from pathlib import Path

Path("build").mkdir(parents=True, exist_ok=True)

# Use the approved dedicated gold-framed launcher emblem. Keep the whole artwork
# visible: fit it onto a transparent square instead of cropping the logo.
source = "assets/optik_lentera_launcher_emblem.png"
target = "build/optik_lentera_launcher_emblem.png"

with Image.open(source) as original:
    artwork = original.convert("RGBA")
    artwork = ImageOps.contain(
        artwork,
        (1024, 1024),
        method=Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    left = (1024 - artwork.width) // 2
    top = (1024 - artwork.height) // 2
    canvas.alpha_composite(artwork, (left, top))
    canvas.save(target, "PNG", optimize=True)
