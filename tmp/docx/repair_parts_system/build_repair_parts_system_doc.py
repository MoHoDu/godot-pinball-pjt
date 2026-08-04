from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING, WD_TAB_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(r"C:\NHN AI\godot-pinball-pjt")
SOURCE = ROOT / "docs" / "repair_parts_system_design.md"
OUTPUT = ROOT / "docs" / "인형사의_수리_부품_시스템_기획서_v0.1.docx"
WORK = ROOT / "tmp" / "docx" / "repair_parts_system"

FONT_NAME = "Malgun Gothic"
MONO_FONT = "D2Coding"
INK = "161925"
SLATE = "2E3A47"
TEAL = "4FA692"
TEAL_DARK = "2F7A69"
IVORY = "F0E0C3"
GOLD = "D9B34C"
MUTED = "67717D"
TABLE_FILL = "E8EEF5"
CALLOUT_FILL = "F4F6F9"
WHITE = "FFFFFF"
TABLE_WIDTH_DXA = 9360
TABLE_INDENT_DXA = 120


def rgb(hex_value: str) -> RGBColor:
	return RGBColor.from_string(hex_value)


def set_run_font(run, *, name: str = FONT_NAME, size: float | None = None,
		color: str | None = None, bold: bool | None = None, italic: bool | None = None) -> None:
	run.font.name = name
	run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), name)
	run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), name)
	run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), name)
	if size is not None:
		run.font.size = Pt(size)
	if color is not None:
		run.font.color.rgb = rgb(color)
	if bold is not None:
		run.bold = bold
	if italic is not None:
		run.italic = italic


def set_repeat_table_header(row) -> None:
	tr_pr = row._tr.get_or_add_trPr()
	header = OxmlElement("w:tblHeader")
	header.set(qn("w:val"), "true")
	tr_pr.append(header)


def set_cell_shading(cell, fill: str) -> None:
	tc_pr = cell._tc.get_or_add_tcPr()
	shd = tc_pr.find(qn("w:shd"))
	if shd is None:
		shd = OxmlElement("w:shd")
		tc_pr.append(shd)
	shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top: int = 80, bottom: int = 80,
		start: int = 120, end: int = 120) -> None:
	tc_pr = cell._tc.get_or_add_tcPr()
	tc_mar = tc_pr.first_child_found_in("w:tcMar")
	if tc_mar is None:
		tc_mar = OxmlElement("w:tcMar")
		tc_pr.append(tc_mar)
	for margin_name, value in (("top", top), ("bottom", bottom), ("start", start), ("end", end)):
		margin = tc_mar.find(qn(f"w:{margin_name}"))
		if margin is None:
			margin = OxmlElement(f"w:{margin_name}")
			tc_mar.append(margin)
		margin.set(qn("w:w"), str(value))
		margin.set(qn("w:type"), "dxa")


def set_table_borders(table, color: str = "C9D1D9", size: int = 4) -> None:
	tbl_pr = table._tbl.tblPr
	borders = tbl_pr.find(qn("w:tblBorders"))
	if borders is None:
		borders = OxmlElement("w:tblBorders")
		tbl_pr.append(borders)
	for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
		border = borders.find(qn(f"w:{edge}"))
		if border is None:
			border = OxmlElement(f"w:{edge}")
			borders.append(border)
		border.set(qn("w:val"), "single")
		border.set(qn("w:sz"), str(size))
		border.set(qn("w:space"), "0")
		border.set(qn("w:color"), color)


def table_widths_for(rows: list[list[str]]) -> list[int]:
	column_count = len(rows[0])
	max_lengths = []
	for column in range(column_count):
		length = max(len(re.sub(r"[`*]", "", row[column])) for row in rows)
		max_lengths.append(max(6, min(length, 42)))
	minimum_share = 0.13 if column_count <= 4 else 0.10
	weights = [max(minimum_share, value / sum(max_lengths)) for value in max_lengths]
	weight_sum = sum(weights)
	widths = [int(TABLE_WIDTH_DXA * weight / weight_sum) for weight in weights]
	widths[-1] += TABLE_WIDTH_DXA - sum(widths)
	return widths


