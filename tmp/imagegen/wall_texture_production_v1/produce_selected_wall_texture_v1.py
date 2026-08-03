from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


PROJECT = Path(__file__).resolve().parents[3]
SOURCE = (
    PROJECT
    / "Resources/Art/walls/texture_concepts/wall_texture_final_cursed_toy_v1.png"
)
MASK_DIR = PROJECT / "Resources/Art/walls/shape_prototype_v1"
OUT = PROJECT / "Resources/Art/walls/cursed_toy_frame_v1"
BOARD_TEXTURE = PROJECT / "Resources/Art/board/octagonal_dark_wood_board.png"
OUTSIDE_BACKGROUND = (
    PROJECT / "Resources/Art/backgrounds/cursed_circus_outside_background.png"
)

OUTPUT_NAMES = {
    "body": "wall_body_256x40_cursed_toy_v1.png",
    "left": "wall_end_cap_left_64x40_cursed_toy_v1.png",
    "right": "wall_end_cap_right_64x40_cursed_toy_v1.png",
    "corner": "wall_corner_90_64x64_cursed_toy_v1.png",
}

MASK_NAMES = {
    "body": "wall_body_shape_256x40_v1.png",
    "left": "wall_end_cap_left_64x40_v1.png",
    "right": "wall_end_cap_right_64x40_v1.png",
    "corner": "wall_corner_90_64x64_v1.png",
}

TARGET_SIZES = {
    "body": (256, 40),
    "left": (64, 40),
    "right": (64, 40),
    "corner": (64, 64),
}


def clamp_box(box: tuple[int, int, int, int], size: tuple[int, int]) -> tuple[int, int, int, int]:
    left, top, right, bottom = box
    width, height = size
    return max(0, left), max(0, top), min(width, right), min(height, bottom)


def component_regions(size: tuple[int, int]) -> dict[str, tuple[int, int, int, int]]:
    width, height = size
    return {
        "body": (int(width * 0.04), int(height * 0.07), int(width * 0.96), int(height * 0.41)),
        "left": (int(width * 0.03), int(height * 0.43), int(width * 0.34), int(height * 0.82)),
        "right": (int(width * 0.34), int(height * 0.43), int(width * 0.66), int(height * 0.82)),
        "corner": (int(width * 0.66), int(height * 0.41), int(width * 0.98), int(height * 0.90)),
    }


def component_bbox(
    sheet: Image.Image,
    region: tuple[int, int, int, int],
    padding: int,
) -> tuple[int, int, int, int]:
    crop = np.asarray(sheet.crop(region).convert("RGB"), dtype=np.int16)
    red = crop[:, :, 0]
    green = crop[:, :, 1]
    blue = crop[:, :, 2]
    navy_surface = (blue - red > 5) & (blue - green > 1) & (blue > 18)
    ivory_surface = (red > 70) & (green > 60) & (blue > 45)
    mask = navy_surface | ivory_surface
    ys, xs = np.nonzero(mask)
    if not len(xs):
        raise ValueError(f"No wall component found inside region {region}")

    left = region[0] + int(xs.min()) - padding
    top = region[1] + int(ys.min()) - padding
    right = region[0] + int(xs.max()) + padding + 1
    bottom = region[1] + int(ys.max()) + padding + 1
    return clamp_box((left, top, right, bottom), sheet.size)


def average_edge_pair(array: np.ndarray, width: int) -> np.ndarray:
    result = array.astype(np.float32).copy()
    image_width = result.shape[1]
    for x in range(width):
        opposite = image_width - 1 - x
        blend = x / max(1, width - 1)
        average = (array[:, x].astype(np.float32) + array[:, opposite].astype(np.float32)) * 0.5
        result[:, x] = average * (1.0 - blend) + array[:, x] * blend
        result[:, opposite] = average * (1.0 - blend) + array[:, opposite] * blend
    result[:, -1] = result[:, 0]
    return np.clip(result, 0, 255).astype(np.uint8)


def sample_muted_teal(sheet: Image.Image) -> np.ndarray:
    pixels = np.asarray(sheet.convert("RGB"), dtype=np.int16).reshape(-1, 3)
    red, green, blue = pixels[:, 0], pixels[:, 1], pixels[:, 2]
    candidates = pixels[
        (green - red > 20)
        & (blue - red > 22)
        & (green > 55)
        & (green < 150)
        & (blue < 165)
    ]
    if not len(candidates):
        return np.array([40, 101, 111], dtype=np.uint8)
    return np.median(candidates, axis=0).astype(np.uint8)


