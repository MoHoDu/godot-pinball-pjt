#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
그룹 2 — 벽 충돌 3종을 inbox 소재에서 마감한다.

  python build_wall_group.py [--dry-run]

★ 셋은 **다른 물체 셋이 아니라 같은 벽의 세기 차이**여야 한다.
  그래서 소재를 따로 뽑지 않고 **같은 나무 톡 위에 층을 쌓는다.**

    B1 저속  나무 톡
    B2 중속  나무 톡 + 몸통          (속 빈 프레임이 울린다)
    B3 고속  나무 톡 + 몸통 + 유리   (유리공이 세게 부딪힌다)

  유리 층은 플리퍼 타격(A4)에 쓴 것과 **같은 파일**이다. 같은 유리공이니
  그래야 게임 전체가 한 재질로 들린다.

★ 기획서 규격 (p.62)
    길이 0.08~0.14초 · 패링 대비 -8~-10dB · 피치 ±5% · 최대 동시 4개
    최소 간격 0.04초 · 두 번째 연타부터 -3dB
  피치와 연타 감쇠는 런타임이 건다. 여기서는 길이와 피크만 맞춘다.

★ 세 파일의 피크는 **같다**. 속도별 음량 차이는 런타임(speed_volume_range)이
  만든다. 파일에 세기를 구우면 이중 적용이 된다.
"""

import argparse
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

from build_sfx import SR, ROOT, env_exp, gate, norm_peak, trim_floor, write_wav
from cut_best_hit import cut_best_hit

INBOX = ROOT / "inbox" / "ball"
GLASS = ROOT / "inbox" / "flipper" / "A4_glass.wav"
OUT = ROOT.parent.parent / "Resources" / "sfx" / "walls"

## 패링(-1dB) 대비 -9dB. 기획서 p.62 의 -8~-10dB 구간 한가운데다.
WALL_PEAK_DB = -10.0

## 규격 0.08~0.14초 안에 들어오게 잡은 게이트다.
GATE_HOLD = 0.060
GATE_FALL = 0.115

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/walls/{name}.wav"

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

# 파일 -> (몸통 비중, 유리 비중, 설명)
#   나무 톡은 셋 다 1.0 으로 같다. 그것이 "같은 벽"을 만든다.
TIERS = {
    "SFX_Wall_Hit_Low": (0.00, 0.00, "저속 — 짧은 나무 톡"),
    "SFX_Wall_Hit_Mid": (0.55, 0.00, "중속 — 속 빈 프레임의 둑"),
    "SFX_Wall_Hit_High": (0.35, 0.30, "고속 — 유리공이 세게 부딪힌다"),
}


def load(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64) / 32768.0
    x = x if x.ndim == 1 else x.mean(axis=1)

    if rate != SR:
        idx = np.linspace(0, len(x) - 1, int(len(x) * SR / rate))
        x = np.interp(idx, np.arange(len(x)), x)

    return x


def body_band(x):
    """몸통 소재에서 쓸 대역만 남긴다.

    ★ 'wooden board' 로 뽑으면 Firefly 는 거의 순수한 초저역 붐을 준다
      (중심 86~187Hz, 400Hz 아래가 87~98%). 그대로 섞으면 나무 톡을 통째로
      삼킨다. 통이 울리는 대역만 남기고 붐은 버린다.
    """
    b, a = signal.butter(2, [150.0 / (SR / 2.0), 900.0 / (SR / 2.0)], btype="band")
    return signal.lfilter(b, a, x)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    rms = lambda v: float(np.sqrt(np.mean(v ** 2))) or 1e-9
    span = int(0.20 * SR)

    def fit(v, tau=None):
        y = np.zeros(span)
        m = min(len(v), span)
        y[:m] = v[:m]
        if tau is not None:
            y = y * env_exp(span, tau)
        return y / rms(y)

    tok = fit(cut_best_hit(load(INBOX / "B_tok.wav")))
    body = fit(body_band(cut_best_hit(load(INBOX / "B_body.wav"))), 0.030)
    glass = fit(cut_best_hit(load(GLASS)), 0.045)

    print(f"{'파일':22s}{'길이':>7s}{'중심':>8s}{'저':>5s}{'몸통':>6s}{'유리':>6s}")
    print("-" * 60)

    lengths = {}
    for name, (body_w, glass_w, why) in TIERS.items():
        mix = tok + body * body_w + glass * glass_w
        mix = np.tanh(mix * 0.30) / np.tanh(0.30)
        x = norm_peak(trim_floor(gate(mix, GATE_HOLD, GATE_FALL)), WALL_PEAK_DB)

        S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / SR)
        total = S.sum() or 1e-12
        lengths[name] = len(x) / SR

        print(f"{name:22s}{len(x) / SR * 1000:6.0f}ms"
              f"{(S * f).sum() / total:7.0f}Hz"
              f"{S[f < 400].sum() / total * 100:4.0f}%"
              f"{S[(f >= 400) & (f < 2500)].sum() / total * 100:5.0f}%"
              f"{S[(f >= 4000) & (f <= 10000)].sum() / total * 100:5.0f}%")
        print(f"{'':22s}{why}")

        if args.dry_run:
            continue

        OUT.mkdir(parents=True, exist_ok=True)
        write_wav(OUT / f"{name}.wav", x)
        (OUT / f"{name}.wav.import").write_text(
            IMPORT_TEMPLATE.format(name=name), encoding="utf-8")

    # ★ 여기서 걸리면 게임에 넣지 않는다. 기획서 p.62 규격이다.
    for name, seconds in lengths.items():
        assert 0.08 <= seconds <= 0.14, \
            f"{name} 길이가 규격(0.08~0.14초)을 벗어났다: {seconds:.3f}초"

    print("\n자가 검증 통과 — 세 구간 모두 길이 0.08~0.14초")
    if args.dry_run:
        print("--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"3종 반입 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
