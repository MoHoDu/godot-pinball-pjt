#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""여러 타격이 담긴 파일에서 **가장 밝은 한 방**을 골라 자른다.

★ 왜 필요한가 (2026-08-07)
  Firefly 는 "one clack" 을 시켜도 여러 번 부딪히는 것을 준다. 당구공 프롬프트는
  4번 부딪혔다. 그런데 단순히 **첫 타격**을 자르면 가장 둔한 것을 집는다 —
  실제로 소스는 중심 2619Hz / 고역 61% 였는데 잘라낸 결과가 1118Hz / 12% 였다.

  그래서 모든 타격 후보를 찾아 각각의 앞 30ms 밝기를 재고, 제일 밝은 것을 쓴다.
"""
import numpy as np
from scipy import signal
from build_sfx import SR


def cut_best_hit(x, window_ms=30.0, rate=SR):
    w = max(int(0.003 * rate), 1)
    env = np.sqrt(np.convolve(x ** 2, np.ones(w) / w, "same"))
    rise = np.diff(env)
    rise[rise < 0] = 0.0
    if rise.max() <= 0:
        return x

    peaks, _ = signal.find_peaks(rise, height=rise.max() * 0.20,
                                 distance=int(0.020 * rate))
    if not len(peaks):
        return x

    span = int(window_ms / 1000.0 * rate)
    best, best_score = None, -1.0
    for p in peaks:
        seg = x[p:p + span]
        if len(seg) < span // 2:
            continue
        S = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
        f = np.fft.rfftfreq(len(seg), 1.0 / rate)
        tot = S.sum() or 1e-12
        # 밝기(2.5kHz 위 비중) × 세기. 밝기만 보면 아주 작은 잡음을 집는다.
        score = (S[f >= 2500].sum() / tot) * float(np.max(np.abs(seg)))
        if score > best_score:
            best, best_score = p, score

    start = max(int(best) - int(0.002 * rate), 0)
    return x[start:]
