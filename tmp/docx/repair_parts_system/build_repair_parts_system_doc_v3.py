from __future__ import annotations

import importlib.util
import re
from pathlib import Path

from docx import Document
from docx.enum.text import WD_LINE_SPACING, WD_TAB_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt


BASE_PATH = Path(__file__).with_name("build_repair_parts_system_doc.py")
SPEC = importlib.util.spec_from_file_location("repair_parts_builder_base_v3", BASE_PATH)
if SPEC is None or SPEC.loader is None:
	raise RuntimeError("Unable to load base document builder")
base = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(base)


def next_id(elements, attribute: str, default: int) -> int:
	values = [int(element.get(qn(attribute))) for element in elements]
	return max(values, default=default) + 1


def insert_abstract_before_nums(numbering, abstract) -> None:
	children = list(numbering)
	first_num_index = next(
		(index for index, child in enumerate(children) if child.tag == qn("w:num")),
		len(children),
	)
	numbering.insert(first_num_index, abstract)


def create_abstract_numbering(doc: Document, num_format: str, level_text: str) -> int:
	numbering = doc.part.numbering_part.element
	abstract_id = next_id(numbering.findall(qn("w:abstractNum")), "w:abstractNumId", -1)
	abstract = OxmlElement("w:abstractNum")
	abstract.set(qn("w:abstractNumId"), str(abstract_id))
	multi = OxmlElement("w:multiLevelType")
	multi.set(qn("w:val"), "singleLevel")
	abstract.append(multi)
	lvl = OxmlElement("w:lvl")
	lvl.set(qn("w:ilvl"), "0")
	for tag, value in (("start", "1"), ("numFmt", num_format), ("lvlText", level_text), ("lvlJc", "left")):
		element = OxmlElement(f"w:{tag}")
		element.set(qn("w:val"), value)
		lvl.append(element)
	p_pr = OxmlElement("w:pPr")
	tabs = OxmlElement("w:tabs")
	tab = OxmlElement("w:tab")
	tab.set(qn("w:val"), "num")
	tab.set(qn("w:pos"), "540")
	tabs.append(tab)
	p_pr.append(tabs)
	indent = OxmlElement("w:ind")
	indent.set(qn("w:left"), "540")
	indent.set(qn("w:hanging"), "271")
	p_pr.append(indent)
	lvl.append(p_pr)
	r_pr = OxmlElement("w:rPr")
	r_fonts = OxmlElement("w:rFonts")
	r_fonts.set(qn("w:ascii"), base.FONT_NAME)
	r_fonts.set(qn("w:hAnsi"), base.FONT_NAME)
	r_fonts.set(qn("w:eastAsia"), base.FONT_NAME)
	r_pr.append(r_fonts)
	lvl.append(r_pr)
	abstract.append(lvl)
	insert_abstract_before_nums(numbering, abstract)
	return abstract_id


def create_numbering_instance(doc: Document, abstract_id: int, *, restart: bool) -> int:
	numbering = doc.part.numbering_part.element
	num_id = next_id(numbering.findall(qn("w:num")), "w:numId", 0)
	num = OxmlElement("w:num")
	num.set(qn("w:numId"), str(num_id))
	abstract_ref = OxmlElement("w:abstractNumId")
	abstract_ref.set(qn("w:val"), str(abstract_id))
	num.append(abstract_ref)
	if restart:
		override = OxmlElement("w:lvlOverride")
		override.set(qn("w:ilvl"), "0")
		start_override = OxmlElement("w:startOverride")
		start_override.set(qn("w:val"), "1")
		override.append(start_override)
		num.append(override)
	numbering.append(num)
	return num_id


def apply_numbering(paragraph, num_id: int) -> None:
	p_pr = paragraph._p.get_or_add_pPr()
	existing = p_pr.find(qn("w:numPr"))
	if existing is not None:
		p_pr.remove(existing)
	num_pr = OxmlElement("w:numPr")
	ilvl = OxmlElement("w:ilvl")
	ilvl.set(qn("w:val"), "0")
	num_id_element = OxmlElement("w:numId")
	num_id_element.set(qn("w:val"), str(num_id))
	num_pr.append(ilvl)
	num_pr.append(num_id_element)
	p_pr.append(num_pr)


