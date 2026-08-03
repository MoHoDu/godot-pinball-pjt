"""발광 테두리 프리셋 5종 — 기존 BallGlowOutlineRules 구조 그대로, 색·분절·흔들림·밝기만 변경"""
import os
os.makedirs('/tmp/var/tres',exist_ok=True)
def c(t,a=1.0):
    r,g,b=[x/255 for x in t]; return f'Color({r:.3f}, {g:.3f}, {b:.3f}, {a})'
# 공별: (주색, 안개색, 분절/흔들림 성격)
P={
 'Clockwork': dict(kr='정속 태엽눈', core=(227,166,63), mist=(150,106,40), ca=0.80, ma=1.0,
                   drift=0.45, wobble=0.02, plume=0.08, wisp=0.45, wisp_lobes=8, bands=5, peak=0.55,
                   note='끊김 간격이 일정한 분절 링. 흔들림 최소'),
 'Rubber':    dict(kr='고무막 유리눈', core=(244,164,98), mist=(196,88,44), ca=0.82, ma=1.0,
                   drift=0.75, wobble=0.09, plume=0.20, wisp=0.85, wisp_lobes=9, bands=5, peak=0.65,
                   note='완벽한 원보다 탄성 있는 곡선. 흔들림 큼'),
 'Gel':       dict(kr='완충 젤 유리눈', core=(222,230,184), mist=(140,168,104), ca=0.70, ma=1.0,
                   drift=0.35, wobble=0.03, plume=0.10, wisp=0.40, wisp_lobes=7, bands=6, peak=0.48,
                   note='두께 변화가 작고 부드러운 원. 낮은 밝기'),
 'Lead':      dict(kr='납심 유리눈', core=(200,162,68), mist=(120,96,48), ca=0.76, ma=1.0,
                   drift=0.28, wobble=0.02, plume=0.05, wisp=0.30, wisp_lobes=6, bands=4, peak=0.52,
                   note='절제된 금색 링. 무거운 빛. 과도한 흔들림 없음'),
 'HollowBell':dict(kr='속빈 방울눈', core=(226,214,240), mist=(140,100,180), ca=0.74, ma=1.0,
                   drift=0.85, wobble=0.07, plume=0.26, wisp=0.95, wisp_lobes=13, bands=5, peak=0.60,
                   note='일부가 비어 있는 원형 링. 빛나는 구간과 빈 구간이 불균일'),
}
TEALC=(79,166,146); GOLD=(217,179,76); IVORY=(240,224,195)
TPL='''[gd_resource type="Resource" script_class="BallGlowOutlineRules" format=3]

[ext_resource type="Script" path="res://scripts/ball_base_system/vfx/ball_glow_outline_rules.gd" id="1_glow"]

[resource]
script = ExtResource("1_glow")
radius_ratio = 1.818
peak_alpha = {peak}
band_count = {bands}
falloff_exp = 0.85
plume_amount = {plume}
plume_lobes = 5
wisp_amount = {wisp}
wisp_lobes = {wisp_lobes}
wisp_radial = 1
inner_bloom = 0.3
gaze_stretch = 0.1
drift_speed = {drift}
core_alpha = {ca}
core_width_ratio = 0.062
wobble_amount = {wobble}
flash_alpha_scale = 1.3
flash_hold_time = 0.04
flash_fade_time = 0.18
normal_grade_strength = 0.45
outer_darken = 0.58
normal_core_color = {ncc}
normal_mist_color = {ncm}
combo_core_color = {ccc}
combo_mist_color = {ccm}
flash_core_color = {fcc}
flash_mist_color = {fcm}
curse_core_color = Color(0.690, 0.839, 0.361, 0.7)
curse_mist_color = Color(0.541, 0.388, 0.788, 1.0)
danger_core_color = Color(1.0, 0.588, 0.667, 0.8)
danger_mist_color = Color(0.839, 0.243, 0.376, 1.0)
'''
for k,v in P.items():
    s=TPL.format(kr=v['kr'], note=v['note'], peak=v['peak'], bands=v['bands'], plume=v['plume'],
                 wisp=v['wisp'], wisp_lobes=v['wisp_lobes'], drift=v['drift'], ca=v['ca'], wobble=v['wobble'],
                 ncc=c(v['core'],v['ca']), ncm=c(v['mist']),
                 ccc=c(v['core'],0.92), ccm=c(v['mist']),
                 fcc=c(IVORY), fcm=c(TEALC))
    open(f'/tmp/var/tres/BallGlowOutlineRules_{k}.tres','w').write(s)
    print(f"{k:<11} {v['kr']:<9} peak {v['peak']} · bands {v['bands']} · drift {v['drift']} · wobble {v['wobble']}  — {v['note']}")
