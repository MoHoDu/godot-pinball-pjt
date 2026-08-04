from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(r"C:\NHN AI\godot-pinball-pjt\tmp\docx\repair_parts_system\render5\pages")
QA = ROOT.parent / "qa"


def main() -> None:
	QA.mkdir(parents=True, exist_ok=True)
	pages = sorted(ROOT.glob("page-*.png"))
	for path in pages:
		with Image.open(path) as image:
			gray = image.convert("L")
			array = np.asarray(gray)
			ink = array < 245
			ys, xs = np.where(ink)
			if len(xs) == 0:
				print(f"{path.name} BLANK")
			else:
				print(
					f"{path.name} bbox=({xs.min()},{ys.min()})-({xs.max()},{ys.max()}) "
					f"size={image.width}x{image.height} ink={ink.mean():.4f}"
				)

	for start in range(0, len(pages), 3):
		batch = pages[start : start + 3]
		canvas = Image.new("L", (620, 285), 230)
		draw = ImageDraw.Draw(canvas)
		for offset, path in enumerate(batch):
			with Image.open(path) as image:
				thumb = image.convert("L")
				thumb.thumbnail((194, 251), Image.Resampling.LANCZOS)
				x = 8 + offset * 204
				canvas.paste(thumb, (x, 25))
				draw.text((x, 6), path.stem, fill=20)
		canvas.save(QA / f"contact-{start // 3 + 1:02d}.jpg", quality=12, optimize=True)


if __name__ == "__main__":
	main()
