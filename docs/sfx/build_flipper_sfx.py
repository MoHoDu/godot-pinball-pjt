#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pinball_Logue - 플리퍼 SFX ① 형태 단계 (절차적 합성)

가이드 근거
  p.20  2-4 플리퍼 사운드
          선택      짧은 딸깍음 · 단추음 · 나무 블록음
          작동      스프링 압축음 + 짧은 휙 소리
          일반 타격  단단한 톡 / 탁
          강한 타격  금속성 쾅보다 탄력 있는 쫙 / 팡
          정확한 패링 명쾌한 탁 소리
          복귀      작은 태엽 떨림
        ★ 선택음과 작동음은 **분명히 달라야 한다**
        ★ 반복 입력해도 커지지 않도록 연속 재생 시 일부 레이어를 줄인다
  p.41  3-10  플리퍼 일반 타격 = 명확한 탁 + 짧은 휙
  p.42  3-12  우선순위: 패링 > 보스 > **플리퍼 타격** > 공·범퍼 > 벽 > 환경음
  p.61  7-2   ★ 벽 충돌에 "플리퍼·패링과 동일한 어택"을 쓰지 않는다
  p.43  MUST  플리퍼 타격 SFX

★ 벽과의 구분을 어디서 만드는가
  벽 충돌음은 공통 어택(band 1.2~5.4kHz)을 쓴다. 플리퍼는 그걸 쓰지 않는다.
  - 어택 자체를 더 낮고 단단하게 잡는다 (고무·나무 쪽, 700~3.8kHz)
  - **휙(공기 가르는 소리)을 얹는다.** 벽에는 없는 레이어라 이것만으로도 갈린다
  - 플리퍼는 스스로 움직여서 때리는 물체다. 벽은 가만히 있다. 그 차이를 소리로 옮긴다

★ 수치 근거 (기획서에 플리퍼 길이·dB 수치가 없다)
  가이드는 플리퍼에 대해 음색만 규정하고 숫자를 주지 않는다.
  대신 **상대 규칙**은 준다 — 우선순위(p.42)와 "벽은 패링·플리퍼보다 작고 짧게"(p.61).
  그래서 이미 확정된 두 끝점 사이에 끼워 넣는다.
      벽 충돌  91~106ms  peak -10dBFS   (확정)
      패링     267ms     peak  -1dBFS   (확정)
  이 표의 값은 **우리가 잡은 것**이다. 형락님 검수 대상이다.