def set_table_geometry(table, widths: list[int]) -> None:
	table.autofit = False
	table.alignment = WD_TABLE_ALIGNMENT.LEFT
	tbl_pr = table._tbl.tblPr
	for name, value in (("tblW", TABLE_WIDTH_DXA), ("tblInd", TABLE_INDENT_DXA)):
		element = tbl_pr.find(qn(f"w:{name}"))
		if element is None:
			element = OxmlElement(f"w:{name}")
			tbl_pr.append(element)
		element.set(qn("w:w"), str(value))
		element.set(qn("w:type"), "dxa")

	tbl_grid = table._tbl.tblGrid
	for child in list(tbl_grid):
		tbl_grid.remove(child)
	for width in widths:
		grid_col = OxmlElement("w:gridCol")
		grid_col.set(qn("w:w"), str(width))
		tbl_grid.append(grid_col)

	for row in table.rows:
		for cell, width in zip(row.cells, widths, strict=True):
			cell.width = Inches(width / 1440)
			tc_pr = cell._tc.get_or_add_tcPr()
			tc_w = tc_pr.find(qn("w:tcW"))
			if tc_w is None:
				tc_w = OxmlElement("w:tcW")
				tc_pr.append(tc_w)
			tc_w.set(qn("w:w"), str(width))
			tc_w.set(qn("w:type"), "dxa")


def set_paragraph_shading(paragraph, fill: str, border_color: str | None = None) -> None:
	p_pr = paragraph._p.get_or_add_pPr()
	shd = OxmlElement("w:shd")
	shd.set(qn("w:fill"), fill)
	p_pr.append(shd)
	if border_color:
		p_bdr = OxmlElement("w:pBdr")
		left = OxmlElement("w:left")
		left.set(qn("w:val"), "single")
		left.set(qn("w:sz"), "18")
		left.set(qn("w:space"), "8")
		left.set(qn("w:color"), border_color)
		p_bdr.append(left)
		p_pr.append(p_bdr)


def add_page_field(paragraph) -> None:
	run = paragraph.add_run("Page ")
	set_run_font(run, size=9, color=MUTED)
	fld_char_begin = OxmlElement("w:fldChar")
	fld_char_begin.set(qn("w:fldCharType"), "begin")
	instr_text = OxmlElement("w:instrText")
	instr_text.set(qn("xml:space"), "preserve")
	instr_text.text = " PAGE "
	fld_char_end = OxmlElement("w:fldChar")
	fld_char_end.set(qn("w:fldCharType"), "end")
	run._r.append(fld_char_begin)
	run._r.append(instr_text)
	run._r.append(fld_char_end)


def configure_styles(doc: Document) -> None:
	styles = doc.styles
	normal = styles["Normal"]
	normal.font.name = FONT_NAME
	normal._element.rPr.rFonts.set(qn("w:ascii"), FONT_NAME)
	normal._element.rPr.rFonts.set(qn("w:hAnsi"), FONT_NAME)
	normal._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_NAME)
	normal.font.size = Pt(10.5)
	normal.font.color.rgb = rgb(INK)
	normal.paragraph_format.space_before = Pt(0)
	normal.paragraph_format.space_after = Pt(6)
	normal.paragraph_format.line_spacing = 1.25
	normal.paragraph_format.widow_control = True

	heading_tokens = {
		"Heading 1": (16, TEAL_DARK, 18, 10),
		"Heading 2": (13, TEAL_DARK, 14, 7),
		"Heading 3": (12, SLATE, 10, 5),
	}
	for style_name, (size, color, before, after) in heading_tokens.items():
		style = styles[style_name]
		style.font.name = FONT_NAME
		style._element.rPr.rFonts.set(qn("w:ascii"), FONT_NAME)
		style._element.rPr.rFonts.set(qn("w:hAnsi"), FONT_NAME)
		style._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_NAME)
		style.font.size = Pt(size)
		style.font.bold = True
		style.font.color.rgb = rgb(color)
		style.paragraph_format.space_before = Pt(before)
		style.paragraph_format.space_after = Pt(after)
		style.paragraph_format.keep_with_next = True
		style.paragraph_format.keep_together = True

	for style_name in ("List Bullet", "List Number"):
		style = styles[style_name]
		style.font.name = FONT_NAME
		style._element.rPr.rFonts.set(qn("w:ascii"), FONT_NAME)
		style._element.rPr.rFonts.set(qn("w:hAnsi"), FONT_NAME)
		style._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_NAME)
		style.font.size = Pt(10.5)
		style.paragraph_format.space_after = Pt(4)
		style.paragraph_format.line_spacing = 1.25
		style.paragraph_format.left_indent = Inches(0.375)
		style.paragraph_format.first_line_indent = Inches(-0.188)

	if "Code Block" not in styles:
		code = styles.add_style("Code Block", 1)
	else:
		code = styles["Code Block"]
	code.font.name = MONO_FONT
	code._element.rPr.rFonts.set(qn("w:ascii"), MONO_FONT)
	code._element.rPr.rFonts.set(qn("w:hAnsi"), MONO_FONT)
	code._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_NAME)
	code.font.size = Pt(8.6)
	code.font.color.rgb = rgb(SLATE)
	code.paragraph_format.space_before = Pt(4)
	code.paragraph_format.space_after = Pt(8)
	code.paragraph_format.left_indent = Inches(0.18)
	code.paragraph_format.right_indent = Inches(0.18)
	code.paragraph_format.line_spacing = 1.05


