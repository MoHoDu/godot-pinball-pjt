#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
전체 오디션 — 게임에 반입된 22종을 **한 파일로 이어 붙여** 한 번에 검수한다

  python build_full_audition.py

★ 단발을 따로 들으면 무엇을 만들어도 밋밋하다. 그리고 22개 파일을 하나씩
  열어보는 것은 검수가 아니라 노동이다. 순서와 간격을 정해 흐름으로 듣는다.

구간
  A 플리퍼 6종      선택 → 작동 → 타격 → 강타격 → 복귀 → 패링
  B 벽 3종          저 → 중 → 고속
  C ★ 네 갈래       같은 Space 가 헛침/타격/강타격/패링으로 갈리는가
  D 흐름 2종        발사 → 낙하
  E 콤보 4종        상승(피치 사다리) → 단계 → 목표도달 → 실패
  F 웨이브 2종      승 → 패
  G 범퍼 8종        단추·솜·용수철·북·대포조작·대포발사·파괴·리스폰
  H 실전 리듬       벽을 튕기다 범퍼를 맞고 콤보가 오르다 패링

★ 구간 사이에는 1초를 비운다. 어디부터 다른 구간인지 알 수 있어야 한다.
★ 파일에 구워진 dB 관계를 그대로 쓴다. 여기서 또 깎으면 검수가 무의미해진다.
"""

import numpy as np
from scipy.io import wavfile

from build_sfx import SR, ROOT, AUDITION, secs, write_wav

RESOURCES = ROOT.parent.parent / "Resources" / "sfx"

# settings/sfx/*.tres 와 같은 값이어야 한다
PITCH_JITTER = 0.05
REPEAT_STEP_DB = -3.0
REPEAT_FLOOR_DB = -9.0
TIER_EDGES = (420.0, 1050.0)

rng = np.random.default_rng(20260806)


def load(rel):
    rate, data = wavfile.read(str(RESOURCES / rel))
    x = data.astype(np.float64) / 32768.0
    return x if x.ndim == 1 else x.mean(axis=1)


def place(buf, x, at, gain_db=0.0, pitch=None):
    """게임이 하는 처리(피치 ±5%)를 걸어 얹는다."""
    p = pitch if pitch is not None else 1.0 + rng.uniform(-PITCH_JITTER, PITCH_JITTER)
    idx = np.arange(0, len(x), p)
    y = np.interp(idx, np.arange(len(x)), x) * (10.0 ** (gain_db / 20.0))
    s = secs(at)
    e = min(len(buf), s + len(y))
    if e > s:
        buf[s:e] += y[:e - s]


def main():
    S = {
        "sel": load("flippers/SFX_Flipper_Select.wav"),
        "act": load("flippers/SFX_Flipper_Activate.wav"),
        "hit": load("flippers/SFX_Flipper_Hit.wav"),
        "str": load("flippers/SFX_Flipper_StrongHit.wav"),
        "ret": load("flippers/SFX_Flipper_Return.wav"),
        "par": load("flippers/SFX_Flipper_Parry.wav"),
        "w_lo": load("walls/SFX_Wall_Hit_Low.wav"),
        "w_mid": load("walls/SFX_Wall_Hit_Mid.wav"),
        "w_hi": load("walls/SFX_Wall_Hit_High.wav"),
        "launch": load("balls/SFX_Ball_Launch.wav"),
        "drain": load("balls/SFX_Ball_Drain.wav"),
        "c_rise": load("combo/SFX_Combo_Rise.wav"),
        "c_tier": load("combo/SFX_Combo_Tier.wav"),
        "c_tgt": load("combo/SFX_Combo_Target.wav"),
        "c_out": load("combo/SFX_Combo_Timeout.wav"),
        "win": load("wave/SFX_Wave_Win.wav"),
        "lose": load("wave/SFX_Wave_Lose.wav"),
        "b_btn": load("bumpers/SFX_Bumper_Button.wav"),
        "b_cot": load("bumpers/SFX_Bumper_Cotton.wav"),
        "b_spr": load("bumpers/SFX_Bumper_Spring.wav"),
        "b_drm": load("bumpers/SFX_Bumper_Drum.wav"),
        "b_clk": load("bumpers/SFX_Bumper_CannonClick.wav"),
        "b_fire": load("bumpers/SFX_Bumper_CannonFire.wav"),
        "b_des": load("bumpers/SFX_Bumper_Destroy.wav"),
        "b_res": load("bumpers/SFX_Bumper_Respawn.wav"),
    }

    parts = []

    # A. 플리퍼 6종을 순서대로
    a = np.zeros(secs(4.0))
    for i, k in enumerate(("sel", "act", "hit", "str", "ret", "par")):
        place(a, S[k], 0.15 + i * 0.62)
    parts.append(a)

    # B. 벽 3종
    b = np.zeros(secs(2.0))
    for i, k in enumerate(("w_lo", "w_mid", "w_hi")):
        place(b, S[k], 0.15 + i * 0.55)
    parts.append(b)

    # C. ★ 같은 Space 가 네 갈래로 갈리는가 — 이 오디션의 핵심
    c = np.zeros(secs(5.4))
    for i, extra in enumerate((None, "hit", "str", "par")):
        at = 0.30 + i * 1.25
        place(c, S["act"], at)                 # 작동음은 네 경우 모두 먼저 난다
        if extra:
            place(c, S[extra], at + 0.07)
        place(c, S["ret"], at + 0.36)
    parts.append(c)

    # D. 흐름 — 발사는 세기에 따라 음량이 갈린다(런타임 처리 재현)
    d = np.zeros(secs(3.0))
    place(d, S["launch"], 0.15, -10.0)         # 약하게 당김
    place(d, S["launch"], 0.90, 0.0)           # 최대로 당김
    place(d, S["drain"], 1.90)
    parts.append(d)

    # E. 콤보 — 상승음은 피치 사다리를 탄다. 그것이 이 소리의 전부다
    e = np.zeros(secs(6.2))
    at = 0.15
    for i in range(8):
        place(e, S["c_rise"], at, 0.0, 1.0 + i * 0.06)
        at += 0.22
    place(e, S["c_tier"], at + 0.15)
    place(e, S["c_tgt"], at + 1.20)
    place(e, S["c_out"], at + 2.60)
    parts.append(e)

    # F. 웨이브 승패
    f = np.zeros(secs(3.0))
    place(f, S["win"], 0.15)
    place(f, S["lose"], 1.60)
    parts.append(f)

    # G. 범퍼 8종 — 서로 갈리는지가 판정 기준이다
    g = np.zeros(secs(5.2))
    for i, k in enumerate(("b_btn", "b_cot", "b_spr", "b_drm",
                           "b_clk", "b_fire", "b_des", "b_res")):
        place(g, S[k], 0.15 + i * 0.60)
    parts.append(g)

    # H. 실전 리듬 — 벽을 튕기다 범퍼를 맞고 콤보가 오르다 패링으로 끝난다
    h = np.zeros(secs(6.0))
    place(h, S["launch"], 0.10)
    at, combo = 0.75, 0
    for k, gap in (("w_hi", 0.26), ("b_btn", 0.34), ("w_mid", 0.30),
                   ("b_drm", 0.36), ("w_lo", 0.32), ("b_spr", 0.38),
                   ("w_mid", 0.30), ("b_des", 0.42)):
        place(h, S[k], at)
        place(h, S["c_rise"], at + 0.04, 0.0, 1.0 + combo * 0.06)
        combo += 1
        at += gap
    place(h, S["c_tier"], at)
    place(h, S["act"], at + 0.55)
    place(h, S["par"], at + 0.62)
    place(h, S["win"], at + 1.30)
    parts.append(h)

    gap_buf = np.zeros(secs(1.0))
    out = np.concatenate([p for pair in zip(parts, [gap_buf] * len(parts))
                          for p in pair])

    path = AUDITION / "SFX_Full_audition.wav"
    write_wav(path, np.clip(out, -1.0, 1.0))

    print(f"전체 오디션: {path}")
    print(f"  길이 {len(out) / SR:.1f}초 · 음원 {len(S)}종")
    print()
    print("  A 플리퍼 6종   B 벽 3종   C ★ 네 갈래   D 흐름 2종")
    print("  E 콤보 4종     F 웨이브 2종   G 범퍼 8종   H 실전 리듬")
    print()
    print("★ 판정 기준")
    print("  C — 같은 Space 가 헛침/타격/강타격/패링으로 갈려 들리는가")
    print("  E — 상승음이 콤보마다 올라가는 사다리로 들리는가")
    print("  G — 범퍼 8종이 서로 다른 물건으로 들리는가")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
