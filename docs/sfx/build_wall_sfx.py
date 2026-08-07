#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pinball_Logue - 벽 충돌 SFX ① 형태 단계 (절차적 합성)

가이드 근거
  p.73  제작 리소스 MUST  "벽 충돌 SFX 3종 — 저·중·고속 대응"
        ★ 3종은 랜덤 변형이 아니라 **속도 구간별**이다. 이게 설계의 전부다.
  p.61  7-2 권장 음색
          1. 짧은 목재 또는 플라스틱 톡
          2. 속이 빈 장난감 프레임의 약한 둑
          3. 고속 충돌에만 작은 유리 팅
        7-1  패링·플리퍼·보스 타격음보다 **작고 짧게** 쓴다
  p.62  7-3 사운드 규격  길이 0.06~0.14초 / 피치 ±5% / 동시 4개 /
        간격 0.04초 / 패링 대비 -8~-10dB / 잔향 없음 또는 극소량 /
        연속 충돌 두 번째부터 -3dB / 보드 종류별로 나누지 않는다

설계 원칙 (파일럿과 동일)
  * 어택·길이·레이어 밸런스는 절차적으로 확정한다. AI에 맡기지 않는다
  * 피치 ±5% 는 파일에 굽지 않는다 → 런타임 pitch_scale
  * 세 파일 모두 피크 -10dBFS 로 맞춘다.
    음량 차이는 런타임 속도→음량 곡선이 만든다. 파일에 구우면 두 번 적용된다.
  * 레이어는 layers/ 에 따로 떨어뜨려 ② 텍스처 단계에서 교체 가능하게 둔다

★ 어택에 대한 판단 (2026-08-06)
  p.61 은 벽 충돌에 "플리퍼·패링과 동일한 어택" 사용을 금지한다.
  그런데 p.89 6-2 는 공통 어택을 "충돌 시점을 인지하는 기준"으로 요구한다.
  여기서는 **공통 어택을 쓴다.** 공이 무언가에 맞았다는 신호는 하나여야 하고,
  그게 파일럿 전체의 전제다.
  대신 구분은 플리퍼 쪽에서 만든다 — 플리퍼 타격음(미착수)과 패링음은 벽과
  다른 어택을 써야 한다. 현재 패링음은 공통 어택 기반이라 이 규칙에 걸린다.
  패링 공용 3레이어 재작업 때 함께 해결할 사항이다.
