from pathlib import Path

from PIL import Image, ImageDraw


root = Path(__file__).resolve().parent / "rendered"
for directory in root.iterdir():
    if not directory.is_dir():
        continue
    pages = sorted(directory.glob("page-*.png"), key=lambda p: int(p.stem.split("-")[-1]))
    if not pages:
        continue
    rendered = []
    for index, path in enumerate(pages, start=1):
        image = Image.open(path).convert("RGB")
        image.thumbnail((720, 940))
        canvas = Image.new("RGB", (760, image.height + 42), "#dfe5e8")
        canvas.paste(image, ((760 - image.width) // 2, 30))
        ImageDraw.Draw(canvas).text((16, 9), f"PAGE {index}", fill="#17324d")
        rendered.append(canvas)
    gap = 16
    sheet = Image.new(
        "RGB",
        (760, sum(img.height for img in rendered) + gap * (len(rendered) - 1)),
        "#aeb9bf",
    )
    y = 0
    for image in rendered:
        sheet.paste(image, (0, y))
        y += image.height + gap
    sheet.save(root / f"{directory.name}_contact.jpg", quality=60, optimize=True)
