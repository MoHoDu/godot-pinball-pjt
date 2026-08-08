#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BGM — 웨이브 앰비언트 루프를 inbox/bgm 3겹에서 마감한다.

  python build_bgm.py [--dry-run]

★ 이 게임의 BGM 은 곡이 아니라 **공간의 소리**다.
  가이드 15장: 우선순위 "공·패링 > 보스 피격 > 공격 위험음 > 환경음·BGM".
  배경음이 공 충돌·패링을 덮으면 안 된다 — 그래서 멜로디 전개가 있는
  곡 대신 태엽·오르골·낮은 공명 3겹 앰비언트를 깔고, 음량을 SFX 보다
  한참 아래(-26dB RMS 목표)에 앉힌다.

★ 루프는 **크로스페이드로 만든다.**
  Firefly 30초는 시작과 끝이 이어지지 않는다. 꼬리 2초를 머리에 겹쳐
  섞으면 이음매가 사라진다. 겹친 만큼 짧아져 28초 루프가 된다.

소재 채택 (2026-08-08, 각 4변형 중 전후반 RMS 차가 가장 작은 것 =
가장 정상적(stationary)이라 루프에 유리한 것):
  E1 태엽   `An old clockwork mechanism ticking slowly and unevenly` 변형1 (0.7dB)
  E2 오르골 `A creepy old music box playing slow sparse notes` 변형2 (0.2dB)
  E3 드론   `A low dark humming drone, faint eerie room resonance` 변형4 (0.7dB)
"""

import argparse

import numpy as np

from build_sfx import ROOT, SR, write_wav
from build_bumper_group import load, hipass, saturate, shift

INBOX = ROOT / "inbox" / "bgm"
OUT = ROOT.parent.parent / "Resources" / "sfx" / "bgm"

CROSSFADE_S = 2.0

def plain(x):
    return x


def heartbeat(x):
    """심장 박동을 들리게 만든다.

    ★ Firefly 심장은 4변형 전부 중심 30~34Hz 순수 초저역이었다.
      새추레이션만으론 기본음이 너무 세서 배음이 안 올라온다(drive 10 에도
      60Hz 위 10%). 1.8배 올리고 눌러야 중심 70Hz·몸통 59% 가 된다.
      박동이 80% 빨라지는 부수효과는 보스전 긴장감으로 오히려 맞는다.
    """
    return saturate(shift(x, 1.8), 8.0)


## 루프별 구성: 파일 -> (RMS 목표 dB, 전처리)
## 웨이브 — 드론이 바닥, 태엽이 결, 오르골이 표정. 오르골이 제일 들려야 한다.
## 보스   — 기획서 11-1 "불규칙한 태엽 진동 + 하트 핵의 둔탁한 박동".
##          박동이 표정이고 뒤틀린 오르골이 저주의 낯빛이다.
LOOPS = {
    "BGM_Wave_Loop": {
        "E1_clockwork.wav": (-34.0, plain),
        "E2_musicbox.wav": (-28.0, plain),
        "E3_drone.wav": (-33.0, plain),
    },
    "BGM_Boss_Loop": {
        "F1_heartbeat.wav": (-27.0, heartbeat),
        "F2_warpedbox.wav": (-29.0, plain),
        "F3_rumble.wav": (-33.0, plain),
    },
}

## ★ 임포트 옵션의 loop_mode 는 스트림의 enum 과 **다르다.**
##   임포터: 0=파일에서 감지, 1=끔, 2=Forward. 스트림: 1=LOOP_FORWARD.
##   1 로 썼다가 "루프 켬" 인 줄 알았는데 실제로는 꺼져 있었다.
IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/bgm/{name}.wav"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def seamless_loop(x, fade_s=CROSSFADE_S):
    """꼬리를 머리에 겹쳐 섞어 이음매 없는 루프를 만든다.

    등전력(sin/cos) 크로스페이드 — 선형으로 섞으면 겹치는 구간의
    에너지가 패여서 루프 지점이 '숨을 쉬듯' 들린다.
    """
    n = int(SR * fade_s)
    body, tail = x[:-n], x[-n:]

    t = np.linspace(0.0, np.pi / 2.0, n)
    head = body[:n] * np.sin(t) ** 2 + tail * np.cos(t) ** 2

    out = body.copy()
    out[:n] = head
    return out


def set_rms(x, target_db):
    rms = float(np.sqrt(np.mean(x ** 2))) or 1e-9
    return x * (10.0 ** (target_db / 20.0)) / rms


def build_loop(loop_name, layers, dry_run):
    print(f"\n[{loop_name}]")
    # ★ 길이를 먼저 맞추고 **그 다음** 루프를 만든다.
    #   루프를 만든 뒤에 자르면 잘린 겹의 루프점(원래 길이 끝)이 사라져
    #   이음매가 30% 씩 점프했다. 심장(1.8배 가공 → 16.7s)과 오르골(28s)을
    #   섞다가 실제로 겪었다. 자르는 것은 루프 이전이어야 한다.
    raws = {name: process(load(INBOX / name))
            for name, (_lv, process) in layers.items()}
    shortest = min(len(x) for x in raws.values())

    mixed = None
    for name, (level_db, _p) in layers.items():
        x = set_rms(seamless_loop(hipass(raws[name][:shortest], 40.0)), level_db)
        mixed = x if mixed is None else mixed + x
        print(f"  {name:20s} {level_db:6.1f}dB  {len(x) / SR:.1f}s")

    peak_db = 20.0 * np.log10(np.max(np.abs(mixed)))
    rms_db = 20.0 * np.log10(np.sqrt(np.mean(mixed ** 2)))

    # 클리핑만 막는다. 피크 정규화로 끌어올리면 BGM 이 SFX 위로 올라온다.
    if peak_db > -6.0:
        mixed *= 10.0 ** ((-6.0 - peak_db) / 20.0)
        rms_db += -6.0 - peak_db

    # ★ 이음매 검사 — **샘플 불연속**을 본다.
    #
    #   처음엔 앞뒤 0.2초 RMS 차로 검사했는데, 성긴 오르골은 루프 지점
    #   직후에 음이 오고 직전엔 조용한 것이 정상이라 11dB 가 나와도
    #   문제가 아니었다. 틱을 내는 것은 레벨 차가 아니라 **파형 점프**다.
    #   구조상 out[-1] → out[0] 은 원본의 연속 구간과 같아야 한다.
    jump = abs(float(mixed[0]) - float(mixed[-1]))
    peak = float(np.max(np.abs(mixed))) or 1e-9
    print(f"\n루프 {len(mixed) / SR:.1f}s  RMS {rms_db:.1f}dB  이음매 점프 {jump / peak * 100:.2f}%")
    assert jump < peak * 0.05, \
        f"루프 이음매가 피크의 {jump / peak * 100:.1f}% 만큼 점프한다. 틱이 들린다."
    assert rms_db < -20.0, f"BGM RMS {rms_db:.1f}dB — SFX 를 덮을 만큼 크다."

    if dry_run:
        return

    OUT.mkdir(parents=True, exist_ok=True)
    write_wav(OUT / f"{loop_name}.wav", mixed)
    (OUT / f"{loop_name}.wav.import").write_text(
        IMPORT_TEMPLATE.format(name=loop_name), encoding="utf-8")
    print(f"  반입 → {OUT / loop_name}.wav")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    for loop_name, layers in LOOPS.items():
        build_loop(loop_name, layers, args.dry_run)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
