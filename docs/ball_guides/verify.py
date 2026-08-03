"""
44px 검수 — 검수 기준은 "예쁜가"가 아니라 "역할과 상태가 즉시 읽히는가".
눈으로 보는 대신 픽셀로 측정한다.

  1) 가독성 : 공 본체가 VFX 보다 밝은가  (공 본체·동공 > 발광 테두리)
  2) 원형성 : 전체 형태가 원으로 읽히는가 (알파 외곽 반지름의 편차)
  3) 상태 구분 : normal/parry/curse/danger 가 색으로 갈리는가
  4) 보드 대비 : 어두운 보드 위에서 VFX 가 실제로 보이는가
"""
import numpy as np
from PIL import Image
from mist_aura import mist_aura, line2d_rings
from make_sheet import STATES, CUR, ball_img

BOARD = (46 / 255, 58 / 255, 71 / 255)      # #2E3A47
BALL_G = 44.0
BR = BALL_G / 2.0


def lum(rgb):
	return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def over_board(a):
	"""VFX RGBA 를 보드색 위에 합성한 RGB."""
	bg = np.array(BOARD, dtype=np.float32)
	return a[..., :3] * a[..., 3:4] + bg * (1 - a[..., 3:4])


def render(outer, colors, mode="mist", **kw):
	size = int(np.ceil(max(outer * 1.16, BR * 1.4) * 2)) | 1
	if mode == "mist":
		return mist_aura(size, BR, outer, colors, seed=11, gaze=-0.55, **kw), size
	return line2d_rings(size, BR, CUR, seed=11, **kw), size


def ball_lum():
	"""공 본체의 밝은 부분(아이보리 테) 휘도 — VFX 는 이걸 넘으면 안 된다."""
	b = np.asarray(ball_img(BALL_G)).astype(np.float32) / 255.0
	rgb, al = b[..., :3], b[..., 3]
	L = lum(rgb)[al > 0.9]
	return float(np.percentile(L, 99)), float(L.mean())


def outline_roundness(a, size, thresh=0.12):
	"""알파 thresh 등고선의 반지름 표준편차 / 평균. 작을수록 원."""
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
	th = np.arctan2(yy - c, xx - c)
	rr = np.hypot(xx - c, yy - c)
	radii = []
	for k in range(72):
		lo, hi = k * np.pi / 36 - np.pi, (k + 1) * np.pi / 36 - np.pi
		m = (th >= lo) & (th < hi) & (a[..., 3] >= thresh)
		if m.any():
			radii.append(rr[m].max())
	radii = np.array(radii)
	return radii.mean(), radii.std() / max(radii.mean(), 1e-6), len(radii)


print("=" * 72)
p99, mean = ball_lum()
print(f"공 본체 휘도    : 최대(99%) {p99:.3f} / 평균 {mean:.3f}")
print("=" * 72)

print("\n[1] 가독성 — VFX 최대 휘도가 공 본체 최대 휘도보다 낮아야 한다")
rows = [("현재 Line2D", None, "ring"), ("안 A 30px", 30.0, "mist"),
        ("안 B 40px", 40.0, "mist"), ("안 C 52px", 52.0, "mist")]
for name, outer, mode in rows:
	a, size = render(outer if outer else BR * 1.24, STATES["NORMAL"], mode=mode)
	comp = over_board(a)
	# 공이 덮는 안쪽은 제외하고 VFX 영역만
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size]
	m = np.hypot(xx - c, yy - c) > BR * 0.98
	Lv = lum(comp)[m]
	vmax = float(np.percentile(Lv, 99.9))
	ok = "PASS" if vmax < p99 else "FAIL"
	print(f"  {name:<14} VFX 최대 {vmax:.3f}  vs 공 {p99:.3f}   {ok}")

print("\n[2] 원형성 — 알파 0.12 등고선 반지름 편차 (기준: 25% 미만이면 원으로 읽힘)")
for name, outer, mode in rows:
	a, size = render(outer if outer else BR * 1.24, STATES["NORMAL"], mode=mode)
	rmean, cv, n = outline_roundness(a, size)
	ok = "PASS" if cv < 0.25 else "FAIL"
	print(f"  {name:<14} 평균반경 {rmean:5.1f}px  편차 {cv * 100:5.1f}%  샘플 {n}/72  {ok}")

print("\n[3] 상태 구분 — 안 B 기준, VFX 영역 평균색의 상호 거리 (기준: 0.15 이상)")
mats = {}
for s, cols in STATES.items():
	g = 1.30 if s == "PARRY" else 1.0
	a, size = render(40.0, cols, core_gain=g, alpha_gain=g)
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size]
	rr = np.hypot(xx - c, yy - c)
	m = (rr > BR * 1.02) & (a[..., 3] > 0.05)
	w = a[..., 3][m]
	mats[s] = (a[..., :3][m] * w[:, None]).sum(0) / w.sum()
names = list(mats)
worst = 9.9
for i in range(len(names)):
	for j in range(i + 1, len(names)):
		dd = float(np.linalg.norm(mats[names[i]] - mats[names[j]]))
		worst = min(worst, dd)
		print(f"  {names[i]:<7}↔{names[j]:<7} {dd:.3f}" + ("" if dd >= 0.15 else "   ← 가까움"))
print(f"  최소 거리 {worst:.3f}  {'PASS' if worst >= 0.15 else 'FAIL'}")

print("\n[4] 보드 대비 — 안개 '중간대'가 보드색과 갈리는가 (기준: 0.04 이상)")
print("    ※ 고정 px 띠로 재면 안마다 다른 위치를 재게 된다. 공 표면~외곽의 35~65% 구간으로 잰다")
Lb = lum(np.array(BOARD, dtype=np.float32)[None, None]).item()
for name, outer, mode in rows:
	o = outer if outer else BR * 1.24
	a, size = render(o, STATES["NORMAL"], mode=mode)
	comp = over_board(a)
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size]
	rr = np.hypot(xx - c, yy - c)
	lo = BR + 0.35 * (o - BR)
	hi = BR + 0.65 * (o - BR)
	band = (rr > lo) & (rr < hi)
	dL = float(lum(comp)[band].mean() - Lb)
	ok = "PASS" if dL >= 0.04 else "약함"
	print(f"  {name:<14} {lo:4.1f}~{hi:4.1f}px 휘도차 {dL:+.3f}   {ok}")

print("\n[5] 안개가 실제로 차지하는 화면 반경 (알파 0.05 기준)")
for name, outer, mode in rows:
	a, size = render(outer if outer else BR * 1.24, STATES["NORMAL"], mode=mode)
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size]
	rr = np.hypot(xx - c, yy - c)
	rmax = float(rr[a[..., 3] > 0.05].max())
	print(f"  {name:<14} 유효 외곽 {rmax:5.1f}px  (전체 지름 {rmax * 2:5.1f}px)")
print()
