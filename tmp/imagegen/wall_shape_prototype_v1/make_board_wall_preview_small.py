from pathlib import Path

from PIL import Image


asset_dir = Path(r"C:\NHN AI\godot-pinball-pjt\Resources\Art\walls\shape_prototype_v1")
source = Image.open(asset_dir / "wall_shape_on_square_board_preview.png").convert("RGB")
source.resize((560, 315), Image.Resampling.LANCZOS).save(
    asset_dir / "wall_shape_on_square_board_preview_560x315.jpg",
    quality=72,
    optimize=True,
)