def configure_page(doc: Document) -> None:
	section = doc.sections[0]
	section.page_width = Inches(8.5)
	section.page_height = Inches(11)
	section.top_margin = Inches(1)
	section.right_margin = Inches(1)
	section.bottom_margin = Inches(1)
	section.left_margin = Inches(1)
	section.header_distance = Inches(0.492)
	section.footer_distance = Inches(0.492)

	header = section.header
	p = header.paragraphs[0]
	p.alignment = WD_ALIGN_PARAGRAPH.LEFT
	p.paragraph_format.space_after = Pt(0)
	run = p.add_run("PINBALL_LOGUE  /  SYSTEM DESIGN")
	set_run_font(run, size=8.5, color=MUTED, bold=True)

	footer = section.footer
	p = footer.paragraphs[0]
	p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
	p.paragraph_format.space_before = Pt(0)
	add_page_field(p)


def add_inline(paragraph, text: str, *, size: float | None = None, color: str | None = None) -> None:
	pattern = re.compile(r"(\*\*.*?\*\*|`.*?`)")
	for part in pattern.split(text):
		if not part:
			continue
		if part.startswith("**") and part.endswith("**"):
			run = paragraph.add_run(part[2:-2])
			set_run_font(run, size=size, color=color, bold=True)
		elif part.startswith("`") and part.endswith("`"):
			run = paragraph.add_run(part[1:-1])
			set_run_font(run, name=MONO_FONT, size=(size or 10.5) - 0.5, color=SLATE)
			run.font.highlight_color = None
		else:
			run = paragraph.add_run(part)
			set_run_font(run, size=size, color=color)


