from pathlib import Path

from PIL import Image


asset_dir = Path(r"C:\NHN AI\godot-pinball-pjt\Resources\Art\walls\shape_prototype_v1")
source = Image.open(asset_dir / "wall_shape_on_square_board_preview.png").convert("RGB")
source.resize((1120, 630), Image.Resampling.LANCZOS).save(
    asset_dir / "wall_shape_on_square_board_preview_1120x630.jpg",
    quality=82,
    optimize=True,
)
