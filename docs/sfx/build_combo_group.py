#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
그룹 3 — 콤보·웨이브 6종을 inbox/combo 소재에서 마감한다.

  python build_combo_group.py [--dry-run]

★ 이 그룹은 전부 **악기 소리**라 Firefly 수율이 극적으로 다르다.
  범퍼 그룹은 재질을 요구할수록 대역 밖으로 도망갔는데, 악기 이름을
  대면 24변형 전부 가청대역에 앉았다 (150Hz 아래 0%). Firefly 는
  물체보다 악기를 훨씬 잘 안다.

★ 상승음(rise)만 특별하다 — **런타임 피치 사다리의 밑음**이다.
  `ComboSfxRules.get_rise_pitch()` 가 콤보 수에 따라 pitch_scale 을
  올리므로, 파일은 깨끗한 한 음이어야 한다. 배음이 지저분하면
  사다리를 올릴 때마다 지저분함도 같이 올라간다.

★ 승패(win/lose)는 사건이 아니라 **장면**이라 길다 (2~3초).
  게이트를 짧게 걸면 멜로디가 중간에 끊긴다. 꼬리만 다듬는다.
"""

import argparse

import numpy as np

from build_sfx import ROOT, SR, gate, norm_peak, trim_floor
from build_sfx import write_wav
from cut_best_hit import cut_best_hit
from build_bumper_group import load

INBOX = ROOT / "inbox" / "combo"
OUT_COMBO = ROOT.parent.parent / "Resources" / "sfx" / "combo"
OUT_WAVE = ROOT.parent.parent / "Resources" / "sfx" / "wave"

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://{rel}/{name}.wav"

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


def one_shot(name):
    """짧은 단발 — 가장 또렷한 타격 하나만 발췌한다."""
    return lambda: cut_best_hit(load(INBOX / name))


def full(name):
    """장면 — 멜로디 전체를 그대로 쓴다. 발췌하면 이야기가 끊긴다."""
    return lambda: load(INBOX / name)


# 파일 -> (소스, 출력 폴더, 피크dB, hold, 총길이, 설명)
#
# ★ gate() 의 마지막 인자는 페이드 길이가 아니라 **총 길이 상한**이다.
#   0.55 를 페이드로 알고 줬다가 승리 멜로디가 0.55초로 잘렸다.
#
# 음량 관계: 단계 > 목표 > 상승 (상승은 초당 여러 번 울린다. 크면 피로하다)
#            승패는 장면이라 크게, 실패는 알림이라 중간.
SPECS = {
    "SFX_Combo_Rise": (one_shot("D1_rise.wav"), OUT_COMBO, -14.0, 0.120, 0.220,
                       "콤보 상승 — 오르골 한 음. 런타임 피치 사다리의 밑음"),
    "SFX_Combo_Tier": (one_shot("D2_tier.wav"), OUT_COMBO, -8.0, 0.200, 0.380,
                       "콤보 단계 — 유리 종. 상승음보다 크고 밝다"),
    "SFX_Combo_Timeout": (full("D3_timeout.wav"), OUT_COMBO, -12.0, 0.700, 1.000,
                          "콤보 실패 — 휘슬이 흘러내린다 (1811→1059Hz 실측)"),
    "SFX_Combo_Target": (one_shot("D4_target.wav"), OUT_COMBO, -9.0, 0.250, 0.380,
                         "목표 도달 — 실로폰 두 음"),
    "SFX_Wave_Win": (full("D5_win.wav"), OUT_WAVE, -6.0, 2.300, 3.000,
                     "웨이브 승리 — 오르골 멜로디. 저주가 풀린다"),
    "SFX_Wave_Lose": (full("D6_lose.wav"), OUT_WAVE, -8.0, 2.300, 3.000,
                      "웨이브 패배 — 태엽이 늘어지며 멈춘다 (1877→779Hz 실측)"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print(f"{'파일':22s}{'길이':>8s}{'피크':>8s}{'중심':>8s}{'고역%':>6s}")
    print("-" * 56)

    for name, (fn, out, peak_db, hold, fall, why) in SPECS.items():
        x = norm_peak(trim_floor(gate(fn(), hold, fall)), peak_db)

        S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / SR)
        total = S.sum() or 1e-12
        cent = float((S * f).sum() / total)

        print(f"{name:22s}{len(x) / SR:6.2f}s{peak_db:7.1f}dB{cent:7.0f}Hz"
              f"{S[f >= 2500].sum() / total * 100:5.0f}%")
        print(f"{'':22s}{why}")

        # 가청대역 검사 — 악기라 통과가 정상이지만, 소재를 바꿀 때를 대비해 둔다.
        assert cent >= 150.0, f"{name} 중심이 {cent:.0f}Hz 다. 안 들린다."

        # 승패는 멜로디가 살아 있어야 한다. 1초 미만이면 게이트가 끊은 것이다.
        if name.startswith("SFX_Wave"):
            assert len(x) / SR >= 1.2, f"{name} 이 {len(x) / SR:.2f}s 로 끊겼다."

        if args.dry_run:
            continue

        out.mkdir(parents=True, exist_ok=True)
        write_wav(out / f"{name}.wav", x)
        rel = "Resources/sfx/" + ("wave" if out is OUT_WAVE else "combo")
        (out / f"{name}.wav.import").write_text(
            IMPORT_TEMPLATE.format(rel=rel, name=name), encoding="utf-8")

    if args.dry_run:
        print("\n--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"\n6종 반입 → {OUT_COMBO} · {OUT_WAVE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