def add_cover(doc: Document) -> None:
	spacer = doc.add_paragraph()
	spacer.paragraph_format.space_after = Pt(18)

	kicker = doc.add_paragraph()
	kicker.paragraph_format.space_after = Pt(6)
	run = kicker.add_run("SYSTEM DESIGN  /  v0.1")
	set_run_font(run, size=10, color=GOLD, bold=True)

	title = doc.add_paragraph()
	title.paragraph_format.space_after = Pt(8)
	run = title.add_run("인형사의 수리 부품")
	set_run_font(run, size=28, color=INK, bold=True)

	subtitle = doc.add_paragraph()
	subtitle.paragraph_format.space_after = Pt(24)
	run = subtitle.add_run("세션 보상 · 보드 배치 · 효과 발동 시스템 기획서")
	set_run_font(run, size=14, color=SLATE)

	metadata = [
		("프로젝트", "Pinball_Logue"),
		("문서 상태", "시스템 기획 초안 / 프로토타입 구현 기준"),
		("작성 기준", "핀볼_수리부품_컨셉_기획서_강보현.pdf"),
		("작성일", "2026-08-04"),
	]
	for label, value in metadata:
		p = doc.add_paragraph()
		p.paragraph_format.space_after = Pt(3)
		run = p.add_run(f"{label}: ")
		set_run_font(run, size=10.5, color=TEAL_DARK, bold=True)
		run = p.add_run(value)
		set_run_font(run, size=10.5, color=INK)

	callout = doc.add_paragraph()
	callout.paragraph_format.space_before = Pt(24)
	callout.paragraph_format.space_after = Pt(8)
	callout.paragraph_format.left_indent = Inches(0.16)
	callout.paragraph_format.right_indent = Inches(0.16)
	set_paragraph_shading(callout, CALLOUT_FILL, GOLD)
	run = callout.add_run("핵심 정의  ")
	set_run_font(run, size=11, color=TEAL_DARK, bold=True)
	run = callout.add_run("웨이브 사이에 공방의 희귀 부품을 고르고, 보드에 직접 장착해, 장난감을 되살리는 자신만의 수리 방식을 만드는 세션 성장 시스템")
	set_run_font(run, size=11, color=INK)

	note = doc.add_paragraph()
	note.paragraph_format.space_before = Pt(18)
	run = note.add_run("원본 컨셉의 정체성과 감정적 역할을 유지하면서, 후속 시스템 단계로 남아 있던 효과·수치·배치·연동 규칙을 프로토타입 수준으로 구체화했다.")
	set_run_font(run, size=9.5, color=MUTED, italic=True)
	doc.add_page_break()


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
	filename = "malgunbd.ttf" if bold else "malgun.ttf"
	path = Path(r"C:\Windows\Fonts") / filename
	return ImageFont.truetype(str(path), size=size)


def draw_centered(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str,
		font: ImageFont.FreeTypeFont, fill: str) -> None:
	bbox = draw.multiline_textbbox((0, 0), text, font=font, spacing=4, align="center")
	w = bbox[2] - bbox[0]
	h = bbox[3] - bbox[1]
	x = box[0] + (box[2] - box[0] - w) / 2
	y = box[1] + (box[3] - box[1] - h) / 2
	draw.multiline_text((x, y), text, font=font, fill=fill, spacing=4, align="center")


def build_diagrams() -> tuple[Path, Path]:
	WORK.mkdir(parents=True, exist_ok=True)
	flow_path = WORK / "repair_parts_session_loop.png"
	runtime_path = WORK / "repair_parts_runtime_flow.png"

	font = load_font(28, bold=True)
	small = load_font(20)
	canvas = Image.new("RGB", (1800, 520), f"#{WHITE}")
	draw = ImageDraw.Draw(canvas)
	labels = [
		("웨이브 전투", "콤보·목표 점수"),
		("점수 정산", "공 종료 후 처리"),
		("후보 3개", "비교·새로고침"),
		("부품 선택", "획득 또는 랭크업"),
		("소켓 배치", "다음 웨이브 준비"),
	]
	box_w, box_h, gap, start_x, y = 270, 150, 75, 65, 155
	colors = [SLATE, TEAL_DARK, "386B63", "8A6A25", SLATE]
	for index, ((title, detail), color) in enumerate(zip(labels, colors, strict=True)):
		x = start_x + index * (box_w + gap)
		draw.rounded_rectangle((x, y, x + box_w, y + box_h), radius=26, fill=f"#{color}")
		draw.text((x + 22, y + 30), title, font=font, fill=f"#{WHITE}")
		draw.text((x + 22, y + 88), detail, font=small, fill=f"#{IVORY}")
		if index < len(labels) - 1:
			arrow_y = y + box_h // 2
			draw.line((x + box_w + 12, arrow_y, x + box_w + gap - 18, arrow_y), fill=f"#{GOLD}", width=8)
			draw.polygon((x + box_w + gap - 18, arrow_y - 15, x + box_w + gap - 18, arrow_y + 15, x + box_w + gap + 5, arrow_y), fill=f"#{GOLD}")
	draw.text((65, 60), "일반 웨이브 3회 반복 후 보스 웨이브로 진입", font=load_font(30, bold=True), fill=f"#{INK}")
	draw.text((65, 355), "보스 웨이브에서는 현재 수리함과 배치를 유지하며, 보상 선택 단계는 생성하지 않는다.", font=small, fill=f"#{MUTED}")
	canvas.save(flow_path)

	canvas = Image.new("RGB", (1800, 580), f"#{WHITE}")
	draw = ImageDraw.Draw(canvas)
	labels = [
		"새로운\n유효 접촉",
		"콤보 기본\n타격 등록",
		"조건·쿨다운\n검사",
		"효과 해결·\n상한 적용",
		"대상 시스템\nAPI 전달",
		"VFX·SFX·\nHUD 피드백",
	]
	box_w, box_h, gap, start_x, y = 230, 155, 58, 52, 180
	for index, label in enumerate(labels):
		x = start_x + index * (box_w + gap)
		fill = SLATE if index in (0, 1, 4) else TEAL_DARK
		if index == 3:
			fill = "8A6A25"
		draw.rounded_rectangle((x, y, x + box_w, y + box_h), radius=24, fill=f"#{fill}")
		draw_centered(draw, (x + 12, y + 12, x + box_w - 12, y + box_h - 12), label, font, f"#{WHITE}")
		if index < len(labels) - 1:
			arrow_y = y + box_h // 2
			draw.line((x + box_w + 8, arrow_y, x + box_w + gap - 16, arrow_y), fill=f"#{GOLD}", width=7)
			draw.polygon((x + box_w + gap - 16, arrow_y - 13, x + box_w + gap - 16, arrow_y + 13, x + box_w + gap + 4, arrow_y), fill=f"#{GOLD}")
	draw.text((52, 60), "발동은 기존 시스템을 우회하지 않는다", font=load_font(30, bold=True), fill=f"#{INK}")
	draw.text((52, 390), "울림·정산 보너스 같은 파생 요청은 새로운 부품 발동의 원인이 되지 않으며, 효과 깊이는 1단계로 제한한다.", font=small, fill=f"#{MUTED}")
	canvas.save(runtime_path)
	return flow_path, runtime_path


