#!/usr/bin/env python3
"""후처리본 인게임 크기 검수 시트.

`cutout_and_finalize.py` 결과를 확정 보드 위에 **실제 표시 지름**으로 올린다.
가이드 7절 검수 기준 두 가지를 여기서 본다.

  - 인게임 크기에서 형태와 내부 묘사가 뭉개지지 않는가
  - 공(64px)보다 먼저 눈에 들어오지 않는가

실행:
  python docs/bumper_guides/make_cutout_review_sheet.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

BOARD = os.path.join(ROOT, "Resources/Art/board/octagonal_dark_wood_board.png")
BALL = os.path.join(ROOT, "Resources/Art/balls/glass_eye_ball.png")
CUTOUT = os.path.join(HERE, "candidates", "masked")
BUTTON = os.path.join(HERE, "step1_v2", "button.png")
OUT = os.path.join(HERE, "candidates", "review_sheet.png")

# --repair 로 수리 부품 쪽을 본다. settings/bumpers/repair_parts/ 실측은 4종 모두
# 표시 88px / 충돌 80px 로 동일하다.
REPAIR_ROOT = os.path.abspath(os.path.join(HERE, "..", "repair_part_guides"))
REPAIR_CUTOUT = os.path.join(REPAIR_ROOT, "candidates", "masked")
REPAIR_OUT = os.path.join(REPAIR_ROOT, "candidates", "review_sheet.png")
REPAIR_ROWS = [
    ("starlight_brooch", 88, 80, "별빛 브로치"),
    ("golden_gears", 88, 80, "황금 톱니바퀴"),
    ("forgotten_star_bell", 88, 80, "잊혀진 별방울"),
]

BALL_DIAMETER = 64

# (폴더, 표시 지름, 충돌 지름, 라벨). settings/bumpers/ 실측.
ROWS = [
    (None, 92, 88, "단추 / NORMAL (확정본)"),
    ("cotton_r2", 104, 96, "솜 / NORMAL"),
    ("spring_doll_r3", 112, 104, "용수철 인형 / BOUNCE (3차)"),
    ("toy_drum_r2", 128, 120, "장난감 북 / BOUNCE"),
    ("clockwork_cannon_r2", 128, 112, "태엽 대포 / SHOT"),
    ("marble_slide_r2", 240, 232, "구슬 미끄럼틀 (지름 가정)"),
]

CELL_W = 300
CELL_H = 300
COLS = 4
PAD_TOP = 34

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\malgun.ttf",
    r"C:\Windows\Fonts\gulim.ttc",
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    raise SystemExit("한글 폰트를 못 찾았다.")


def load_board(width: int, height: int) -> Image.Image:
    board = Image.open(BOARD).convert("RGBA")
    crop = board.crop((320, 200, 1920, 1060))
    return crop.resize((width, height), Image.LANCZOS)


def paste_centered(canvas: Image.Image, sprite: Image.Image, cx: int, cy: int, diameter: int) -> None:
    scaled = sprite.resize((diameter, diameter), Image.LANCZOS)
    canvas.alpha_composite(scaled, (cx - diameter // 2, cy - diameter // 2))


def row_files(folder: str | None, cutout_root: str) -> list[str]:
    if folder is None:
        return [BUTTON]
    path = os.path.join(cutout_root, folder)
    return [os.path.join(path, f) for f in sorted(os.listdir(path)) if f.endswith(".png")]


def main() -> None:
    import sys

    repair = "--repair" in sys.argv
    rows = REPAIR_ROWS if repair else ROWS
    cutout_root = REPAIR_CUTOUT if repair else CUTOUT
    out_path = REPAIR_OUT if repair else OUT

    font = load_font(19)
    small = load_font(15)

    width = COLS * CELL_W
    height = sum(CELL_H + PAD_TOP for _ in rows)

    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    sheet.alpha_composite(load_board(width, height))
    draw = ImageDraw.Draw(sheet)
    ball = Image.open(BALL).convert("RGBA")

    y = 0
    for folder, visual, collision, label in rows:
        draw.rectangle([0, y, width, y + PAD_TOP], fill=(12, 14, 20, 210))
        draw.text((12, y + 8), f"{label}   표시 {visual}px / 충돌 {collision}px",
                  font=font, fill=(240, 234, 220, 255))

        files = row_files(folder, cutout_root)
        for col, path in enumerate(files[:COLS]):
            cx = col * CELL_W + CELL_W // 2
            cy = y + PAD_TOP + CELL_H // 2

            # 충돌 원을 얇게 겹쳐 외곽과 일치하는지 본다.
            r = collision / 2
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 90, 90, 120), width=1)

            sprite = Image.open(path).convert("RGBA")
            paste_centered(sheet, sprite, cx, cy, visual)

            # 같은 셀에 공을 놓아 시각 우선순위를 비교한다.
            paste_centered(sheet, ball, cx + CELL_W // 2 - 46, cy + CELL_H // 2 - 46, BALL_DIAMETER)

            draw.text((col * CELL_W + 10, y + PAD_TOP + CELL_H - 24),
                      os.path.splitext(os.path.basename(path))[0],
                      font=small, fill=(226, 220, 206, 255))

        y += CELL_H + PAD_TOP

    sheet.convert("RGB").save(out_path, quality=95)
    print(f"저장: {out_path}  ({sheet.size[0]}x{sheet.size[1]})")


if __name__ == "__main__":
    main()
