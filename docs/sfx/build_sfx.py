#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pinball_Logue - 공 SFX ① 형태 단계 (절차적 합성)

가이드 근거
  PDF 6-2  공통 어택 / 공별 재질음 / 결과 레이어 3레이어 구조
  PDF 6-3  정확한 패링 = 탁 + 팅 + 웅(원형 링) 3레이어. 공별로는 2번째만 바꾼다
  PDF 6-4  일반 충돌음 0.08~0.20초, 잔향 짧게, 긴 금속 잔향 금지
  PDF 7-9  정속 태엽눈 = 공통 짧은 탁 + 유리 팅 + 작은 태엽 클릭. 피치 편차 작게
           패링 = 명확한 탁 + 밝은 유리 팅 + 짧은 종 1음 + 원형 파동음
  75쪽가이드 11.1  길이 0.06~0.14초, 피치 ±5%, 패링 대비 -8~-10dB,
           연속 충돌 두 번째부터 약 3dB 감소

설계 원칙
  * 어택 트랜지언트와 총 길이는 절차적으로 확정한다 (AI에 맡기지 않는다)
  * 공통 어택은 5종이 "완전히 같은 파형"을 공유한다 (PDF 6-2)
  * 재질 레이어는 layers/ 에 따로 떨어뜨려, ② 텍스처 단계에서 통째로 교체 가능
  * 피치 ±5% 랜덤은 파일에 굽지 않는다 → Godot AudioStreamPlayer.pitch_scale 런타임 처리
