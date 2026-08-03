#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
공 SFX ③ 검수 단계 — 수치 실측 + 오디션 파일 + 파형/스펙트로그램 시트

오디션 파일 구성
  A  공통 어택 3종            (5종 공유 레이어. 이것만 따로 들어본다)
  B  정속 태엽눈 일반 충돌 3종
  C  연속 충돌 8연타          간격 0.08초 / 피치 ±5% 랜덤 / 2번째부터 -3dB, 하한 -9dB
  D  정확한 패링 1종
  E  실전 리듬                충돌·충돌·패링·충돌
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
matplotlib.rcParams["font.family"] = "Noto Sans CJK JP"   # 한글 글리프 포함
matplotlib.rcParams["axes.unicode_minus"] = False
from matplotlib import gridspec
from scipy.io import wavfile
from scipy import signal
from pathlib import Path
import subprocess

SR = 48000
OUT = Path(__file__).resolve().parent

HITS = [f"SFX_Ball_Clockwork_Hit_{i:02d}.wav" for i in (1, 2, 3)]
ATTACKS = [f"SFX_Ball_Common_Attack_{i:02d}.wav" for i in (1, 2, 3)]
PARRY = "SFX_Ball_Clockwork_Parry_01.wav"


def load(name):
    sr, x = wavfile.read(str(OUT / name))
    assert sr == SR, name
    return x.astype(np.float64) / 32768.0


def pitch(x, ratio):
    """재생 속도 기반 피치 시프트 = Godot AudioStreamPlayer.pitch_scale 과 같은 동작."""
    n = int(round(len(x) / ratio))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def place(buf, x, at_s, gain_db=0.0):
    i = int(round(at_s * SR))
    g = 10.0 ** (gain_db / 20.0)
    m = min(len(x), len(buf) - i)
    if m > 0:
        buf[i:i + m] += x[:m] * g


def build_audition():
    rng = np.random.default_rng(7)
    buf = np.zeros(int(SR * 14.0))
    marks = []
    t = 0.4

    marks.append(("A  공통 어택 3종", t))
    for a in ATTACKS:
        place(buf, load(a), t)
        t += 0.55
    t += 0.7

    marks.append(("B  일반 충돌 3종", t))
    for h in HITS:
        place(buf, load(h), t)
        t += 0.55
    t += 0.7

    marks.append(("C  연속 충돌 8연타 (-3dB 누적, 하한 -9dB)", t))
    for k in range(8):
        x = load(HITS[rng.integers(0, 3)])
        x = pitch(x, float(rng.uniform(0.95, 1.05)))          # 피치 ±5%
        drop = 0.0 if k == 0 else max(-9.0, -3.0 * k)          # 2번째부터 3dB씩, 하한 -9dB
        place(buf, x, t, drop)
        t += 0.08
    t += 1.1

    marks.append(("D  정확한 패링", t))
    place(buf, load(PARRY), t)
    t += 0.9

    marks.append(("E  실전 리듬 (충돌·충돌·패링·충돌)", t))
    for dt, name, g in [(0.00, HITS[0], 0.0), (0.26, HITS[2], 0.0),
                        (0.62, PARRY, 0.0), (1.05, HITS[1], 0.0)]:
        x = load(name)
        x = pitch(x, float(rng.uniform(0.96, 1.04)))
        place(buf, x, t + dt, g)
    t += 1.8

    buf = buf[:int(t * SR)]
    buf /= max(1.0, np.max(np.abs(buf)) / 0.95)
    wavfile.write(str(OUT / "SFX_Clockwork_audition.wav"), SR,
                  (buf * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error",
                    "-i", str(OUT / "SFX_Clockwork_audition.wav"),
                    "-b:a", "192k", str(OUT / "SFX_Clockwork_audition.mp3")], check=True)
    return buf, marks


