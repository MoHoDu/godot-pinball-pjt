from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
OUT = Path(r"C:\NHN AI\godot-pinball-pjt\Resources\Art\walls\shape_prototype_v1")
OUT.mkdir(parents=True, exist_ok=True)

BODY_COLOR = (25, 39, 58)
BURGUNDY_COLOR = (126, 35, 58)
IVORY_COLOR = (224, 215, 196)


def flatten_colors(image: Image.Image) -> Image.Image:
    src = image.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    src_px = src.load()
    out_px = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src_px[x, y]
            if a <= 8:
                continue
            if r > 145 and g > 135 and b > 115:
                color = IVORY_COLOR
            elif r > g * 1.35 and r > b * 1.15:
                color = BURGUNDY_COLOR
            else:
                color = BODY_COLOR
            out_px[x, y] = (*color, a)
    return out


def alpha_bbox(image: Image.Image, threshold: int = 16) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value > threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Image contains no visible pixels")
    return bbox


def crop_body_center(image: Image.Image) -> Image.Image:
    left, top, right, bottom = alpha_bbox(image)
    width = right - left
    trim = int(width * 0.28)
    return image.crop((left + trim, top, right - trim, bottom))


def crop_visible(image: Image.Image) -> Image.Image:
    return image.crop(alpha_bbox(image))


def resize_asset(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.resize(size, Image.Resampling.LANCZOS)


def save_asset(image: Image.Image, name: str) -> Path:
    target = OUT / name
    image.save(target, optimize=True)
    return target


body_source = flatten_colors(Image.open(ROOT / "wall_body_alpha.png"))
cap_source = flatten_colors(Image.open(ROOT / "wall_end_cap_right_alpha.png"))
corner_source = flatten_colors(Image.open(ROOT / "wall_corner_90_alpha.png"))

body = resize_asset(crop_body_center(body_source), (256, 40))
cap_right = resize_asset(crop_visible(cap_source), (64, 40))
cap_left = ImageOps.mirror(cap_right)
corner = resize_asset(crop_visible(corner_source), (64, 64))

assets = {
    "wall_body_shape_256x40_v1.png": body,
    "wall_end_cap_left_64x40_v1.png": cap_left,
    "wall_end_cap_right_64x40_v1.png": cap_right,
    "wall_corner_90_64x64_v1.png": corner,
}

for filename, asset in assets.items():
    save_asset(asset, filename)

preview = Image.new("RGB", (960, 520), (28, 31, 38))
draw = ImageDraw.Draw(preview)
font = ImageFont.load_default()

checker = Image.new("RGB", preview.size, (0, 0, 0))
checker_draw = ImageDraw.Draw(checker)
cell = 24
for y in range(0, preview.height, cell):
    for x in range(0, preview.width, cell):
        shade = 58 if (x // cell + y // cell) % 2 == 0 else 72
        checker_draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(shade, shade, shade))
preview.paste(checker)
draw = ImageDraw.Draw(preview)

body_preview = body.resize((768, 120), Image.Resampling.NEAREST)
preview.paste(body_preview, (96, 72), body_preview)
draw.text((96, 48), "WALL BODY 256 x 40", fill=(235, 235, 235), font=font)

cap_left_preview = cap_left.resize((192, 120), Image.Resampling.NEAREST)
cap_right_preview = cap_right.resize((192, 120), Image.Resampling.NEAREST)
corner_preview = corner.resize((192, 192), Image.Resampling.NEAREST)
preview.paste(cap_left_preview, (96, 292), cap_left_preview)
preview.paste(cap_right_preview, (352, 292), cap_right_preview)
preview.paste(corner_preview, (672, 256), corner_preview)
draw.text((96, 268), "LEFT CAP 64 x 40", fill=(235, 235, 235), font=font)
draw.text((352, 268), "RIGHT CAP 64 x 40", fill=(235, 235, 235), font=font)
draw.text((672, 232), "CORNER 64 x 64", fill=(235, 235, 235), font=font)

preview_path = OUT / "wall_shape_prototype_v1_preview.png"
preview.save(preview_path, optimize=True)

for filename, asset in assets.items():
    alpha = asset.getchannel("A")
    print(f"{filename}: size={asset.size}, mode={asset.mode}, alpha_range={alpha.getextrema()}")
print(f"preview: {preview_path}")
