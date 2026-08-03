"""공별 이동 꼬리 프리셋 — 확정된 셰이더 구조(BallTrailRules)에 색만 갈아끼운다"""
import os
os.makedirs('/tmp/var/tres2',exist_ok=True)
def C(t,a=1.0):
    r,g,b=[x/255 for x in t]; return f'Color({r:.3f}, {g:.3f}, {b:.3f}, {a})'
IVORY=(240,224,195)
# (kr, laser_tip, bloom_in, bloom_mid, bloom_out, 길이·폭 성격)
P={
 'Clockwork': ('정속 태엽눈', (246,235,210), (231,183,104), (200,146,54), (118,80,30),
               dict(length_ratio=6.364, min_length_scale=0.60, max_length_scale=1.10, bloom_root=1.20)),
 'Rubber':    ('고무막 유리눈', (255,246,236), (246,170,110), (226,112,54), (128,58,28),
               dict(length_ratio=7.000, min_length_scale=0.45, max_length_scale=1.45, bloom_root=1.55)),
 'Gel':       ('완충 젤 유리눈', (251,251,240), (222,230,184), (169,200,124), (96,118,72),
               dict(length_ratio=5.000, min_length_scale=0.45, max_length_scale=1.15, bloom_root=1.55)),
 'Lead':      ('납심 유리눈', (240,216,154), (214,180,96), (168,134,58), (78,70,52),
               dict(length_ratio=6.364, min_length_scale=0.55, max_length_scale=1.20, bloom_root=0.95)),
 'HollowBell':('속빈 방울눈', (253,248,255), (216,200,238), (168,140,204), (86,60,116),
               dict(length_ratio=6.800, min_length_scale=0.40, max_length_scale=1.35, bloom_root=1.45)),
}
BASE=dict(length_ratio=6.364, reference_speed=900.0, min_length_scale=0.45, max_length_scale=1.3,
          hide_below_speed=60.0, point_count=24, point_lifetime=0.22,
          bloom_root=1.35, bloom_tip=0.02, bloom_power=1.0, bloom_alpha=0.8,
          core_root=0.2, core_tip=0.004, core_power=1.0, core_alpha=0.95,
          band_steps=4, step_gamma=1.15, core_step_drop=1,
          fade_in_time=0.05, fade_out_time=0.12)
ORDER=list(BASE)
for k,(kr,ltip,bi,bm,bo,ov) in P.items():
    v=dict(BASE); v.update(ov)
    lines=['[gd_resource type="Resource" script_class="BallTrailRules" format=3]','',
           '[ext_resource type="Script" path="res://scripts/ball_base_system/vfx/ball_trail_rules.gd" id="1_trail"]','',
           '[resource]','script = ExtResource("1_trail")']
    for p in ORDER:
        val=v[p]
        lines.append(f'{p} = {val}' if not isinstance(val,float) else f'{p} = {val:g}')
    lines += [f'laser_hot = {C((255,255,254))}', f'laser_tip = {C(ltip)}',
              f'bloom_in = {C(bi)}', f'bloom_mid = {C(bm)}', f'bloom_out = {C(bo)}', '']
    open(f'/tmp/var/tres2/BallTrailRules_{k}.tres','w').write('\n'.join(lines))
    print(f'{k:<11} {kr:<9} length_ratio {v["length_ratio"]:g} · bloom_root {v["bloom_root"]:g} · '
          f'min/max {v["min_length_scale"]:g}/{v["max_length_scale"]:g}')
print('\n★ laser_hot(순백)은 5종 공통 — 의도적으로 가독성 우선순위를 뒤집은 확정 사항이라 건드리지 않았다')
