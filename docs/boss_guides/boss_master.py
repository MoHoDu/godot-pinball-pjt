"""눈 잃은 테디베어 보스 - 형태 마스터 생성기.

`docs/bumper_guides/bumper_master.py` 와 같은 목적이다. **실루엣을 좌표로 확정**하고
색·표면만 AI(Leonardo / Firefly)로 입힌다. 실루엣을 AI 에게 맡기면 포즈마다 몸이
달라져서 프레임을 갈아 끼울 수 없다.

## 이 파일이 지키는 것

1. **몸은 고정, 팔만 움직인다.**
   포즈 7종이 전부 같은 `bear_body()` 를 호출한다. 몸을 포즈마다 다시 그리면
   프레임 교체 순간 그림이 튄다. 용수철 인형 두 프레임에서 겪은 문제와 같다.

2. **포즈별 bbox 정규화를 하지 않는다.**
   `finalize()` 로 각자 잘라 맞추면 포즈끼리 어긋난다. 전부 같은 캔버스에
   같은 원점으로 남긴다. 북 머리/테 레이어에서 같은 이유로 정규화를 뺐다.

3. **팔은 따로도 뽑는다.**
   기획서의 팔 충돌체는 캡슐이고 공격 회전 범위가 80~90° 다. 즉 팔은 코드가
   **회전**시키는 것이지 프레임을 넘기는 것이 아니다. 몸/팔/하트핵을 나눠 저장해
   코드가 회전·박동을 직접 돌릴 수 있게 한다.

## 좌표계

기획서 18절의 인게임 크기를 그대로 쓴다. 비주얼 520×620, 원점은 좌상단.
내부는 SS 배로 슈퍼샘플링해 그리고 마지막에 2배(1040×1240)로 저장한다.

비주얼보다 충돌체가 작다. 이는 의도된 설계다(귀·실 장식에 공이 억울하게 걸리지
않게). 그래서 **귀와 실 장식을 크게 뻗치면 비주얼만 커지고 충돌은 안 따라온다.**

실행:
    python docs/boss_guides/boss_master.py

결과:
    docs/boss_guides/step1/pose_*.png     포즈 7종 전신 (검수·AI 입력용)
    docs/boss_guides/step1/layer_*.png    몸/팔/하트핵 분리 (엔진 연결용)
    docs/boss_guides/step1/sheet.png      한 장 대조 시트
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

# --------------------------------------------------------------------------
# 캔버스
# --------------------------------------------------------------------------
# 기획서 18절: 보스 비주얼 약 520×620px
GAME_W, GAME_H = 520, 620
SS = 4  # 슈퍼샘플링
W, H = GAME_W * SS, GAME_H * SS
OUT_SCALE = 2  # 저장 배율 (1040×1240)

OUT = os.path.join(os.path.dirname(__file__), "step1")


def U(v: float) -> float:
    """인게임 좌표 -> 내부 캔버스 좌표."""
    return v * SS


# --------------------------------------------------------------------------
# 팔레트 — 가이드 v5 6절 "색상 방향"
# --------------------------------------------------------------------------
# 순검정 금지. 먹빛 청흑색을 쓴다 (기존 bumper_master.py 의 INK 와 같은 값).
INK = "#12161C"
INK_SOFT = "#1E252E"

# 보스 본체: 먹색 / 짙은 남색 / 저채도 보라
BODY = "#2C3040"
BODY_HI = "#383D51"
BODY_LO = "#20232F"
BODY_PURPLE = "#3A3048"

# 남아 있는 천: 탁한 회갈색 / 낡은 베이지. 원본 테디베어의 흔적이다.
CLOTH = "#8A7C68"
CLOTH_HI = "#A3947C"
CLOTH_LO = "#655A4B"

SEAM = "#171A23"  # 봉제선. 몸을 수선한다기보다 억지로 붙들고 있는 구속 구조.
HOLE = "#080A0E"  # 눈구멍. 거의 검정.

CURSE = "#6B4A86"  # 저주 보라
CURSE_DIM = "#3E3350"
LIME = "#A8C24E"  # 저주 내부 빛

HEART = "#7E2038"  # 하트형 저주핵. 짙은 진홍.
HEART_HI = "#A02C48"
HEART_LO = "#571526"

DANGER = "#C63455"  # 공격 예고 진홍
DANGER_HI = "#E4577A"


# --------------------------------------------------------------------------
# 형태 헬퍼 — bumper_master.py 와 같은 방식
# --------------------------------------------------------------------------


def _noise(rng: random.Random, count: int, octaves: int = 3) -> list[float]:
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


def blob(
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    seed: int,
    amp: float = 0.035,
    count: int = 220,
    rotate: float = 0.0,
) -> list[tuple[float, float]]:
    """비뚤어진 타원. 가이드 4-1 "완벽한 원형 금지" 를 만족시킨다."""
    rng = random.Random(seed)
    n = _noise(rng, count)
    pts = []
    for i in range(count):
        a = math.tau * i / count
        k = 1.0 + amp * n[i]
        x, y = math.cos(a) * rx * k, math.sin(a) * ry * k
        if rotate:
            c, s = math.cos(rotate), math.sin(rotate)
            x, y = x * c - y * s, x * s + y * c
        pts.append((cx + x, cy + y))
    return pts


def capsule(
    x0: float, y0: float, x1: float, y1: float, width: float, seed: int,
    taper: float = 0.24,
) -> list[tuple[float, float]]:
    """양 끝이 둥근 굵은 막대. 팔과 붓획에 쓴다.

    `taper` 가 양수면 끝으로 갈수록 두꺼워진다(늘어진 천 주머니).
    음수면 끝으로 갈수록 가늘어진다(붓획). 위험 방향선은 음수를 쓴다.
    """
    rng = random.Random(seed)
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    steps = 60
    n = _noise(rng, steps * 2 + 2)
    pts = []
    # 한쪽 변
    for i in range(steps + 1):
        t = i / steps
        w = width * 0.5 * (1.0 + 0.05 * n[i])
        # 끝으로 갈수록 살짝 두꺼워진다. 천 주머니가 늘어진 느낌.
        w *= (1.0 - taper * 0.5) + taper * t
        pts.append((x0 + ux * length * t + nx * w, y0 + uy * length * t + ny * w))
    # 끝 반원
    for i in range(1, 18):
        a = math.pi * i / 18
        w = width * 0.5 * (1.0 + taper * 0.5) * 1.06
        c, s = math.cos(a), math.sin(a)
        pts.append((x1 + nx * w * c + ux * w * s, y1 + ny * w * c + uy * w * s))
    # 반대쪽 변
    for i in range(steps, -1, -1):
        t = i / steps
        w = width * 0.5 * (1.0 + 0.05 * n[steps + i])
        w *= (1.0 - taper * 0.5) + taper * t
        pts.append((x0 + ux * length * t - nx * w, y0 + uy * length * t - ny * w))
    return pts


def heart_shape(
    cx: float, cy: float, size: float, seed: int
) -> list[tuple[float, float]]:
    """찌그러진 심장형. 가이드 5절 "예쁜 ♡ 형태 금지"."""
    rng = random.Random(seed)
    count = 160
    n = _noise(rng, count)
    pts = []
    for i in range(count):
        t = math.tau * i / count
        # 고전적인 하트 파라메트릭을 쓰되 좌우를 다르게 눌러 비대칭으로 만든다.
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t)
              - 2 * math.cos(3 * t) - math.cos(4 * t))
        # 한쪽 볼이 더 크고, 아래로 갈수록 한쪽으로 쏠린다.
        x *= 1.0 + 0.30 * math.sin(t) - 0.12 * math.cos(2 * t)
        y *= 1.0 + 0.12 * math.sin(t + 0.9)
        x += 2.2 * math.sin(t * 2 + 1.3)
        k = 1.0 + 0.16 * n[i]
        pts.append((cx + x * size / 16.0 * k, cy + y * size / 16.0 * k))
    return pts


def ink_poly(
    d: ImageDraw.ImageDraw,
    pts: list[tuple[float, float]],
    fill: str | None,
    outline: str | None = INK,
    width: float = 10.0,
) -> None:
    if fill is not None:
        d.polygon(pts, fill=fill)
    if outline and width > 0:
        w = int(width * SS / 2)
        d.line(list(pts) + [pts[0]], fill=outline, width=w, joint="curve")
        r = w / 2.0
        for x, y in pts[:: max(1, len(pts) // 56)]:
            d.ellipse([x - r, y - r, x + r, y + r], fill=outline)


def ink_line(
    d: ImageDraw.ImageDraw,
    pts: list[tuple[float, float]],
    color: str = SEAM,
    width: float = 5.0,
) -> None:
    if len(pts) < 2:
        return
    w = int(width * SS / 2)
    d.line(pts, fill=color, width=w, joint="curve")
    r = w / 2.0
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def stitch(
    d: ImageDraw.ImageDraw,
    pts: list[tuple[float, float]],
    color: str = SEAM,
    width: float = 3.4,
    step: int = 9,
) -> None:
    """봉제선의 X 자 실땀. 굵은 대표선 위에 얹는다."""
    w = int(width * SS / 2)
    for i in range(0, len(pts) - step, step):
        x0, y0 = pts[i]
        x1, y1 = pts[min(i + step, len(pts) - 1)]
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * U(5.0), dx / L * U(5.0)
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        d.line([(mx - nx, my - ny), (mx + nx, my + ny)], fill=color, width=w)


def wobble_path(
    pts: list[tuple[float, float]], seed: int, amp: float, count: int = 90
) -> list[tuple[float, float]]:
    """직선을 손그림처럼 흔든다. 가이드 7절 "완전히 매끈한 벡터선 금지"."""
    rng = random.Random(seed)
    n = _noise(rng, count)
    out = []
    for i in range(count):
        t = i / (count - 1)
        # 구간 선형 보간
        f = t * (len(pts) - 1)
        j = min(int(f), len(pts) - 2)
        u = f - j
        x = pts[j][0] * (1 - u) + pts[j + 1][0] * u
        y = pts[j][1] * (1 - u) + pts[j + 1][1] * u
        # 진행 방향의 법선으로 흔든다
        dx = pts[j + 1][0] - pts[j][0]
        dy = pts[j + 1][1] - pts[j][1]
        L = math.hypot(dx, dy) or 1.0
        out.append((x - dy / L * amp * n[i], y + dx / L * amp * n[i]))
    return out


def layer() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# --------------------------------------------------------------------------
# 해부 좌표 — 여기만 고치면 모든 포즈가 같이 움직인다
# --------------------------------------------------------------------------
# 기획서 4-1 충돌체: 머리 330×190 타원, 몸통 300×300 타원.
# 비주얼은 충돌체보다 크게 잡는다.
HEAD = dict(cx=260.0, cy=168.0, rx=148.0, ry=104.0, tilt=math.radians(-4.0))
# 몸통을 좁힌다. 어깨가 몸통 안에 들어가면 팔이 뒤에 가려 안 보인다.
# 실루엣 우선순위 1위가 "긴 양팔" 이므로 팔이 몸통 밖으로 확실히 나와야 한다.
BODY_E = dict(cx=257.0, cy=396.0, rx=116.0, ry=142.0)

# 귀는 크기와 높이를 서로 다르게 한다 (가이드 3-1).
EAR_L = dict(cx=146.0, cy=84.0, r=50.0)
EAR_R = dict(cx=374.0, cy=70.0, r=57.0)

# 어깨는 몸통 가장자리에 둔다. 한쪽이 더 높다 (가이드 4-4).
SHOULDER_L = (166.0, 296.0)
SHOULDER_R = (350.0, 282.0)

ARM_LEN = 268.0  # 기획서 8-2 팔 길이 320px 에 대응하는 비주얼 길이
ARM_W = 78.0  # 기획서 8-2 폭 100px

HEART_POS = (253.0, 372.0)
HEART_SIZE = 58.0  # 몸통의 절반을 넘으면 "긴 팔보다 핵이 먼저 보임" 반려 사유가 된다

EYE_L = dict(cx=204.0, cy=162.0, rx=37.0, ry=32.0)
EYE_R = dict(cx=318.0, cy=155.0, rx=40.0, ry=34.0)


# --------------------------------------------------------------------------
# 포즈 정의
# --------------------------------------------------------------------------
# arm: 아래(0°) 기준 바깥으로 벌어지는 각도. 양수가 바깥.
# squash: 몸 전체 세로 눌림. 1.0 이 기본.
# lean: 몸이 좌우로 기우는 정도(도).
# mouth: 봉제 입이 벌어진 정도. 0 이 기본, 1 이 포효.
POSES: dict[str, dict] = {
    # 상태 2. 기본 대기 — 양팔이 아래로 처지고 몸이 좌우로 불안정하게 흔들림
    "idle": dict(arm_l=15.0, arm_r=13.0, squash=1.0, lean=-1.2, mouth=0.0, head_lift=0.0),
    # 상태 3. 팔 공격 예고 — 팔이 바닥을 누르듯 압축, 몸 전체가 아래로 압축
    "telegraph": dict(
        arm_l=22.0, arm_r=20.0, squash=0.92, lean=0.0, mouth=0.0, head_lift=-6.0,
        arm_scale=0.86, danger=True,
    ),
    # 상태 4. 팔 공격 — 양팔이 양옆에서 위로 크게 벌어진다. 실루엣이 완전히 바뀐다.
    "arm_attack": dict(
        arm_l=158.0, arm_r=154.0, squash=1.05, lean=0.0, mouth=0.25, head_lift=8.0,
        arm_scale=0.92, trail=True,
    ),
    # 상태 5. 공격 후 경직 — 팔이 힘없이 떨어진다
    "recovery": dict(
        arm_l=6.0, arm_r=4.0, squash=0.96, lean=2.0, mouth=0.1, head_lift=-10.0
    ),
    # 상태 6. 일반 피격 — 몸이 짧게 찌그러지고 흔들림
    "hit": dict(arm_l=26.0, arm_r=8.0, squash=0.94, lean=3.5, mouth=0.15, head_lift=-3.0),
    # 상태 9. 강한 피격(정확한 반격) — 크게 비틀리거나 눌림
    "hit_strong": dict(
        arm_l=38.0, arm_r=12.0, squash=0.88, lean=6.5, mouth=0.35, head_lift=-6.0
    ),
    # 상태 7. 페이즈 전환 — 고개를 들고 포효. 봉제 입이 비정상적으로 늘어난다.
    "roar": dict(
        arm_l=19.0, arm_r=17.0, squash=1.03, lean=0.0, mouth=1.0, head_lift=16.0,
        smoke=True,
    ),
}


# --------------------------------------------------------------------------
# 부위 그리기
# --------------------------------------------------------------------------


def draw_arm(d: ImageDraw.ImageDraw, side: str, angle_deg: float, scale: float = 1.0) -> None:
    """팔 하나. **0° 가 수직 아래, 양수가 항상 바깥쪽**이다. 좌우 모두 양수를 쓴다.

    화면 좌표는 아래가 +y 라 아래 = 90°, 왼쪽 = 180°, 위 = 270° 다.
    따라서 왼팔은 각도를 더하고 오른팔은 뺀다. 이걸 반대로 두면 팔이 안쪽으로
    돌아 얼굴을 덮는다 (2026-08-07 에 실제로 그렇게 나왔다).
    """
    sx, sy = SHOULDER_L if side == "L" else SHOULDER_R
    sign = 1.0 if side == "L" else -1.0
    a = math.pi / 2 + math.radians(angle_deg) * sign
    length = ARM_LEN * scale
    ex = sx + math.cos(a) * length
    ey = sy + math.sin(a) * length
    seed = 41 if side == "L" else 57

    # 팔은 곧은 막대가 아니다. 중간을 바깥으로 살짝 부풀려 늘어진 천으로 만든다.
    nx, ny = -math.sin(a), math.cos(a)
    bow = ARM_W * 0.30 * (-sign)
    mx = sx + math.cos(a) * length * 0.52 + nx * bow
    my = sy + math.sin(a) * length * 0.52 + ny * bow
    upper = capsule(U(sx), U(sy), U(mx), U(my), U(ARM_W * 0.98), seed, 0.10)
    lower = capsule(U(mx), U(my), U(ex), U(ey), U(ARM_W * 1.06), seed + 3, 0.16)
    ink_poly(d, upper, BODY, INK, 11.0)
    ink_poly(d, lower, BODY, INK, 11.0)

    # 팔 안쪽의 굵은 대표선 2개. 가이드 7절 "한 영역에 2~4개의 굵은 대표선".
    for k, off in enumerate((-0.22, 0.20)):
        nx, ny = -math.sin(a), math.cos(a)
        p0 = (U(sx + nx * ARM_W * off), U(sy + ny * ARM_W * off))
        p1 = (U(ex + nx * ARM_W * off * 0.7), U(ey + ny * ARM_W * off * 0.7))
        ink_line(d, wobble_path([p0, p1], seed + k, U(4.0)), SEAM, 4.0)

    # 손끝은 손가락이 아니라 커다란 천·솜 덩어리 (가이드 4-5).
    tip = blob(U(ex), U(ey), U(ARM_W * 0.62), U(ARM_W * 0.56), seed + 9, 0.10)
    ink_poly(d, tip, BODY_HI, INK, 10.0)
    # 낡은 천 패치 하나
    patch = blob(U(ex - 8), U(ey + 4), U(ARM_W * 0.26), U(ARM_W * 0.22), seed + 13, 0.14)
    ink_poly(d, patch, CLOTH_LO, SEAM, 4.0)


def draw_body(d: ImageDraw.ImageDraw, pose: dict) -> None:
    """머리·귀·몸통·봉제선·눈구멍·입. **포즈가 달라도 이 구조는 같다.**"""
    squash = pose["squash"]
    lean = math.radians(pose["lean"])
    lift = pose["head_lift"]

    def T(x: float, y: float) -> tuple[float, float]:
        """몸 전체의 눌림·기울임을 한 곳에서 적용한다."""
        py = BODY_E["cy"]
        y2 = py + (y - py) * squash
        cx = BODY_E["cx"]
        c, s = math.cos(lean), math.sin(lean)
        dx, dy = x - cx, y2 - py
        return (U(cx + dx * c - dy * s), U(py + dx * s + dy * c))

    # --- 귀. 크기와 높이를 서로 다르게 (가이드 3-1) ---
    for ear, seed in ((EAR_L, 11), (EAR_R, 17)):
        pts = [T(ear["cx"] + math.cos(t) * ear["r"] * (1 + 0.06 * math.sin(3 * t)),
                 ear["cy"] + lift + math.sin(t) * ear["r"] * 0.94)
               for t in [math.tau * i / 120 for i in range(120)]]
        ink_poly(d, pts, BODY, INK, 12.0)
        inner = [T(ear["cx"] + math.cos(t) * ear["r"] * 0.52,
                   ear["cy"] + lift + math.sin(t) * ear["r"] * 0.50)
                 for t in [math.tau * i / 90 for i in range(90)]]
        ink_poly(d, inner, CURSE_DIM, SEAM, 4.0)

    # --- 몸통 ---
    body_pts = [T(x / SS, y / SS) for x, y in
                blob(U(BODY_E["cx"]), U(BODY_E["cy"]), U(BODY_E["rx"]),
                     U(BODY_E["ry"]), 23, 0.045)]
    ink_poly(d, body_pts, BODY, INK, 13.0)

    # 배 볼륨. 좌우가 완전히 같지 않다 (가이드 4-4).
    belly = [T(x / SS, y / SS) for x, y in
             blob(U(BODY_E["cx"] + 5), U(BODY_E["cy"] + 22), U(BODY_E["rx"] * 0.68),
                  U(BODY_E["ry"] * 0.58), 29, 0.07)]
    ink_poly(d, belly, BODY_HI, SEAM, 5.0)

    # 남아 있는 낡은 천 패치. 원본 테디베어의 흔적 (가이드 6절).
    for cx, cy, rx, ry, sd in (
        (196.0, 438.0, 36.0, 31.0, 31),
        (316.0, 452.0, 31.0, 28.0, 37),
        (292.0, 330.0, 26.0, 23.0, 43),
    ):
        patch = [T(x / SS, y / SS) for x, y in
                 blob(U(cx), U(cy), U(rx), U(ry), sd, 0.13)]
        ink_poly(d, patch, CLOTH_LO, SEAM, 4.5)
        stitch(d, patch, SEAM, 3.0, 11)

    # --- 몸통을 억지로 붙들고 있는 봉제선 (가이드 4-4) ---
    spine = wobble_path(
        [T(260.0, 250.0), T(254.0, 330.0), T(262.0, 414.0), T(252.0, 528.0)],
        5, U(7.0), 120
    )
    ink_line(d, spine, SEAM, 6.5)
    stitch(d, spine, SEAM, 3.6, 8)
    cross = wobble_path([T(148.0, 388.0), T(366.0, 378.0)], 7, U(6.0), 110)
    ink_line(d, cross, SEAM, 5.5)
    stitch(d, cross, SEAM, 3.2, 9)

    # 봉제선 사이로 새어 나오는 검은 솜 (가이드 4-4)
    for cx, cy, r, sd in ((228.0, 458.0, 18.0, 61), (286.0, 472.0, 15.0, 67)):
        puff = [T(x / SS, y / SS) for x, y in blob(U(cx), U(cy), U(r), U(r * 0.86), sd, 0.22)]
        ink_poly(d, puff, BODY_LO, None, 0.0)

    # --- 머리. 넓고 납작하며 한쪽으로 기울어져 있다 ---
    head_pts = [T(x / SS, y / SS + lift) for x, y in
                blob(U(HEAD["cx"]), U(HEAD["cy"]), U(HEAD["rx"]), U(HEAD["ry"]),
                     13, 0.038, rotate=HEAD["tilt"])]
    ink_poly(d, head_pts, BODY, INK, 13.0)

    # 머리 중앙 봉제선. 정확한 직선이 아니라 비뚤게 이어진다 (가이드 4-1).
    mid = wobble_path(
        [T(266.0, 68.0 + lift), T(256.0, 142.0 + lift), T(264.0, 222.0 + lift)],
        3, U(8.0), 90
    )
    ink_line(d, mid, SEAM, 6.0)
    stitch(d, mid, SEAM, 3.4, 8)

    # --- 눈구멍. 두 눈 모두 완전히 비어 있다 ---
    # 흰자·동공·단추눈·발광 전부 금지 (가이드 4-2). 핵보다 밝아지면 안 된다.
    for eye, sd in ((EYE_L, 71), (EYE_R, 79)):
        socket = [T(x / SS, y / SS + lift) for x, y in
                  blob(U(eye["cx"]), U(eye["cy"]), U(eye["rx"]), U(eye["ry"]), sd, 0.20)]
        ink_poly(d, socket, HOLE, INK, 9.0)
        # 눈구멍 안쪽의 아주 약한 보라 연기. 핵보다 밝으면 안 된다.
        inner = [T(x / SS, y / SS + lift) for x, y in
                 blob(U(eye["cx"] + 2), U(eye["cy"] + 5), U(eye["rx"] * 0.34),
                      U(eye["ry"] * 0.30), sd + 5, 0.08)]
        ink_poly(d, inner, CURSE_DIM, None, 0.0)
        # 눈 주변을 꿰맨 자국
        ring = [T(x / SS, y / SS + lift) for x, y in
                blob(U(eye["cx"]), U(eye["cy"]), U(eye["rx"] * 1.34),
                     U(eye["ry"] * 1.34), sd + 11, 0.10)]
        stitch(d, ring, SEAM, 3.0, 10)

    # --- 입. 봉제선이 벌어진 틈이지 괴물 입이 아니다 (가이드 4-3) ---
    m = pose["mouth"]
    my = 228.0 + lift
    half = 38.0 + 30.0 * m
    drop = 6.0 + 62.0 * m  # 포효할 때만 아래로 비정상적으로 늘어난다
    lip = wobble_path(
        [T(HEAD["cx"] - half, my), T(HEAD["cx"] - half * 0.3, my + drop),
         T(HEAD["cx"] + half * 0.4, my + drop * 0.9), T(HEAD["cx"] + half, my - 2)],
        9, U(5.0), 80
    )
    if m > 0.3:
        # 벌어진 틈 안쪽은 비어 있다. 이빨을 그리지 않는다.
        gap = lip + [T(HEAD["cx"] + half, my - 10), T(HEAD["cx"] - half, my - 8)]
        ink_poly(d, gap, HOLE, INK, 8.0)
        stitch(d, lip, SEAM, 3.2, 7)
    else:
        ink_line(d, lip, SEAM, 5.0)
        stitch(d, lip, SEAM, 3.0, 9)


def draw_heart(d: ImageDraw.ImageDraw, pose: dict, glow: float = 0.0) -> None:
    """가슴 중앙의 하트형 저주핵.

    **약점이 아니다.** 크로스헤어·약점 아이콘·지속 강발광을 붙이지 않는다.
    HP·페이즈·암전 상태를 알려주는 상태 표시용이다 (기획서 1-2, 가이드 5절).
    """
    squash = pose["squash"]
    cx, cy = HEART_POS
    cy = BODY_E["cy"] + (cy - BODY_E["cy"]) * squash
    size = HEART_SIZE * (1.0 + 0.06 * glow)

    pts = heart_shape(U(cx), U(cy), U(size), 89)
    ink_poly(d, pts, HEART, INK, 10.0)
    inner = heart_shape(U(cx), U(cy + 3), U(size * 0.68), 97)
    ink_poly(d, inner, HEART_LO, None, 0.0)

    # 박동 시 라임색 균열이 잠깐 보인다 (가이드 5절).
    if glow > 0.0:
        for k, (dx, dy) in enumerate(((-14, -8), (10, -2), (-4, 14))):
            crack = wobble_path(
                [(U(cx + dx), U(cy + dy - 16)), (U(cx + dx + 6), U(cy + dy + 18))],
                101 + k, U(4.0), 40
            )
            ink_line(d, crack, LIME, 3.4)

    # 몸 안에 실과 봉제선으로 억지로 고정돼 있다 (가이드 5절).
    for k, ang in enumerate((-2.5, -0.9, 0.5, 2.1)):
        x0 = U(cx + math.cos(ang) * size * 0.62)
        y0 = U(cy + math.sin(ang) * size * 0.58)
        x1 = U(cx + math.cos(ang) * size * 1.26)
        y1 = U(cy + math.sin(ang) * size * 1.20)
        ink_line(d, wobble_path([(x0, y0), (x1, y1)], 111 + k, U(3.0), 30), SEAM, 3.6)


def draw_danger_lines(d: ImageDraw.ImageDraw) -> None:
    """공격 예고의 아래→위 굵은 위험 방향선.

    가는 화살표 UI 가 아니라 **카툰식 붓획**으로 그린다 (가이드 9-1).
    금지: 공 바로 위를 덮는 거대한 붉은 면 / 화면 전체 플래시 / 작은 화살표 여러 개.
    """
    for side, sx, sy in (("L", SHOULDER_L[0], SHOULDER_L[1]),
                         ("R", SHOULDER_R[0], SHOULDER_R[1])):
        # 여기서 sign 은 화면 x 방향이다. 왼쪽이 -x.
        sign = -1.0 if side == "L" else 1.0
        for k in range(3):
            x0 = sx + sign * (52.0 + k * 20.0)
            y0 = sy + 272.0 - k * 26.0
            # 위로 갈수록 바깥으로 휜다. 팔이 지나갈 길을 가리킨다.
            x1 = x0 + sign * (54.0 + k * 22.0)
            y1 = sy - 34.0 - k * 40.0
            # taper 가 음수라 끝이 가늘어진다. 가는 화살표 UI 가 아니라 붓획이다.
            stroke = capsule(
                U(x0), U(y0), U(x1), U(y1), U(34.0 - k * 8.0), 200 + k, -0.72
            )
            ink_poly(d, stroke, DANGER_HI if k == 0 else DANGER, None, 0.0)


def draw_trail(d: ImageDraw.ImageDraw, arm_l: float, arm_r: float,
               scale: float = 1.0) -> None:
    """팔이 지나간 자리의 짧고 굵은 스윙 잔상 (가이드 9-2).

    무거운 몬스터 펀치가 아니라 커다란 봉제인형 팔이 지나간 느낌이어야 한다.
    """
    for side in ("L", "R"):
        sx, sy = SHOULDER_L if side == "L" else SHOULDER_R
        sign = -1.0 if side == "L" else 1.0
        for k in range(3):
            # 바깥쪽 절반만 남긴다. 안쪽까지 그리면 얼굴을 가로질러
            # "보스 연출이 공보다 먼저 보임" 반려 사유가 된다.
            # 바깥 위쪽 사분면만 쓴다. 범위를 넓히면 호가 얼굴을 가로질러
            # "보스 연출이 공보다 먼저 보임" 반려 사유가 된다.
            a0 = math.pi / 2 + math.radians(98.0 + k * 6.0) * sign
            a1 = math.pi / 2 + math.radians(152.0 - k * 5.0) * sign
            r = ARM_LEN * (0.70 + 0.12 * k)
            arc = []
            for i in range(26):
                t = i / 25
                a = a0 + (a1 - a0) * t
                arc.append((U(sx + math.cos(a) * r), U(sy + math.sin(a) * r)))
            ink_line(d, arc, DANGER_HI if k == 0 else DANGER, 9.0 - k * 2.4)


def draw_smoke(d: ImageDraw.ImageDraw) -> None:
    """포효 시 봉제선 사이에서 뿜어 나오는 검은 연기 (가이드 11-1)."""
    for k, (cx, cy, r) in enumerate((
        (196.0, 300.0, 34.0), (318.0, 288.0, 30.0), (258.0, 250.0, 26.0),
        (150.0, 352.0, 24.0), (372.0, 344.0, 22.0),
    )):
        puff = blob(U(cx), U(cy), U(r), U(r * 0.84), 130 + k, 0.24)
        ink_poly(d, puff, BODY_LO, None, 0.0)
        inner = blob(U(cx + 4), U(cy - 3), U(r * 0.5), U(r * 0.44), 140 + k, 0.28)
        ink_poly(d, inner, CURSE_DIM, None, 0.0)


# --------------------------------------------------------------------------
# 조립
# --------------------------------------------------------------------------


def compose(name: str, pose: dict) -> Image.Image:
    img, d = layer()

    if pose.get("smoke"):
        draw_smoke(d)

    # 팔 -> 몸 -> 하트핵 순. 팔이 몸 뒤로 들어가야 어깨가 자연스럽다.
    scale = pose.get("arm_scale", 1.0)
    # 들어 올린 팔은 몸 **앞**에 그린다. 뒤에 두면 머리에 가려 실루엣이 사라진다.
    raised = abs(pose["arm_l"]) > 90.0
    if not raised:
        draw_arm(d, "L", pose["arm_l"], scale)
        draw_arm(d, "R", pose["arm_r"], scale)
    draw_body(d, pose)
    if raised:
        draw_arm(d, "L", pose["arm_l"], scale)
        draw_arm(d, "R", pose["arm_r"], scale)
    # 하트핵 밝기: 페이즈 전환과 암전 중에 증가 (가이드 5절)
    glow = 1.0 if (pose.get("smoke") or name == "hit_strong") else 0.0
    draw_heart(d, pose, glow)

    if pose.get("danger"):
        draw_danger_lines(d)
    if pose.get("trail"):
        draw_trail(d, pose["arm_l"], pose["arm_r"], scale)

    return img


def save(img: Image.Image, name: str) -> None:
    """**bbox 정규화를 하지 않는다.** 포즈끼리 정렬을 유지해야 한다."""
    out = img.resize((GAME_W * OUT_SCALE, GAME_H * OUT_SCALE), Image.LANCZOS)
    path = os.path.join(OUT, f"{name}.png")
    out.save(path)
    box = out.getbbox()
    print(f"  {name:<22} bbox={box}")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    print(f"캔버스 {GAME_W}×{GAME_H} (저장 {GAME_W*OUT_SCALE}×{GAME_H*OUT_SCALE})")

    print("\n포즈 7종")
    posed: dict[str, Image.Image] = {}
    for name, pose in POSES.items():
        img = compose(name, pose)
        posed[name] = img
        save(img, f"pose_{name}")

    print("\n분리 레이어 (엔진 연결용)")
    # 몸: 팔 없이. 코드가 팔을 따로 회전시킬 수 있게 한다.
    img, d = layer()
    draw_body(d, POSES["idle"])
    save(img, "layer_body")

    # 팔 한 짝씩. 회전 피벗은 어깨다.
    for side in ("L", "R"):
        img, d = layer()
        draw_arm(d, side, 0.0)
        save(img, f"layer_arm_{side.lower()}")

    # 하트핵 기본 / 점멸
    for tag, glow in (("base", 0.0), ("pulse", 1.0)):
        img, d = layer()
        draw_heart(d, POSES["idle"], glow)
        save(img, f"layer_heart_{tag}")

    # 대조 시트
    cols, rows = 4, 2
    tw, th = GAME_W, GAME_H
    sheet = Image.new("RGBA", (tw * cols, th * rows), (24, 27, 36, 255))
    for i, (name, img) in enumerate(posed.items()):
        cell = img.resize((tw, th), Image.LANCZOS)
        sheet.paste(cell, ((i % cols) * tw, (i // cols) * th), cell)
    sheet.save(os.path.join(OUT, "sheet.png"))
    print(f"\n대조 시트: {os.path.join(OUT, 'sheet.png')}")

    print("\n피벗 좌표(인게임 520×620 기준) — 엔진에서 팔을 돌릴 때 쓴다")
    print(f"  왼팔 어깨 {SHOULDER_L}   오른팔 어깨 {SHOULDER_R}")
    print(f"  하트핵   {HEART_POS}      팔 길이 {ARM_LEN} 폭 {ARM_W}")


if __name__ == "__main__":
    main()
