"""VFX 3 패링 성공 원형 파동 - 1 형태 단계 목표 그림 렌더러.

비주얼 가이드 3-5 수치를 그대로 넣고 형태만 확정하기 위한 스크립트다.
셰이더/GDScript 구현 전에 "무엇을 그릴 것인가"를 픽셀로 못박는 용도.

원칙 (project_pinball_logue / vfx01 / vfx02 에서 확정된 것):
  - 완전 평면 정사영. 광원 없음. 소프트 그라디언트 음영 금지
  - 입체감은 명도 단차와 굵은 외곽선으로만
  - 밴딩(계단)은 최종 알파에 딱 한 번만 건다 (vfx01 교훈)
  - 실루엣은 수치로 확정한다. 흔들림은 텍스처가, 형태는 원이 담당

좌표 단위는 전부 px 이고 공 지름 44px(반지름 22px) 기준이다.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

# 이 파일은 docs/ball_guides/ 에 있다. 리포 루트는 두 단계 위.
REPO = Path(__file__).resolve().parents[2]
BALL_PNG = REPO / "Resources" / "Art" / "balls" / "glass_eye_ball.png"

# 공/기존 VFX 규격 -- 여기를 바꾸면 전부 따라간다
BALL_R = 22.0          # 공 반지름 (기획서 r22, 실제 게임 크기 44px)
AURA_R = 40.0          # 안개 오라 명목 외곽 (BallGlowOutlineRules radius_ratio 1.818)
AURA_REACH = 36.0      # 안개 실측 도달 (vfx01 메모: 혓바닥 방향에서만 40에 닿는다)

# 가이드 3-5 권장 수치
R_START = 27.0         # 시작 반지름 (권장 25~30)
R_END = 105.0          # 종료 반지름 (권장 90~120)
DURATION = 0.16        # 전체 지속 (권장 0.12~0.20)
FLASH_TIME = 0.045     # 중심 플래시 (권장 0.03~0.06)
RING_W = 6.0           # 주요 링 두께 (권장 4~8)
CENTER_SHIFT = 4.0     # 중심을 타격 방향으로 이동 (권장 2~5)

# 색 -- 가이드 3-5 색상 + 리포 기존 값
TEAL = (0.435, 0.890, 0.784)    # 밝은 청록. 주요 링
TEAL_DEEP = (0.310, 0.651, 0.573)  # BallGlowOutlineRules normal_mist_color
IVORY = (0.941, 0.878, 0.765)   # 아이보리. 중심/보조
GOLD = (1.000, 0.780, 0.120)    # FlipperParryFeedback PERFECT_COLOR
BOARD_BG = (0.098, 0.122, 0.157)  # 어두운 보드 배경 대용

SS = 4  # 슈퍼샘플 배율


def _grids(size: int, scale: float, cx: float, cy: float):
    """px 단위 반경/각도 격자를 만든다. cx, cy 는 px 단위 중심 오프셋."""
    n = size * SS
    ax = (np.arange(n) + 0.5) / SS / scale
    half = size / scale / 2.0
    X = ax[None, :] - half - cx
    Y = ax[:, None] - half - cy
    R = np.hypot(X, Y)
    A = np.arctan2(Y, X)
    return R, A


def _wobble(A: np.ndarray, amount: float, lobes: int, phase: float) -> np.ndarray:
    """카툰형 원 -- 매끈한 네온 원이 아니라 약간 흔들리는 원 (가이드 3-2)."""
    w = np.sin(A * lobes + phase) * 0.6 + np.sin(A * (lobes * 2 + 1) - phase * 1.7) * 0.4
    return 1.0 + w * amount


def _band(a: np.ndarray, bands: int) -> np.ndarray:
    """최종 알파에 계단을 한 번만 건다. 카툰 명도 단차."""
    if bands <= 0:
        return a
    return np.ceil(np.clip(a, 0.0, 1.0) * bands) / bands


def _annulus(R, A, r_mid, width, wob=0.10, lobes=7, phase=0.0, gaps=0, gap_w=0.22):
    """가장자리 1px만 완화한 평탄한 고리. 그라디언트로 흐리지 않는다."""
    rr = r_mid * _wobble(A, wob, lobes, phase)
    d = np.abs(R - rr)
    half = width * 0.5
    a = np.clip((half - d) / 1.0 + 1.0, 0.0, 1.0)
    if gaps > 0:
        # 링을 몇 군데 끊는다. 완전히 자르지 않고 알파만 떨어뜨린다
        g = np.cos(A * gaps + phase * 0.5)
        cut = np.clip((g - (1.0 - gap_w)) / max(gap_w, 1e-6), 0.0, 1.0)
        a = a * (1.0 - cut * 0.85)
    return a


def _disc(R, A, r, wob=0.06, lobes=5, phase=0.0):
    rr = r * _wobble(A, wob, lobes, phase)
    return np.clip((rr - R) / 1.0 + 1.0, 0.0, 1.0)


def _spokes(R, A, r_in, r_out, count, width_deg, offset=0.0, taper=True):
    """링 주변 방사형 선. 각도 폭을 px 폭으로 환산해 끝이 벌어지지 않게 한다."""
    a = np.zeros_like(R)
    step = 2.0 * np.pi / count
    half_w = np.deg2rad(width_deg) * 0.5
    for i in range(count):
        ang = offset + i * step
        d = np.abs(np.arctan2(np.sin(A - ang), np.cos(A - ang)))
        # 각도 거리 -> px 거리
        px = d * np.maximum(R, 1.0)
        w_px = half_w * r_out
        if taper:
            # 바깥으로 갈수록 얇아진다
            t = np.clip((R - r_in) / max(r_out - r_in, 1e-6), 0.0, 1.0)
            w_px = w_px * (1.0 - 0.65 * t)
        band = np.clip((w_px - px) / 1.0 + 1.0, 0.0, 1.0)
        radial = ((R >= r_in) & (R <= r_out)).astype(np.float64)
        radial = np.clip(np.minimum(R - r_in, r_out - R) / 1.0 + 1.0, 0.0, 1.0) * radial
        a = np.maximum(a, band * radial)
    return a


def _sparks(R, A, r_mid, count, length, width, offset=0.35, seed=3, size=None, scale=1.0):
    """짧은 별 조각. 방사형 선과 구분되도록 십자(별)로 그린다.

    선과 같은 모양으로 그리면 방사선과 뭉쳐 하나로 읽힌다.
    """
    rng = np.random.default_rng(seed)
    a = np.zeros_like(R)
    # 극좌표 격자에서 별을 그리려면 직교 좌표가 필요하다
    X = R * np.cos(A)
    Y = R * np.sin(A)
    arm = length * 0.5
    for i in range(count):
        ang = offset + i * (2.0 * np.pi / count) + float(rng.uniform(-0.22, 0.22))
        rc = r_mid * float(rng.uniform(1.12, 1.30))
        px, py = rc * np.cos(ang), rc * np.sin(ang)
        dx, dy = X - px, Y - py
        # 십자 두 팔. 하나는 방사 방향, 하나는 직교
        ca, sa = np.cos(ang), np.sin(ang)
        u = dx * ca + dy * sa
        v = -dx * sa + dy * ca
        arm1 = np.clip((arm - np.abs(u)) + 1.0, 0.0, 1.0) * np.clip(
            (width * 0.5 - np.abs(v)) + 1.0, 0.0, 1.0
        )
        arm2 = np.clip((arm * 0.62 - np.abs(v)) + 1.0, 0.0, 1.0) * np.clip(
            (width * 0.5 - np.abs(u)) + 1.0, 0.0, 1.0
        )
        a = np.maximum(a, np.maximum(arm1, arm2))
    return a


def _over(dst_rgb, dst_a, src_rgb, src_a):
    """src 를 dst 위에 알파 합성한다."""
    out_a = src_a + dst_a * (1.0 - src_a)
    safe = np.maximum(out_a, 1e-6)
    out_rgb = np.empty_like(dst_rgb)
    for c in range(3):
        out_rgb[..., c] = (
            src_rgb[..., c] * src_a + dst_rgb[..., c] * dst_a * (1.0 - src_a)
        ) / safe
    return out_rgb, out_a


def _solid(shape, color):
    rgb = np.empty(shape + (3,), dtype=np.float64)
    for c in range(3):
        rgb[..., c] = color[c]
    return rgb


# 후보 3안 --------------------------------------------------------------

CANDIDATES = {
    "A": dict(
        name="A. 문서 그대로",
        note="중심 플래시 = 꽉 찬 원 / 방사선 12개 균등 / 보조 링 금색 뒤따름",
        flash_hollow=False,
        spoke_count=12,
        spoke_directional=False,
        center_shift=0.0,
        ring_asym=0.0,
    ),
    "B": dict(
        name="B. 동공 보호형",
        note="중심 플래시를 속 빈 고리로 (동공을 가리지 않는다) / 나머지 A와 동일",
        flash_hollow=True,
        spoke_count=12,
        spoke_directional=False,
        center_shift=0.0,
        ring_asym=0.0,
    ),
    "C": dict(
        name="C. 방향 강조형",
        note="중심 4px 이동 / 방사선을 진행 방향 5개만 길게 / 링이 진행 방향으로 두껍다",
        flash_hollow=True,
        spoke_count=5,
        spoke_directional=True,
        center_shift=CENTER_SHIFT,
        ring_asym=0.35,
    ),
}


def ease_out(x: float) -> float:
    """파동은 빠르게 커지고 사라진다 (가이드 3-5)."""
    return 1.0 - (1.0 - x) ** 2.0


def wave_rgba(size: int, scale: float, cfg: dict, t: float, hit_angle: float = -0.6):
    """t 는 0~1 정규화 시간. size 는 출력 px, scale 은 1px=몇 배로 볼지."""
    shift = cfg["center_shift"]
    cx = np.cos(hit_angle) * shift
    cy = np.sin(hit_angle) * shift
    R, A = _grids(size, scale, cx, cy)

    e = ease_out(t)
    r_main = R_START + (R_END - R_START) * e
    # 보조 링은 뒤따른다 (가이드: 금색/아이보리 보조 링이 뒤따름)
    r_sub = R_START + (R_END - R_START) * ease_out(max(t - 0.18, 0.0) / 0.82)

    # 링은 커질수록 얇아진다. 두께를 고정하면 끝에서 덩어리가 된다
    w_main = RING_W * (1.0 - 0.35 * e)
    w_sub = RING_W * 0.5 * (1.0 - 0.3 * e)

    # 사라짐은 밴딩 뒤에 곱한다. ceil 밴딩을 먼저 걸면 페이드가 계단에 먹힌다
    fade = 1.0 - np.clip((t - 0.45) / 0.55, 0.0, 1.0) ** 1.3

    rgb = _solid(R.shape, (0.0, 0.0, 0.0))
    acc = np.zeros_like(R)

    # 주요 링 (밝은 청록)
    asym = cfg["ring_asym"]
    if asym > 0.0:
        dirw = 1.0 + asym * np.cos(A - hit_angle)
    else:
        dirw = 1.0
    a_main = _annulus(R, A, r_main, w_main, wob=0.022, lobes=7, phase=1.1,
                      gaps=3, gap_w=0.16)
    a_main = np.clip(a_main * dirw, 0.0, 1.0) * 0.95
    rgb, acc = _over(rgb, acc, _solid(R.shape, TEAL), a_main)

    # 방사형 선 -- 링 바깥에만. 링을 가로지르면 톱니바퀴로 읽힌다
    if t > 0.05:
        if cfg["spoke_directional"]:
            sp = np.zeros_like(R)
            for k in range(cfg["spoke_count"]):
                ang = hit_angle + (k - (cfg["spoke_count"] - 1) / 2.0) * 0.26
                d = np.abs(np.arctan2(np.sin(A - ang), np.cos(A - ang))) * np.maximum(R, 1.0)
                w_px = np.deg2rad(1.5) * r_main
                band = np.clip((w_px - d) / 1.0 + 1.0, 0.0, 1.0)
                r_in, r_out = r_main * 1.05, r_main * 1.34
                rad = np.clip(
                    np.minimum(R - r_in, r_out - R) / 1.0 + 1.0, 0.0, 1.0
                ) * ((R >= r_in) & (R <= r_out))
                sp = np.maximum(sp, band * rad)
        else:
            sp = _spokes(
                R, A, r_main * 1.06, r_main * 1.26, cfg["spoke_count"], 1.1, offset=0.26
            )
        rgb, acc = _over(rgb, acc, _solid(R.shape, TEAL), sp * 0.85)

    # 보조 링 (금색) -- 성공 포인트. 금색은 여기서만 쓴다
    if t > 0.20:
        a_sub = _annulus(R, A, r_sub, w_sub, wob=0.02, lobes=5, phase=-0.4,
                         gaps=2, gap_w=0.22)
        rgb, acc = _over(rgb, acc, _solid(R.shape, GOLD), a_sub * 0.92)

    # 별/번개 조각
    if 0.10 < t < 0.80:
        sk = _sparks(R, A, r_main, 5, length=8.0, width=2.2, seed=7)
        rgb, acc = _over(rgb, acc, _solid(R.shape, IVORY), sk * 0.9)

    # 중심 플래시 -- 전체의 FLASH_TIME/DURATION 구간만
    ft = FLASH_TIME / DURATION
    if t < ft:
        fa = (1.0 - (t / ft)) ** 0.8
        if cfg["flash_hollow"]:
            # 공 바깥 고리로만. 동공을 가리지 않는다
            fl = _annulus(R, A, (BALL_R + R_START) * 0.5, R_START - BALL_R,
                          wob=0.04, lobes=5)
        else:
            fl = _disc(R, A, R_START * 0.92, wob=0.03, lobes=5)
        rgb, acc = _over(rgb, acc, _solid(R.shape, IVORY), np.clip(fl, 0, 1) * fa)

    acc = _band(acc, 6) * fade

    out = np.dstack([np.clip(rgb, 0, 1), np.clip(acc, 0, 1)])
    im = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    return im.resize((size, size), Image.LANCZOS)


def ball_layer(size: int, scale: float) -> Image.Image:
    """공 + 안개 오라를 근사해 깐다. 파동이 무엇 위에 얹히는지 보기 위한 것."""
    R, A = _grids(size, scale, 0.0, 0.0)
    rgb = _solid(R.shape, (0, 0, 0))
    acc = np.zeros_like(R)

    # 안개 오라 근사 (평탄 5단 계단)
    m = np.clip((AURA_REACH - R) / (AURA_REACH - BALL_R), 0.0, 1.0) ** 0.85
    m = np.where(R < BALL_R, 1.0, m) * 0.55
    m = _band(m, 5)
    rgb, acc = _over(rgb, acc, _solid(R.shape, TEAL_DEEP), m * (R > BALL_R * 0.98))

    im = Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(acc, 0, 1)]) * 255)
                         .astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)

    ball = Image.open(BALL_PNG).convert("RGBA")
    d = int(round(BALL_R * 2 * scale))
    ball = ball.resize((d, d), Image.LANCZOS)
    im.alpha_composite(ball, ((size - d) // 2, (size - d) // 2))
    return im


if __name__ == "__main__":
    im = wave_rgba(320, 1.4, CANDIDATES["C"], 0.45)
    im.save(Path(__file__).with_name("_probe.png"))
    print("probe ok", im.size)