"""

import numpy as np
from scipy import signal

from build_sfx import (
    SR, ROOT, AUDITION, HIT_PEAK_DBFS,
    secs, tt, env_exp, band_noise, gate, trim_floor, norm_peak,
    write_wav, measure, common_attack, glass_ting, short_tail,
    GLASS_MODES_HIT, detune,
)

# 출력 폴더 (build_sfx 의 ball/ 과 나눠 쓴다)
OUT = ROOT / "wall"
LAYERS = ROOT / "layers" / "wall"
for _d in (OUT, LAYERS):
    _d.mkdir(parents=True, exist_ok=True)

# 속도 구간별 길이 게이트 (초). 빠를수록 길고 밝다 —
# 고속에만 유리 팅이 붙는 구조(p.61)와 방향이 같다.
#
# 게이트는 길이의 **상한**만 잡는다. 실제 길이는 trim_floor(-60dBFS)가 정한다.
# 둘 중 먼저 걸리는 쪽이 이기므로 게이트만, 또는 tau 만 만져서는 길이가 안 움직인다.
LOW_GATE = (0.075, 0.115)
MID_GATE = (0.085, 0.125)
HIGH_GATE = (0.090, 0.135)

# 목재·플라스틱 톡. 비조화 배열이라 음정으로 안 읽힌다.
#
# ★ 1차 시안은 기본음 620Hz 였는데 800Hz 미만에 에너지의 89% 가 몰렸다(실측).
#   그건 장난감 나무 블록이 아니라 p.61 이 금지한 "강한 저음 충격"이다.
#   실제 작은 나무·플라스틱 조각의 톡은 1~4kHz 대다. 기본음을 그쪽으로 올렸다.
#
# tau 와 실제 길이의 관계: trim_floor 의 -60dBFS 는 **어택 피크 기준**이다.
# 어택이 재질보다 훨씬 크므로 모드 자신의 감쇠시간(tau × 6.9)보다 일찍 걸린다.
WOOD_MODES = [
    (1185.0, 1.00, 0.0178),
    (1792.0, 0.62, 0.0132),
    (2648.0, 0.34, 0.0097),
    (3815.0, 0.18, 0.0068),
]

# ★ 공은 **유리눈**이다 (2026-08-06 형락님 지적).
#
#   충돌에는 재질이 둘 있다 — 공(유리)과 벽(목재·속 빈 프레임).
#   이 중 **변하지 않는 쪽은 공**이다. 벽에 부딪히든 플리퍼에 맞든 유리공은 유리공이다.
#   그래서 유리 성분은 **모든 충돌에 있어야 하고**, 벽·플리퍼 재질이 그 위에 얹힌다.
#
#   1차 구조는 거꾸로였다 — 유리를 "고속 충돌에만 얹는 장식"으로 다뤘다.
#   가이드 p.61 의 "고속 충돌에만 작은 유리 팅"은 **벽이 우는 유리 팅**을 말한 것이고,
#   공 자신의 유리 몸통과는 다른 층이다. 둘을 합쳐 하나로 보면 공의 정체성이 사라진다.
#
#   주파수는 파일럿(build_sfx.GLASS_MODES_HIT)과 같게 둔다. 공은 하나뿐이니
#   공 소리도 하나여야 한다. 감쇠만 짧게 잡아 유리가 주인공이 되지 않게 한다.
WALL_GLASS_MODES = [(f, a, tau * 0.52) for f, a, tau in GLASS_MODES_HIT]

# 속이 빈 장난감 프레임. 한쪽이 막힌 관처럼 홀수 배음만 세운다 = "둑" 하는 공동감.
# 기본음을 400Hz 아래로 내리면 같은 이유로 저음 충격이 된다.
# 가이드가 요구하는 것은 "약한 둑"이지 북소리가 아니다.
#
# ★ tau 가 목재보다 길면 공동이 에너지를 지배해서 저역 덩어리로 들린다.
#   525Hz·tau 0.0205 일 때 중속이 800Hz 미만 80.7% 였다(실측). 둘 다 줄였다.
HOLLOW_MODES = [
    (628.0, 1.00, 0.0186),
    (1884.0, 0.50, 0.0140),
    (3140.0, 0.26, 0.0103),
    (4396.0, 0.13, 0.0073),
]


# ★ "밋밋하다"에 대한 대응 (2026-08-06 형락님 피드백)
#
# 1차본은 어택 + 지수감쇠 모드뿐이라 시간축에서 아무 일도 일어나지 않았다.
# 저역을 걷어내는 과정에서(89% → 1~15%) 몸통까지 같이 날아간 것도 겹쳤다.
# 실제 충돌음이 살아 있게 들리는 이유 세 가지를 넣는다.
#
#   ① 피치 드롭  — 접촉 강성이 풀리며 음정이 처음 10~20ms 에 살짝 내려간다
#   ② 짧은 저역 몸통 — 몸통은 필요하다. 다만 **짧아야** 한다.
#                      1차 시안이 실패한 건 저역이 있어서가 아니라 tau 가 길어서였다
#   ③ 스냅        — 아주 짧은 고역 버스트. 어택의 가장자리를 세운다
GLIDE_CENTS = -95.0      # 약 -5.5%. 더 내리면 음정이 흔들리는 것으로 들린다
GLIDE_TAU = 0.011
THUMP_FREQ = 232.0
THUMP_TAU = 0.0062       # 짧다. 이게 길어지면 1차 시안의 저음 덩어리로 되돌아간다


# ★ 2차 대응 (2026-08-06, "더 밀어달라")
#
#   ④ 부분음 비팅 — 모드마다 몇 센트 어긋난 짝을 두면 진폭이 느리게 출렁인다.
#                   순수 감쇠 사인은 죽은 소리로 들린다
#   ⑤ 결(grain)   — 감쇠 구간 내내 깔리는 미세 노이즈. 표면 거칠기다
#   ⑥ 2단 충돌    — 실제 충돌은 한 번이 아니다. 접촉하고 튕기며 아주 짧게 다시 닿는다
#   ⑦ 소프트 새추레이션 — 피크는 그대로 두고 배음만 늘린다. 체감 두께가 올라간다
BEAT_CENTS = 6.5
DOUBLE_DELAY = {"low": 0.0092, "mid": 0.0125, "high": 0.0148}
DOUBLE_GAIN = {"low": 0.30, "mid": 0.34, "high": 0.38}
DRIVE = {"low": 1.9, "mid": 2.1, "high": 2.1}


def modal_glide(n, modes, cents, tau_glide, seed=0, beat_cents=BEAT_CENTS):
    """감쇠 사인 합 + 음정이 처음에 살짝 내려가는 글라이드 + 부분음 비팅."""
    rng = np.random.default_rng(seed)
    t = tt(n)
    g = 2.0 ** (cents / 1200.0) - 1.0
    # f(t) = f * (1 + g·e^(-t/tau)) 의 위상 적분
    warp = t + g * tau_glide * (1.0 - np.exp(-t / tau_glide))
    beat = 2.0 ** (beat_cents / 1200.0)
    y = np.zeros(n)
    for f, a, tau in modes:
        env = env_exp(n, tau)
        y += a * np.sin(2 * np.pi * f * warp + rng.uniform(0, 2 * np.pi)) * env
        # 짝 부분음. 진폭을 낮게 둬서 음정이 흔들리는 게 아니라 결로 들리게 한다
        y += a * 0.62 * np.sin(2 * np.pi * f * beat * warp
                               + rng.uniform(0, 2 * np.pi)) * env
    return y


def grain(n, seed=0):
    """감쇠 내내 깔리는 미세 노이즈. 매끈한 사인 감쇠를 표면감으로 바꾼다."""
    y = band_noise(n, 1100, 7400, 0.0185, seed=7500 + seed, order=1)
    # 일정한 쉬이 소리가 되지 않도록 느린 흔들림을 준다
    rng = np.random.default_rng(7600 + seed)
    wobble = 1.0 + 0.45 * np.sin(2 * np.pi * rng.uniform(38.0, 62.0) * tt(n)
                                 + rng.uniform(0, 2 * np.pi))
    y = y * wobble
    return y / np.max(np.abs(y))


def soft_clip(x, drive):
    """피크는 그대로 두고 배음만 늘린다. 체감 두께가 올라간다."""
    m = np.max(np.abs(x))
    if m <= 0:
        return x
    y = np.tanh(drive * x / m) / np.tanh(drive)
    return y * m


def double_contact(x, delay_s, gain):
    """접촉하고 튕기며 아주 짧게 다시 닿는 2단 충돌."""
    d = secs(delay_s)
    y = np.zeros(len(x))
    y[d:] = x[:len(x) - d] * gain
    return x + y


def low_thump(n, seed=0):
    """짧은 저역 몸통. 공이 '무언가에 맞았다'는 무게를 준다."""
    t = tt(n)
    g = 2.0 ** (-140.0 / 1200.0) - 1.0
    warp = t + g * 0.008 * (1.0 - np.exp(-t / 0.008))
    y = np.sin(2 * np.pi * THUMP_FREQ * warp) * env_exp(n, THUMP_TAU, attack=0.0004)
    return y / np.max(np.abs(y))


def snap(n, seed=0):
    """어택 가장자리를 세우는 초단타 고역 버스트."""
    y = band_noise(n, 5200, 13000, 0.0009, seed=7000 + seed)
    return y / np.max(np.abs(y))


def pad_to(x, n):
    y = np.zeros(n)
    m = min(len(x), n)
    y[:m] = x[:m]
    return y


def wood_tok(n, variant=0):
    """짧은 목재·플라스틱 톡 (p.61 권장 음색 1)."""
    cents = (-14.0, 0.0, 14.0)[variant % 3]
    knock = band_noise(n, 1400, 6200, 0.0016, seed=6000 + variant) * 0.62
    body = modal_glide(n, detune(WOOD_MODES, cents), GLIDE_CENTS, GLIDE_TAU,
                       seed=6100 + variant)
    y = knock + body
    return y / np.max(np.abs(y))


def hollow_duk(n, variant=0):
    """속이 빈 장난감 프레임의 약한 둑 (p.61 권장 음색 2)."""
    cents = (-10.0, 0.0, 10.0)[variant % 3]
    air = band_noise(n, 620, 2600, 0.0068, seed=6200 + variant) * 0.36
    tube = modal_glide(n, detune(HOLLOW_MODES, cents), GLIDE_CENTS * 0.7, GLIDE_TAU,
                       seed=6300 + variant)
    y = tube + air
    return y / np.max(np.abs(y))


# 레이어 게인 표. (게이트, 목재, 공동, 유리, 몸통, 스냅, 잔향, variant)
#
# "약한 둑"·"작은 유리 팅"(p.61)이라 공동과 유리는 목재보다 항상 작게 얹는다.
# 유리 0.30 에서는 고속이 4.1kHz 로 태엽 재질음보다 밝아졌다(실측) → 0.34 + 짧은 tau.
# 몸통·스냅은 속도가 빠를수록 세진다. 세게 부딪힐수록 무게와 날이 같이 선다.
#
# 2026-08-06 형락님 "더 두껍게" → 두꺼운 쪽을 base 로 올렸다.
# 두께를 만드는 것은 몸통·공동·잔향이고, 스냅은 반대로 얇게 만들므로 같이 줄인다.
#
# base 외 둘은 **방향 결정용 시안**이다. 채택된 것만 남기고 나머지는 지운다.
#   thicker — 한 단계 더 두껍게
#   sharp   — 스냅과 어택 쪽에 몰고 몸통을 줄인다. 더 날카롭고 타이트하다
PROFILES = {
    # ★ 유리(g_glass)가 **세 구간 모두** 0이 아니다. 공은 항상 유리다.
    #   속도가 오를수록 유리가 세지는 것은 세게 부딪힐수록 유리가 더 우는 것이지,
    #   저속에서 공이 유리가 아니게 되는 것이 아니다.
    # ★ 2026-08-06 형락님: "공은 **구슬이 사물에 부딪친다**고 생각하고 만들어라"
    #
    #   구슬은 작고 **속이 꽉 찬** 유리다. 크고 속 빈 유리공이 아니다.
    #   → 밝고(4~10kHz) 짧고 날카롭다. 저역 몸통이 앞에 나오면 구슬이 아니다.
    #
    #   그래서 주역을 바꾼다. **유리가 앞, 벽 재질이 뒤**다.
    #   이전에는 목재 0.62 / 유리 0.30 으로 나무가 주역이었다 — 나무 블록 소리였다.
    "base": {
        "low": (LOW_GATE, 0.52, 0.06, 0.72, 0.24, 0.16, 0.18, 0),
        "mid": (MID_GATE, 0.34, 0.62, 0.80, 0.30, 0.18, 0.16, 1),
        "high": (HIGH_GATE, 0.22, 0.20, 1.00, 0.26, 0.26, 0.16, 2),
    },
    # 벽 재질을 더 키운 시안. 유리가 묻히는지 비교용.
    "thicker": {
        "low": (LOW_GATE, 0.72, 0.34, 0.24, 0.78, 0.06, 0.34, 0),
        "mid": (MID_GATE, 0.56, 0.86, 0.30, 0.92, 0.09, 0.28, 1),
        "high": (HIGH_GATE, 0.52, 0.60, 0.42, 0.98, 0.14, 0.28, 2),
    },
    "sharp": {
        "low": (LOW_GATE, 0.80, 0.00, 0.34, 0.12, 0.30, 0.10, 0),
        "mid": (MID_GATE, 0.70, 0.24, 0.42, 0.16, 0.40, 0.07, 1),
        "high": (HIGH_GATE, 0.60, 0.14, 0.56, 0.20, 0.52, 0.07, 2),
    },
}


def wall_hit(tier, profile="base"):
    """
    tier: "low" | "mid" | "high"

    저속  = 어택 + 목재 톡
    중속  = 어택 + 목재 톡 + 속 빈 둑
    고속  = 위 + 작은 유리 팅 (p.61 "고속 충돌에만")
    """
    spec = PROFILES[profile][tier]
    gate_spec, g_wood, g_hollow, g_glass, g_thump, g_snap, g_tail, variant = spec

    n = secs(0.20)
    layers = {}

    L_attack = pad_to(common_attack(variant), n)
    dry = L_attack * 1.00
    layers["attack"] = L_attack

    L_snap = pad_to(snap(secs(0.012), variant), n)
    dry = dry + L_snap * g_snap
    layers["snap"] = L_snap * g_snap

    L_thump = pad_to(low_thump(secs(0.045), variant), n)
    dry = dry + L_thump * g_thump
    layers["thump"] = L_thump * g_thump

    L_wood = pad_to(wood_tok(secs(0.060), variant), n)
    dry = dry + L_wood * g_wood
    layers["wood"] = L_wood * g_wood

    if g_hollow > 0.0:
        L_hollow = pad_to(hollow_duk(secs(0.090), variant), n)
        dry = dry + L_hollow * g_hollow
        layers["hollow"] = L_hollow * g_hollow

    if g_glass > 0.0:
        # 주파수는 파일럿과 같다. 공과 벽이 같은 유리 계열로 읽혀야 한다.
        L_glass = pad_to(glass_ting(secs(0.070), WALL_GLASS_MODES, variant), n)
        dry = dry + L_glass * g_glass
        layers["glass"] = L_glass * g_glass

    # 결은 재질 레이어를 따라간다. 목재가 클수록 표면감도 크다.
    L_grain = pad_to(grain(secs(0.090), variant), n) * (g_wood * 0.16)
    dry = dry + L_grain
    layers["grain"] = L_grain

    # 2단 충돌 — 접촉하고 튕기며 다시 닿는다. 어택이 하나뿐이면 죽은 소리로 들린다.
    dry = double_contact(dry, DOUBLE_DELAY[tier], DOUBLE_GAIN[tier])

    # 새추레이션은 잔향 전에 건다. 잔향까지 왜곡되면 지저분해진다.
    dry = soft_clip(dry, DRIVE[tier])

    # 잔향은 "없음 또는 극소량"(p.62). 방 울림이 아니라 재질이 사그라드는 꼬리다.
    wet = signal.fftconvolve(dry, short_tail(n, variant))[:n]
    wet = wet / (np.max(np.abs(wet)) or 1.0)
    L_tail = wet * g_tail
    layers["tail"] = L_tail

    mix = trim_floor(gate(dry + L_tail, *gate_spec))
    keep = len(mix)
    cut = {k: gate(v, *gate_spec)[:keep] for k, v in layers.items()}

    return norm_peak(mix, HIT_PEAK_DBFS), cut


def audition(takes):
    """
    게임이 실제로 하는 처리(피치 ±5%, 속도→음량, 연타 -3dB)를 걸어 이어 붙인다.
    70~90ms 짜리 한 발을 따로 들으면 무조건 밋밋하다. 판단은 리듬 위에서 해야 한다.

    A 구간별 단발  B 저속 8연타  C 속도가 오르내리는 실전 리듬
    """
    rng = np.random.default_rng(9000)
    parts = []

    def place(buf, x, at, gain_db, pitch):
        # 피치는 리샘플로 흉내낸다 (Godot 의 pitch_scale 과 같은 효과)
        idx = np.arange(0, len(x), pitch)
        y = np.interp(idx, np.arange(len(x)), x) * (10.0 ** (gain_db / 20.0))
        s = secs(at)
        e = min(len(buf), s + len(y))
        buf[s:e] += y[:e - s]

    def jitter():
        return 1.0 + rng.uniform(-0.05, 0.05)

    # A. 구간별 단발 — 저 → 중 → 고
    a = np.zeros(secs(2.1))
    for i, t in enumerate(("low", "mid", "high")):
        for r in range(2):
            place(a, takes[t], 0.15 + i * 0.7 + r * 0.30, 0.0, jitter())
    parts.append(a)

    # B. 저속 8연타 — 연타 -3dB 누적, 바닥 -9dB
    b = np.zeros(secs(1.5))
    for i in range(8):
        place(b, takes["low"], 0.12 + i * 0.11, max(-3.0 * i, -9.0), jitter())
    parts.append(b)

    # C. 실전 리듬 — 빠르게 시작해 느려지다 다시 빨라진다
    c = np.zeros(secs(3.4))
    at = 0.15
    for step, (tier, gap, vol) in enumerate([
        ("high", 0.26, 0.0), ("high", 0.22, 0.0), ("mid", 0.30, -2.0),
        ("mid", 0.38, -3.0), ("low", 0.46, -6.0), ("low", 0.52, -9.0),
        ("low", 0.30, -11.0), ("mid", 0.24, -4.0), ("high", 0.28, 0.0),
        ("high", 0.20, 0.0),
    ]):
        place(c, takes[tier], at, vol, jitter())
        at += gap
    parts.append(c)

    gapbuf = np.zeros(secs(0.45))
    out = np.concatenate([p for pair in zip(parts, [gapbuf] * len(parts))
                          for p in pair])
    return np.clip(out, -1.0, 1.0)


def main():
    rows = []
    takes = {}
    for tier in ("low", "mid", "high"):
        mix, lay = wall_hit(tier)
        name = f"SFX_Wall_Hit_{tier.capitalize()}.wav"
        write_wav(OUT / name, mix)
        rows.append((name, measure(mix)))
        takes[tier] = mix
        for k, s in lay.items():
            if np.max(np.abs(s)) <= 0:
                continue
            write_wav(LAYERS / f"Wall_Hit_{tier.capitalize()}__{k}.wav",
                      norm_peak(s, HIT_PEAK_DBFS))

    print(f"{'file':34s} {'len(s)':>8s} {'peak dB':>9s} {'rms dB':>9s} "
          f"{'t_peak ms':>10s} {'t_E50 ms':>9s}")
    for name, m in rows:
        print(f"{name:34s} {m['len_s']:8.4f} {m['peak_dbfs']:9.2f} "
              f"{m['rms_dbfs']:9.2f} {m['t_peak_ms']:10.2f} {m['t_e50_ms']:9.2f}")

    # 규격 자가 검증 — 여기서 걸리면 파일을 게임에 넣지 않는다
    #
    # ★ 길이 기준은 **벽 규격 p.62 의 0.06~0.14** 다.
    #   공 공통 규격(p.42/90)은 0.08~0.20 이라 겹치는 구간이 0.08~0.14 이고,
    #   파일럿(공별 재질음)은 그 겹치는 구간으로 만들었다.
    #   벽 충돌음에 그 하한을 그대로 적용하려면 저속 톡의 감쇠를 크게 늘려야 하는데,
    #   그건 p.61 의 "짧은 목재 톡"과 p.62 의 "잔향 없음 또는 극소량"을 거스른다.
    #   숫자를 맞추려고 소리를 망치는 쪽이라, 자산이 속한 절의 규격을 따른다.
    #   현재 저속 72ms 는 벽 규격 안이고 공 규격 하한(80ms)에는 8ms 못 미친다.
    print()
    ok = True
    for name, m in rows:
        within = 0.08 <= m["len_s"] <= 0.14
        peak_ok = abs(m["peak_dbfs"] - HIT_PEAK_DBFS) < 0.01
        ok = ok and within and peak_ok
        print(f"{name:34s} 길이 {'OK ' if within else '★초과'} "
              f"피크 {'OK' if peak_ok else '★어긋남'}")
    print("규격 검증:", "통과" if ok else "★실패")

    write_wav(AUDITION / "SFX_Wall_audition_base.wav", audition(takes))
    print()
    print("오디션 (A 구간별 단발 / B 저속 8연타 / C 실전 리듬)")
    print("  SFX_Wall_audition_base.wav   ← 게임에 들어간 것")

    # 방향 결정용 시안. 정식 WAV 는 건드리지 않는다.
    for profile in ("thicker", "sharp"):
        alt = {t: wall_hit(t, profile)[0] for t in ("low", "mid", "high")}
        write_wav(AUDITION / f"SFX_Wall_audition_{profile}.wav", audition(alt))
        lens = " / ".join(f"{len(alt[t]) / SR * 1000:.0f}ms"
                          for t in ("low", "mid", "high"))
        print(f"  SFX_Wall_audition_{profile}.wav  ({lens})")

    return rows


if __name__ == "__main__":
    main()
