#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
② 텍스처 단계 — 받은 AI 음원에서 **첫 타격의 재질 구간만** 잘라낸다

  python extract_material.py <그룹> [--length 80]

★ 이게 원래 파이프라인이다.
  우리가 쓰는 것은 어택 직후 30~80ms 뿐이다. AI 파일이 10연타로 오든,
  뒤에 잔향이 붙든 상관없다. **첫 타격만 잘라 확정된 엔벨로프에 얹는다.**

  그래서 원본에 대고 "클릭이 하나인가"를 따지는 것은 의미가 없었다(2026-08-06).
  잘라낸 결과로 판단해야 한다.

하는 일
  1. 첫 트랜지언트를 찾는다 (피크 대비 -30dB 를 처음 넘는 지점)
  2. 그 2ms 앞부터 length ms 만큼 자른다
  3. 앞뒤에 짧은 페이드를 걸어 클릭 잡음을 막는다
  4. -10dBFS 로 정규화한다 (절차적 합성물과 같은 기준)

결과는 raw/<그룹>/cut/ 에 쌓인다. 이 파일들이 build_*.py 의 재질 레이어를 대체한다.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile

from sfx_layout import RAW, ROLES, role_of, source_dir  # noqa: E402

ROOT = Path(__file__).resolve().parent

SR_TARGET = 48000
ONSET_REL_DB = -30.0    # 피크 대비 이 위로 처음 올라오는 지점을 첫 타격으로 본다
PRE_MS = 2.0            # 어택 앞쪽 여유. 트랜지언트 머리를 자르지 않기 위해
FADE_IN_MS = 0.5
FADE_OUT_MS = 8.0
TARGET_DBFS = -10.0     # 절차적 합성물과 같은 기준


def first_onset(x, rate):
    """
    첫 **실제 타격**의 시작점.

    ★ 단순히 "피크 대비 -30dB 를 처음 넘는 샘플"로 잡으면 안 된다(2026-08-06).
      조용하게 생성된 파일에서는 앞쪽 **잡음**이 그 문턱을 먼저 넘어,
      타격이 아니라 무음 구간을 잘라내게 된다.
      실제로 pang_02 는 6.6kHz 잡음 80ms 가 잘려 나와 "소리가 없다"는 판정을 받았다.

    그래서 순간값이 아니라 **3ms 이동 RMS** 로 본다. 잡음은 이 창에서 낮게 깔리고
    타격만 솟는다. 최대 창 대비 35% 를 처음 넘는 지점을 타격의 시작으로 본다.
    """
    if np.max(np.abs(x)) <= 0:
        return None

    win = max(int(0.003 * rate), 1)
    trimmed = x[:len(x) // win * win]
    if len(trimmed) < win:
        return None

    frames = trimmed.reshape(-1, win)
    energy = np.sqrt(np.mean(frames ** 2, axis=1))
    top = np.max(energy)
    if top <= 0:
        return None

    hits = np.where(energy >= top * 0.35)[0]
    if not len(hits):
        return None

    # 창 시작에서 조금 앞으로 물러나 트랜지언트 머리를 놓치지 않는다
    return max(int(hits[0]) * win - win, 0)


def extract(path, length_ms):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)

    onset = first_onset(x, rate)
    if onset is None:
        return None, "전 구간 무음"

    start = max(onset - int(PRE_MS / 1000.0 * rate), 0)
    end = min(start + int(length_ms / 1000.0 * rate), len(x))
    seg = x[start:end].copy()

    if len(seg) < int(0.010 * rate):
        return None, "구간이 너무 짧다"

    # 앞뒤 페이드 — 자른 자리에서 딱 소리가 나지 않게
    fi = max(int(FADE_IN_MS / 1000.0 * rate), 1)
    fo = max(int(FADE_OUT_MS / 1000.0 * rate), 1)
    seg[:fi] *= np.linspace(0.0, 1.0, fi)
    seg[-fo:] *= 0.5 * (1.0 + np.cos(np.pi * np.linspace(0.0, 1.0, fo)))

    peak = np.max(np.abs(seg))
    if peak <= 0:
        return None, "구간이 무음"
    seg = seg / peak * (10.0 ** (TARGET_DBFS / 20.0)) * 32767.0

    return (rate, seg.astype(np.int16)), None


def snr_db(seg):
    """앞 1ms(어택 전) 대비 피크. 잘라낸 조각이 쓸 만한지 보는 값."""
    head = seg[:max(len(seg) // 80, 8)].astype(np.float64)
    floor = np.sqrt(np.mean(head ** 2)) + 1e-9
    return 20.0 * np.log10(np.max(np.abs(seg.astype(np.float64))) / floor)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("group")
    ap.add_argument("--length", type=float, default=80.0, help="잘라낼 길이(ms)")
    # ★ 길이는 역할마다 다르다. 걸림쇠 '철컥' 은 60ms 면 끝나는데 그룹 전체를
    #   300ms 로 자르면 뒤에 붙은 잔향까지 들어가 길이 기준에 걸린다.
    #   소재가 나빠서가 아니라 자르기를 잘못한 것이다.
    ap.add_argument("--only", nargs="+", metavar="역할",
                    help="이 역할만 추출한다 (예: --only bumper_cannon_click)")
    args = ap.parse_args()

    base = RAW / args.group

    # 원본은 역할 폴더의 _source/ 에 있다. 정리 전 평평한 배치도 받아준다.
    files = sorted(base.glob("*/_source/*.wav")) or sorted(base.glob("*.wav"))
    if args.only:
        files = [p for p in files if role_of(p.stem) in args.only]

    if not files:
        print(f"파일이 없다: {base}")
        return 1

    print(f"{'원본':30s}{'첫 타격':>9s}{'길이':>8s}{'SNR':>9s}  결과")
    print("-" * 76)

    made = 0
    for p in files:
        rate, data = wavfile.read(str(p))
        x = data.astype(np.float64)
        onset = first_onset(x if x.ndim == 1 else x.mean(axis=1), rate)
        got, err = extract(p, args.length)
        if got is None:
            print(f"{p.name:30s}{'-':>9s}{'-':>8s}{'-':>9s}  건너뜀 ({err})")
            continue

        # 추출본은 _source/ 바로 위, 즉 재생할 역할 폴더에 놓는다.
        role = role_of(p.stem)
        out = source_dir(args.group, role).parent
        out.mkdir(parents=True, exist_ok=True)

        rate_o, seg = got
        dst = out / p.name
        wavfile.write(str(dst), rate_o, seg)
        made += 1
        print(f"{p.name:30s}{onset / rate * 1000:8.1f}ms{len(seg) / rate_o * 1000:7.1f}ms"
              f"{snr_db(seg):8.1f}dB  {dst.relative_to(RAW)}")

    print(f"\n{made}/{len(files)} 추출 → {base}")
    for role in sorted({role_of(p.stem) for p in files}):
        print(f"  {source_dir(args.group, role).parent.name:14s}"
              f"{ROLES.get(role, '')}")
    print(f"\n다음: python organize_takes.py {args.group}  (반려본을 지운다)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
