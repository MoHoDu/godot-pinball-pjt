#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Firefly 변형 여러 개를 측정해 역할에 가장 맞는 것을 고른다.

  python pick_best.py <역할> <파일...>

★ 사람이 4개를 다 들어볼 필요를 없앤다. 역할마다 원하는 성질이 수치로
  정해져 있으므로 그것에 가장 가까운 것을 뽑는다. 근거를 함께 출력해
  판단이 다르면 되돌릴 수 있게 한다.
"""
import sys, warnings
warnings.filterwarnings("ignore")
import numpy as np
from scipy.io import wavfile
from scipy import signal

# 역할 -> (목표 중심Hz, 목표 유효길이ms, 타격수 선호, 고역 최소%)
#
# ★ 2026-08-07 값을 전부 위로 올렸다. Firefly 는 **어두운 쪽으로 강하게
#   치우친다** — 나무·상자를 넣으면 초저역만 나온다. 그리고 확정된 A2 는
#   고역(2.5kHz 위)이 62% 였다. 어두운 것을 고르면 형락님 귀에 "약하다"가 된다.
#
# ★ 공은 유리공이다. 충돌음은 4~10kHz 에 성분이 있어야 유리로 들린다.
GOALS = {
    "A2": (4500.0, 180.0, 2, 40.0),   # 철컥+덜컹. 확정본이 5538Hz / 62%
    "A3": (1600.0, 120.0, 1, 10.0),   # 내려앉음. A2 보다 어둡되 먹먹하면 안 된다
    "A4": (2500.0, 120.0, 1, 30.0),   # 단단한 톡/탁. 유리 성분 필수
    "A5": (2200.0, 170.0, 1, 25.0),   # 탄력 있는 쫙/팡
    "A6": (3000.0, 140.0, 1, 35.0),   # 명쾌한 탁. 여섯 중 가장 밝아도 된다
}

def measure(p):
    r, d = wavfile.read(p)
    x = d.astype(np.float64) / 32768.0
    x = x if x.ndim == 1 else x.mean(axis=1)
    peak = np.max(np.abs(x)) or 1e-9
    w = max(int(0.003 * r), 1)
    env = np.sqrt(np.convolve(x ** 2, np.ones(w) / w, "same"))
    idx = np.where(env > env.max() * 0.05)[0]
    eff = (idx[-1] - idx[0]) / r * 1000 if len(idx) else 0.0
    win = max(int(0.010 * r), 1)
    q = np.array([np.sqrt(np.mean(x[i:i+win]**2)) for i in range(0, max(len(x)-win,1), win)])
    q = q[q > 0]
    snr = 20*np.log10(peak / max(q.min(), 1e-9)) if len(q) else 0.0
    S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0/r); tot = S.sum() or 1e-12
    dd = np.diff(env); dd[dd < 0] = 0
    pk, _ = signal.find_peaks(dd, height=dd.max()*0.25, distance=int(0.02*r))
    return {
        "peak_db": 20*np.log10(peak), "snr": snr, "eff": eff,
        "cent": float((S*f).sum()/tot), "hits": len(pk),
        "low": float(S[f < 400].sum()/tot*100),
        "hi": float(S[f >= 2500].sum()/tot*100),
    }

def main():
    role = sys.argv[1].upper()
    goal_c, goal_len, goal_hits, goal_hi = GOALS[role]
    rows = []
    for p in sys.argv[2:]:
        m = measure(p)
        # 점수: 중심은 옥타브 거리, 길이는 비율 거리, 타격수·SNR·레벨은 보너스
        s = abs(np.log2(max(m["cent"],1)/goal_c)) * 1.0
        s += abs(np.log2(max(m["eff"],1)/goal_len)) * 0.6
        s += 0.5 if m["hits"] != goal_hits else 0.0
        s += 0.8 if m["snr"] < 40 else 0.0
        s += 0.8 if m["peak_db"] < -20 else 0.0
        # ★ 고역이 목표에 못 미치면 강하게 감점한다. 여기가 판정의 핵심이다.
        s += max(0.0, (goal_hi - m["hi"]) / goal_hi) * 1.6
        rows.append((s, p, m))
    rows.sort(key=lambda r: r[0])
    print(f"[{role}] 목표 중심 {goal_c:.0f}Hz · 길이 {goal_len:.0f}ms · 타격 {goal_hits}개\n")
    for i,(s,p,m) in enumerate(rows):
        mark = "★채택" if i == 0 else "     "
        print(f"{mark} {p.split('/')[-1][-18:]:20s} 점수{s:5.2f}  "
              f"중심{m['cent']:6.0f}Hz 길이{m['eff']:4.0f}ms 타격{m['hits']}개 "
              f"피크{m['peak_db']:5.1f}dB SNR{m['snr']:3.0f} 저역{m['low']:3.0f}% 고역{m['hi']:3.0f}%")
    print(f"\n채택: {rows[0][1]}")

main()
