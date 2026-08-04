from pathlib import Path

from PIL import Image


ROOT = Path(r"C:\NHN AI\godot-pinball-pjt\tmp\pdfs\repair_parts_source")
BOXES = {
	7: (73.5, 69.7, 279.8, 378.7),
	9: (73.5, 148.4, 297.0, 371.9),
	11: (73.5, 96.0, 269.3, 276.7),
	13: (73.5, 148.4, 247.5, 322.4),
}


def main() -> None:
	for page_number, box in BOXES.items():
		with Image.open(ROOT / f"page-{page_number:02d}.png") as page:
			scale_x = page.width / 596.0
			scale_y = page.height / 842.0
			crop_box = (
				int(box[0] * scale_x),
				int(box[1] * scale_y),
				int(box[2] * scale_x),
				int(box[3] * scale_y),
			)
			crop = page.crop(crop_box).convert("RGB")
			crop.thumbnail((260, 320), Image.Resampling.LANCZOS)
			crop.save(ROOT / f"reference-{page_number}.jpg", quality=45, optimize=True)


if __name__ == "__main__":
	main()
