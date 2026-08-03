"""
VFX ② 꼬리 44px 검수 — 검수 기준은 "예쁜가"가 아니라 "방향이 즉시 읽히는가".

문서 체크리스트에서 꼬리에 걸리는 항목:
  - 최고 속도에도 이동 방향을 읽을 수 있는가
  - 공이 가장 먼저 보이는가 (가독성: 공 > 발광 테두리 > 이동 꼬리)
  - VFX가 공의 흐름 판단을 방해하지 않는가
"""
import numpy as np
from make_trail_sheet import compose, MIST_OUTER, BALL_G, BR, OPTS

BOARD = np.array([46 / 255, 58 / 255, 71 / 255], dtype=np.float32)


def lum(rgb):
	return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def arrays(length, kind="straight", angle=0.0, with_mist=True):
	im = compose(BALL_G, length, kind=kind, angle=angle, with_mist=with_mist)
	a = np.asarray(im).astype(np.float32) / 255.0
	return a


print("=" * 74)
print("VFX ② 이동 꼬리 — 44px 검수   (안개 외곽 %.0fpx 를 얹은 상태)" % MIST_OUTER)
print("=" * 74)

print("\n[1] 안개 밖으로 실제로 보이는 꼬리 길이")
print("    ※ 라벨의 '길이 - 40px' 은 산수다. 안개 알파에 묻히는 만큼을 실제로 재야 한다.")
vis_len = {}
for name, L in OPTS:
	with_m = arrays(L, "straight", 0.0, True)
	no_m = arrays(L, "straight", 0.0, False)
	h, w = with_m.shape[:2]
	c = (w - 1) / 2.0, (h - 1) / 2.0
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	dx = xx - c[0]
	dy = yy - c[1]
	r = np.hypot(dx, dy)
	# 진행 방향은 +x, 꼬리는 -x 쪽. 꼬리 축을 따라 알파가 살아 있는 최대 거리
	axis = (np.abs(dy) < 6.0) & (dx < -BR * 0.9)
	trail_only = no_m[..., 3]
	reach = float(r[axis & (trail_only > 0.06)].max()) if (axis & (trail_only > 0.06)).any() else 0.0
	# 안개보다 꼬리가 더 진한 구간만 "보인다"고 본다
	beyond = axis & (trail_only > 0.06) & (r > MIST_OUTER)
	vis = float(r[beyond].max() - MIST_OUTER) if beyond.any() else 0.0
	vis_len[L] = vis
	print("  %-26s 꼬리 도달 %5.1fpx / 안개 밖 노출 %5.1fpx" % (name, reach, vis))

print("\n[2] 방향 판독 — 안개 '바깥'에서 뒤/앞 비 (안쪽에서 재면 안개만 재게 된다)")
print("    ※ 안개는 진행방향으로 늘어나고 꼬리는 반대로 뻗는다. 둘은 서로 싸우는 게 아니라")
print("      '앞은 안개, 뒤는 꼬리'로 축을 만든다. 그래서 안개 밖에서 재야 꼬리 신호가 잡힌다.")
for name, L in OPTS:
	a = arrays(L, "straight", 0.0, True)
	h, w = a.shape[:2]
	c = (w - 1) / 2.0, (h - 1) / 2.0
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	dx = xx - c[0]
	dy = yy - c[1]
	r = np.hypot(dx, dy)
	ring = (r > MIST_OUTER) & (r < MIST_OUTER + 25) & (np.abs(dy) < 22)
	back = float(a[..., 3][ring & (dx < 0)].mean())
	front = float(a[..., 3][ring & (dx > 0)].mean())
	ratio = back / max(front, 1e-4)
	# 전체 VFX 알파 무게중심이 공 뒤에 있어야 "뒤로 끌린다"고 읽힌다
	wgt = a[..., 3]
	cxw = float((wgt * dx).sum() / max(wgt.sum(), 1e-6)) / BR
	print("  %-26s 뒤 %.3f / 앞 %.3f = %5.1f배 · 무게중심 %+.2f R  %s"
	      % (name, back, front, ratio, cxw,
	         "PASS" if (ratio >= 2.0 and cxw <= -0.10) else "약함"))

print("\n[3] 가독성 — 꼬리가 공 본체(0.955)보다, 그리고 안개보다 어두운가")
for name, L in OPTS:
	no_m = arrays(L, "straight", 0.0, False)
	comp = no_m[..., :3] * no_m[..., 3:4] + BOARD * (1 - no_m[..., 3:4])
	h, w = no_m.shape[:2]
	c = (w - 1) / 2.0, (h - 1) / 2.0
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	r = np.hypot(xx - c[0], yy - c[1])
	outside = r > BR * 1.05
	tmax = float(np.percentile(lum(comp)[outside], 99.9))
	print("  %-26s 꼬리 최대 휘도 %.3f  %s"
	      % (name, tmax, "PASS" if tmax < 0.62 else "밝다 — 안개(0.62)와 경쟁"))

print("\n[4] 보드 대비 — 꼬리 중간이 보드색과 갈리는가 (0.03 이상)")
Lb = lum(BOARD[None, None]).item()
for name, L in OPTS:
	no_m = arrays(L, "straight", 0.0, False)
	comp = no_m[..., :3] * no_m[..., 3:4] + BOARD * (1 - no_m[..., 3:4])
	h, w = no_m.shape[:2]
	c = (w - 1) / 2.0, (h - 1) / 2.0
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	dx = xx - c[0]
	r = np.hypot(dx, yy - c[1])
	mid = (r > BR + 0.35 * (L - BR)) & (r < BR + 0.65 * (L - BR)) & (dx < 0) & (no_m[..., 3] > 0.02)
	dl = float(lum(comp)[mid].mean() - Lb) if mid.any() else 0.0
	print("  %-26s 중간대 휘도차 %+.3f  %s" % (name, dl, "PASS" if dl >= 0.03 else "약함"))

print("\n[5] 밴딩이 살아 있는가 (안개와 화풍 통일)")
print("    ※ 테두리 1.2px 램프 픽셀까지 세면 수십 종이 나온다. 넓게 깔린 '평지'만 센다.")
for name, L in OPTS:
	no_m = arrays(L, "straight", 0.0, False)
	h, w = no_m.shape[:2]
	c = (w - 1) / 2.0, (h - 1) / 2.0
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	dx = xx - c[0]
	body = (no_m[..., 3] > 0.02) & (dx < -BR)
	vals = (no_m[..., 3][body] * 255).round().astype(int)
	uniq, cnt = np.unique(vals, return_counts=True)
	plateau = int((cnt >= max(3, 0.03 * cnt.sum())).sum())
	print("  %-26s 평지 계단 %d 종 (전체 %d 종 중)  %s"
	      % (name, plateau, len(uniq), "PASS" if 3 <= plateau <= 8 else "확인"))

print("\n[6] 화면 점유 — 고속에서 시끄럽지 않은가 (꼬리 픽셀 수 / 공 픽셀 수)")
ball_px = np.pi * BR * BR
for name, L in OPTS:
	no_m = arrays(L, "curve", 0.0, False)
	px = float((no_m[..., 3] > 0.06).sum())
	print("  %-26s 꼬리 %5.0fpx² = 공의 %.2f배  %s"
	      % (name, px, px / ball_px, "PASS" if px / ball_px <= 2.2 else "넓다"))
print()
