#!/usr/bin/env python3
"""범퍼 STEP1 마스터 v2 — v1 확정본에 레퍼런스 요소만 얹는다.

v1(`bumper_master.py`)의 형태와 명도 단차가 확정본이다. 2026-08-06 검수에서
"입체감은 v1이 낫다"로 결론이 났으므로 실루엣·색·구조는 건드리지 않는다.

이 파일이 하는 일은 하나다. **가이드 11쪽 레퍼런스 사진의 눌려 찍힌 별 문양**을
윗면에 추가한다. v1 에 없던 단추의 정체성 요소다.

v1 은 수정하지 않고 헬퍼만 가져다 쓴다(스크립트 확장 규칙).

출력:
  step1_v2/<이름>.png   1024x1024 RGBA, 알파 bbox == 캔버스

실행:
  python docs/bumper_guides/bumper_master_v2.py
"""

from __future__ import annotations

import math
import os
import random

import bumper_master as v1

OUT_DIR = os.path.join(os.path.dirname(__file__), "step1_v2")

# 눌려 찍힌 자국이라 면색만 쓰고 잉크 테두리는 두르지 않는다.
# 테두리를 넣으면 별이 구멍보다 강해져 시각 우선순위가 뒤집힌다.
# 바깥 링과 같은 BTN_FACE_LO 로는 92px 에서 안 읽혀 한 단 더 내렸다.
STAR_PRESSED = "#5A2634"

# 윗면 띠(눌린 접시 0.60 ~ 윗면 가장자리 0.845) 한가운데에 앉힌다.
STAR_RING = 0.723
STAR_SIZE = (0.090, 0.113)
# 균등 배치를 피한다. 가이드 2-2 "좌우 완벽 대칭 금지".
STAR_ANGLES = (-1.35, -0.16, 1.12, 2.35, 3.86)


def pressed_star(
    draw,
    cx: float,
    cy: float,
    size: float,
    rotate: float,
    seed: int,
) -> None:
    """살짝 비뚤어진 5각 별 음각."""
    rnd = random.Random(seed)
    pts = []
    for i in range(10):
        r = size if i % 2 == 0 else size * 0.41
        r *= rnd.uniform(0.88, 1.12)
        a = rotate + math.pi * i / 5 + rnd.uniform(-0.05, 0.05)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    # 꼭짓점 사이를 흔들어 손으로 찍은 자국처럼 만든다.
    wobbled = v1.wobble_path(pts + [pts[0]], seed=seed, amp=size * 0.05, resolution=90)
    draw.polygon(wobbled, fill=STAR_PRESSED)


def draw_button() -> "v1.Image.Image":
    """v1 단추 그대로 + 윗면에 눌려 찍힌 별 5개.

    v1 `draw_button()` 의 순서를 그대로 따르고, 눌린 접시면 다음에 별만 끼워
    넣는다. 목재 결이 별 위를 지나가야 표면에 파인 자국으로 읽힌다.
    """
    img, d = v1.new_layer()
    C, R = v1.C, v1.R

    outer = R * 0.985
    body = v1.wobble_circle(C, C, outer, seed=11, amp=0.014)
    v1.ink_polygon(d, body, v1.BTN_FACE_LO, v1.INK, width=R * 0.055)

    face = v1.wobble_circle(C, C - outer * 0.012, outer * 0.845, seed=12, amp=0.016)
    v1.ink_polygon(d, face, v1.BTN_FACE, v1.INK, width=R * 0.030)

    dish = v1.wobble_circle(C, C, outer * 0.60, seed=13, amp=0.020)
    v1.ink_polygon(d, dish, v1.BTN_FACE_HI, v1.INK_SOFT, width=R * 0.016)

    # ★ v1 대비 추가된 유일한 요소
    for i, ang in enumerate(STAR_ANGLES):
        rnd = random.Random(300 + i)
        rr = outer * STAR_RING * rnd.uniform(0.97, 1.03)
        pressed_star(
            d,
            C + math.cos(ang) * rr,
            C + math.sin(ang) * rr,
            outer * rnd.uniform(*STAR_SIZE),
            rotate=ang * 1.7,
            seed=310 + i,
        )

    for i, frac in enumerate((-0.42, -0.14, 0.16, 0.44)):
        y = C + outer * frac
        half = math.sqrt(max(0.0, (outer * 0.80) ** 2 - (outer * frac) ** 2))
        seg = v1.wobble_path(
            [(C - half * 0.86, y), (C + half * 0.86, y)], seed=40 + i, amp=R * 0.012
        )
        v1.ink_line(d, seg, v1.BTN_WOOD, width=R * 0.012)

    hole_r = outer * 0.115
    for i, (ox, oy) in enumerate(((-0.235, -0.235), (0.235, -0.235), (-0.235, 0.235), (0.235, 0.235))):
        hx, hy = C + outer * ox, C + outer * oy
        rim = v1.wobble_circle(hx, hy, hole_r, seed=60 + i, amp=0.05)
        v1.ink_polygon(d, rim, v1.SLATE_DARK, v1.INK, width=R * 0.020)
        v1.disc(d, hx, hy, hole_r * 0.55, "#0C1014")

    thread = v1.wobble_path(
        [(C - outer * 0.235, C - outer * 0.235), (C + outer * 0.235, C + outer * 0.235)],
        seed=71,
        amp=R * 0.010,
    )
    v1.ink_line(d, thread, v1.PURPLE, width=R * 0.026)
    thread2 = v1.wobble_path(
        [(C + outer * 0.235, C - outer * 0.235), (C - outer * 0.235, C + outer * 0.235)],
        seed=72,
        amp=R * 0.010,
    )
    v1.ink_line(d, thread2, v1.PURPLE, width=R * 0.026)

    frayed = v1.wobble_path(
        [(C + outer * 0.30, C + outer * 0.30), (C + outer * 0.52, C + outer * 0.46)],
        seed=73,
        amp=R * 0.014,
    )
    v1.ink_line(d, frayed, v1.PURPLE, width=R * 0.018)

    hi = v1.arc_points(C, C, outer * 0.915, math.radians(188), math.radians(256))
    v1.ink_line(
        d, v1.wobble_path(hi, seed=74, amp=R * 0.004, resolution=60), v1.IVORY_DIM, width=R * 0.034
    )

    return v1.finalize(img, "button")


BUILDERS = {
    "button": draw_button,
}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    print("STEP1 v2 (v1 + 별 문양)")
    for name, builder in BUILDERS.items():
        path = os.path.join(OUT_DIR, f"{name}.png")
        builder().save(path)
        print(f"  저장: {path}")


if __name__ == "__main__":
    main()
