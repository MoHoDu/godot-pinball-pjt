#!/usr/bin/env python3
"""범퍼 STEP1 형태 마스터 생성기.

3단계 파이프라인(형태 -> 텍스처 -> 디테일)의 ① 형태 단계를 담당한다.
실루엣과 내부 구조는 여기서 좌표로 확정하고, Leonardo 에는 ② 텍스처만 맡긴다.

출력:
  step1/<이름>.png          1024x1024 RGBA, 알파 bbox == 캔버스
  step2_plates/<이름>.png   1024x1024 RGBA, 사방 여백을 둔 Leonardo 입력용 여백판

실행:
  python3 docs/bumper_guides/bumper_master.py
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

CANVAS = 1024
SS = 3  # 슈퍼샘플링 배수
SIZE = CANVAS * SS

OUT_STEP1 = os.path.join(os.path.dirname(__file__), "step1")
OUT_PLATE = os.path.join(os.path.dirname(__file__), "step2_plates")

# 여백판 채움률. 보드 STEP2 에서 검증된 값(공 가이드 74%)과 같은 의도.
PLATE_FILL = 0.74


# --------------------------------------------------------------------------
# 팔레트
# --------------------------------------------------------------------------
# 확정 플리퍼 Flipper_cartoon.png / glass_eye_ball.png 에서 가져온 공통색과,
# 범퍼 가이드 v0.2 "2-4 보드판과 어울리는 범퍼 팔레트 기준" 의 저채도 팔레트.

INK = "#12161C"  # 먹빛 청흑색. 가이드가 순검정보다 이쪽을 권장한다.
INK_SOFT = "#1E252E"  # 내부선용. 외곽선보다 얇고 옅다.
IVORY = "#F0E0C3"
IVORY_DIM = "#D6C4A2"
IVORY_DEEP = "#B8A588"
TEAL = "#4FA692"
TEAL_DARK = "#2F7A69"
TEAL_LIGHT = "#7FC9B4"
PURPLE = "#6B4A86"  # 세계관 연결색 - 보라 실밥
GOLD = "#D9AE52"
BRASS = "#A9822F"
BRASS_DARK = "#6E5320"
SLATE = "#3C4757"  # 회청색
SLATE_DARK = "#28313D"

# 단추
BTN_FACE = "#94485A"
BTN_FACE_HI = "#A85668"
BTN_FACE_LO = "#6E3040"
BTN_WOOD = "#7A4A3A"

# 솜
# ★ 명도 주의: 어두운 남청색 보드 위에서 근백색 대면적은 공보다 먼저 눈에 띈다.
#   인게임 크기 대조에서 확인하고 톤을 낮췄다. 가이드의 "톤다운 크림/베이지" 를 지킨다.
COT_BODY = "#C4B79B"
COT_BODY_HI = "#D6CAAE"
COT_SHADE = "#9A8E76"
COT_DUSK = "#857A8C"  # 먼지 낀 회보라
COT_SEAM = "#6E5B44"

# 용수철 인형
DOLL_FACE = "#D8C6A6"
DOLL_FACE_SHADE = "#B4A386"
DOLL_MUSTARD = "#C2A044"
DOLL_BASE = "#7A4034"

# 장난감 북
DRUM_HEAD = "#C9B994"
DRUM_HEAD_SHADE = "#A89876"
DRUM_RIM = "#7E3140"
DRUM_RIM_LO = "#5C2130"
DRUM_HORSE = "#8A4436"

# 구슬 미끄럼틀
SLIDE_RAIL = "#6B5478"
SLIDE_RAIL_LO = "#4A3856"
SLIDE_FLOOR = "#C6B79A"  # 통로 바닥. 접시보다 밝아야 경로가 먼저 읽힌다.
SLIDE_DISH = "#8B7F6C"  # 접시 내부. 통로와 명도를 벌린다.
SLIDE_SHADOW = "#232C38"

# 태엽 장난감 대포
CAN_BASE = "#7A4034"
CAN_BASE_HI = "#8E4E40"
CAN_BARREL = "#2F7A69"
CAN_BARREL_HI = "#3F9280"


# --------------------------------------------------------------------------
# 손그림 선 유틸
# --------------------------------------------------------------------------


def _noise_series(rng: random.Random, count: int, octaves: int = 3) -> list[float]:
    """0 을 중심으로 순환하는 저주파 노이즈. 손그림 흔들림에 쓴다."""
    out = [0.0] * count
    for octave in range(octaves):
        freq = 2 ** (octave + 1)
        amp = 1.0 / (octave + 1.6)
        phase = rng.uniform(0.0, math.tau)
        for i in range(count):
            out[i] += amp * math.sin(phase + math.tau * freq * i / count)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out]


def wobble_circle(
    cx: float,
    cy: float,
    radius: float,
    seed: int,
    amp: float = 0.012,
    count: int = 240,
    squash: float = 1.0,
    rotate: float = 0.0,
) -> list[tuple[float, float]]:
    """약간 비뚤어진 원. 완전한 정원을 금지하는 가이드 규칙을 만족시킨다."""
    rng = random.Random(seed)
    noise = _noise_series(rng, count)
    points: list[tuple[float, float]] = []
    for i in range(count):
        angle = math.tau * i / count + rotate
        r = radius * (1.0 + amp * noise[i])
        points.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r * squash))
    return points


def wobble_path(
    points: list[tuple[float, float]],
    seed: int,
    amp: float,
    resolution: int = 160,
) -> list[tuple[float, float]]:
    """열린 경로를 부드럽게 보간하고 손그림 흔들림을 준다."""
    if len(points) < 2:
        return points
    rng = random.Random(seed)
    noise = _noise_series(rng, resolution)
    dense = _resample(points, resolution)
    out: list[tuple[float, float]] = []
    for i, (x, y) in enumerate(dense):
        nx, ny = _normal_at(dense, i)
        # 양 끝은 흔들지 않아 접합부가 어긋나지 않게 한다.
        taper = math.sin(math.pi * i / max(1, resolution - 1))
        offset = noise[i] * amp * taper
        out.append((x + nx * offset, y + ny * offset))
    return out


def _resample(points: list[tuple[float, float]], count: int) -> list[tuple[float, float]]:
    lengths = [0.0]
    for i in range(1, len(points)):
        dx = points[i][0] - points[i - 1][0]
        dy = points[i][1] - points[i - 1][1]
        lengths.append(lengths[-1] + math.hypot(dx, dy))
    total = lengths[-1] or 1.0
    out = []
    for i in range(count):
        target = total * i / (count - 1)
        j = 1
        while j < len(lengths) - 1 and lengths[j] < target:
            j += 1
        span = lengths[j] - lengths[j - 1] or 1.0
        t = (target - lengths[j - 1]) / span
        x = points[j - 1][0] + (points[j][0] - points[j - 1][0]) * t
        y = points[j - 1][1] + (points[j][1] - points[j - 1][1]) * t
        out.append((x, y))
    return out


def _normal_at(points: list[tuple[float, float]], i: int) -> tuple[float, float]:
    a = points[max(0, i - 1)]
    b = points[min(len(points) - 1, i + 1)]
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1.0
    return -dy / length, dx / length


def arc_points(
    cx: float,
    cy: float,
    radius: float,
    start: float,
    end: float,
    count: int = 80,
    squash: float = 1.0,
) -> list[tuple[float, float]]:
    return [
        (
            cx + math.cos(start + (end - start) * i / (count - 1)) * radius,
            cy + math.sin(start + (end - start) * i / (count - 1)) * radius * squash,
        )
        for i in range(count)
    ]


def star_points(
    cx: float, cy: float, outer: float, inner: float, tips: int = 5, rotate: float = -math.pi / 2
) -> list[tuple[float, float]]:
    pts = []
    for i in range(tips * 2):
        r = outer if i % 2 == 0 else inner
        a = rotate + math.pi * i / tips
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


# --------------------------------------------------------------------------
# 드로잉 헬퍼
# --------------------------------------------------------------------------


def ink_polygon(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: str | None,
    outline: str | None = INK,
    width: float = 14.0,
) -> None:
    if fill is not None:
        draw.polygon(points, fill=fill)
    if outline is not None and width > 0:
        draw.line(list(points) + [points[0]], fill=outline, width=int(width), joint="curve")
        # 선 끝을 둥글게 마감해 굵은 선의 각진 이음매를 없앤다.
        for x, y in points[:: max(1, len(points) // 48)]:
            r = width / 2.0
            draw.ellipse([x - r, y - r, x + r, y + r], fill=outline)


def ink_line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    color: str = INK_SOFT,
    width: float = 8.0,
    round_caps: bool = True,
) -> None:
    if len(points) < 2:
        return
    draw.line(points, fill=color, width=int(width), joint="curve")
    if round_caps:
        r = width / 2.0
        for x, y in (points[0], points[-1]):
            draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def disc(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str) -> None:
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def new_layer() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# --------------------------------------------------------------------------
# 마무리 - 알파 bbox 를 캔버스에 맞춘다
# --------------------------------------------------------------------------


def finalize(img: Image.Image, name: str) -> Image.Image:
    """알파 bbox == 캔버스 규칙을 강제한다.

    `refresh_ball_size()` 계열 로직은 텍스처의 긴 변으로 표시 크기를 나눈다.
    캔버스 여백은 그대로 표시 크기 손실이 되므로 여기서 제거한다.
    """
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError(f"{name}: 빈 이미지")
    cropped = img.crop(bbox)
    w, h = cropped.size
    side = max(w, h)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - w) // 2, (side - h) // 2))
    out = square.resize((CANVAS, CANVAS), Image.LANCZOS)

    final_box = out.getbbox()
    fill_w = (final_box[2] - final_box[0]) / CANVAS
    fill_h = (final_box[3] - final_box[1]) / CANVAS
    print(f"  {name:<24} 채움률 가로 {fill_w:6.2%} 세로 {fill_h:6.2%}")
    return out


def make_plate(master: Image.Image) -> Image.Image:
    """Leonardo 입력용 여백판.

    생성물이 프레임에 닿으면 마스킹으로 rim 을 제거할 수 없다.
    여백 안에서 끝나면 모델이 무엇을 붙이든 깨끗하게 잘린다.
    """
    inner = int(CANVAS * PLATE_FILL)
    plate = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    scaled = master.resize((inner, inner), Image.LANCZOS)
    offset = (CANVAS - inner) // 2
    plate.paste(scaled, (offset, offset), scaled)
    return plate


# --------------------------------------------------------------------------
# 범퍼별 형태
# --------------------------------------------------------------------------

C = SIZE / 2.0  # 중심
R = SIZE / 2.0  # 외곽 반지름 기준


def draw_button() -> Image.Image:
    """단추 - 두껍고 둥근 목재 단추, 구멍 4개, 약간 찌그러진 원.

    표현 기준: 옆면 노출 금지, 재질선은 윗면 안쪽에만, 충돌 원과 외곽 일치.
    """
    img, d = new_layer()
    outer = R * 0.985
    body = wobble_circle(C, C, outer, seed=11, amp=0.014)
    ink_polygon(d, body, BTN_FACE_LO, INK, width=R * 0.055)

    # 윗면. 바깥 테두리와 명도 차이로 두께를 표현한다.
    face = wobble_circle(C, C - outer * 0.012, outer * 0.845, seed=12, amp=0.016)
    ink_polygon(d, face, BTN_FACE, INK, width=R * 0.030)

    # 안쪽 눌린 접시면
    dish = wobble_circle(C, C, outer * 0.60, seed=13, amp=0.020)
    ink_polygon(d, dish, BTN_FACE_HI, INK_SOFT, width=R * 0.016)

    # 목재 결. 윗면 안쪽에만 배치한다.
    for i, frac in enumerate((-0.42, -0.14, 0.16, 0.44)):
        y = C + outer * frac
        half = math.sqrt(max(0.0, (outer * 0.80) ** 2 - (outer * frac) ** 2))
        seg = wobble_path(
            [(C - half * 0.86, y), (C + half * 0.86, y)], seed=40 + i, amp=R * 0.012
        )
        ink_line(d, seg, BTN_WOOD, width=R * 0.012)

    # 구멍 4개. 탑뷰에서 명확히 구분되어야 한다.
    hole_r = outer * 0.115
    for i, (ox, oy) in enumerate(((-0.235, -0.235), (0.235, -0.235), (-0.235, 0.235), (0.235, 0.235))):
        hx, hy = C + outer * ox, C + outer * oy
        rim = wobble_circle(hx, hy, hole_r, seed=60 + i, amp=0.05)
        ink_polygon(d, rim, SLATE_DARK, INK, width=R * 0.020)
        disc(d, hx, hy, hole_r * 0.55, "#0C1014")

    # 세계관 연결색 - 구멍을 잇는 보라 실밥
    thread = wobble_path(
        [
            (C - outer * 0.235, C - outer * 0.235),
            (C + outer * 0.235, C + outer * 0.235),
        ],
        seed=71,
        amp=R * 0.010,
    )
    ink_line(d, thread, PURPLE, width=R * 0.026)
    thread2 = wobble_path(
        [
            (C + outer * 0.235, C - outer * 0.235),
            (C - outer * 0.235, C + outer * 0.235),
        ],
        seed=72,
        amp=R * 0.010,
    )
    ink_line(d, thread2, PURPLE, width=R * 0.026)

    # 끊어진 실밥 한 가닥 - 내구도 감소 연출의 기준 위치
    frayed = wobble_path(
        [(C + outer * 0.30, C + outer * 0.30), (C + outer * 0.52, C + outer * 0.46)],
        seed=73,
        amp=R * 0.014,
    )
    ink_line(d, frayed, PURPLE, width=R * 0.018)

    # 테두리 아이보리 소량. 바깥 링 띠를 따라 짧게 얹는다.
    hi = arc_points(C, C, outer * 0.915, math.radians(188), math.radians(256))
    ink_line(d, wobble_path(hi, seed=74, amp=R * 0.004, resolution=60), IVORY_DIM, width=R * 0.034)

    return finalize(img, "button")


def draw_cotton() -> Image.Image:
    """솜 - 위에서 본 비대칭 구름형 실루엣.

    표현 기준: 높은 솜뭉치가 아니라 보드에 붙은 부드러운 원형 완충재.
    중심 타격 위치가 장식에 가리지 않아야 한다.
    """
    img, d = new_layer()

    # 겹친 솜 덩어리로 구름형 외곽을 만든다. 좌우 대칭 금지.
    # 덩어리 반지름은 아래에서 한 번은 잉크선용으로 키워서, 한 번은 원래 크기로 그린다.
    # 모폴로지 연산 없이 실루엣 전체를 감싸는 하나의 연속된 굵은 외곽선이 나온다.
    tufts = [
        (-0.30, 0.02, 0.60),
        (-0.14, -0.30, 0.48),
        (0.16, -0.32, 0.52),
        (0.34, -0.02, 0.50),
        (0.20, 0.30, 0.46),
        (-0.20, 0.30, 0.44),
        (0.02, 0.04, 0.66),
    ]
    ink_width = R * 0.052

    def tuft_points(index: int, grow: float) -> list[tuple[float, float]]:
        ox, oy, rr = tufts[index]
        base_r = R * rr * 0.94
        return wobble_circle(
            C + R * ox * 0.98,
            C + R * oy * 0.98,
            base_r + grow,
            seed=100 + index,
            amp=0.06 * base_r / (base_r + grow),
        )

    # ① 잉크 실루엣 - 원래 크기보다 선 굵기만큼 키운 합집합
    for i in range(len(tufts)):
        d.polygon(tuft_points(i, ink_width), fill=INK)
    # ② 색면 - 원래 크기 합집합. 내부 덩어리 경계선은 남기지 않는다.
    for i in range(len(tufts)):
        d.polygon(tuft_points(i, 0.0), fill=COT_BODY)

    # 내부 - 솜이 뭉친 방향을 보여주는 큰 곡선만 사용한다. 잔선을 늘리지 않는다.
    core = wobble_circle(C - R * 0.05, C - R * 0.02, R * 0.50, seed=120, amp=0.06)
    d.polygon(core, fill=COT_BODY_HI)

    # 먼지 낀 회보라 그늘. 외곽 덩어리 하나에만 얹어 떠 보이지 않게 한다.
    dusk = wobble_circle(C - R * 0.46, C + R * 0.26, R * 0.26, seed=124, amp=0.08)
    d.polygon(dusk, fill=COT_DUSK)

    # 솜이 말린 방향을 보여주는 굵은 곡선. 서로 교차시키면 긁힌 자국으로 읽히므로
    # 같은 중심의 겹겹 곡선으로 배치해 뭉친 결로 읽히게 한다.
    swirl_cx, swirl_cy = C + R * 0.08, C + R * 0.04
    swirl = [
        (R * 0.46, 154, 348, 121),
        (R * 0.32, 176, 330, 122),
        (R * 0.18, 198, 312, 123),
    ]
    for radius, a0, a1, seed in swirl:
        pts = arc_points(swirl_cx, swirl_cy, radius, math.radians(a0), math.radians(a1))
        ink_line(
            d,
            wobble_path(pts, seed=seed, amp=R * 0.008, resolution=44),
            COT_SHADE,
            width=R * 0.040,
        )

    # 작은 천 조각. 외곽 일부에만 제한적으로 배치한다.
    patch = wobble_path(
        [
            (C + R * 0.30, C + R * 0.28),
            (C + R * 0.58, C + R * 0.22),
            (C + R * 0.62, C + R * 0.50),
            (C + R * 0.34, C + R * 0.56),
        ],
        seed=125,
        amp=R * 0.012,
    )
    ink_polygon(d, patch, TEAL_DARK, INK, width=R * 0.026)
    for i in range(4):
        t = 0.18 + i * 0.22
        sx = C + R * (0.32 + t * 0.26)
        ink_line(
            d,
            [(sx, C + R * 0.30), (sx + R * 0.03, C + R * 0.50)],
            COT_SEAM,
            width=R * 0.012,
        )

    # 봉제선은 삐뚤게
    seam = wobble_path(
        [(C - R * 0.52, C - R * 0.16), (C - R * 0.06, C - R * 0.40), (C + R * 0.34, C - R * 0.34)],
        seed=126,
        amp=R * 0.016,
        resolution=40,
    )
    ink_line(d, seam, COT_SEAM, width=R * 0.020)
    # 삐뚤삐뚤한 땀
    for i in range(0, len(seam) - 2, 5):
        px, py = seam[i]
        nx, ny = _normal_at(seam, i)
        ink_line(
            d,
            [(px - nx * R * 0.026, py - ny * R * 0.026), (px + nx * R * 0.026, py + ny * R * 0.026)],
            COT_SEAM,
            width=R * 0.011,
        )

    # 보라 실매듭 1개
    knot_x, knot_y = C + R * 0.36, C - R * 0.36
    disc(d, knot_x, knot_y, R * 0.036, PURPLE)
    ink_line(
        d,
        wobble_path([(knot_x - R * 0.10, knot_y - R * 0.06), (knot_x + R * 0.11, knot_y + R * 0.05)], seed=127, amp=R * 0.008),
        PURPLE,
        width=R * 0.016,
    )

    return finalize(img, "cotton")


def draw_spring_doll() -> Image.Image:
    """용수철 인형 기본 상태 - 둥근 인형 얼굴이 범퍼 대부분을 차지한다.

    용수철은 기본 상태에서 보이지 않고 가장자리 일부만 노출한다.
    얼굴 중심 = 실제 충돌 위치.
    """
    img, d = new_layer()
    outer = R * 0.985

    # 받침대 테두리를 얇게 노출
    base = wobble_circle(C, C, outer, seed=200, amp=0.012)
    ink_polygon(d, base, SLATE, INK, width=R * 0.050)
    base_in = wobble_circle(C, C, outer * 0.93, seed=201, amp=0.014)
    ink_polygon(d, base_in, SLATE_DARK, None)

    # 가장자리에 살짝 보이는 스프링 감김.
    # 기본 상태에서 용수철은 직접 보이지 않거나 일부만 보인다는 규칙을 지킨다.
    for i in range(4):
        a0 = math.radians(28 + i * 90)
        seg = arc_points(C, C, outer * 0.905, a0, a0 + math.radians(34))
        ink_line(d, seg, GOLD, width=R * 0.040)
        seg_lo = arc_points(C, C, outer * 0.905, a0 + math.radians(36), a0 + math.radians(52))
        ink_line(d, seg_lo, BRASS_DARK, width=R * 0.032)

    # 둥근 인형 얼굴
    face = wobble_circle(C, C - outer * 0.015, outer * 0.855, seed=202, amp=0.016)
    ink_polygon(d, face, DOLL_FACE, INK, width=R * 0.046)

    # 얼굴 아래쪽 그늘로 두께 암시
    shade = arc_points(C, C - outer * 0.015, outer * 0.80, math.radians(24), math.radians(156))
    ink_line(d, wobble_path(shade, seed=203, amp=R * 0.010), DOLL_FACE_SHADE, width=R * 0.052)

    # 겨자색 모자챙 - 방향성 없이 상단에만
    brim = arc_points(C, C - outer * 0.015, outer * 0.735, math.radians(198), math.radians(342))
    ink_line(d, wobble_path(brim, seed=204, amp=R * 0.012), DOLL_MUSTARD, width=R * 0.090)

    # 눈 2개. 단순한 실루엣 위주.
    for i, ox in enumerate((-0.27, 0.27)):
        ex, ey = C + outer * ox, C - outer * 0.10
        eye = wobble_circle(ex, ey, outer * 0.125, seed=210 + i, amp=0.06)
        ink_polygon(d, eye, IVORY, INK, width=R * 0.024)
        disc(d, ex + outer * 0.02 * (1 if i else -1), ey + outer * 0.015, outer * 0.058, INK)

    # 입 - 살짝 비뚤게
    mouth = wobble_path(
        [
            (C - outer * 0.20, C + outer * 0.24),
            (C - outer * 0.02, C + outer * 0.34),
            (C + outer * 0.21, C + outer * 0.21),
        ],
        seed=212,
        amp=R * 0.014,
    )
    ink_line(d, mouth, INK, width=R * 0.028)

    # 뺨 - 탁한 청록 보조색
    for ox in (-0.44, 0.44):
        disc(d, C + outer * ox, C + outer * 0.14, outer * 0.085, TEAL)

    # 이마 봉제선 + 보라 실밥
    stitch = wobble_path(
        [(C - outer * 0.30, C - outer * 0.46), (C + outer * 0.28, C - outer * 0.50)],
        seed=213,
        amp=R * 0.014,
    )
    ink_line(d, stitch, PURPLE, width=R * 0.020)

    return finalize(img, "spring_doll")


def draw_spring_doll_hit() -> Image.Image:
    """용수철 인형 타격 상태 - 얼굴이 눌리고 내부 용수철이 드러난다.

    기본 상태와 형태 차이로 Bounce 기능을 전달하는 것이 핵심이다.
    """
    img, d = new_layer()
    outer = R * 0.985

    base = wobble_circle(C, C, outer, seed=200, amp=0.012)
    ink_polygon(d, base, SLATE, INK, width=R * 0.050)
    base_in = wobble_circle(C, C, outer * 0.93, seed=201, amp=0.014)
    ink_polygon(d, base_in, SLATE_DARK, None)

    # 드러난 용수철. 압축된 상태의 굵은 감김선.
    coil_top = C - outer * 0.30
    coil_bottom = C + outer * 0.46
    turns = 4
    for i in range(turns):
        t = i / (turns - 1)
        y = coil_top + (coil_bottom - coil_top) * t
        w = outer * (0.44 + 0.16 * t)
        pts = arc_points(C, y, w, math.radians(8), math.radians(172), squash=0.42)
        ink_line(d, wobble_path(pts, seed=300 + i, amp=R * 0.010), GOLD, width=R * 0.052)
        back = arc_points(C, y - outer * 0.05, w * 0.94, math.radians(190), math.radians(350), squash=0.38)
        ink_line(d, wobble_path(back, seed=320 + i, amp=R * 0.008), BRASS_DARK, width=R * 0.034)

    # 눌린 얼굴 - 위로 짧게 압축된 타원
    face = wobble_circle(
        C, C - outer * 0.40, outer * 0.72, seed=202, amp=0.018, squash=0.52
    )
    ink_polygon(d, face, DOLL_FACE, INK, width=R * 0.046)

    brim = arc_points(C, C - outer * 0.40, outer * 0.60, math.radians(196), math.radians(344))
    ink_line(
        d,
        wobble_path([(x, C - outer * 0.40 + (y - (C - outer * 0.40)) * 0.52) for x, y in brim], seed=204, amp=R * 0.010),
        DOLL_MUSTARD,
        width=R * 0.076,
    )

    # 눌린 표정 - 눈은 감기고 입은 벌어진다
    for i, ox in enumerate((-0.26, 0.26)):
        ex, ey = C + outer * ox, C - outer * 0.44
        ink_line(
            d,
            wobble_path([(ex - outer * 0.10, ey), (ex + outer * 0.10, ey)], seed=330 + i, amp=R * 0.008),
            INK,
            width=R * 0.026,
        )
    mouth = wobble_circle(C, C - outer * 0.26, outer * 0.11, seed=331, amp=0.08, squash=0.75)
    ink_polygon(d, mouth, INK, None)

    for ox in (-0.42, 0.42):
        disc(d, C + outer * ox, C - outer * 0.34, outer * 0.075, TEAL)

    return finalize(img, "spring_doll_hit")


def draw_toy_drum() -> Image.Image:
    """장난감 북 - 넓은 원형 북막 + 두꺼운 외곽 링(북틀).

    표현 기준: 옆면은 외곽 링 안쪽 그림자와 테두리 두께로만 암시한다.
    북막 안은 회전목마의 말.
    """
    img, d = new_layer()
    outer = R * 0.985

    # 외곽 북틀
    frame = wobble_circle(C, C, outer, seed=400, amp=0.010)
    ink_polygon(d, frame, DRUM_RIM, INK, width=R * 0.052)

    # 금색 테두리 링
    gold_ring = wobble_circle(C, C, outer * 0.895, seed=401, amp=0.012)
    ink_polygon(d, gold_ring, GOLD, None)
    gold_in = wobble_circle(C, C, outer * 0.845, seed=402, amp=0.012)
    ink_polygon(d, gold_in, DRUM_RIM_LO, None)

    # 북틀 별 장식
    for i in range(8):
        a = math.tau * i / 8 + math.radians(11)
        sx, sy = C + math.cos(a) * outer * 0.915, C + math.sin(a) * outer * 0.915
        ink_polygon(
            d,
            star_points(sx, sy, outer * 0.062, outer * 0.026, rotate=a),
            GOLD,
            INK,
            width=R * 0.014,
        )

    # 북막. 범퍼의 주요 면적.
    head = wobble_circle(C, C, outer * 0.775, seed=403, amp=0.014)
    ink_polygon(d, head, DRUM_HEAD, INK, width=R * 0.040)

    # 안쪽 그림자로 깊이만 암시
    inner_shadow = arc_points(C, C, outer * 0.735, math.radians(18), math.radians(162))
    ink_line(d, wobble_path(inner_shadow, seed=404, amp=R * 0.008), DRUM_HEAD_SHADE, width=R * 0.048)

    # 북막의 장력선. 약간 찌그러지게.
    for i in range(6):
        a = math.tau * i / 6 + math.radians(14)
        p0 = (C + math.cos(a) * outer * 0.30, C + math.sin(a) * outer * 0.30)
        p1 = (C + math.cos(a) * outer * 0.735, C + math.sin(a) * outer * 0.735)
        ink_line(d, wobble_path([p0, p1], seed=410 + i, amp=R * 0.012), DRUM_HEAD_SHADE, width=R * 0.012)

    # 회전목마의 말 - 큰 색면 실루엣으로만. 잔선을 넣지 않는다.
    # 주둥이에서 시계 방향으로 한 바퀴. 머리 왼쪽, 꼬리 오른쪽.
    horse = [
        (-0.46, -0.14),  # 주둥이
        (-0.42, -0.28),  # 이마
        (-0.30, -0.34),  # 귀
        (-0.24, -0.24),  # 목덜미
        (-0.10, -0.22),  # 기갑
        (0.10, -0.22),  # 등
        (0.26, -0.16),  # 엉덩이
        (0.40, -0.30),  # 꼬리 끝
        (0.36, -0.06),  # 꼬리 아래
        (0.30, 0.06),
        (0.26, 0.26),  # 뒷다리 뒤
        (0.16, 0.26),  # 뒷다리 앞
        (0.12, 0.04),
        (-0.14, 0.04),  # 배
        (-0.16, 0.26),  # 앞다리 뒤
        (-0.26, 0.26),  # 앞다리 앞
        (-0.28, 0.00),  # 가슴
        (-0.38, -0.02),  # 턱밑
    ]
    horse_pts = [(C + outer * x, C + outer * y) for x, y in horse]
    ink_polygon(
        d,
        wobble_path(horse_pts + [horse_pts[0]], seed=420, amp=R * 0.004, resolution=120),
        DRUM_HORSE,
        INK,
        width=R * 0.020,
    )

    # 갈기 - 아이보리 포인트
    mane = wobble_path(
        [
            (C - outer * 0.34, C - outer * 0.30),
            (C - outer * 0.22, C - outer * 0.26),
            (C - outer * 0.08, C - outer * 0.24),
        ],
        seed=422,
        amp=R * 0.006,
        resolution=40,
    )
    ink_line(d, mane, IVORY_DIM, width=R * 0.020)

    # 흔들 목마 받침 - 발굽 바로 아래에 붙는 활 모양. 떨어져 있으면 웃는 입으로 읽힌다.
    rocker = arc_points(C, C + outer * 0.02, outer * 0.30, math.radians(34), math.radians(146))
    ink_line(
        d,
        wobble_path(rocker, seed=421, amp=R * 0.005, resolution=48),
        DRUM_HORSE,
        width=R * 0.046,
    )

    return finalize(img, "toy_drum")


def draw_marble_slide() -> Image.Image:
    """구슬 미끄럼틀 - 원형 접시 + U자 통로 + 낮은 출구.

    표현 기준: 지지대와 높은 측면 구조는 생략한다.
    진입부에서 출구까지 경로가 한눈에 읽혀야 한다. 화살표 장식 금지.
    """
    img, d = new_layer()
    outer = R * 0.985

    # 보드에서 살짝 떠 있는 높이를 암시하는 아래쪽 얇은 그림자
    shadow = wobble_circle(C, C + outer * 0.055, outer * 0.955, seed=500, amp=0.012)
    ink_polygon(d, shadow, SLIDE_SHADOW, None)

    # 원형 접시 바깥 레일
    dish = wobble_circle(C, C, outer * 0.96, seed=501, amp=0.014)
    ink_polygon(d, dish, SLIDE_RAIL, INK, width=R * 0.050)

    # 접시 내부. 통로 바닥보다 어둡게 잡아 통로가 경로로 먼저 읽히게 한다.
    floor = wobble_circle(C, C, outer * 0.80, seed=502, amp=0.016)
    ink_polygon(d, floor, SLIDE_DISH, INK_SOFT, width=R * 0.022)

    # 동심원. 완전 정원 금지.
    for i, rr in enumerate((0.60, 0.42)):
        ring = wobble_circle(C, C, outer * rr, seed=510 + i, amp=0.030)
        ink_line(d, list(ring) + [ring[0]], SLIDE_FLOOR, width=R * 0.014)

    # U자 통로. 진입부(좌상) -> 접시 바닥을 감는 U -> 출구(우상).
    # 흔들림을 크게 주면 굵은 스트로크가 자기 자신과 교차해 삐죽삐죽해진다.
    # 진폭을 낮추고 보간 밀도를 줄여 매끈한 홈으로 만든다.
    entry_pt = (C - outer * 0.42, C - outer * 0.50)
    exit_pt = (C + outer * 0.42, C - outer * 0.50)
    channel = [
        entry_pt,
        (C - outer * 0.58, C - outer * 0.06),
        (C - outer * 0.40, C + outer * 0.40),
        (C, C + outer * 0.56),
        (C + outer * 0.40, C + outer * 0.40),
        (C + outer * 0.58, C - outer * 0.06),
        exit_pt,
    ]
    path = wobble_path(channel, seed=520, amp=R * 0.006, resolution=64)
    # 통로 양쪽 경계는 굵은 외곽선으로, 안쪽 바닥면은 접시보다 밝은 재질색으로 구분한다.
    # ★ 통로 바닥 폭은 공(지름 64px)이 실제로 담기는 폭이어야 한다.
    #   바닥 0.30 x 표시 지름 = 공 지름 이상이 되도록 잡는다. 제작 가이드 1절 참고.
    ink_line(d, path, INK, width=R * 0.460)
    ink_line(d, path, SLIDE_RAIL_LO, width=R * 0.395)
    ink_line(d, path, SLIDE_FLOOR, width=R * 0.300)

    # 진입부 - 공이 들어오는 열린 입구
    entry = wobble_circle(entry_pt[0], entry_pt[1], outer * 0.215, seed=521, amp=0.05)
    ink_polygon(d, entry, SLIDE_FLOOR, INK, width=R * 0.042)

    # 출구 - 마지막 곡선 방향과 실루엣으로만 방향을 읽게 한다. 화살표 장식 금지.
    exit_lip = arc_points(exit_pt[0], exit_pt[1], outer * 0.205, math.radians(104), math.radians(330))
    ink_line(d, wobble_path(exit_lip, seed=522, amp=R * 0.004, resolution=40), GOLD, width=R * 0.052)

    # 금색 연결부
    for t in (0.30, 0.70):
        px, py = path[int((len(path) - 1) * t)]
        disc(d, px, py, outer * 0.052, GOLD)
        d.ellipse(
            [px - outer * 0.052, py - outer * 0.052, px + outer * 0.052, py + outer * 0.052],
            outline=INK,
            width=int(R * 0.016),
        )

    # 청록 구조 클립 - 접시 테두리와 통로를 잡아 주는 부품으로 읽히게 좌우 대칭 배치
    for i, a_deg in enumerate((150, 210)):
        a = math.radians(a_deg)
        clip = [
            (C + math.cos(a) * outer * 0.80, C + math.sin(a) * outer * 0.80),
            (C + math.cos(a) * outer * 0.93, C + math.sin(a) * outer * 0.93),
        ]
        ink_line(d, clip, TEAL_DARK, width=R * 0.046)

    return finalize(img, "marble_slide")


def draw_clockwork_cannon() -> Image.Image:
    """태엽 장난감 대포 - 원형 회전 받침대 + 짧고 굵은 포신 + 큰 태엽.

    표현 기준: 받침대가 충돌 실루엣. 포신은 중심에서 바깥으로 짧고 굵게.
    포구 내부는 어둡게. 받침대 동심원과 방향축은 실제 회전 중심과 일치.
    포신은 +X(0도) 를 기준 방향으로 그린다. 런타임 회전은 Godot 에서 준다.
    """
    img, d = new_layer()
    outer = R * 0.985

    # 원형 회전 받침대 = 기본 충돌 실루엣
    base = wobble_circle(C, C, outer, seed=600, amp=0.012)
    ink_polygon(d, base, CAN_BASE, INK, width=R * 0.052)
    base_in = wobble_circle(C, C, outer * 0.905, seed=601, amp=0.014)
    ink_polygon(d, base_in, CAN_BASE_HI, INK_SOFT, width=R * 0.018)

    # 동심원과 방향축. 회전 중심과 일치시킨다.
    for i, rr in enumerate((0.80, 0.62)):
        ring = wobble_circle(C, C, outer * rr, seed=610 + i, amp=0.022)
        ink_line(d, list(ring) + [ring[0]], BRASS, width=R * 0.016)

    # 바퀴 - 이동 기능이 아니라 장난감 대포의 정체성 전달용 외곽 장식
    for i, a_deg in enumerate((118, 242)):
        a = math.radians(a_deg)
        wx, wy = C + math.cos(a) * outer * 0.70, C + math.sin(a) * outer * 0.70
        wheel = wobble_circle(wx, wy, outer * 0.235, seed=620 + i, amp=0.030)
        ink_polygon(d, wheel, BRASS_DARK, INK, width=R * 0.034)
        disc(d, wx, wy, outer * 0.175, GOLD)
        for k in range(6):
            sa = math.tau * k / 6 + math.radians(9)
            ink_line(
                d,
                [(wx, wy), (wx + math.cos(sa) * outer * 0.165, wy + math.sin(sa) * outer * 0.165)],
                BRASS_DARK,
                width=R * 0.018,
            )
        disc(d, wx, wy, outer * 0.052, BRASS)

    # 큰 태엽 - 포신 후방에 노출. 감개 날개는 원판 바깥으로 확실히 빼서 겹침을 없앤다.
    kx, ky = C - outer * 0.54, C
    key_r = outer * 0.125
    for k in range(2):
        a = math.radians(90 + k * 180)
        ex, ey = kx + math.cos(a) * key_r * 1.95, ky + math.sin(a) * key_r * 1.95
        ink_polygon(
            d,
            wobble_circle(ex, ey, key_r * 0.60, seed=632 + k, amp=0.06, squash=1.75),
            GOLD,
            INK,
            width=R * 0.026,
        )
    ink_polygon(d, wobble_circle(kx, ky, key_r, seed=630, amp=0.04), BRASS, INK, width=R * 0.030)
    # 태엽선은 굵고 불규칙하게
    spiral = []
    for i in range(52):
        t = i / 51
        a = t * math.tau * 1.15
        rr = key_r * (0.20 + 0.50 * t)
        spiral.append((kx + math.cos(a) * rr, ky + math.sin(a) * rr))
    ink_line(d, spiral, INK, width=R * 0.017)

    # 짧고 굵은 포신. 중심에서 +X 로 돌출.
    # 포구까지 포함해 받침대 원 안에서 끝나야 충돌 실루엣과 어긋나지 않는다.
    half_w0, half_w1 = outer * 0.200, outer * 0.235
    lip_r = half_w1 * 0.98
    barrel_len = outer * 0.905 - lip_r  # 포구 바깥 경계 = 받침대 원 안쪽
    barrel = [
        (C - outer * 0.12, C - half_w0),
        (C + barrel_len, C - half_w1),
        (C + barrel_len, C + half_w1),
        (C - outer * 0.12, C + half_w0),
    ]
    ink_polygon(
        d,
        wobble_path(barrel + [barrel[0]], seed=640, amp=R * 0.005, resolution=80),
        CAN_BARREL,
        INK,
        width=R * 0.046,
    )

    # 포신 윗면 하이라이트
    hl = wobble_path(
        [(C + outer * 0.06, C - half_w0 * 0.52), (C + barrel_len * 0.94, C - half_w1 * 0.56)],
        seed=641,
        amp=R * 0.006,
        resolution=40,
    )
    ink_line(d, hl, CAN_BARREL_HI, width=R * 0.048)

    # 아이보리 포신 끝 구조부
    lip = wobble_circle(C + barrel_len, C, lip_r, seed=642, amp=0.05)
    ink_polygon(d, lip, IVORY_DIM, INK, width=R * 0.040)
    # 포구 내부는 어둡게 처리해 앞뒤를 구분한다
    ink_polygon(d, wobble_circle(C + barrel_len, C, lip_r * 0.58, seed=643, amp=0.06), "#0C1014", None)

    # 공 포획 중심. 받침대 중심에 배치하고 포신에 가리지 않게 테두리를 남긴다.
    ink_polygon(d, wobble_circle(C, C, outer * 0.225, seed=650, amp=0.04), SLATE_DARK, INK, width=R * 0.034)
    ink_line(
        d,
        list(wobble_circle(C, C, outer * 0.175, seed=651, amp=0.05)),
        TEAL_DARK,
        width=R * 0.022,
    )

    # 보라 실밥 2가닥
    for i, a_deg in enumerate((206, 318)):
        a = math.radians(a_deg)
        p0 = (C + math.cos(a) * outer * 0.40, C + math.sin(a) * outer * 0.40)
        p1 = (C + math.cos(a) * outer * 0.62, C + math.sin(a) * outer * 0.62)
        ink_line(d, wobble_path([p0, p1], seed=660 + i, amp=R * 0.010), PURPLE, width=R * 0.020)

    return finalize(img, "clockwork_cannon")


# --------------------------------------------------------------------------

BUMPERS = {
    "button": draw_button,
    "cotton": draw_cotton,
    "spring_doll": draw_spring_doll,
    "spring_doll_hit": draw_spring_doll_hit,
    "toy_drum": draw_toy_drum,
    "marble_slide": draw_marble_slide,
    "clockwork_cannon": draw_clockwork_cannon,
}


def main() -> None:
    os.makedirs(OUT_STEP1, exist_ok=True)
    os.makedirs(OUT_PLATE, exist_ok=True)
    print("STEP1 형태 마스터 생성")
    for name, fn in BUMPERS.items():
        master = fn()
        master.save(os.path.join(OUT_STEP1, f"{name}.png"))
        make_plate(master).save(os.path.join(OUT_PLATE, f"{name}_plate.png"))
    print(f"\n완료: {OUT_STEP1}, {OUT_PLATE}")


if __name__ == "__main__":
    main()
