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
