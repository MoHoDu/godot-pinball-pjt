#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
raw/ 폴더 구조의 단일 기준 — 생성·추출·필터가 전부 여기를 본다.

★ 왜 만들었나 (2026-08-06 형락님 지적)
  "한 그룹 생성할 때마다 폴더 하나씩 만들어서 거기다 넣어줘.
   어떤 걸 내가 재생해야 할지 모르겠잖아."

  맞는 지적이다. 36개가 한 폴더에 평평하게 쌓여 있으면 무엇을 들어야
  하는지 알 수 없다. 게다가 `cut/` 파일은 전부 -10dBFS 로 정규화돼 있어서
  **원본이 무음이어도 겉보기엔 멀쩡하다.**

구조

  raw/<그룹>/
    1_select/           ← ★ 여기 있는 걸 재생하면 된다. 걸러낸 후보만 남는다
      flipper_select_01.wav
      flipper_select_05.wav
      _source/          ← 생성 원본. 길이를 바꿔 다시 자를 때만 쓴다
    2_activate/
    3_hit/
    ...
    README.md           ← 역할별로 뭐가 남았고 뭐가 왜 없는지

  폴더 앞 숫자는 **오디션 순서**다. 파일 탐색기에서 위에서부터 재생하면
  기획서가 말하는 순서(선택 → 작동 → 타격 → 강타격 → 복귀 → 패링)가 된다.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"

## 생성 원본을 넣는 하위 폴더 이름. 밑줄로 시작해 목록 맨 아래로 밀린다.
SOURCE_DIR = "_source"

# 오디션 순서. 게임에서 소리가 나는 차례대로 둔다.
ORDER = {
    "wall": ["wall_wood_tok", "wall_hollow_duk", "wall_glass_ting"],
    "flipper": [
        "flipper_select", "flipper_activate", "flipper_hit",
        "flipper_strong", "flipper_return", "flipper_parry",
    ],
    "parry": ["parry_glass_ting", "parry_bell"],
    "ball": [
        "ball_clockwork_escapement", "ball_clockwork_glass_pin",
        "ball_clockwork_detent",
    ],
    # Tier 3 — 게임 흐름
    "flow": ["flow_launch", "flow_drain"],
    "combo": ["combo_rise", "combo_tier", "combo_timeout", "combo_target"],
    "wave": ["wave_win", "wave_lose"],
    # Tier 4 — 범퍼 5종 + 파괴 + 리스폰
    "bumper": [
        "bumper_button", "bumper_cotton", "bumper_spring", "bumper_drum",
        "bumper_cannon_click", "bumper_cannon_fire",
        "bumper_destroy", "bumper_respawn",
    ],
}

# 각 음원이 게임에서 무엇을 표현하는지.
# 소리만 들으면 무엇을 위한 건지 알 수 없어서 판단이 안 된다.
# 생성·검수·정리 어디서든 같이 출력한다.
ROLES = {
    "wall_wood_tok": "벽 충돌 — 저속. 공이 벽에 약하게 닿을 때 (목재 톡)",
    "wall_hollow_duk": "벽 충돌 — 중속. 속 빈 프레임의 둑 하는 몸통",
    "wall_glass_ting": "벽 충돌 — 고속에만 얹는 작은 유리 팅",
    "flipper_hit": "플리퍼 일반 타격 — 플리퍼가 공을 침 (MUST)",
    "flipper_parry": "정확한 패링 — 리듬천국 탁구 같은 음정 있는 폭",
    "flipper_strong": "플리퍼 강한 타격 — 세게 쳤을 때. 금속 쾅이 아닌 탄력 있는 쫙",
    "flipper_activate": "플리퍼 작동 — Space 로 플리퍼가 올라가는 순간. ★기계 동작음",
    "flipper_select": "플리퍼 선택 — 방향키로 조작할 플리퍼 그룹을 바꿀 때",
    "flipper_return": "플리퍼 복귀 — 제자리로 내려앉는 기계 동작음",
    "parry_glass_ting": "정확한 패링 2번째 레이어 — 성공을 알리는 밝은 유리 팅",
    "parry_bell": "정확한 패링 악센트 — 짧은 종 1음",
    "ball_clockwork_escapement": "정속 태엽눈 재질음 — 태엽 걸림쇠 클릭",
    "ball_clockwork_glass_pin": "정속 태엽눈 재질음 — 유리 위 금속 톡",
    "ball_clockwork_detent": "정속 태엽눈 재질음 — 태엽 감기 멈춤",

    # Tier 3 — 게임 흐름. 물릴 시그널을 함께 적는다.
    "flow_launch": "공 발사 — 태엽이 풀리며 튕겨나감 (ball_launched, speed→음량)",
    "flow_drain": "공 낙하 — 공을 잃음. 하강감 (ball_drained)",
    "combo_rise": "콤보 상승 — 한 음. 피치 사다리는 런타임 (combo_changed)",
    "combo_tier": "콤보 단계 상승 — 상승보다 크고 밝게 (combo_tier_changed)",
    "combo_timeout": "콤보 실패 — 시간 초과로 끊김. 태엽 풀리는 실망 (combo_finished)",
    "combo_target": "목표 점수 도달 — 밝은 성취 (target_score_reached)",
    "wave_win": "웨이브 승리 — 저주가 풀림. 오르골 한 음",
    "wave_lose": "웨이브 패배 — 태엽이 멈춤 (wave_balls_exhausted)",

    # Tier 4 — 범퍼. 가이드의 3층 구조(어택 + 재질음 + 기능 악센트) 중 재질음.
    "bumper_button": "범퍼 단추 — 딱. 큰 플라스틱 단추가 눌림",
    "bumper_cotton": "범퍼 솜인형 — 푹. 소리를 먹는 느낌",
    "bumper_spring": "범퍼 용수철인형 — 끽+팡. 튀어오름",
    "bumper_drum": "범퍼 장난감 북 — 통. 속 빈 울림",
    "bumper_cannon_click": "범퍼 태엽대포 조작 — 철컥 (control_started)",
    "bumper_cannon_fire": "범퍼 태엽대포 발사 — 팡 (control_ended)",
    "bumper_destroy": "범퍼 공통 파괴음 — 장난감이 부서짐 (durability 0)",
    "bumper_respawn": "범퍼 리스폰 예고음 — 태엽이 다시 감김 (state_changed)",
}


def role_of(stem):
    """`flipper_select_03` → `flipper_select`. 끝의 변형 번호만 뗀다."""
    head, _, tail = stem.rpartition("_")
    return head if head and tail.isdigit() else stem


def folder_name(group, role):
    """`flipper`, `flipper_select` → `1_select`"""
    order = ORDER.get(group, [])
    index = order.index(role) + 1 if role in order else len(order) + 1
    short = role[len(group) + 1:] if role.startswith(group + "_") else role
    return f"{index}_{short}"


def role_dir(group, role):
    """재생할 후보가 들어가는 폴더."""
    return RAW / group / folder_name(group, role)


def source_dir(group, role):
    """생성 원본이 들어가는 폴더. 다시 자를 때만 쓴다."""
    return role_dir(group, role) / SOURCE_DIR


def iter_role_dirs(group):
    """그룹 안의 역할 폴더를 오디션 순서대로 돌려준다."""
    base = RAW / group
    if not base.is_dir():
        return

    for role in ORDER.get(group, []):
        d = base / folder_name(group, role)
        if d.is_dir():
            yield role, d