def sheet():
    files = ATTACKS[:1] + HITS + [PARRY]
    titles = ["공통 어택 01 (5종 공유)",
              "태엽눈 일반 충돌 01", "태엽눈 일반 충돌 02", "태엽눈 일반 충돌 03",
              "태엽눈 정확한 패링 01"]

    fig = plt.figure(figsize=(15, 12), facecolor="#12161c")
    gs = gridspec.GridSpec(5, 2, width_ratios=[1, 1.25], hspace=0.55, wspace=0.18,
                           left=0.06, right=0.97, top=0.93, bottom=0.05)
    fig.suptitle("Pinball_Logue  공 SFX 파일럿 — 정속 태엽눈 (Clockwork)   ①형태 단계",
                 color="#F0E0C3", fontsize=15, y=0.975)

    for r, (f, ti) in enumerate(zip(files, titles)):
        x = load(f)
        t = np.arange(len(x)) / SR * 1000.0

        ax = fig.add_subplot(gs[r, 0], facecolor="#1a2029")
        ax.plot(t, x, lw=0.7, color="#4FD1C5")
        ax.axhline(0, color="#39424f", lw=0.5)
        ax.set_xlim(0, max(t))
        ax.set_ylim(-0.45, 0.45)
        ax.set_ylabel("amp", color="#8b97a6", fontsize=8)
        ax.tick_params(colors="#8b97a6", labelsize=7)
        for s in ax.spines.values():
            s.set_color("#39424f")
        peak = np.max(np.abs(x))
        ax.set_title(f"{ti}   len {len(x)/SR*1000:.1f} ms   peak "
                     f"{20*np.log10(peak):.1f} dBFS",
                     color="#F0E0C3", fontsize=9, loc="left", pad=4)

        ax2 = fig.add_subplot(gs[r, 1], facecolor="#1a2029")
        f_, t_, S = signal.spectrogram(x, SR, nperseg=256, noverlap=224)
        ax2.pcolormesh(t_ * 1000, f_ / 1000,
                       10 * np.log10(S + 1e-12), cmap="magma",
                       vmin=-108, vmax=-42, shading="gouraud")
        ax2.set_ylim(0, 14)
        ax2.set_ylabel("kHz", color="#8b97a6", fontsize=8)
        ax2.set_xlabel("ms", color="#8b97a6", fontsize=8)
        ax2.tick_params(colors="#8b97a6", labelsize=7)
        for s in ax2.spines.values():
            s.set_color("#39424f")

    fig.savefig(OUT / "sfx_pilot_clockwork_sheet.png", dpi=110,
                facecolor=fig.get_facecolor())
    plt.close(fig)


def report():
    print(f"{'file':38s} {'len ms':>8s} {'peak dB':>9s} {'rms dB':>9s} "
          f"{'t_peak ms':>10s} {'centroid Hz':>12s}")
    rows = {}
    for f in ATTACKS + HITS + [PARRY]:
        x = load(f)
        peak = np.max(np.abs(x))
        rms = np.sqrt(np.mean(x ** 2))
        X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
        fr = np.fft.rfftfreq(len(x), 1 / SR)
        cen = float((X * fr).sum() / X.sum())
        rows[f] = (20 * np.log10(peak), 20 * np.log10(rms))
        print(f"{f:38s} {len(x)/SR*1000:8.1f} {20*np.log10(peak):9.2f} "
              f"{20*np.log10(rms):9.2f} {np.argmax(np.abs(x))/SR*1000:10.2f} {cen:12.0f}")

    hp = np.mean([rows[h][0] for h in HITS])
    hr = np.mean([rows[h][1] for h in HITS])
    print(f"\n패링 대비 충돌 볼륨차   peak {hp - rows[PARRY][0]:+.2f} dB   "
          f"rms {hr - rows[PARRY][1]:+.2f} dB   (목표 -8 ~ -10 dB)")


if __name__ == "__main__":
    report()
    build_audition()
    sheet()
    print("\naudition + sheet 생성 완료")
