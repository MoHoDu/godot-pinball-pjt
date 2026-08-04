from pathlib import Path

import pypdfium2 as pdfium


PDF = Path(r"C:\NHN AI\godot-pinball-pjt\tmp\docx\repair_parts_system\render3\repair_parts_system_design.pdf")
OUTPUT = PDF.parent / "pages"


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	doc = pdfium.PdfDocument(PDF)
	print(f"pages={len(doc)}")
	for index in range(len(doc)):
		page = doc[index]
		bitmap = page.render(scale=1.6)
		image = bitmap.to_pil()
		image.save(OUTPUT / f"page-{index + 1:02d}.png")
		page.close()


if __name__ == "__main__":
	main()
