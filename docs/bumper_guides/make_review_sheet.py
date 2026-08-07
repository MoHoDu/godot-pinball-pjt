#!/usr/bin/env python3
"""범퍼 STEP1 인게임 크기 검수 시트.

검수 기준 두 가지를 눈으로 확인하기 위한 도구다.

- 실제 게임 크기(92~128px)에서 형태가 뭉개지는가
- 범퍼가 공보다 먼저 눈에 들어오지 않는가

확정 보드(`Resources/Art/board/octagonal_dark_wood_board.png`) 위에
각 범퍼를 `visual_diameter` 실측값으로, 공을 64px 로 나란히 놓는다.

실행:
  python3 docs/bumper_guides/make_review_sheet.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

BOARD = os.path.join(ROOT, "Resources/Art/board/octagonal_dark_wood_board.png")
BALL = os.path.join(ROOT, "Resources/Art/balls/glass_eye_ball.png")
STEP1 = os.path.join(HERE, "step1")
OUT = os.path.join(HERE, "step1_review_sheet.png")

# scripts/ball_base_system/pinball.gd: DEFAULT_BALL_DIAMETER = 64.0
BALL_DIAMETER = 64

# settings/bumpers/ 실측. (파일명, 표시 지름, 충돌 지름, 라벨)
ITEMS = [
    ("button", 92, 88, "단추 / NORMAL"),
    ("cotton", 104, 96, "솜 / NORMAL"),
    ("spring_doll", 112, 104, "용수철 인형 / BOUNCE"),
    ("spring_doll_hit", 112, 104, "용수철 인형 타격"),
    ("toy_drum", 128, 120, "장난감 북 / BOUNCE"),
    ("clockwork_cannon", 128, 112, "태엽 대포 / SHOT"),
    # 미끄럼틀은 `.tres` 가 없어 확정 지름이 없다. 공(64px)이 통로에 담기려면
    # 최소 이 정도는 돼야 한다는 가정값이다. 제작 가이드 1절 참고.
    ("marble_slide", 240, 232, "구슬 미끄럼틀 (지름 가정)"),
]

CELL = 280
COLS = 4
PAD = 26
ZOOM = 3  # 확대 비교용 배수


def load_board(width: int, height: int) -> Image.Image:
    board = Image.open(BOARD).convert("RGBA")
    # 판자 결이 가장 고른 중앙부를 잘라 타일처럼 늘린다.
    crop = board.crop((320, 200, 1920, 1060))
    return crop.resize((width, height), Image.LANCZOS)


def paste_centered(canvas: Image.Image, sprite: Image.Image, cx: int, cy: int, diameter: int) -> None:
    scaled = sprite.resize((diameter, diameter), Image.LANCZOS)
    canvas.alpha_composite(scaled, (cx - diameter // 2, cy - diameter // 2))


def main() -> None:
    rows = (len(ITEMS) + COLS - 1) // COLS
    width = COLS * CELL + PAD * 2
    height = rows * CELL + PAD * 2 + CELL + PAD  # 아래에 확대 비교 한 줄

    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    sheet.alpha_composite(load_board(width, height))
    draw = ImageDraw.Draw(sheet)

    ball = Image.open(BALL).convert("RGBA")

    # ① 실제 게임 크기 + 공 대조
    for index, (name, visual, collision, label) in enumerate(ITEMS):
        col, row = index % COLS, index // COLS
        cx = PAD + col * CELL + CELL // 2
        cy = PAD + row * CELL + CELL // 2

        # 충돌 원을 얇게 표시해 외곽과 일치하는지 본다.
        r = collision / 2
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 80, 80, 150), width=1)

        sprite = Image.open(os.path.join(STEP1, f"{name}.png")).convert("RGBA")
        paste_centered(sheet, sprite, cx, cy, visual)

        # 같은 셀 우하단에 공을 놓아 시각 우선순위를 비교한다.
        paste_centered(sheet, ball, cx + CELL // 2 - 40, cy + CELL // 2 - 40, BALL_DIAMETER)

        draw.text((cx - CELL // 2 + 8, cy + CELL // 2 - 16), f"{label}  {visual}px", fill=(230, 224, 210, 255))

    # ② 확대 비교 한 줄 - 선 두께와 내부 묘사가 뭉개지는지 본다
    base_y = PAD + rows * CELL + PAD + CELL // 2
    zoom_items = ITEMS[:COLS]
    for index, (name, visual, _collision, _label) in enumerate(zoom_items):
        cx = PAD + index * CELL + CELL // 2
        sprite = Image.open(os.path.join(STEP1, f"{name}.png")).convert("RGBA")
        # 게임 크기로 한 번 줄였다가 다시 키운다. 실제로 보이는 해상도가 그대로 드러난다.
        small = sprite.resize((visual, visual), Image.LANCZOS)
        paste_centered(sheet, small, cx, base_y, visual * ZOOM // 2)

    draw.text((PAD, PAD + rows * CELL + PAD - 18), f"아래 = 게임 크기로 줄인 뒤 {ZOOM // 2}배 확대", fill=(230, 224, 210, 255))

    sheet.convert("RGB").save(OUT, quality=95)
    print(f"저장: {OUT}  ({sheet.size[0]}x{sheet.size[1]})")


if __name__ == "__main__":
    main()