def prototype_zone_masks(prototype: Image.Image) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgba = np.asarray(prototype.convert("RGBA"))
    red = rgba[:, :, 0].astype(np.int16)
    green = rgba[:, :, 1].astype(np.int16)
    blue = rgba[:, :, 2].astype(np.int16)
    alpha = rgba[:, :, 3]
    visible = alpha > 8
    inner_boundary = visible & (red > 145) & (green > 135) & (blue > 115)
    outer_band = visible & (red > green * 1.35) & (red > blue * 1.15)
    body = visible & ~inner_boundary & ~outer_band
    return body, outer_band, inner_boundary


def apply_exact_mask(
    sample: Image.Image,
    prototype: Image.Image,
    teal: np.ndarray,
) -> Image.Image:
    sample_rgba = np.asarray(sample.convert("RGBA"), dtype=np.uint8).copy()
    prototype_rgba = np.asarray(prototype.convert("RGBA"), dtype=np.uint8)
    _, _, inner_boundary = prototype_zone_masks(prototype)

    luminance = (
        sample_rgba[:, :, 0].astype(np.int16)
        + sample_rgba[:, :, 1].astype(np.int16)
        + sample_rgba[:, :, 2].astype(np.int16)
    ) // 3
    variation = np.clip(luminance - int(np.median(luminance)), -7, 7)
    teal_surface = np.clip(teal[None, None, :].astype(np.int16) + variation[:, :, None], 0, 255)
    sample_rgba[inner_boundary, :3] = teal_surface[inner_boundary].astype(np.uint8)
    sample_rgba[:, :, 3] = prototype_rgba[:, :, 3]
    sample_rgba[prototype_rgba[:, :, 3] == 0, :3] = 0
    return Image.fromarray(sample_rgba, mode="RGBA")


def body_join_colors(body_array: np.ndarray, column: int) -> np.ndarray:
    colors = body_array[:, column, :3].copy()
    alpha = body_array[:, column, 3]
    visible_rows = np.flatnonzero(alpha > 8)
    if not len(visible_rows):
        return colors
    for y in np.flatnonzero(alpha <= 8):
        nearest = visible_rows[np.argmin(np.abs(visible_rows - y))]
        colors[y] = colors[nearest]
    return colors


def blend_cap_join(cap: Image.Image, body: Image.Image, side: str, width: int = 6) -> Image.Image:
    cap_array = np.asarray(cap.convert("RGBA"), dtype=np.uint8).copy()
    body_array = np.asarray(body.convert("RGBA"), dtype=np.uint8)
    body_column = 0 if side == "right" else body.width - 1
    target = body_join_colors(body_array, body_column).astype(np.float32)

    for distance in range(width):
        x = cap.width - 1 - distance if side == "right" else distance
        amount = 1.0 - distance / max(1, width - 1)
        visible = cap_array[:, x, 3] > 8
        original = cap_array[:, x, :3].astype(np.float32)
        blended = original * (1.0 - amount) + target * amount
        cap_array[visible, x, :3] = np.clip(blended[visible], 0, 255).astype(np.uint8)
    return Image.fromarray(cap_array, mode="RGBA")


