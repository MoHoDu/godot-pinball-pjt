from pathlib import Path

from PIL import Image, ImageDraw


OUTPUT = Path(r"C:\NHN AI\godot-pinball-pjt\tmp\pdfs\repair_parts_source")


def main() -> None:
	page_paths = sorted(OUTPUT.glob("page-*.png"))
	for batch_index in range(0, len(page_paths), 5):
		batch = page_paths[batch_index : batch_index + 5]
		thumbs: list[Image.Image] = []
		for path in batch:
			with Image.open(path) as source_image:
				thumb = source_image.convert("RGB")
				thumb.thumbnail((360, 510), Image.Resampling.LANCZOS)
				thumbs.append(thumb.copy())
		canvas = Image.new("RGB", (len(thumbs) * 380, 550), "#20232b")
		draw = ImageDraw.Draw(canvas)
		for offset, (path, thumb) in enumerate(zip(batch, thumbs, strict=True)):
			x = offset * 380 + 10
			canvas.paste(thumb, (x, 30))
			draw.text((x, 8), path.stem, fill="white")
		canvas.save(OUTPUT / f"contact-{batch_index // 5 + 1}.png")


if __name__ == "__main__":
	main()
