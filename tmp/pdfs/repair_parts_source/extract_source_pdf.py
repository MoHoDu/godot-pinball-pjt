from __future__ import annotations

from pathlib import Path

import pdfplumber
import pypdfium2 as pdfium


SOURCE = Path(r"C:\Users\robot\Downloads\핀볼_수리부품_컨셉_기획서_강보현.pdf")
OUTPUT = Path(r"C:\NHN AI\godot-pinball-pjt\tmp\pdfs\repair_parts_source")


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	text_parts: list[str] = []
	with pdfplumber.open(SOURCE) as pdf:
		print(f"pages={len(pdf.pages)}")
		for page_number, page in enumerate(pdf.pages, start=1):
			text = page.extract_text(x_tolerance=2, y_tolerance=2) or ""
			text_parts.append(f"\n===== PAGE {page_number} =====\n{text}\n")
			print(
				f"page={page_number} size={page.width:.1f}x{page.height:.1f} "
				f"chars={len(text)} images={len(page.images)}"
			)
	(OUTPUT / "source_text.txt").write_text("".join(text_parts), encoding="utf-8")

	doc = pdfium.PdfDocument(SOURCE)
	for page_index in range(len(doc)):
		page = doc[page_index]
		bitmap = page.render(scale=1.5, rotation=0)
		image = bitmap.to_pil()
		image.save(OUTPUT / f"page-{page_index + 1:02d}.png")
		page.close()
	print(f"rendered={len(doc)}")


if __name__ == "__main__":
	main()
