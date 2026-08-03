from pathlib import Path

from PIL import Image


PROJECT = Path(r"C:\NHN AI\godot-pinball-pjt")
ASSET_DIR = PROJECT / "Resources" / "Art" / "walls" / "shape_prototype_v1"
BOARD_PATH = PROJECT / "Resources" / "Art" / "board" / "octagonal_dark_wood_board.png"

board = Image.open(BOARD_PATH).convert("RGBA")
if board.size != (2240, 1260):
    raise ValueError(f"Unexpected board size: {board.size}")

wall = Image.open(ASSET_DIR / "wall_assembled_820px_preview.png").convert("RGBA")

placements = [
    ((1855, 140), -20.0),
    ((385, 140), 20.0),
    ((1855, 1120), -160.0),
    ((385, 1120), 160.0),
]

preview = board.copy()
for center, angle in placements:
    rotated = wall.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    position = (round(center[0] - rotated.width / 2), round(center[1] - rotated.height / 2))
    preview.alpha_composite(rotated, position)

target = ASSET_DIR / "wall_shape_on_square_board_preview.png"
preview.save(target, optimize=True)
print(f"preview={target}")
