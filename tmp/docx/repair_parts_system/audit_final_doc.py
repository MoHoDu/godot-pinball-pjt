import re
import zipfile
from pathlib import Path

from docx import Document
from lxml import etree
from pypdf import PdfReader


ROOT = Path(r"C:\NHN AI\godot-pinball-pjt")
DOCX = ROOT / "docs" / "인형사의_수리_부품_시스템_기획서_v0.1.docx"
PDF = ROOT / "tmp" / "docx" / "repair_parts_system" / "render5" / "repair_parts_system_design.pdf"
NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}


def qn(name: str) -> str:
	prefix, local = name.split(":")
	return f"{{{NS[prefix]}}}{local}"


def audit_docx() -> None:
	doc = Document(DOCX)
	all_text = "\n".join(p.text for p in doc.paragraphs)
	print(f"docx={DOCX.name} paragraphs={len(doc.paragraphs)} tables={len(doc.tables)} sections={len(doc.sections)}")
	for index, section in enumerate(doc.sections, 1):
		print(
			f"section-{index}: page={section.page_width}x{section.page_height} "
			f"margins={section.left_margin},{section.right_margin},{section.top_margin},{section.bottom_margin} "
			f"header={section.header_distance} footer={section.footer_distance}"
		)

	with zipfile.ZipFile(DOCX) as archive:
		document_xml = etree.fromstring(archive.read("word/document.xml"))
		numbering_xml = etree.fromstring(archive.read("word/numbering.xml"))
		media = [name for name in archive.namelist() if name.startswith("word/media/")]
		print(f"embedded-media={len(media)}: {', '.join(Path(name).name for name in media)}")

	abstract_formats: dict[tuple[str, str], str] = {}
	for abstract in numbering_xml.xpath("w:abstractNum", namespaces=NS):
		abstract_id = abstract.get(qn("w:abstractNumId"))
		for level in abstract.xpath("w:lvl", namespaces=NS):
			ilvl = level.get(qn("w:ilvl"))
			fmt = level.find("w:numFmt", NS)
			abstract_formats[(abstract_id, ilvl)] = fmt.get(qn("w:val")) if fmt is not None else "missing"

	num_to_abstract: dict[str, str] = {}
	restarts: set[str] = set()
	for num in numbering_xml.xpath("w:num", namespaces=NS):
		num_id = num.get(qn("w:numId"))
		abstract = num.find("w:abstractNumId", NS)
		if abstract is not None:
			num_to_abstract[num_id] = abstract.get(qn("w:val"))
		if num.find("w:lvlOverride/w:startOverride", NS) is not None:
			restarts.add(num_id)

	list_rows: list[tuple[str, str, str, str]] = []
	for paragraph in document_xml.xpath(".//w:body/w:p", namespaces=NS):
		num_pr = paragraph.find("w:pPr/w:numPr", NS)
		if num_pr is None:
			continue
		num_id_node = num_pr.find("w:numId", NS)
		ilvl_node = num_pr.find("w:ilvl", NS)
		if num_id_node is None:
			continue
		num_id = num_id_node.get(qn("w:val"))
		ilvl = ilvl_node.get(qn("w:val")) if ilvl_node is not None else "0"
		abstract_id = num_to_abstract.get(num_id, "missing")
		fmt = abstract_formats.get((abstract_id, ilvl), "missing")
		text = "".join(paragraph.xpath(".//w:t/text()", namespaces=NS))
		list_rows.append((num_id, ilvl, fmt, text))

	groups: list[list[tuple[str, str, str, str]]] = []
	for row in list_rows:
		if not groups or groups[-1][-1][0] != row[0]:
			groups.append([row])
		else:
			groups[-1].append(row)
	print(f"numbered-paragraphs={len(list_rows)} list-groups={len(groups)}")
	for group in groups:
		num_id, ilvl, fmt, first = group[0]
		print(
			f"list numId={num_id} fmt={fmt} ilvl={ilvl} count={len(group)} "
			f"restart={'yes' if num_id in restarts else 'no'} first={first[:55]!r}"
		)

	fake_markers = [
		p.text for p in doc.paragraphs
		if re.match(r"^\s*(?:[•●▪◦]|\d+[.)])\s+", p.text)
	]
	print(f"manual-list-markers={len(fake_markers)}")
	bad_tokens = [token for token in ("TODO", "TBD", "{{", "}}", "codex-file-citation") if token in all_text]
	print(f"placeholder-tokens={bad_tokens}")

	for index, table in enumerate(document_xml.xpath(".//w:tbl", namespaces=NS), 1):
		width_node = table.find("w:tblPr/w:tblW", NS)
		width = width_node.get(qn("w:w")) if width_node is not None else "missing"
		grid_values = [int(node.get(qn("w:w"))) for node in table.xpath("w:tblGrid/w:gridCol", namespaces=NS)]
		exact_heights = table.xpath(".//w:trHeight[@w:hRule='exact']", namespaces=NS)
		print(f"table-{index}: width={width} grid-sum={sum(grid_values)} cols={len(grid_values)} exact-row-heights={len(exact_heights)}")


def audit_pdf() -> None:
	reader = PdfReader(PDF)
	print(f"pdf-pages={len(reader.pages)}")
	for index, page in enumerate(reader.pages, 1):
		text = page.extract_text() or ""
		compact = re.sub(r"\s+", " ", text).strip()
		print(f"pdf-page-{index:02d}: chars={len(compact)} start={compact[:75]!r}")


if __name__ == "__main__":
	audit_docx()
	audit_pdf()
