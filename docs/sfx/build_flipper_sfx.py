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
    write_wav, measure, short_tail, detune,
)

# 출력 폴더 (build_sfx 의 ball/ 과 나눠 쓴다)
OUT = ROOT / "flipper"
LAYERS = ROOT / "layers" / "flipper"
for _d in (OUT, LAYERS):
    _d.mkdir(parents=True, exist_ok=True)
from build_wall_sfx import modal_glide, soft_clip, grain

# (피크 dBFS, 게이트 hold, 게이트 fall)
# 우선순위상 플리퍼 타격은 벽(-10)보다 크고 패링(-1)보다 작아야 한다.
SPECS = {
    "Select": (-14.0, 0.030, 0.055),   # 조작 확인음. 작아야 한다. 연타로 눌린다
    "Activate": (-9.0, 0.060, 0.105),  # 선택음보다 크고 확실히 다른 음색
    "Hit": (-4.0, 0.095, 0.150),       # MUST. 벽보다 크고 길다
    "StrongHit": (-2.5, 0.120, 0.185),  # 탄력 있는 쫙/팡. 금속 쾅이 아니다
    "Return": (-16.0, 0.080, 0.130),   # 작은 태엽 떨림. 있는 줄 모를 만큼 작게
}

# 단단한 톡·탁. 고무 얹은 나무 쪽이라 벽(1.2~3.8kHz)보다 낮게 잡되,
# **너무 낮추면 '탁'이 아니라 둔탁한 쿵이 된다.**
# 486Hz 기본음일 때 800Hz 미만이 84% 였다(실측). '탁'의 성격은 0.8~3kHz 에 있다.
TAK_MODES = [
    (742.0, 1.00, 0.0165),
    (1164.0, 0.68, 0.0122),
    (1806.0, 0.40, 0.0090),
    (2635.0, 0.21, 0.0064),
]

# 강한 타격의 탄력. 일반 타격보다 낮고 길지만 여전히 '쫙/팡'이어야 한다.
# 352Hz 기본음일 때 800Hz 미만이 96% 였다 — 그건 p.20 이 금지한 금속 쾅 쪽의 둔함이다.
PANG_MODES = [
    (568.0, 1.00, 0.0235),
    (884.0, 0.72, 0.0176),
    (1462.0, 0.44, 0.0128),
    (2244.0, 0.24, 0.0092),
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
    """
    n = secs(0.220)
    modes = PANG_MODES if strong else TAK_MODES
    name = "StrongHit" if strong else "Hit"

    # 어택을 여기서 직접 만든다. 벽의 공통 어택을 쓰지 않는다 (p.61)
    attack = band_noise(n, 700, 3800, 0.0034, seed=8500 + int(strong))
    body = modal_glide(n, modes, -120.0 if strong else -90.0, 0.014,
                       seed=8600 + int(strong))
    whoosh = swept_noise(n, 520.0, 2900.0, 0.038, 0.020, seed=8700 + int(strong))
    tex = grain(n, seed=20 + int(strong))

    return assemble(name, {
        "attack": (attack, 0.92 if strong else 0.86),
        "body": (body, 1.00),
        "whoosh": (whoosh, 0.52 if strong else 0.42),
        "grain": (tex, 0.13),
    }, tail_gain=0.17 if strong else 0.13, drive=2.4 if strong else 2.1)


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

    # B. 한 사이클: 선택 → 작동 → 타격 → 복귀
    b = np.zeros(secs(2.4))
    place(b, takes["Select"], 0.12, 0.0, jit())
    place(b, takes["Activate"], 0.46, 0.0, jit())
    place(b, takes["Hit"], 0.53, 0.0, jit())
    place(b, takes["Return"], 0.74, 0.0, jit())
    place(b, takes["Activate"], 1.28, 0.0, jit())
    place(b, takes["StrongHit"], 1.35, 0.0, jit())
    place(b, takes["Return"], 1.62, 0.0, jit())
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
        ("타격 < 패링 (크기)", peaks["Hit"] < -1.0),
        ("강타 > 일반 타격", peaks["StrongHit"] > peaks["Hit"]),
        ("선택 < 작동 (크기)", peaks["Select"] < peaks["Activate"]),
        ("선택이 가장 짧다", lens["Select"] < min(lens["Activate"], lens["Hit"])),
        ("복귀가 가장 작다", peaks["Return"] == min(peaks.values())),
    ]
    ok = True
    for label, passed in checks:
        ok = ok and passed
        print(f"  {label:22s} {'OK' if passed else '★어긋남'}")
    print("검증:", "통과" if ok else "★실패")

    write_wav(AUDITION / "SFX_Flipper_audition.wav", audition(takes))
    print()
    print("오디션: SFX_Flipper_audition.wav")
    print("  A 선택 3연타 / B 선택→작동→타격→복귀 / C 반복 입력 감쇠")
    return rows


if __name__ == "__main__":
    main()