def add_diagram(doc: Document, path: Path, caption: str) -> None:
	p = doc.add_paragraph()
	p.alignment = WD_ALIGN_PARAGRAPH.CENTER
	p.paragraph_format.space_before = Pt(2)
	p.paragraph_format.space_after = Pt(4)
	run = p.add_run()
	run.add_picture(str(path), width=Inches(6.35))
	caption_p = doc.add_paragraph()
	caption_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
	caption_p.paragraph_format.space_after = Pt(10)
	run = caption_p.add_run(caption)
	set_run_font(run, size=8.5, color=MUTED, italic=True)


def add_table(doc: Document, rows: list[list[str]]) -> None:
	widths = table_widths_for(rows)
	table = doc.add_table(rows=len(rows), cols=len(rows[0]))
	table.style = "Table Grid"
	set_table_geometry(table, widths)
	set_table_borders(table)
	set_repeat_table_header(table.rows[0])
	for row_index, (row, values) in enumerate(zip(table.rows, rows, strict=True)):
		for column_index, (cell, value) in enumerate(zip(row.cells, values, strict=True)):
			cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
			set_cell_margins(cell)
			if row_index == 0:
				set_cell_shading(cell, TABLE_FILL)
			p = cell.paragraphs[0]
			p.paragraph_format.space_before = Pt(0)
			p.paragraph_format.space_after = Pt(0)
			p.paragraph_format.line_spacing = 1.12
			if column_index > 0 and len(value) <= 16 and not re.search(r"[.。]", value):
				p.alignment = WD_ALIGN_PARAGRAPH.CENTER
			add_inline(p, value, size=8.8, color=INK)
			for run in p.runs:
				if row_index == 0:
					run.bold = True
					run.font.color.rgb = rgb(SLATE)
	paragraph = doc.add_paragraph()
	paragraph.paragraph_format.space_after = Pt(2)


def parse_table(lines: list[str], start: int) -> tuple[list[list[str]], int]:
	rows: list[list[str]] = []
	index = start
	while index < len(lines) and lines[index].strip().startswith("|"):
		cells = [cell.strip() for cell in lines[index].strip().strip("|").split("|")]
		if not all(re.fullmatch(r":?-{3,}:?", cell.replace(" ", "")) for cell in cells):
			rows.append(cells)
		index += 1
	return rows, index


