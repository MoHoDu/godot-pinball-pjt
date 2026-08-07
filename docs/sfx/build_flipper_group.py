#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
그룹 1(플리퍼) 5종을 inbox 소재에서 한 번에 마감한다.

  python build_flipper_group.py [--dry-run]

★ 왜 스크립트인가
  층 비율·엔벨로프·음량을 손으로 맞추다 보니 같은 작업을 반복하게 됐고,
  한 번 고칠 때마다 다른 것이 어긋났다. 표 하나로 모아 둔다.

★ 2026-08-07 형락님 지시 두 가지를 반영한다.
  ① "모든 소리에 쇠음 같은 거 전부 빼"
     -> 고역을 깎는다. 쇠 느낌은 대부분 4kHz 위의 날선 링에서 온다.
  ② "타격이 낮게, 강타격이 중간, 패링이 높게"
     -> 세 소리의 피크를 6dB 씩 벌린다. 1dB 차이는 귀로 안 갈린다.
        기존 -2.0 / -1.6 / -1.0 은 사실상 같은 크기였다.
"""

import argparse
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

from build_sfx import SR, ROOT, env_exp, gate, norm_peak, trim_floor, write_wav
from cut_best_hit import cut_best_hit

INBOX = ROOT / "inbox" / "flipper"
OUT = ROOT.parent.parent / "Resources" / "sfx" / "flippers"

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/flippers/{name}.wav"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""

# 파일 -> (소재 목록, 피크dB, 게이트 hold, fall, 쇠깎기 강도, 설명)
#
# 소재 목록은 (파일명, 감쇠시간, 비중). 여러 개면 겹친다.
#   감쇠시간이 짧으면 '치는' 층, 길면 '울리는' 층이 된다.
#
# ★ 음량은 6dB 씩 벌린다. 기획서 우선순위 순서는 지키되 차이가 들려야 한다.
#     복귀 -15(+6 보정) < 선택 -14 < 작동 -9 < 타격 -8 < 강타격 -4 < 패링 -1
#
# ★ 복귀음(A3)은 뺐다 (2026-08-07 형락님 지시). 작동음과 계속 뭉쳐 들렸고,
#   Space 한 번에 두 소리가 나는 것 자체가 과했다. 올라갈 때 한 번만 난다.
SPECS = {
    "SFX_Flipper_Select": (
        # ★ 원본이 중심 5907Hz 라 0.55 로는 쇠가 63% 남았다. 강하게 깎는다.
        [("A1.wav", None, 1.0)], -14.0, 0.030, 0.055, 0.90,
        "짧은 딸깍. 조작 확인음"),
    "SFX_Flipper_Activate": (
        # ★ 형락님 지시로 되돌림 (2026-08-07) — 쇠음을 깎기 전 상태가 낫다.
        [("A2.wav", None, 1.0)], -9.0, 0.150, 0.235, 0.0,
        "철컥 + 덜컹. Space 로 올라가는 순간"),
    "SFX_Flipper_Return": (
        # ★ 되살림 (2026-08-07). 쇠깎기 없이, 재생 보정 +6dB 로 들리게 한다.
        [("A3.wav", None, 1.0)], -15.0, 0.070, 0.130, 0.0,
        "내려앉는다. Space 를 놓을 때"),
    "SFX_Flipper_Hit": (
        [("A4_body.wav", 0.020, 1.0), ("A4_head.wav", 0.010, 0.8),
         ("A4_glass.wav", 0.080, 0.10)], -8.0, 0.095, 0.150, 0.45,
        "단단한 톡/탁. 나무가 치고 유리가 울린다"),
    # ★ 2026-08-07 형락님 지시로 A5 와 A6 의 소재를 맞바꿨다.
    #   강타격은 당구공 그대로, 패링은 거기에 유리를 얹은 쪽이 낫다는 판단이다.
    "SFX_Flipper_StrongHit": (
        [("A6.wav", None, 1.0)], -4.0, 0.120, 0.185, 0.40,
        "탄력 있는 쫙/팡. 타격보다 밝고 크다"),
    "SFX_Flipper_Parry": (
        [("A5_body.wav", 0.026, 1.0), ("A4_glass.wav", 0.090, 0.22)],
        -1.0, 0.100, 0.170, 0.40,
        "명쾌한 탁. 우선순위 1위, 가장 크다"),
}


def load(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64) / 32768.0
    x = x if x.ndim == 1 else x.mean(axis=1)

    if rate != SR:
        idx = np.linspace(0, len(x) - 1, int(len(x) * SR / rate))
        x = np.interp(idx, np.arange(len(x)), x)

    return x


def de_metal(x, amount, cutoff=3600.0):
    """쇠 느낌을 걷어낸다.

    ★ 날선 '쇠음' 은 대부분 4kHz 위의 링에서 온다. 다만 전부 자르면 어택이
      죽어 뭉툭해지므로 남길 비율을 정해 섞는다.
    """
    b, a = signal.butter(2, cutoff / (SR / 2.0), btype="low")
    low = signal.lfilter(b, a, x)
    return low + (x - low) * (1.0 - amount)


def bands(x):
    S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    total = S.sum() or 1e-12
    return {
        "cent": float((S * f).sum() / total),
        "body": float(S[(f >= 800) & (f < 2500)].sum() / total * 100.0),
        "glass": float(S[(f >= 4000) & (f <= 10000)].sum() / total * 100.0),
        "metal": float(S[f >= 6000].sum() / total * 100.0),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    rms = lambda v: float(np.sqrt(np.mean(v ** 2))) or 1e-9
    span = int(0.26 * SR)

    print(f"{'파일':26s}{'길이':>7s}{'피크':>8s}{'중심':>8s}{'몸통':>6s}{'유리':>6s}{'쇠':>6s}")
    print("-" * 74)

    for name, (layers, peak_db, hold, fall, metal_cut, why) in SPECS.items():
        mix = np.zeros(span)
        for filename, tau, weight in layers:
            src = INBOX / filename
            if not src.exists():
                print(f"★ 소재가 없다: {src}")
                return 1

            v = cut_best_hit(load(src))
            y = np.zeros(span)
            m = min(len(v), span)
            y[:m] = v[:m]

            if tau is not None:
                # ★ 엔벨로프를 씌운 **뒤에** 에너지를 맞춘다.
                #   먼저 맞추면 짧게 깎인 층이 그만큼 작아져 사라진다.
                y = y * env_exp(span, tau)
                y = y / rms(y)

            mix += y * weight

        mix = np.tanh(mix * 0.30) / np.tanh(0.30) if len(layers) > 1 else mix
        mix = de_metal(mix, metal_cut)
        x = norm_peak(trim_floor(gate(mix, hold, fall)), peak_db)

        b = bands(x)
        print(f"{name:26s}{len(x) / SR * 1000:6.0f}ms{peak_db:7.1f}dB"
              f"{b['cent']:7.0f}Hz{b['body']:5.0f}%{b['glass']:5.0f}%{b['metal']:5.0f}%")
        print(f"{'':26s}{why}")

        if args.dry_run:
            continue

        OUT.mkdir(parents=True, exist_ok=True)
        write_wav(OUT / f"{name}.wav", x)
        (OUT / f"{name}.wav.import").write_text(
            IMPORT_TEMPLATE.format(name=name), encoding="utf-8")

    # ★ 여기서 걸리면 게임에 넣지 않는다.
    peaks = {n: SPECS[n][1] for n in SPECS}
    order = ["SFX_Flipper_Return", "SFX_Flipper_Select", "SFX_Flipper_Activate",
             "SFX_Flipper_Hit", "SFX_Flipper_StrongHit", "SFX_Flipper_Parry"]
    got = [peaks[n] for n in order]
    assert got == sorted(got), f"음량 위계가 뒤집혔다: {got}"

    gap_hit = peaks["SFX_Flipper_StrongHit"] - peaks["SFX_Flipper_Hit"]
    gap_parry = peaks["SFX_Flipper_Parry"] - peaks["SFX_Flipper_StrongHit"]
    assert gap_hit >= 3.0 and gap_parry >= 3.0, \
        f"타격/강타격/패링 차이가 너무 작다 ({gap_hit:.1f}dB, {gap_parry:.1f}dB)"

    print(f"\n자가 검증 통과 — 위계 유지, 타격→강타격 {gap_hit:+.0f}dB, "
          f"강타격→패링 {gap_parry:+.0f}dB")
    if args.dry_run:
        print("--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"{len(SPECS)}종 반입 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
