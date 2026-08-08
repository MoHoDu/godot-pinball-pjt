#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
보스(눈 잃은 테디베어) SFX 8종을 inbox/boss 소재에서 마감한다.

  python build_boss_group.py [--dry-run]

근거 문서
  핀볼_보스_스테이지1_기획서 11장 — 상태별 소리 정의
  보스 비주얼·사운드 가이드 13~16장 — 음색·레이어 구조·우선순위

★ 핵심 문장: "거대한 괴물이 아니라, 저주에 잠식된 낡은 봉제 장난감."
  금속·산업 기계음 금지. 천·솜·실·태엽·오르골·유리로만 만든다.

★ 가이드 15장이 포효를, 11-7이 처치를 **레이어 구조**로 정의한다.
  한 프롬프트로 여러 성질을 받으면 매번 한쪽만 왔으므로(범퍼에서 확인),
  레이어는 따로 받거나 기존 소재를 재사용해 여기서 겹친다.
    처치 = 봉제선 연속 풀림 + 유리 공명(A4_glass 재사용) + 오르골 종(D1 재사용)
    솜 생성 = 실 스르륵 + 솜 푹 (+ 솜 부스럭 C2_rustle 재사용)
"""

import argparse

import numpy as np
from scipy import signal

from build_sfx import ROOT, SR, gate, norm_peak, secs, trim_floor
from build_sfx import write_wav
from cut_best_hit import cut_best_hit
from build_bumper_group import hipass, load, saturate, shift, tilt

INBOX = ROOT / "inbox" / "boss"
BUMPER_INBOX = ROOT / "inbox" / "bumper"
COMBO_INBOX = ROOT / "inbox" / "combo"
FLIPPER_INBOX = ROOT / "inbox" / "flipper"
OUT = ROOT.parent.parent / "Resources" / "sfx" / "boss"

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/boss/{name}.wav"

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


def _rms(x):
    return float(np.sqrt(np.mean(x ** 2))) or 1e-9


def _mix(layers):
    """(신호, 배율, 시작초) 목록을 RMS 기준으로 겹친다. 피크 매칭의 함정은 A2 에서 배웠다."""
    n = max(secs(at) + len(x) for x, _, at in layers)
    out = np.zeros(n)
    for x, gain, at in layers:
        s = secs(at)
        out[s:s + len(x)] += (x / _rms(x)) * gain
    return out


def telegraph():
    """팔 공격 예고 — 굵은 실이 당겨지는 끼익 (기획서 11-2)."""
    return load(INBOX / "E1_telegraph.wav")


def arm_swing():
    """팔 공격 — 큰 천 덩어리의 휙 + 속 빈 몸체의 턱 (기획서 11-3).

    금속음 금지가 명시돼 있다. 소재가 천 재질이라 이미 조건을 만족한다.
    초저역만 걷어 무게가 새지 않게 한다.
    """
    return hipass(load(INBOX / "E2_swing.wav"), 40.0)


def boss_hit():
    """보스 피격 — 탄력 있는 팡 + 낮은 장난감 충격 + 솜 푹 (기획서 11-6).

    "쾅!" 이 아니라 "팡 — 푹/툭" 이라고 가이드 16장이 못 박았다.
    봉제 인형을 치는 소재가 정확히 그 결이다. 새추레이션으로 몸통만 세운다.
    """
    return saturate(hipass(cut_best_hit(load(INBOX / "E3_hit.wav")), 45.0), 6.0)


def cotton_telegraph():
    """솜뭉치 생성 예고 — 짧은 저주 점멸음 (기획서 11-5)."""
    return load(INBOX / "E5_blink.wav")


def cotton_spawn():
    """솜뭉치 생성 — 실이 풀리는 스르륵 + 솜 덩어리의 푹 (기획서 11-5).

    받은 소재는 푹(저역)만 있고 스르륵이 약해서, 범퍼 솜에서 검증된
    부스럭(C2_rustle)을 앞에 얹는다. 같은 세계의 솜이라 재질이 맞는다.
    """
    body = hipass(load(INBOX / "E4_spawn.wav"), 45.0)

    b, a = signal.butter(2, 3500.0 / (SR / 2.0), btype="low")
    rustle = signal.lfilter(b, a, cut_best_hit(load(BUMPER_INBOX / "C2_rustle.wav")))

    return _mix([(body, 1.0, 0.0), (rustle, 0.5, 0.0)])


def roar():
    """포효 — 낮게 뒤틀린 오르골 + 천 찢어지는 숨소리 (가이드 15장).

    실제 곰 울음 샘플 금지. 한 프롬프트에 두 레이어를 함께 요구했는데
    이번에는 둘 다 들어왔다 — 악기(오르골)가 절반이라 수율이 좋았다.
    끝의 먹먹해짐은 파일이 아니라 런타임 버스 처리 몫이라 여기 없다.
    """
    return tilt(load(INBOX / "E6_roar.wav"), 4000.0, 0.30)


def defeated():
    """처치 — 봉제선 연속 풀림 + 낮은 바람 + 유리 공명 + 오르골 종 (기획서 11-7).

    저주가 풀리고 유리눈이 돌아오는 **장면**이다. 순서가 이야기다:
    봉제선이 풀리는 동안 → 1.6초에 유리가 울리고 → 2.1초에 오르골 종.
    """
    seams = tilt(load(INBOX / "E7_defeat.wav"), 6000.0, 0.35)
    glass = cut_best_hit(load(FLIPPER_INBOX / "A4_glass.wav"))
    bell = shift(cut_best_hit(load(COMBO_INBOX / "D1_rise.wav")), 0.75)

    return _mix([(seams, 1.0, 0.0), (glass, 0.45, 1.60), (bell, 0.60, 2.10)])


def heartbeat():
    """기본 환경 — 하트 핵의 둔탁한 박동 + 불규칙한 태엽 (기획서 11-1).

    사건이 아니라 깔림이다. 새추레이션으로 배음을 세워 저역이 스피커에서
    죽지 않게만 하고, 음량은 규칙에서 가장 작게 잡는다.
    가이드 13장: 공·패링 > 보스 피격 > 공격 위험음 > **환경음**.
    """
    return saturate(hipass(load(INBOX / "E8_heart.wav"), 40.0), 5.0)


# 파일 -> (함수, 피크dB, hold, 총길이, 설명)
#
# ★ gate() 의 마지막 인자는 총 길이 상한이다 (콤보 그룹에서 얻은 교훈).
# 음량은 가이드 13장의 우선순위를 따른다. 피격이 크고 환경음이 가장 작다.
SPECS = {
    "SFX_Boss_Telegraph": (telegraph, -10.0, 0.700, 1.000, "팔 예고 — 실이 당겨지는 끼익"),
    "SFX_Boss_ArmSwing": (arm_swing, -6.0, 0.600, 0.900, "팔 공격 — 천 휙 + 몸체 턱"),
    "SFX_Boss_Hit": (boss_hit, -4.0, 0.180, 0.380, "피격 — 팡, 푹/툭"),
    "SFX_Boss_CottonTelegraph": (cotton_telegraph, -14.0, 0.500, 0.800, "솜 예고 — 저주 점멸"),
    "SFX_Boss_CottonSpawn": (cotton_spawn, -11.0, 0.550, 0.850, "솜 생성 — 스르륵 + 푹"),
    "SFX_Boss_Roar": (roar, -5.0, 2.300, 3.000, "포효 — 뒤틀린 오르골 + 찢어지는 숨"),
    "SFX_Boss_Defeated": (defeated, -5.0, 2.600, 3.200, "처치 — 봉제선, 유리, 오르골 종"),
    "SFX_Boss_Heartbeat": (heartbeat, -16.0, 2.600, 3.000, "환경 — 하트 핵 박동"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print(f"{'파일':26s}{'길이':>8s}{'피크':>8s}{'중심':>8s}{'<150':>6s}{'RMS':>8s}")
    print("-" * 66)

    for name, (fn, peak_db, hold, total, why) in SPECS.items():
        x = norm_peak(trim_floor(gate(fn(), hold, total)), peak_db)

        S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / SR)
        tot = S.sum() or 1e-12
        cent = float((S * f).sum() / tot)
        low = S[f < 150.0].sum() / tot * 100.0
        rms_db = 20.0 * np.log10(_rms(x))

        print(f"{name:26s}{len(x) / SR:6.2f}s{peak_db:7.1f}dB{cent:7.0f}Hz{low:5.0f}%{rms_db:7.1f}dB")
        print(f"{'':26s}{why}")

        # 저역 자체가 재질인 소리(피격·심장)도 60Hz 아래는 재생이 안 된다.
        assert cent >= 60.0, f"{name} 중심이 {cent:.0f}Hz 다. 스피커가 못 낸다."

        # 장면(포효·처치)은 이야기가 끊기면 안 된다.
        if name in ("SFX_Boss_Roar", "SFX_Boss_Defeated"):
            assert len(x) / SR >= 2.0, f"{name} 이 {len(x) / SR:.2f}s 로 끊겼다."

        if args.dry_run:
            continue

        OUT.mkdir(parents=True, exist_ok=True)
        write_wav(OUT / f"{name}.wav", x)
        (OUT / f"{name}.wav.import").write_text(
            IMPORT_TEMPLATE.format(name=name), encoding="utf-8")

    if args.dry_run:
        print("\n--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"\n8종 반입 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