def process_markdown(doc: Document, session_diagram: Path, runtime_diagram: Path) -> None:
	lines = SOURCE.read_text(encoding="utf-8").splitlines()
	start = next(i for i, line in enumerate(lines) if line.startswith("## "))
	index = start
	page_break_prefixes = ("8. ", "12. ", "14. ", "16. ", "부록 A")
	while index < len(lines):
		line = lines[index].rstrip()
		stripped = line.strip()
		if not stripped or stripped == "---":
			index += 1
			continue

		if stripped.startswith("```"):
			code_lines: list[str] = []
			index += 1
			while index < len(lines) and not lines[index].strip().startswith("```"):
				code_lines.append(lines[index])
				index += 1
			index += 1
			p = doc.add_paragraph(style="Code Block")
			set_paragraph_shading(p, "F1F3F5")
			run = p.add_run("\n".join(code_lines))
			set_run_font(run, name=MONO_FONT, size=8.6, color=SLATE)
			continue

		if stripped.startswith("|"):
			rows, index = parse_table(lines, index)
			if rows:
				add_table(doc, rows)
			continue

		heading_match = re.match(r"^(#{2,4})\s+(.+)$", stripped)
		if heading_match:
			level = len(heading_match.group(1)) - 1
			text = heading_match.group(2)
			p = doc.add_paragraph(style=f"Heading {min(level, 3)}")
			if level == 1 and text.startswith(page_break_prefixes):
				p.paragraph_format.page_break_before = True
			add_inline(p, text)
			if text.startswith("3. 세션 루프"):
				add_diagram(doc, session_diagram, "그림 1. 수리 부품이 포함된 세션 루프")
			elif text.startswith("7. 공통 발동 구조"):
				add_diagram(doc, runtime_diagram, "그림 2. 유효 접촉에서 피드백까지의 런타임 처리 순서")
			index += 1
			continue

		bullet_match = re.match(r"^-\s+(.+)$", stripped)
		if bullet_match:
			p = doc.add_paragraph(style="List Bullet")
			p.paragraph_format.left_indent = Inches(0.375)
			p.paragraph_format.first_line_indent = Inches(-0.188)
			p.paragraph_format.tab_stops.add_tab_stop(Inches(0.375), WD_TAB_ALIGNMENT.LEFT)
			add_inline(p, bullet_match.group(1))
			index += 1
			continue

		number_match = re.match(r"^\d+\.\s+(.+)$", stripped)
		if number_match:
			p = doc.add_paragraph(style="List Number")
			p.paragraph_format.left_indent = Inches(0.375)
			p.paragraph_format.first_line_indent = Inches(-0.188)
			p.paragraph_format.tab_stops.add_tab_stop(Inches(0.375), WD_TAB_ALIGNMENT.LEFT)
			add_inline(p, number_match.group(1))
			index += 1
			continue

		paragraph_lines = [stripped]
		index += 1
		while index < len(lines):
			next_line = lines[index].strip()
			if (not next_line or next_line == "---" or next_line.startswith("#") or
					next_line.startswith("|") or next_line.startswith("```") or
					re.match(r"^-\s+", next_line) or re.match(r"^\d+\.\s+", next_line)):
				break
			paragraph_lines.append(next_line)
			index += 1
		p = doc.add_paragraph()
		add_inline(p, " ".join(paragraph_lines))


def main() -> None:
	WORK.mkdir(parents=True, exist_ok=True)
	OUTPUT.parent.mkdir(parents=True, exist_ok=True)
	doc = Document()
	configure_styles(doc)
	configure_page(doc)
	doc.core_properties.title = "인형사의 수리 부품 시스템 기획서"
	doc.core_properties.subject = "Pinball_Logue 세션 보상 및 보드 배치 시스템"
	doc.core_properties.author = "Pinball_Logue Team"
	doc.core_properties.keywords = "Pinball_Logue, 수리 부품, 시스템 기획, 보상, 배치, 콤보"
	add_cover(doc)
	session_diagram, runtime_diagram = build_diagrams()
	process_markdown(doc, session_diagram, runtime_diagram)
	doc.save(OUTPUT)
	print(f"saved={OUTPUT}")


if __name__ == "__main__":
	main()