"""

import numpy as np
from scipy import signal

from build_sfx import (
    SR, ROOT, AUDITION,
    secs, tt, env_exp, band_noise, gate, trim_floor, norm_peak,
    write_wav, measure, short_tail, detune, ring_wave, GLASS_MODES_PARRY,
)

# 출력 폴더 (build_sfx 의 ball/ 과 나눠 쓴다)
OUT = ROOT / "flipper"
LAYERS = ROOT / "layers" / "flipper"
for _d in (OUT, LAYERS):
    _d.mkdir(parents=True, exist_ok=True)
from build_wall_sfx import modal_glide, soft_clip, grain, WALL_GLASS_MODES

# (피크 dBFS, 게이트 hold, 게이트 fall)
# 우선순위상 플리퍼 타격은 벽(-10)보다 크고 패링(-1)보다 작아야 한다.
SPECS = {
    "Select": (-14.0, 0.030, 0.055),   # 조작 확인음. 작아야 한다. 연타로 눌린다
    "Activate": (-9.0, 0.060, 0.105),  # 선택음보다 크고 확실히 다른 음색
    "Hit": (-4.0, 0.095, 0.150),       # MUST. 벽보다 크고 길다
    "StrongHit": (-2.5, 0.120, 0.185),  # 탄력 있는 쫙/팡. 금속 쾅이 아니다
    "Return": (-16.0, 0.080, 0.130),   # 작은 태엽 떨림. 있는 줄 모를 만큼 작게
    "Parry": (-1.0, 0.130, 0.240),     # 우선순위 1위(p.42). 전체에서 가장 크고 길다
}

# 패링 2번째 레이어에 쓰는 밝은 유리 팅.
# ★ 여기가 **공별로 갈아끼우는 유일한 자리**다 (p.90 6-3).
#   1번(탁)과 3번(원형 파동)은 모든 공이 공유한다.
#   이 파일이 만드는 것은 그 공용 3레이어의 기준본이다.
PARRY_GLASS_MODES = GLASS_MODES_PARRY

# ★ 짧은 유리 팅.
#   GLASS_MODES_PARRY 는 tau 가 0.040~0.072 로 폭(0.030)의 두 배가 넘는다.
#   게인을 0.18 까지 낮춰도 시간이 지나며 에너지를 다 먹어, 주음이 폭(1184Hz)이
#   아니라 유리(5420Hz)로 잡혔다(실측). 감쇠를 줄여야 주역이 바뀐다.
SHORT_GLASS_MODES = [(f, a, tau * 0.45) for f, a, tau in GLASS_MODES_PARRY]

# ★ 2026-08-06 형락님 방향: "플리퍼가 공을 치는 소리는 **유리로 된 탁구공**을 치는 느낌"
#
#   가볍고 · 속이 비었고 · 밝다. 무거운 물체의 낮은 쿵이 아니다.
#   그래서 기본음을 1.8kHz 대로 올리고 감쇠를 짧게 잡는다.
#   가벼운 물체일수록 고유진동수가 높고 빨리 죽는다 — 그게 "가볍다"로 들리는 이유다.
#
#   이력: 486Hz → 저역 84% 로 둔탁 / 742Hz → 여전히 나무 쪽 / 1840Hz → 유리 탁구공
TAK_MODES = [
    (1840.0, 1.00, 0.0118),
    (2757.0, 0.66, 0.0087),
    (4118.0, 0.38, 0.0064),
    (6180.0, 0.20, 0.0045),
]

# 같은 유리 공을 **더 세게** 친 것. 밝기는 유지하고 몸통과 길이만 조금 늘린다.
# 낮추면 p.20 이 금지한 "금속성 쾅"으로 넘어간다. 강함은 저역이 아니라 배음으로 만든다.
PANG_MODES = [
    (1520.0, 1.00, 0.0168),
    (2356.0, 0.72, 0.0124),
    (3610.0, 0.44, 0.0091),
    (5480.0, 0.24, 0.0065),
]

# ★ 2026-08-06 형락님 방향: "패링은 **리듬천국 탁구** 같은 소리로"
#
#   기획서 p.20 이 플리퍼 사운드 레퍼런스로 "리듬 세상 — 돌아온 리듬 랠리"를
#   직접 지목한다. 리듬 랠리가 그 탁구 게임이다. 우연이 아니라 원래 방향이었다.
#
#   그 소리의 정체는 **음정이 있는 깨끗한 폭** 이다. 잡음이 아니라 거의 악기다.
#   그래서 다른 충돌음과 정반대로 만든다.
#     - 다른 충돌음: **비조화** 배열 (음정으로 안 읽히게)
#     - 이 소리:     **조화** 배열 (음정이 하나로 또렷하게 읽히게)
#   배음을 정수배로 두는 것이 "장난감스럽고 깨끗한" 인상의 정체다.
PONG_MODES = [
    (1184.0, 1.00, 0.0300),
    (2368.0, 0.42, 0.0140),
    (3552.0, 0.18, 0.0092),
    (4736.0, 0.08, 0.0062),
]

# 단추·나무 블록. 아주 짧고 건조하다.
BUTTON_MODES = [
    (1620.0, 1.00, 0.0052),
    (2480.0, 0.54, 0.0038),
    (3610.0, 0.26, 0.0027),
]

# 복귀 태엽 떨림. 작은 황동 딸깍이 몇 번.
TREMBLE_MODES = [
    (2870.0, 1.00, 0.0042),
    (4310.0, 0.52, 0.0031),
    (6120.0, 0.24, 0.0022),
]


def pad_to(x, n):
    y = np.zeros(n)
    m = min(len(x), n)
    y[:m] = x[:m]
    return y


def swept_noise(n, f_start, f_end, sweep_time, tau, seed=0, bands=8):
    """
    중심 주파수가 시간에 따라 이동하는 노이즈 = 공기를 가르는 '휙'.

    ★ 이 레이어가 벽 충돌음과 플리퍼를 가르는 핵심이다.
      벽은 가만히 있는 물체라 휙 소리가 날 이유가 없다.
    """
    y = np.zeros(n)
    t = tt(n)
    width = max(sweep_time * 0.30, 1.0 / SR)
    for k in range(bands):
        frac = k / (bands - 1)
        fc = f_start * (f_end / f_start) ** frac
        band = band_noise(n, fc * 0.70, fc * 1.42, tau, seed=seed + k, order=1)
        # 이 밴드가 열리는 시각을 순서대로 밀어 스윕을 만든다
        w = np.exp(-((t - sweep_time * frac) ** 2) / (2.0 * width ** 2))
        y += band * w
    m = np.max(np.abs(y))
    return y / m if m > 0 else y


def spring_press(n, seed=0):
    """스프링 압축음 — 음정이 **올라가는** 끽. 충돌음은 전부 내려가므로 확실히 갈린다."""
    t = tt(n)
    # 위로 글라이드 (+320센트)
    g = 2.0 ** (320.0 / 1200.0) - 1.0
    warp = t + (-g) * 0.030 * (1.0 - np.exp(-t / 0.030))
    coil = np.zeros(n)
    for f, a, tau in [(586.0, 1.00, 0.030), (1172.0, 0.42, 0.022), (1758.0, 0.20, 0.016)]:
        coil += a * np.sin(2 * np.pi * f * warp) * env_exp(n, tau, attack=0.0016)
    creak = band_noise(n, 1500, 5200, 0.0135, seed=8100 + seed, order=1) * 0.42
    y = coil + creak
    return y / np.max(np.abs(y))


def tremble(n, seed=0):
    """작은 태엽 떨림 — 아주 작은 딸깍 네 번이 잦아든다."""
    rng = np.random.default_rng(8200 + seed)
    y = np.zeros(n)
    at = 0.0
    for i in range(4):
        tick = modal_glide(secs(0.020), detune(TREMBLE_MODES, i * 7.0),
                           -40.0, 0.006, seed=8300 + seed * 10 + i)
        tick = tick / np.max(np.abs(tick)) * (0.62 ** i)
        s = secs(at)
        e = min(n, s + len(tick))
        y[s:e] += tick[:e - s]
        at += rng.uniform(0.019, 0.027)
    return y / np.max(np.abs(y))


def assemble(name, layers, tail_gain, drive):
    """레이어를 섞고 게이트·트림·피크 정규화까지 한 번에."""
    peak_db, hold, fall = SPECS[name]
    n = secs(0.30)

    dry = np.zeros(n)
    kept = {}
    for key, (sig, gain) in layers.items():
        padded = pad_to(sig, n) * gain
        dry = dry + padded
        kept[key] = padded

    dry = soft_clip(dry, drive)

    wet = signal.fftconvolve(dry, short_tail(n, 0))[:n]
    wet = wet / (np.max(np.abs(wet)) or 1.0)
    L_tail = wet * tail_gain
    kept["tail"] = L_tail

    mix = trim_floor(gate(dry + L_tail, hold, fall))
    keep = len(mix)
    cut = {k: gate(v, hold, fall)[:keep] for k, v in kept.items()}
    return norm_peak(mix, peak_db), cut


def flipper_select():
    """짧은 딸깍음 · 단추음 · 나무 블록음 (p.20)."""
    n = secs(0.060)
    return assemble("Select", {
        "click": (band_noise(n, 2200, 8200, 0.0011, seed=8000), 0.90),
        "button": (modal_glide(n, BUTTON_MODES, -60.0, 0.005, seed=8010), 0.62),
    }, tail_gain=0.07, drive=1.6)


def flipper_activate():
    """스프링 압축음 + 짧은 휙 (p.20). 선택음과 **분명히** 달라야 한다."""
    n = secs(0.120)
    return assemble("Activate", {
        "spring": (spring_press(n, seed=0), 1.00),
        "whoosh": (swept_noise(n, 380.0, 2400.0, 0.052, 0.024, seed=8400), 0.46),
    }, tail_gain=0.10, drive=1.8)


def flipper_hit(strong=False):
    """
    일반 타격 = 단단한 톡/탁 + 짧은 휙 (p.20, p.41)
    강한 타격 = 금속 쾅이 아니라 탄력 있는 쫙/팡 (p.20)

    ★ 2026-08-06 형락님 지시: **기존 패링음을 일반 타격음 자리로 옮긴다.**
      그 소리(두꺼운 탁 + 밝은 유리 팅)가 타격에 더 어울린다는 판단이다.

      그래서 패링의 레이어 구성을 그대로 가져오되 **원형 파동은 빼고** 온다.
      원형 파동은 기획서가 "정확한 패링의 고유 언어"로 못 박은 것이라(p.38)
      일반 타격이 가져가면 패링과 구분이 사라진다. 언어는 패링에 남긴다.

      길이·음량은 Hit 규격(-4dBFS / 0.095~0.150초)을 그대로 쓴다.
      음색만 옮기는 것이지 서열을 옮기는 게 아니다.
    """
    n = secs(0.220)
    name = "StrongHit" if strong else "Hit"

    # 어택을 여기서 직접 만든다. 벽의 공통 어택을 쓰지 않는다 (p.61)
    # 패링에서 쓰던 "두꺼운 탁" 구성이다 — 얇은 어택 + 낮은 대역 두께.
    attack = band_noise(n, 700, 3800, 0.0040, seed=8500 + int(strong))
    thick = band_noise(n, 420, 2100, 0.0062, seed=8510 + int(strong)) * 0.52

    body = modal_glide(n, PANG_MODES if strong else TAK_MODES,
                       -120.0 if strong else -80.0, 0.014,
                       seed=8600 + int(strong))
    whoosh = swept_noise(n, 520.0, 2900.0, 0.038, 0.020, seed=8700 + int(strong))
    tex = grain(n, seed=20 + int(strong))

    # ★ 공은 구슬이다. 벽에 부딪히든 플리퍼에 맞든 유리 성분은 항상 있다.
    #   패링에서 쓰던 **밝은 유리 팅**(GLASS_MODES_PARRY)을 여기로 가져온다.
    #   벽 충돌의 짧은 유리보다 길고 밝아서 "플리퍼가 제대로 받았다"가 읽힌다.
    bright_glass = modal_glide(n, SHORT_GLASS_MODES, -30.0, 0.020,
                               seed=8750 + int(strong))
    bright_glass = bright_glass / np.max(np.abs(bright_glass))

    return assemble(name, {
        "tak": (attack + thick, 1.00),
        "body": (body, 0.62 if strong else 0.76),
        "bright_glass": (bright_glass, 0.46 if strong else 0.42),
        "whoosh": (whoosh, 0.52 if strong else 0.42),
        "grain": (tex, 0.13),
    }, tail_gain=0.17 if strong else 0.14, drive=2.4 if strong else 2.2)


def flipper_parry():
    """
    정확한 패링 — 공용 3레이어 (p.90 6-3, p.41 3-10)

      ① 플리퍼와 공이 맞닿은 **명확한 탁**   ← 공용
      ② 성공을 전달하는 **밝은 유리 팅**     ← 공별로 갈아끼우는 자리
      ③ 원형 링이 퍼지는 **짧은 웅/팡**      ← 공용

    ★ 일반 타격과 반드시 구분한다 (p.42 3-11).
      "일반 타격보다 어택이 선명함 / 중앙에 밝은 유리 팅 / 바깥으로 퍼지는 짧은 충격음"
      → 타격과 같은 탁을 쓰되 **더 두껍고 선명하게** 하고, ②③을 얹어 갈라놓는다.

    ★ 원형 파동은 VFX ③ 과 같은 언어다. 지속 0.12~0.20초 파동에 맞춰 길이를 잡았다.

    ★ 2026-08-06 형락님 지시: **리듬천국 탁구 같은 소리로.**
      기획서 p.20 이 플리퍼 사운드 레퍼런스로 "리듬 세상 — 돌아온 리듬 랠리"를
      직접 지목한다. 리듬 랠리가 그 탁구 게임이라 원래 방향과 같다.

      그 소리의 정체는 **음정이 있는 깨끗한 폭** 이다. 잡음이 아니라 거의 악기다.
      그래서 이 소리만 다른 충돌음과 정반대로 만든다.

        다른 충돌음: 비조화 모드 + 노이즈 + 결 + 새추레이션 (재질을 들려준다)
        이 소리:     조화 모드 중심 + 노이즈 최소 + 새추레이션 낮게 (음정을 들려준다)

      ①탁은 **아주 짧은 점화**로만 남긴다. 두꺼운 탁은 일반 타격으로 넘어갔다.
      ②는 폭의 음정을 받쳐주는 밝은 팅으로 얇게.
      ③원형 파동은 패링의 고유 언어라 유지하되, 폭이 묻히지 않게 낮춘다.
    """
    n = secs(0.360)

    # ① 점화 — 깨끗한 폭의 머리. 두께를 주지 않는다. 두꺼우면 타격음이 된다
    click = band_noise(n, 1800, 7200, 0.0016, seed=8900)

    # ★ 리듬 랠리의 폭 — 조화 배열이라 음정이 하나로 또렷하게 읽힌다.
    #   글라이드를 거의 주지 않는다. 음정이 흔들리면 "악기"가 아니라 "충돌"이 된다
    pong = modal_glide(n, PONG_MODES, -18.0, 0.010, seed=8905, beat_cents=2.5)
    pong = pong / np.max(np.abs(pong))

    # ② 폭을 받치는 밝은 팅 (공별 악센트 자리). 얇게 얹는다
    glass = modal_glide(n, SHORT_GLASS_MODES, -30.0, 0.020, seed=8930)
    glass = glass / np.max(np.abs(glass))

    # ③ 원형 파동 — 패링의 고유 언어. 폭을 가리지 않을 만큼만
    ring = ring_wave()

    return assemble("Parry", {
        "click": (click, 0.44),
        "pong": (pong, 1.00),
        "glass": (glass, 0.12),
        "ring": (ring, 0.12),
    }, tail_gain=0.10, drive=1.5)


def flipper_return():
    """복귀 — 작은 태엽 떨림 (p.20). 있는 줄 모를 만큼 작아야 한다."""
    n = secs(0.140)
    return assemble("Return", {
        "tremble": (tremble(n, seed=0), 1.00),
        "air": (band_noise(n, 900, 3400, 0.0090, seed=8800, order=1), 0.16),
    }, tail_gain=0.09, drive=1.5)


def audition(takes):
    """
    실제 조작 흐름으로 이어 붙인다.
    A 선택 3연타  B 선택 → 작동 → 타격 → 복귀  C 강타와 연타 감쇠
    """
    rng = np.random.default_rng(9100)
    out = []

    def place(buf, x, at, gain_db=0.0, pitch=1.0):
        idx = np.arange(0, len(x), pitch)
        y = np.interp(idx, np.arange(len(x)), x) * (10.0 ** (gain_db / 20.0))
        s = secs(at)
        e = min(len(buf), s + len(y))
        buf[s:e] += y[:e - s]

    def jit():
        return 1.0 + rng.uniform(-0.05, 0.05)

    # A. 선택음만 3연타 — 작동음과 헷갈리지 않는지
    a = np.zeros(secs(1.3))
    for i in range(3):
        place(a, takes["Select"], 0.15 + i * 0.28, 0.0, jit())
    out.append(a)

    # B. 같은 Space 입력이 세 갈래로 갈리는지 — 이게 이 오디션의 핵심이다
    #    ① 헛침(작동만) ② 일반 타격 ③ 정확한 패링
    b = np.zeros(secs(3.4))
    place(b, takes["Select"], 0.12, 0.0, jit())
    # ① 공을 못 맞힘 — 작동음만
    place(b, takes["Activate"], 0.50, 0.0, jit())
    place(b, takes["Return"], 0.72, 0.0, jit())
    # ② 일반 타격
    place(b, takes["Activate"], 1.25, 0.0, jit())
    place(b, takes["Hit"], 1.32, 0.0, jit())
    place(b, takes["Return"], 1.54, 0.0, jit())
    # ③ 정확한 패링
    place(b, takes["Activate"], 2.10, 0.0, jit())
    place(b, takes["Parry"], 2.17, 0.0, jit())
    place(b, takes["Return"], 2.48, 0.0, jit())
    # 강한 타격
    place(b, takes["Activate"], 2.85, 0.0, jit())
    place(b, takes["StrongHit"], 2.92, 0.0, jit())
    out.append(b)

    # C. 반복 입력 — p.20 "연속 재생 시 일부 레이어를 줄인다"를 -3dB 누적으로 흉내
    c = np.zeros(secs(2.4))
    at = 0.12
    for i in range(7):
        place(c, takes["Activate"], at, max(-3.0 * i, -9.0), jit())
        place(c, takes["Hit"], at + 0.07, max(-3.0 * i, -9.0), jit())
        at += 0.30
    out.append(c)

    gapbuf = np.zeros(secs(0.45))
    y = np.concatenate([p for pair in zip(out, [gapbuf] * len(out)) for p in pair])
    return np.clip(y, -1.0, 1.0)


def main():
    builds = {
        "Select": flipper_select(),
        "Activate": flipper_activate(),
        "Hit": flipper_hit(False),
        "StrongHit": flipper_hit(True),
        "Parry": flipper_parry(),
        "Return": flipper_return(),
    }

    rows = []
    takes = {}
    for name, (mix, lay) in builds.items():
        path = OUT / f"SFX_Flipper_{name}.wav"
        write_wav(path, mix)
        rows.append((path.name, measure(mix)))
        takes[name] = mix
        for k, s in lay.items():
            if np.max(np.abs(s)) <= 0:
                continue
            write_wav(LAYERS / f"Flipper_{name}__{k}.wav", norm_peak(s, SPECS[name][0]))

    print(f"{'file':34s} {'len(s)':>8s} {'peak dB':>9s} {'rms dB':>9s} "
          f"{'t_peak ms':>10s} {'t_E50 ms':>9s}")
    for name, m in rows:
        print(f"{name:34s} {m['len_s']:8.4f} {m['peak_dbfs']:9.2f} "
              f"{m['rms_dbfs']:9.2f} {m['t_peak_ms']:10.2f} {m['t_e50_ms']:9.2f}")

    # 자가 검증 — 우선순위(p.42)와 "벽은 플리퍼보다 작고 짧게"(p.61)
    print()
    lens = {n.split("_")[2].split(".")[0]: m["len_s"] for n, m in rows}
    peaks = {n.split("_")[2].split(".")[0]: m["peak_dbfs"] for n, m in rows}
    checks = [
        ("타격 > 벽 (크기)", peaks["Hit"] > -10.0),
        ("타격 > 벽 (길이)", lens["Hit"] > 0.106),
        ("패링이 가장 크다", peaks["Parry"] == max(peaks.values())),
        ("패링이 가장 길다", lens["Parry"] == max(lens.values())),
        ("패링 > 타격", peaks["Parry"] > peaks["Hit"]),
        ("강타 > 일반 타격", peaks["StrongHit"] > peaks["Hit"]),
        ("선택 < 작동 (크기)", peaks["Select"] < peaks["Activate"]),
        ("선택이 가장 짧다", lens["Select"] < min(lens["Activate"], lens["Hit"])),
        ("복귀가 가장 작다", peaks["Return"] == min(peaks.values())),
    ]
    ok = True
    for label, passed in checks:
        ok = ok and passed
        print(f"  {label:22s} {'OK' if passed else '★어긋남'}")

    # ★ 검수 항목 "선택음·작동음·패링 성공음이 서로 다른가"(p.5)를 수치로 확인한다.
    #   어택 12ms 구간의 상관계수. 1.0 이면 같은 소리, 0 근처면 서로 다른 소리다.
    print()
    print("어택 12ms 상관 — 0 에 가까울수록 확실히 구분된다")
    order = ["Select", "Activate", "Hit", "StrongHit", "Parry", "Return"]
    win = secs(0.012)

    def head(name):
        x = takes[name][:win].astype(float)
        return x - x.mean()

    print(f"{'':12s}" + "".join(f"{n[:6]:>8s}" for n in order))
    worst = 0.0
    for a in order:
        row = f"{a[:11]:12s}"
        for b in order:
            xa, xb = head(a), head(b)
            d = np.sqrt((xa * xa).sum() * (xb * xb).sum())
            c = float((xa * xb).sum() / d) if d > 0 else 0.0
            row += f"{c:+8.3f}"
            if a != b:
                worst = max(worst, abs(c))
        print(row)
    print(f"  서로 다른 소리끼리의 최대 상관: {worst:.3f} "
          f"({'OK — 0.5 미만' if worst < 0.5 else '★ 너무 닮았다'})")
    ok = ok and worst < 0.5
    print("검증:", "통과" if ok else "★실패")

    write_wav(AUDITION / "SFX_Flipper_audition.wav", audition(takes))
    print()
    print("오디션: SFX_Flipper_audition.wav")
    print("  A 선택 3연타 / B 헛침·타격·패링·강타 네 갈래 / C 반복 입력 감쇠")
    return rows


if __name__ == "__main__":
    main()
