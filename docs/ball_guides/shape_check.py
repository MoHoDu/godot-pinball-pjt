"""형태 3단계 검수 — 가이드가 정한 상한을 넘는지만 본다."""
import numpy as np
from trail_glow import render_trail_shape, LEVELS
from run_shader import read_rules

BOARD = np.array([46 / 255, 58 / 255, 71 / 255], np.float32)
BALL_G, LEN = 44.0, 140.0
BR = BALL_G / 2.0
rules = read_rules()
MIST_OUTER = BR * rules["radius_ratio"]
SIZE = 395
# 공 아이보리 테 / 안개 최대 (앞선 검수에서 실측한 값)
BALL_LUM, MIST_LUM = 0.955, 0.650


def lum(rgb):
	return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


print("=" * 76)
print("VFX ② 꼬리 형태 3단계 — 가이드 상한 검수 (44px, 길이 140px)")
print("=" * 76)
c = (SIZE - 1) / 2.0
yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
dx, dy = xx - c, yy - c
r = np.hypot(dx, dy)

for lv in (0, 1, 2):
	cfg = LEVELS[lv]
	a = render_trail_shape(SIZE, BR, LEN, level=lv, kind="straight", angle=0.0)
	comp = a[..., :3] * a[..., 3:4] + BOARD * (1 - a[..., 3:4])
	out = r > BR * 1.05
	tmax = float(np.percentile(lum(comp)[out], 99.9))
	amax = float(a[..., 3].max())
	# 방향: 알파 무게중심이 공 뒤에 있어야
	w = a[..., 3]
	cxw = float((w * dx).sum() / max(w.sum(), 1e-6)) / BR
	px = float((a[..., 3] > 0.06).sum()) / (np.pi * BR * BR)
	reach = float(r[a[..., 3] > 0.05].max())

	print("\n%s" % cfg["name"])
	print("  꼬리 최대 휘도 %.3f   %s" % (
		tmax, "PASS (공 0.955 · 안개 0.650 아래)" if tmax < MIST_LUM else "FAIL 안개보다 밝다"))
	print("  최대 알파     %.2f    %s" % (
		amax, "PASS" if amax <= 0.98 else "포화 — 홍채를 덮을 위험"))
	print("  무게중심      %+.2f R  %s" % (
		cxw, "PASS 뒤로 끌린다" if cxw <= -0.10 else "약함"))
	print("  화면 점유     공의 %.2f배  %s" % (px, "PASS" if px <= 2.2 else "넓다"))
	print("  도달 반경     %.0fpx" % reach)
	n = cfg["sparks"]
	print("  보조 입자     %d개   %s" % (
		n, "PASS (가이드 2~5개)" if n <= 5 else "★ 가이드 상한 2~5개 초과 — 확인 필요"))
print()