"""

import numpy as np
from scipy import signal
from scipy.io import wavfile
from pathlib import Path

SR = 48000

# 대상별로 폴더를 나눈다. 한 폴더에 다 쌓으면 어느 소리가 어느 계열인지 안 보인다.
#   ROOT/ball  wall  flipper  audition  layers/<대상>  prompts  raw
ROOT = Path(__file__).resolve().parent
OUT = ROOT / "ball"
LAYERS = ROOT / "layers" / "ball"
AUDITION = ROOT / "audition"
for _d in (OUT, LAYERS, AUDITION):
    _d.mkdir(parents=True, exist_ok=True)

# 목표 라우드니스 (75쪽 가이드 11.1: 충돌은 패링 대비 -8~-10dB)
PARRY_PEAK_DBFS = -1.0
HIT_PEAK_DBFS = -10.0          # 차이 9dB

# 총 길이 게이트 (초). 페이드로 강제해서 길이를 수치로 확정한다
# 길이 상한 게이트 (유지 끝, 완전 소멸). 실제 길이는 trim_floor 가 -60dBFS 로 잘라서 정한다
HIT_GATE = (0.100, 0.140)      # 75쪽 가이드 11.1 상한 0.14초를 넘지 못하게
PARRY_GATE = (0.170, 0.300)
ATTACK_GATE = (0.018, 0.032)


# ----------------------------------------------------------------- 기본 도구
def tt(n):
    return np.arange(n) / SR


def secs(d):
    return int(round(SR * d))


def env_exp(n, tau, attack=0.00025):
    """지수 감쇠 + 아주 짧은 어택 램프(DC 튐 방지)."""
    t = tt(n)
    e = np.exp(-t / tau)
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def modal(n, modes, seed=0):
    """감쇠 사인 합 — (주파수, 진폭, 감쇠상수) 리스트."""
    rng = np.random.default_rng(seed)
    t = tt(n)
    y = np.zeros(n)
    for f, a, tau in modes:
        ph = rng.uniform(0, 2 * np.pi)
        y += a * np.sin(2 * np.pi * f * t + ph) * env_exp(n, tau)
    return y


def band_noise(n, lo, hi, tau, seed=0, order=2):
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(n)
    nyq = SR / 2
    lo = max(20.0, min(lo, nyq * 0.98))
    hi = max(lo + 20.0, min(hi, nyq * 0.98))
    b, a = signal.butter(order, [lo / nyq, hi / nyq], btype="band")
    x = signal.lfilter(b, a, x)
    x *= env_exp(n, tau)
    m = np.max(np.abs(x))
    return x / m if m > 0 else x


def gate(x, hold, fall):
    """hold초까지 그대로 두고 fall초에 0이 되도록 코사인 페이드. 길이 상한을 강제한다."""
    n = secs(fall)
    y = np.zeros(n)
    m = min(len(x), n)
    y[:m] = x[:m]
    h = secs(hold)
    if h < n:
        k = np.arange(n - h) / (n - h)
        y[h:] *= 0.5 * (1.0 + np.cos(np.pi * k))
    return y


def trim_floor(x, floor_db=-60.0, fade_ms=2.0):
    """
    -60 dBFS 아래로 떨어진 뒤는 잘라낸다.
    게이트만 쓰면 파일 뒤가 무음으로 채워져 '길이'가 실제보다 길게 보고된다.
    """
    peak = np.max(np.abs(x))
    if peak <= 0:
        return x
    thr = peak * (10.0 ** (floor_db / 20.0))
    idx = np.where(np.abs(x) > thr)[0]
    end = int(idx[-1]) + 1 if len(idx) else len(x)
    f = secs(fade_ms / 1000.0)
    end = min(len(x), end + f)
    y = x[:end].copy()
    if f < len(y):
        y[-f:] *= 0.5 * (1.0 + np.cos(np.pi * np.linspace(0, 1, f)))
    return y


def norm_peak(x, dbfs):
    m = np.max(np.abs(x))
    if m <= 0:
        return x
    return x / m * (10.0 ** (dbfs / 20.0))


def write_wav(path, x):
    y = np.clip(x, -1.0, 1.0)
    wavfile.write(str(path), SR, (y * 32767.0).astype(np.int16))
    return path


def measure(x):
    peak = np.max(np.abs(x))
    rms = float(np.sqrt(np.mean(x ** 2)))
    # 어택 시간: 피크의 90%에 처음 도달하는 시각
    idx = int(np.argmax(np.abs(x)))
    # 에너지의 50%가 쌓이는 시각 = 소리의 무게중심
    e = np.cumsum(x ** 2)
    c50 = int(np.searchsorted(e, e[-1] * 0.5))
    return {
        "len_s": len(x) / SR,
        "peak_dbfs": 20 * np.log10(peak) if peak > 0 else -np.inf,
        "rms_dbfs": 20 * np.log10(rms) if rms > 0 else -np.inf,
        "t_peak_ms": idx / SR * 1000.0,
        "t_e50_ms": c50 / SR * 1000.0,
    }


# ------------------------------------------------- 레이어 1: 공통 어택 (5종 공유)
def common_attack(variant=0):
    """
    PDF 6-2 '공통 어택 — 짧은 톡/탁, 명확한 초기 어택.
    공 종류가 달라도 충돌 시점을 인지하는 기준은 유지한다.'
    → 5종이 이 파형을 그대로 공유한다. 변종 3개는 연타 반복감만 없애는 용도.
    """
    n = secs(0.020)
    seed = 1000 + variant
    click = band_noise(n, 1200, 5400, 0.0028, seed=seed)
    # 나무·장난감 느낌의 몸통 (금속 쾅 금지 → 저역은 짧게)
    body = np.sin(2 * np.pi * (168.0 + variant * 3.0) * tt(n)) * env_exp(n, 0.0062)
    y = click * 0.90 + body * 0.42
    return y / np.max(np.abs(y))


# ------------------------------------- 레이어 2: 공별 재질음 (정속 태엽눈 = 태엽 클릭)
# 황동 이스케이프먼트 클릭. 비조화 모드 4개, 전부 짧다 (긴 금속 잔향 금지)
CLOCKWORK_MODES = [
    (3180.0, 1.00, 0.0265),
    (4730.0, 0.70, 0.0205),
    (6920.0, 0.44, 0.0142),
    (9140.0, 0.26, 0.0096),
]
# 유리 팅 — 일반 충돌에서는 작게, 패링에서는 밝게
GLASS_MODES_HIT = [
    (5420.0, 1.00, 0.0330),
    (7310.0, 0.58, 0.0250),
    (9830.0, 0.32, 0.0180),
]
GLASS_MODES_PARRY = [
    (5420.0, 1.00, 0.0720),
    (7310.0, 0.62, 0.0560),
    (9830.0, 0.36, 0.0400),
]
# 짧은 종 1음 (앰버·황동). 음정이 하나로 읽히도록 거의 조화 배열
BELL_MODES = [
    (1178.0, 0.50, 0.0620),
    (2356.0, 1.00, 0.0640),
    (3540.0, 0.40, 0.0430),
    (4712.0, 0.22, 0.0300),
    (6300.0, 0.12, 0.0210),
]


def detune(modes, cents):
    r = 2.0 ** (cents / 1200.0)
    return [(f * r, a, tau) for f, a, tau in modes]


def clockwork_material(variant=0):
    """태엽 클릭 = 톱니 걸림쇠 딸깍(초단타 노이즈) + 황동 모드."""
    n = secs(0.060)
    # 피치 편차는 작게 유지 (PDF 7-9) → ±12센트 (약 ±0.7%)
    cents = (-12.0, 0.0, 12.0)[variant % 3]
    detent = band_noise(n, 4200, 11000, 0.0014, seed=2000 + variant) * 0.55
    brass = modal(n, detune(CLOCKWORK_MODES, cents), seed=2100 + variant)
    y = detent + brass
    return y / np.max(np.abs(y))


def glass_ting(n, modes, variant=0, cents=0.0):
    y = modal(n, detune(modes, cents), seed=3000 + variant)
    return y / np.max(np.abs(y))


def short_tail(n, seed=0):
    """결과 레이어 = 짧은 잔향. 방 울림이 아니라 '재질이 사그라드는 꼬리'."""
    rng = np.random.default_rng(4000 + seed)
    ir_n = secs(0.030)
    ir = rng.standard_normal(ir_n) * np.exp(-tt(ir_n) / 0.0085)
    ir[0] = 0.0
    return ir / np.max(np.abs(ir))


# ------------------------------------------------------------- 조립: 일반 충돌
def clockwork_hit(variant=0):
    n = secs(0.20)

    def pad(x):
        y = np.zeros(n)
        m = min(len(x), n)
        y[:m] = x[:m]
        return y

    L_attack = pad(common_attack(variant))
    L_material = pad(clockwork_material(variant))
    L_glass = pad(glass_ting(secs(0.080), GLASS_MODES_HIT, variant,
                             cents=(-12.0, 0.0, 12.0)[variant % 3]))

    dry = L_attack * 1.00 + L_material * 0.62 + L_glass * 0.21
    wet = signal.fftconvolve(dry, short_tail(n, variant))[:n]
    wet = wet / (np.max(np.abs(wet)) or 1.0)
    L_tail = wet * 0.13

    mix = trim_floor(gate(dry + L_tail, *HIT_GATE))
    keep = len(mix)
    layers = {
        "attack": gate(L_attack, *HIT_GATE)[:keep],
        "material": gate(L_material * 0.62, *HIT_GATE)[:keep],
        "glass": gate(L_glass * 0.21, *HIT_GATE)[:keep],
        "tail": gate(L_tail, *HIT_GATE)[:keep],
    }
    return norm_peak(mix, HIT_PEAK_DBFS), layers


# --------------------------------------------------------------- 조립: 패링
def ring_wave():
    """원형 파동음 '웅/팡' — VFX 파동(0.12~0.20초)에 맞춘 하강 처프 + 저역 팡."""
    n = secs(0.220)
    t = tt(n)
    f0, f1 = 820.0, 255.0
    k = np.log(f1 / f0) / t[-1]
    phase = 2 * np.pi * f0 * (np.exp(k * t) - 1.0) / k
    chirp = np.sin(phase) * env_exp(n, 0.062, attack=0.0060)
    pang = band_noise(n, 180, 1150, 0.030, seed=5000) * 0.55
    y = chirp * 0.85 + pang
    return y / np.max(np.abs(y))


def clockwork_parry():
    n = secs(0.36)

    def pad(x):
        y = np.zeros(n)
        m = min(len(x), n)
        y[:m] = x[:m]
        return y

    # 레이어 1: 플리퍼와 맞닿은 '명확한 탁' — 공통 어택을 세게, 약간 더 두껍게
    a = common_attack(0)
    thick = band_noise(secs(0.026), 700, 3600, 0.0055, seed=5100) * 0.45
    L_tak = pad(np.pad(a, (0, max(0, len(thick) - len(a))))[:max(len(a), len(thick))]
                + np.pad(thick, (0, max(0, len(a) - len(thick))))[:max(len(a), len(thick))])
    L_tak = L_tak / np.max(np.abs(L_tak))

    # 레이어 2 (★ 공별로 바뀌는 유일한 레이어): 밝은 유리 팅 + 짧은 종 1음
    L_glass = pad(glass_ting(secs(0.20), GLASS_MODES_PARRY, 0))
    L_bell = pad(modal(secs(0.28), BELL_MODES, seed=5200))
    L_bell = L_bell / np.max(np.abs(L_bell))
    L_material = L_glass * 0.55 + L_bell * 0.72
    L_material = L_material / np.max(np.abs(L_material))

    # 레이어 3: 원형 파동음
    L_ring = pad(ring_wave())

    # 밸런스: 유리 팅·종(레이어2)이 파동(레이어3)에 먹히면 '밝은 성공음'으로 안 읽힌다.
    # 1차 시안은 스펙트럼 중심 1939Hz 로 저역 파동이 지배해서 링 게인을 0.40 → 0.26 으로 낮췄다.
    mix = trim_floor(gate(L_tak * 1.00 + L_material * 0.98 + L_ring * 0.26, *PARRY_GATE))
    keep = len(mix)
    layers = {
        "tak": gate(L_tak, *PARRY_GATE)[:keep],
        "material": gate(L_material * 0.98, *PARRY_GATE)[:keep],
        "ring": gate(L_ring * 0.26, *PARRY_GATE)[:keep],
    }
    return norm_peak(mix, PARRY_PEAK_DBFS), layers


# --------------------------------------------------------------------- 실행
def main():
    rows = []

    # 공통 어택 3종 (5종 공유 — 파일도 공용 이름)
    for v in range(3):
        x = norm_peak(trim_floor(gate(common_attack(v), *ATTACK_GATE)), HIT_PEAK_DBFS)
        p = write_wav(OUT / f"SFX_Ball_Common_Attack_{v+1:02d}.wav", x)
        rows.append((p.name, measure(x)))

    # 정속 태엽눈 일반 충돌 3종 (75쪽 가이드 11.1 '기본 음원 3종')
    for v in range(3):
        mix, lay = clockwork_hit(v)
        p = write_wav(OUT / f"SFX_Ball_Clockwork_Hit_{v+1:02d}.wav", mix)
        rows.append((p.name, measure(mix)))
        for k, s in lay.items():
            write_wav(LAYERS / f"Clockwork_Hit_{v+1:02d}__{k}.wav",
                      norm_peak(s, HIT_PEAK_DBFS) if np.max(np.abs(s)) > 0 else s)

    # 정속 태엽눈 패링 악센트 1종
    mix, lay = clockwork_parry()
    p = write_wav(OUT / "SFX_Ball_Clockwork_Parry_01.wav", mix)
    rows.append((p.name, measure(mix)))
    for k, s in lay.items():
        write_wav(LAYERS / f"Clockwork_Parry_01__{k}.wav", norm_peak(s, PARRY_PEAK_DBFS))

    print(f"{'file':40s} {'len(s)':>8s} {'peak dB':>9s} {'rms dB':>9s} "
          f"{'t_peak ms':>10s} {'t_E50 ms':>9s}")
    for name, m in rows:
        print(f"{name:40s} {m['len_s']:8.4f} {m['peak_dbfs']:9.2f} "
              f"{m['rms_dbfs']:9.2f} {m['t_peak_ms']:10.2f} {m['t_e50_ms']:9.2f}")
    return rows


if __name__ == "__main__":
    main()
