#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
그룹 2 — 공 흐름 3종(발사·낙하·선택)을 마감한다.

  python build_ball_group.py [--dry-run]

★ 낙하음(B5)은 생성이 아니라 **파생**이다.
  "low wooden thud sinking down" 으로 세 번 뽑았는데 전부 중심 13~44Hz 의
  압력 계단이었다. Firefly 는 low·heavy·wooden 을 겹쳐 주면 가청대역을
  통째로 비운다. 앞서 대포 발사음과 콤보 실패음에서도 같은 함정에 빠졌다.

  그리고 애초에 "가라앉는 느낌"은 **낮은 주파수가 아니라 음이 내려가는 것**이다.
  벽 충돌음(B_tok)에 피치 하강을 걸면 그게 바로 "떨어진다" 가 된다.
  같은 벽 소재를 쓰므로 공이 그 보드에서 사라지는 것으로도 들린다.
"""

import argparse
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

from build_sfx import SR, ROOT, env_exp, gate, norm_peak, trim_floor, write_wav
from cut_best_hit import cut_best_hit

INBOX = ROOT / "inbox" / "ball"
OUT = ROOT.parent.parent / "Resources" / "sfx" / "balls"

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/balls/{name}.wav"

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


def load(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64) / 32768.0
    x = x if x.ndim == 1 else x.mean(axis=1)

    if rate != SR:
        idx = np.linspace(0, len(x) - 1, int(len(x) * SR / rate))
        x = np.interp(idx, np.arange(len(x)), x)

    return x


def pitch_fall(x, drop=0.55, curve=2.0):
    """재생 속도를 점점 늦춰 음이 아래로 미끄러지게 한다.

    ★ 이것이 '가라앉는 느낌' 의 정체다. 단순히 저역만 많은 소리는
      웅웅거릴 뿐 떨어지는 것으로 안 들린다.

    drop 은 끝에서의 재생 배속이다. 0.55 면 음이 약 한 옥타브 아래로 내려간다.
    """
    n = len(x)
    t = np.linspace(0.0, 1.0, n)
    rate = 1.0 - (1.0 - drop) * (t ** (1.0 / curve))

    # 누적 위치. 배속이 1 아래로 떨어지므로 결과는 원본보다 길어진다.
    pos = np.cumsum(rate)
    pos = pos[pos < n - 1]
    return np.interp(pos, np.arange(n), x)


def tilt_highs(x, cutoff, amount):
    b, a = signal.butter(2, cutoff / (SR / 2.0), btype="low")
    low = signal.lfilter(b, a, x)
    return low + (x - low) * (1.0 - amount)


def build_launch():
    """발사 — 태엽이 풀리며 공이 튕겨나간다.

    세기는 파일이 아니라 당긴 힘(speed)이 정한다. 여기서는 음색만 맞춘다.
    """
    x = cut_best_hit(load(INBOX / "B4.wav"))
    # 4개 중 유일하게 몸통이 있는 것을 골랐지만 여전히 고역이 세다.
    return tilt_highs(x, 5000.0, 0.45)


def build_drain():
    """낙하 — 공을 잃는다. ★ 벽 소재에서 파생한다 (모듈 주석 참고)."""
    tok = cut_best_hit(load(INBOX / "B_tok.wav"))
    body = cut_best_hit(load(INBOX / "B_body.wav"))

    b, a = signal.butter(2, [150.0 / (SR / 2.0), 900.0 / (SR / 2.0)], btype="band")
    body = signal.lfilter(b, a, body)

    n = int(0.22 * SR)
    rms = lambda v: float(np.sqrt(np.mean(v ** 2))) or 1e-9

    def fit(v, tau):
        y = np.zeros(n)
        m = min(len(v), n)
        y[:m] = v[:m]
        return (y * env_exp(n, tau)) / rms(y * env_exp(n, tau))

    mix = fit(tok, 0.070) * 1.0 + fit(body, 0.090) * 0.45
    return tilt_highs(pitch_fall(mix), 2600.0, 0.55)


def build_select():
    """공 선택 — 웨이브 시작 시 공을 고른다. 조작 확인음이라 짧고 작다."""
    x = cut_best_hit(load(INBOX / "B6.wav"))
    return tilt_highs(x, 4200.0, 0.35)


# 파일 -> (만드는 함수, 피크dB, hold, fall, 설명)
SPECS = {
    "SFX_Ball_Launch": (build_launch, -5.0, 0.090, 0.200,
                        "발사 — 세기는 speed 가 정한다"),
    "SFX_Ball_Drain": (build_drain, -7.0, 0.140, 0.320,
                       "낙하 — 벽 소재에 피치 하강. 공을 잃는다"),
    "SFX_Ball_Select": (build_select, -12.0, 0.040, 0.090,
                        "공 선택 — 짧은 확인음"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print(f"{'파일':22s}{'길이':>7s}{'피크':>8s}{'중심':>8s}{'저':>5s}{'몸통':>6s}{'고':>5s}")
    print("-" * 64)

    stats = {}
    for name, (fn, peak_db, hold, fall, why) in SPECS.items():
        x = norm_peak(trim_floor(gate(fn(), hold, fall)), peak_db)

        S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / SR)
        total = S.sum() or 1e-12
        stats[name] = {
            "cent": float((S * f).sum() / total),
            "audible": float(S[f >= 120].sum() / total * 100.0),
        }

        print(f"{name:22s}{len(x) / SR * 1000:6.0f}ms{peak_db:7.1f}dB"
              f"{stats[name]['cent']:7.0f}Hz"
              f"{S[f < 400].sum() / total * 100:4.0f}%"
              f"{S[(f >= 400) & (f < 2500)].sum() / total * 100:5.0f}%"
              f"{S[f >= 2500].sum() / total * 100:4.0f}%")
        print(f"{'':22s}{why}")

        if args.dry_run:
            continue

        OUT.mkdir(parents=True, exist_ok=True)
        write_wav(OUT / f"{name}.wav", x)
        (OUT / f"{name}.wav.import").write_text(
            IMPORT_TEMPLATE.format(name=name), encoding="utf-8")

    # ★ 여기서 걸리면 게임에 넣지 않는다.
    #   120Hz 아래는 노트북·휴대폰 스피커가 거의 못 낸다. 낙하음이 계속
    #   그 아래로 떨어져서 넣은 검사다.
    for name, s in stats.items():
        assert s["audible"] >= 40.0, \
            f"{name} 의 에너지가 가청대역 밖이다 (120Hz 위 {s['audible']:.0f}%)"

    print("\n자가 검증 통과 — 세 소리 모두 가청대역에 에너지가 있다")
    if args.dry_run:
        print("--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"3종 반입 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