def prepare_body_crop(sheet: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    left, top, right, bottom = box
    width = right - left
    center_trim = int(width * 0.17)
    return sheet.crop((left + center_trim, top, right - center_trim, bottom))


def save_png(image: Image.Image, filename: str) -> Path:
    target = OUT / filename
    image.save(target, optimize=True)
    return target


def assemble_wall(body: Image.Image, left: Image.Image, right: Image.Image, length: int) -> Image.Image:
    wall = Image.new("RGBA", (length, 40), (0, 0, 0, 0))
    body_end = length - right.width
    x = left.width
    while x < body_end:
        tile_width = min(body.width, body_end - x)
        wall.alpha_composite(body.crop((0, 0, tile_width, body.height)), (x, 0))
        x += tile_width
    wall.alpha_composite(left, (0, 0))
    wall.alpha_composite(right, (body_end, 0))
    return wall


def make_component_preview(assets: dict[str, Image.Image]) -> Image.Image:
    preview = Image.new("RGB", (1152, 640), (30, 31, 35))
    draw = ImageDraw.Draw(preview)
    font = ImageFont.load_default()

    body_large = assets["body"].resize((1024, 160), Image.Resampling.NEAREST)
    left_large = assets["left"].resize((256, 160), Image.Resampling.NEAREST)
    right_large = assets["right"].resize((256, 160), Image.Resampling.NEAREST)
    corner_large = assets["corner"].resize((256, 256), Image.Resampling.NEAREST)

    preview.paste(body_large, (64, 72), body_large)
    preview.paste(left_large, (96, 360), left_large)
    preview.paste(right_large, (448, 360), right_large)
    preview.paste(corner_large, (800, 320), corner_large)
    draw.text((64, 48), "BODY 256 x 40", fill=(235, 235, 235), font=font)
    draw.text((96, 336), "LEFT CAP 64 x 40", fill=(235, 235, 235), font=font)
    draw.text((448, 336), "RIGHT CAP 64 x 40", fill=(235, 235, 235), font=font)
    draw.text((800, 296), "CORNER 64 x 64", fill=(235, 235, 235), font=font)
    return preview


def alpha_composite_center(
    canvas: Image.Image,
    sprite: Image.Image,
    center: tuple[float, float],
) -> None:
    position = (
        round(center[0] - sprite.width * 0.5),
        round(center[1] - sprite.height * 0.5),
    )
    canvas.alpha_composite(sprite, position)


def make_board_application_preview(wall: Image.Image) -> Image.Image:
    canvas_size = (2240, 1260)
    background = Image.open(OUTSIDE_BACKGROUND).convert("RGBA").resize(
        canvas_size,
        Image.Resampling.LANCZOS,
    )
    board = Image.open(BOARD_TEXTURE).convert("RGBA")
    background.alpha_composite(board, (0, 0))

    center = np.array([1120.0, 630.0])
    transforms = (
        (np.array([735.0, -490.0]), 0.348772),
        (np.array([735.0, 490.0]), 2.7928207),
        (np.array([-735.0, 490.0]), -2.7928207),
        (np.array([-735.0, -490.0]), -0.348772),
    )
    for offset, radians in transforms:
        degrees = float(np.degrees(radians))
        rotated = wall.rotate(-degrees, resample=Image.Resampling.BICUBIC, expand=True)
        wall_center = center + offset
        alpha_composite_center(background, rotated, (float(wall_center[0]), float(wall_center[1])))
    return background


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE).convert("RGB")
    regions = component_regions(sheet.size)
    boxes = {
        name: component_bbox(sheet, region, padding=8 if name != "corner" else 12)
        for name, region in regions.items()
    }

    teal = sample_muted_teal(sheet)
    assets: dict[str, Image.Image] = {}
    for name in ("body", "left", "right", "corner"):
        prototype = Image.open(MASK_DIR / MASK_NAMES[name]).convert("RGBA")
        source_crop = (
            prepare_body_crop(sheet, boxes[name])
            if name == "body"
            else sheet.crop(boxes[name])
        )
        sample = source_crop.resize(TARGET_SIZES[name], Image.Resampling.LANCZOS).convert("RGBA")
        if name == "body":
            seamless = average_edge_pair(np.asarray(sample), width=18)
            sample = Image.fromarray(seamless, mode="RGBA")
        asset = apply_exact_mask(sample, prototype, teal)
        assets[name] = asset

    assets["left"] = blend_cap_join(assets["left"], assets["body"], side="right")
    assets["right"] = blend_cap_join(assets["right"], assets["body"], side="left")
    for name, asset in assets.items():
        save_png(asset, OUTPUT_NAMES[name])

    assembled: dict[int, Image.Image] = {}
    for length in (820, 1090, 1222):
        wall = assemble_wall(assets["body"], assets["left"], assets["right"], length)
        assembled[length] = wall
        save_png(wall, f"wall_assembled_{length}px_cursed_toy_v1.png")

    preview = make_component_preview(assets)
    preview.save(OUT / "wall_components_cursed_toy_v1_preview.png", optimize=True)
    board_preview = make_board_application_preview(assembled[820])
    board_preview.save(OUT / "wall_board_application_cursed_toy_v1_preview.png", optimize=True)

    body_array = np.asarray(assets["body"])
    edge_match = bool(np.array_equal(body_array[:, 0], body_array[:, -1]))
    print(f"source_size={sheet.size}")
    for name, box in boxes.items():
        print(f"{name}_source_box={box}")
    print(f"sampled_teal={tuple(int(value) for value in teal)}")
    for name, asset in assets.items():
        alpha = asset.getchannel("A")
        print(f"{OUTPUT_NAMES[name]} size={asset.size} alpha={alpha.getextrema()}")
    print(f"body_tile_edge_match={edge_match}")
    print(f"output={OUT}")


if __name__ == "__main__":
    main()
