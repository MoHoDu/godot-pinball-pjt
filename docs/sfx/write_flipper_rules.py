#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FlipperSfxRules.tres 를 **채택된 음원에서 생성한다.**

  python write_flipper_rules.py

★ 왜 생성하는가 (2026-08-07)
  손으로 고치다 두 번 깨뜨렸다. 한 번은 없는 파일을 ext_resource 로 남겨서
  **리소스 전체 로딩이 깨졌고**(남아 있던 큐까지 전부 무음), 한 번은 정규식
  편집이 `[resource]` 블록을 날렸다.

  음원 파일이 있느냐 없느냐가 유일한 진실이다. 폴더를 보고 있는 것만 적는다.
  없는 것은 아예 안 쓰므로 끊어진 참조가 원천적으로 생기지 않는다.

음량 위계는 기획서 우선순위를 따른다. 파일 피크에 이미 구워져 있고
여기서는 순서만 지킨다.
    복귀 -15 < 선택 -14 < 작동 -9 < 타격 -2 < 강타격 -1.6 < 패링 -1
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
FLIPPERS = REPO / "Resources" / "sfx" / "flippers"
OUT = REPO / "settings" / "sfx" / "FlipperSfxRules.tres"

# 큐 이름 -> (파일명, 규칙 필드, cue_id, 역할 설명, 우선순위, 동시재생, 피치흔들림, 보정dB)
#
# 순서가 곧 음량 위계 순서다. 위에서부터 작다.
#
# ★ 보정dB 는 파일 피크와 별개다. 복귀음은 위계상 -15dB 로 굽지만 그대로 두면
#   작동음(-9dB) 옆에서 아예 안 들려 "올라감/내려옴"이 구분되지 않는다.
#   파일에는 위계를 지켜 굽고, 재생할 때 올린다.
CUES = [
    # ★ 복귀음은 뺐다 (2026-08-07). 파일이 없으면 여기 남아 있어도 무시된다.
    ("SFX_Flipper_Select", "select_cue", "flipper_select",
     "플리퍼 선택 — 방향키로 조작할 그룹을 바꾼다. 공과 무관", 0, 2, 0.04, 0.0),
    ("SFX_Flipper_Activate", "activate_cue", "flipper_activate",
     "플리퍼 작동 — Space 로 올라간다. 공을 못 맞혀도 난다", 0, 3, 0.05, 0.0),
    ("SFX_Flipper_Hit", "hit_cue", "flipper_hit",
     "플리퍼 일반 타격 — 유리공을 친다. 단단한 톡/탁 (기획서 MUST)", 30, 3, 0.05, 0.0),
    ("SFX_Flipper_StrongHit", "strong_hit_cue", "flipper_strong_hit",
     "플리퍼 강한 타격 — 금속성 쾅이 아닌 탄력 있는 쫙/팡", 30, 2, 0.04, 0.0),
    ("SFX_Flipper_Parry", "parry_perfect_cue", "flipper_parry_perfect",
     "정확한 패링 — 명쾌한 탁. 우선순위 1위", 50, 3, 0.03, 0.0),
]

# 타격 계열만 속도에 반응한다. 조작음은 세기 개념이 없다.
SPEED_AWARE = {"hit_cue", "strong_hit_cue"}

HEADER = """[gd_resource type="Resource" script_class="FlipperSfxRules" load_steps={steps} format=3]

; ★ 이 파일은 write_flipper_rules.py 가 생성한다. 손으로 고치지 않는다.
;   Resources/sfx/flippers/ 에 **실제로 있는 음원만** 적는다.
;
;   없는 파일을 ext_resource 로 참조하면 리소스 전체 로딩이 깨지고,
;   그러면 남아 있는 큐까지 전부 무음이 된다. 실제로 그렇게 됐었다.

[ext_resource type="Script" path="res://scripts/sfx_system/rules/flipper_sfx_rules.gd" id="1_rules"]
[ext_resource type="Script" path="res://scripts/sfx_system/sfx_cue.gd" id="2_cue"]
"""


def main():
    live = [c for c in CUES if (FLIPPERS / f"{c[0]}.wav").exists()]
    if not live:
        print("★ 반입된 플리퍼 음원이 없다.")
        return 1

    steps = 2 + len(live) * 2 + 1
    body = HEADER.format(steps=steps)

    for i, (name, _field, _cid, _role, _pri, _cc, _pj, _db) in enumerate(live):
        body += ('[ext_resource type="AudioStream" '
                 f'path="res://Resources/sfx/flippers/{name}.wav" id="{i + 3}_snd"]\n')

    for i, (name, field, cid, role, pri, cc, pj, db) in enumerate(live):
        speed = ("speed_reference_range = Vector2(200, 1200)\n"
                 "speed_volume_range = Vector2(-3, 0)\n"
                 if field in SPEED_AWARE else
                 "speed_volume_range = Vector2(0, 0)\n")
        body += f"""
[sub_resource type="Resource" id="Cue_{field}"]
script = ExtResource("2_cue")
cue_id = &"{cid}"
role = "{role}"
streams = Array[AudioStream]([ExtResource("{i + 3}_snd")])
selection_mode = 0
priority = {pri}
maximum_concurrent = {cc}
base_volume_db = {db}
{speed}pitch_jitter = {pj}
minimum_repeat_interval = 0.04
repeat_attenuation_db = -3.0
repeat_attenuation_floor_db = -6.0
"""

    body += '\n[resource]\nscript = ExtResource("1_rules")\n'
    for _name, field, _cid, _role, _pri, _cc, _pj, _db in live:
        body += f'{field} = SubResource("Cue_{field}")\n'
    body += "strong_hit_speed_threshold = 1200.0\n"

    OUT.write_text(body, encoding="utf-8")

    print(f"규칙 생성 → {OUT}")
    for name, field, _cid, role, _pri, _cc, _pj, _db in live:
        print(f"  {field:18s} {name:26s} {role}")

    missing = [c[1] for c in CUES if c not in live]
    if missing:
        print(f"\n대기 중 ({len(missing)}종): {', '.join(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