def add_list_paragraph(doc: Document, text: str, num_id: int) -> None:
	p = doc.add_paragraph(style="Normal")
	p.paragraph_format.space_after = Pt(4)
	p.paragraph_format.line_spacing = 1.25
	p.paragraph_format.left_indent = Inches(0.375)
	p.paragraph_format.first_line_indent = Inches(-0.188)
	p.paragraph_format.tab_stops.add_tab_stop(Inches(0.375), WD_TAB_ALIGNMENT.LEFT)
	apply_numbering(p, num_id)
	base.add_inline(p, text)


def process_markdown(doc: Document, session_diagram: Path, runtime_diagram: Path) -> None:
	lines = base.SOURCE.read_text(encoding="utf-8").splitlines()
	index = next(i for i, line in enumerate(lines) if line.startswith("## "))
	decimal_abstract_id = create_abstract_numbering(doc, "decimal", "%1.")
	bullet_abstract_id = create_abstract_numbering(doc, "bullet", "•")
	bullet_num_id = create_numbering_instance(doc, bullet_abstract_id, restart=False)
	active_decimal_num_id: int | None = None
	while index < len(lines):
		stripped = lines[index].strip()
		if not stripped or stripped == "---":
			index += 1
			continue

		if stripped.startswith("```"):
			active_decimal_num_id = None
			code_lines: list[str] = []
			index += 1
			while index < len(lines) and not lines[index].strip().startswith("```"):
				code_lines.append(lines[index])
				index += 1
			index += 1
			p = doc.add_paragraph(style="Code Block")
			base.set_paragraph_shading(p, "F1F3F5")
			run = p.add_run("\n".join(code_lines))
			base.set_run_font(run, name=base.MONO_FONT, size=8.6, color=base.SLATE)
			continue

		if stripped.startswith("|"):
			active_decimal_num_id = None
			rows, index = base.parse_table(lines, index)
			if rows:
				base.add_table(doc, rows)
			continue

		heading_match = re.match(r"^(#{2,4})\s+(.+)$", stripped)
		if heading_match:
			active_decimal_num_id = None
			level = len(heading_match.group(1)) - 1
			text = heading_match.group(2)
			p = doc.add_paragraph(style=f"Heading {min(level, 3)}")
			base.add_inline(p, text)
			if text.startswith("3. 세션 루프"):
				base.add_diagram(doc, session_diagram, "그림 1. 수리 부품이 포함된 세션 루프")
			elif text.startswith("7. 공통 발동 구조"):
				base.add_diagram(doc, runtime_diagram, "그림 2. 유효 접촉에서 피드백까지의 런타임 처리 순서")
			index += 1
			continue

		bullet_match = re.match(r"^-\s+(.+)$", stripped)
		if bullet_match:
			active_decimal_num_id = None
			add_list_paragraph(doc, bullet_match.group(1), bullet_num_id)
			index += 1
			continue

		number_match = re.match(r"^\d+\.\s+(.+)$", stripped)
		if number_match:
			if active_decimal_num_id is None:
				active_decimal_num_id = create_numbering_instance(doc, decimal_abstract_id, restart=True)
			add_list_paragraph(doc, number_match.group(1), active_decimal_num_id)
			index += 1
			continue

		active_decimal_num_id = None
		paragraph_lines = [stripped]
		index += 1
		while index < len(lines):
			next_line = lines[index].strip()
			if (
				not next_line
				or next_line == "---"
				or next_line.startswith("#")
				or next_line.startswith("|")
				or next_line.startswith("```")
				or re.match(r"^-\s+", next_line)
				or re.match(r"^\d+\.\s+", next_line)
			):
				break
			paragraph_lines.append(next_line)
			index += 1
		p = doc.add_paragraph()
		base.add_inline(p, " ".join(paragraph_lines))


base.process_markdown = process_markdown


if __name__ == "__main__":
	base.main()
