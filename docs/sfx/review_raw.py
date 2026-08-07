#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
② 텍스처 단계 — 받은 AI 재질음을 채택 기준으로 거른다

  python review_raw.py <그룹>

채택 기준 4개 (sfx_elevenlabs_prompts.md §4)
  ① 앞 30ms 안에 재질 특성이 다 들어있는가   — 뒤로 갈수록 잔향뿐이면 버린다
  ② 잔향·룸톤이 안 붙었는가                  — 우리 "짧은 잔향" 레이어와 충돌한다
  ③ 재질 모드가 뚜렷한가                     — 3~9kHz 에 특성이 있어야 한다
  ④ 클릭이 하나인가                          — 모델이 종종 2~3연타를 넣는다

우리가 쓰는 것은 **어택 직후의 재질 구간뿐**이다. 총 길이는 상관없다.
0.5초를 요청해도 더 길게 오는데, 뒤쪽은 어차피 잘라낸다.
"""

import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile

from generate_elevenlabs import ROLES

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"

ONSET_REL_DB = -20.0     # 피크 대비 이 위로 올라오면 트랜지언트로 센다
ONSET_GAP_MS = 25.0      # 이 간격 이상 떨어져야 별개의 타격이다
HEAD_MS = 30.0           # 기준 ① 의 "앞 30ms"


def load(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64)
    if x.ndim > 1:
        x = x[:, 0]
    peak = np.max(np.abs(x))
    return (x / peak if peak > 0 else x), rate


def onsets(x, rate):
    """피크 대비 -20dB 를 넘어서는 상승 지점을 타격으로 센다."""
    env = np.abs(x)
    # 1ms 이동최대로 매끈하게
    w = max(int(rate * 0.001), 1)
    env = np.maximum.reduceat(env, np.arange(0, len(env), w))
    thr = 10.0 ** (ONSET_REL_DB / 20.0)
    gap = int(ONSET_GAP_MS / 1000.0 * rate / w)

    hits = []
    last = -gap
    for i in range(1, len(env)):
        if env[i] >= thr > env[i - 1] and i - last >= gap:
            hits.append(i * w / rate)
            last = i
    return hits


def review(path):
    rate0, data0 = wavfile.read(str(path))
    peak_dbfs = 20 * np.log10((np.max(np.abs(data0.astype(float))) or 1e-9) / 32768.0)
    x, rate = load(path)
    env = np.abs(x)
    peak_i = int(np.argmax(env))

    # 유효 길이 — -60dBFS 아래로 떨어진 뒤는 없는 것으로 본다
    thr60 = 10.0 ** (-60.0 / 20.0)
    above = np.where(env > thr60)[0]
    start, end = (int(above[0]), int(above[-1])) if len(above) else (0, len(x))

    # ① 어택 이후 30ms 에 에너지가 얼마나 몰려 있나
    head = int(HEAD_MS / 1000.0 * rate)
    e_all = float(np.sum(x[start:end] ** 2)) or 1e-12
    e_head = float(np.sum(x[peak_i:peak_i + head] ** 2))

    # ② 룸톤 — 어택 이전 구간의 바닥. 조용할수록 좋다
    pre = x[:max(peak_i - int(0.005 * rate), 1)]
    floor_db = 20 * np.log10(np.sqrt(np.mean(pre ** 2)) + 1e-12) if len(pre) > 10 else -99.0
    #    감쇠 — 피크에서 -40dB 까지 걸리는 시간. 길면 잔향이 붙은 것
    tail = env[peak_i:]
    below = np.where(tail < 10.0 ** (-40.0 / 20.0))[0]
    decay_ms = (below[0] / rate * 1000.0) if len(below) else (len(tail) / rate * 1000.0)

    # ③ 재질 모드 — 3~9kHz 비중
    seg = x[peak_i:peak_i + head]
    S = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
    f = np.fft.rfftfreq(len(seg), 1 / rate)
    tot = S.sum() or 1e-12
    band = float(S[(f >= 3000) & (f <= 9000)].sum() / tot * 100)
    centroid = float((S * f).sum() / tot)

    # ④ 타격 개수
    hits = onsets(x, rate)

    return {
        "len_ms": (end - start) / rate * 1000.0,
        "attack_ms": peak_i / rate * 1000.0,
        "head_ratio": e_head / e_all * 100.0,
        "floor_db": floor_db,
        "decay_ms": decay_ms,
        "band_3_9k": band,
        "centroid": centroid,
        "hits": len(hits),
        "peak_dbfs": peak_dbfs,
    }


def verdict(m):
    """4개 기준으로 채택/보류/탈락."""
    fails = []
    # 모델이 거의 무음을 뱉는 경우가 있다 (실측 -40dBFS). 다른 검사보다 먼저 건다.
    if m["peak_dbfs"] < -24.0:
        return "탈락", [f"⑤무음({m['peak_dbfs']:.0f}dB)"]
    if m["head_ratio"] < 45.0:
        fails.append("①앞30ms약함")
    if m["floor_db"] > -26.0:
        fails.append("②룸톤")
    if m["decay_ms"] > 220.0:
        fails.append("②잔향김")
    if m["band_3_9k"] < 12.0:
        fails.append("③모드약함")
    if m["hits"] != 1:
        fails.append(f"④{m['hits']}연타")
    return ("채택", []) if not fails else ("탈락", fails)


def main():
    if len(sys.argv) < 2:
        print("사용법: python review_raw.py <그룹>")
        return 1

    d = RAW / sys.argv[1]
    files = sorted(d.glob("*.wav")) + sorted(d.glob("*.mp3"))
    if not files:
        print(f"파일이 없다: {d}")
        return 1

    print(f"{'파일':32s}{'유효':>8s}{'어택':>8s}{'앞30ms':>8s}{'룸톤':>8s}"
          f"{'감쇠':>8s}{'3~9k':>7s}{'타격':>5s}  판정")
    print("-" * 100)

    keep = []
    for p in files:
        m = review(p)
        v, fails = verdict(m)
        if v == "채택":
            keep.append(p.name)
        print(f"  용도: {ROLES.get(p.stem.rsplit('_', 1)[0], '(미기재)')}")
        print(f"{p.name:32s}{m['len_ms']:7.0f}ms{m['attack_ms']:7.1f}ms"
              f"{m['head_ratio']:7.1f}%{m['floor_db']:7.1f}dB"
              f"{m['decay_ms']:7.0f}ms{m['band_3_9k']:6.1f}%{m['hits']:5d}"
              f"  {v} {' '.join(fails)}")

    print()
    print(f"채택 {len(keep)}/{len(files)}")
    for n in keep:
        print(f"  {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
