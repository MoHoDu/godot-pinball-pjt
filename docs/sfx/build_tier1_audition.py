#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tier 1 오디션 — 게임에 반입된 음원을 **게임이 하는 처리 그대로** 걸어 이어 붙인다.

  python build_tier1_audition.py

★ 단발을 따로 들으면 무엇을 만들어도 밋밋하다. 판단은 리듬 위에서 해야 한다.

★ 여기 적용하는 수치는 전부 settings/sfx/*.tres 와 같아야 한다.
  다르면 오디션에서 들은 것과 게임에서 나는 것이 달라져 검수가 무의미해진다.
    피치 ±5% / 최소 간격 0.04초 / 연타 -3dB(바닥 -9dB) / 속도→음량 -14~0dB
    속도 구간 경계 420 · 1050 px/s

구성
  A 벽 속도 3구간   저 → 중 → 고. 구간마다 음색이 갈리는가
  B 벽 8연타        연타 감쇠가 과하지도 부족하지도 않은가
  C 플리퍼 네 갈래   ★ 핵심. 같은 Space 가 헛침 / 타격 / 강타격 / 패링으로 갈리는가
  D 실전 리듬        벽·타격·패링이 섞인 흐름
"""

import numpy as np
from scipy.io import wavfile

from build_sfx import SR, ROOT, AUDITION, secs, write_wav

RESOURCES = ROOT.parent.parent / "Resources" / "sfx"

# settings/sfx/*.tres 와 같은 값이어야 한다
PITCH_JITTER = 0.05
MIN_INTERVAL = 0.04
REPEAT_STEP_DB = -3.0
REPEAT_FLOOR_DB = -9.0
SPEED_RANGE = (120.0, 900.0)
VOLUME_RANGE = (-14.0, 0.0)
TIER_EDGES = (420.0, 1050.0)


def load(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64) / 32768.0
    return x if x.ndim == 1 else x.mean(axis=1)


def speed_volume_db(speed):
    low, high = SPEED_RANGE
    t = np.clip((speed - low) / (high - low), 0.0, 1.0)
    return VOLUME_RANGE[0] + (VOLUME_RANGE[1] - VOLUME_RANGE[0]) * t


def wall_take(takes, speed):
    """속도 구간으로 음원을 고른다. 랜덤이 아니다."""
    if speed >= TIER_EDGES[1]:
        return takes["wall_high"]
    if speed >= TIER_EDGES[0]:
        return takes["wall_mid"]
    return takes["wall_low"]


def main():
    takes = {
        "wall_low": load(RESOURCES / "walls" / "SFX_Wall_Hit_Low.wav"),
        "wall_mid": load(RESOURCES / "walls" / "SFX_Wall_Hit_Mid.wav"),
        "wall_high": load(RESOURCES / "walls" / "SFX_Wall_Hit_High.wav"),
        "select": load(RESOURCES / "flippers" / "SFX_Flipper_Select.wav"),
        "activate": load(RESOURCES / "flippers" / "SFX_Flipper_Activate.wav"),
        "return": load(RESOURCES / "flippers" / "SFX_Flipper_Return.wav"),
        "hit": load(RESOURCES / "flippers" / "SFX_Flipper_Hit.wav"),
        "strong": load(RESOURCES / "flippers" / "SFX_Flipper_StrongHit.wav"),
        "parry": load(RESOURCES / "flippers" / "SFX_Flipper_Parry.wav"),
    }

    rng = np.random.default_rng(20260806)
    parts = []

    def place(buf, x, at, gain_db=0.0):
        pitch = 1.0 + rng.uniform(-PITCH_JITTER, PITCH_JITTER)
        idx = np.arange(0, len(x), pitch)
        y = np.interp(idx, np.arange(len(x)), x) * (10.0 ** (gain_db / 20.0))
        s = secs(at)
        e = min(len(buf), s + len(y))
        buf[s:e] += y[:e - s]

    # A. 벽 속도 3구간
    a = np.zeros(secs(2.2))
    for i, speed in enumerate((200.0, 700.0, 1500.0)):
        for r in range(2):
            place(a, wall_take(takes, speed), 0.15 + i * 0.7 + r * 0.30,
                  speed_volume_db(speed))
    parts.append(a)

    # B. 벽 8연타 — 연타 감쇠 누적
    b = np.zeros(secs(1.6))
    at = 0.12
    for i in range(8):
        place(b, wall_take(takes, 600.0), at,
              speed_volume_db(600.0) + max(REPEAT_STEP_DB * i, REPEAT_FLOOR_DB))
        at += max(MIN_INTERVAL, 0.11)
    parts.append(b)

    # C. ★ 같은 Space 입력이 네 갈래로 갈리는가 — 이 오디션의 핵심
    #    작동음은 네 경우 모두 먼저 난다. 그 뒤에 무엇이 붙느냐로 결과가 읽혀야 한다.
    c = np.zeros(secs(5.6))
    #    앞머리: 플리퍼 그룹 전환
    place(c, takes["select"], 0.15)
    place(c, takes["select"], 0.45)

    #    ① 헛침 — 작동음 + 복귀음만. 공을 못 맞혔다
    place(c, takes["activate"], 1.10)
    place(c, takes["return"], 1.42)

    #    ② 일반 타격
    place(c, takes["activate"], 2.10)
    place(c, takes["hit"], 2.17)
    place(c, takes["return"], 2.46)

    #    ③ 강한 타격
    place(c, takes["activate"], 3.20)
    place(c, takes["strong"], 3.27)
    place(c, takes["return"], 3.58)

    #    ④ 정확한 패링 (리듬 랠리)
    place(c, takes["activate"], 4.30)
    place(c, takes["parry"], 4.37)
    place(c, takes["return"], 4.72)
    parts.append(c)

    # D. 실전 리듬 — 벽을 튕기다 플리퍼로 받고 마지막에 패링
    d = np.zeros(secs(4.2))
    at = 0.15
    for speed, gap in ((1400.0, 0.26), (1100.0, 0.30), (800.0, 0.34),
                       (600.0, 0.40), (420.0, 0.46)):
        place(d, wall_take(takes, speed), at, speed_volume_db(speed))
        at += gap
    place(d, takes["hit"], at + 0.10)
    at += 0.70
    for speed, gap in ((1300.0, 0.24), (900.0, 0.32), (650.0, 0.38)):
        place(d, wall_take(takes, speed), at, speed_volume_db(speed))
        at += gap
    place(d, takes["parry"], at + 0.12)
    parts.append(d)

    gap_buf = np.zeros(secs(0.5))
    out = np.concatenate([p for pair in zip(parts, [gap_buf] * len(parts))
                          for p in pair])

    path = AUDITION / "SFX_Tier1_audition.wav"
    write_wav(path, np.clip(out, -1.0, 1.0))

    print(f"오디션: {path}")
    print("  A 벽 속도 3구간 / B 벽 8연타 / C ★ 플리퍼 네 갈래 / D 실전 리듬")
    print()
    print("적용한 처리 (settings/sfx/*.tres 와 같은 값)")
    print(f"  피치 ±{PITCH_JITTER * 100:.0f}% · 연타 {REPEAT_STEP_DB}dB"
          f"(바닥 {REPEAT_FLOOR_DB}dB) · 속도→음량 {VOLUME_RANGE[0]}~{VOLUME_RANGE[1]}dB")
    print(f"  속도 구간 경계 {TIER_EDGES[0]:.0f} · {TIER_EDGES[1]:.0f} px/s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
