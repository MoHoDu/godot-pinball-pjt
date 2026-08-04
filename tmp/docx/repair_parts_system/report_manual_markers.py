import re
from pathlib import Path

from docx import Document


DOCX = Path(r"C:\NHN AI\godot-pinball-pjt\docs\인형사의_수리_부품_시스템_기획서_v0.1.docx")

for paragraph in Document(DOCX).paragraphs:
	if re.match(r"^\s*(?:[•●▪◦]|\d+[.)])\s+", paragraph.text):
		print(f"{paragraph.style.name}: {paragraph.text}")
