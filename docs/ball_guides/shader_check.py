"""
셰이더 실행 결과가 승인받은 목표 그림과 같은 성질을 갖는지 측정한다.
해시 함수가 numpy 판과 다르므로 픽셀 일치가 아니라 성질(반경·원형성·가독성·대비)로 본다.
"""
import numpy as np
from run_shader import read_rules, render, QUAD_PADDING

BOARD = np.array([46 / 255, 58 / 255, 71 / 255], dtype=np.float32)
BALL_D = 44.0
BR = BALL_D / 2.0
FAILS = []


def lum(rgb):
	return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def check(cond, msg):
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		FAILS.append(msg)


rules = read_rules()
outer_r = BR * rules["radius_ratio"]
half_quad = outer_r * QUAD_PADDING
size = int(round(half_quad * 2))

print(f"규칙: radius_ratio={rules['radius_ratio']}  bands={rules['band_count']}  "
      f"peak={rules['peak_alpha']}")
print(f"공 {BALL_D}px -> 안개 외곽 {outer_r:.1f}px, 쿼드 {size}px\n")

a = render(size, rules, BALL_D, gaze=-0.55)
c = (size - 1) / 2.0
yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
rr = np.hypot(xx - c, yy - c)
th = np.arctan2(yy - c, xx - c)

print("[1] 쿼드 경계에서 잘리지 않는가 (네모 자국)")
border = (xx < 1) | (yy < 1) | (xx > size - 2) | (yy > size - 2)
check(float(a[..., 3][border].max()) < 0.02,
      "쿼드 테두리 알파 최대 %.4f — 0.02 미만이어야 네모 자국이 없다"
      % a[..., 3][border].max())

print("\n[2] 공 안쪽은 비어 있는가 (공 본체가 가독성 1순위)")
inside = rr < BR * 0.88
check(float(a[..., 3][inside].max()) < 0.02,
      "공 반지름 88%% 안쪽 알파 최대 %.4f" % a[..., 3][inside].max())

print("\n[3] 안개 도달 반경 — 확정 40px 은 '상한'이다")
# 혓바닥의 가장 긴 방향과 진행방향이 같은 각도에 겹쳐야만 40px 에 닿는다.
# 노이즈 실현값에 따라 그 아래에서 끝나는 게 정상이고, 넘는 것이 문제다.
ext = float(rr[a[..., 3] > 0.05].max())
check(ext <= outer_r + 1.0,
      "상한을 넘지 않아야 한다: 외곽 %.1fpx <= %.1fpx" % (ext, outer_r))
check(ext >= outer_r * 0.82,
      "상한에 충분히 근접해야 한다: 외곽 %.1fpx >= %.1fpx (상한의 82%%)"
      % (ext, outer_r * 0.82))

print("\n[4] 전체가 원으로 읽히는가 (편차 25% 미만)")
radii = []
for k in range(72):
	lo, hi = k * np.pi / 36 - np.pi, (k + 1) * np.pi / 36 - np.pi
	m = (th >= lo) & (th < hi) & (a[..., 3] >= 0.12)
	if m.any():
		radii.append(rr[m].max())
radii = np.array(radii)
cv = radii.std() / radii.mean()
check(cv < 0.25 and len(radii) == 72,
      "등고선 반지름 편차 %.1f%%, 샘플 %d/72" % (cv * 100, len(radii)))

print("\n[5] 밴딩이 살아 있는가 (매끈한 글로우가 아닌가)")
# 코어 링은 연속 감쇠(가우시안)라 계단이 아니다. 링 바깥에서만 재야 밴딩을 본다.
band = (rr > BR * 1.30) & (rr < outer_r)
steps = int(np.unique((a[..., 3][band] * 255).round()).size)
check(steps <= int(rules["band_count"]) + 2,
      "코어링 바깥 알파 계단 %d 종 (밴드 %d, 0 포함해 +2 이내)"
      % (steps, int(rules["band_count"])))
check(steps >= 3, "계단이 3종 미만이면 안개가 아니라 단색 판이다 (%d)" % steps)

print("\n[6] 보드 위에서 실제로 보이는가")
comp = a[..., :3] * a[..., 3:4] + BOARD * (1 - a[..., 3:4])
lo, hi = BR + 0.35 * (outer_r - BR), BR + 0.65 * (outer_r - BR)
mid = (rr > lo) & (rr < hi)
dl = float(lum(comp)[mid].mean() - lum(BOARD[None, None]).item())
check(dl >= 0.04, "중간대(%.0f~%.0fpx) 휘도차 %+.3f" % (lo, hi, dl))

print("\n[7] VFX 가 공 본체보다 어두운가 (공 아이보리 테 0.955)")
vfx_max = float(np.percentile(lum(comp)[rr > BR * 0.98], 99.9))
check(vfx_max < 0.955, "VFX 최대 휘도 %.3f" % vfx_max)

print("\n[8] 상태 4종이 색으로 갈리는가")
means = {}
for st in ("normal", "combo", "curse", "danger"):
	s = render(size, rules, BALL_D, state=st, gaze=-0.55)
	m = (rr > BR * 1.02) & (s[..., 3] > 0.05)
	w = s[..., 3][m]
	means[st] = (s[..., :3][m] * w[:, None]).sum(0) / w.sum()
# combo 는 normal 과 같은 청록의 '밝기' 변형이라 색 거리가 가까운 게 정상이다.
# 색으로 갈려야 하는 건 기본/저주/위험 셋뿐이다.
hue_states = ("normal", "curse", "danger")
worst, pair = 9.9, ""
for i, x in enumerate(hue_states):
	for y in hue_states[i + 1:]:
		d = float(np.linalg.norm(means[x] - means[y]))
		if d < worst:
			worst, pair = d, f"{x}↔{y}"
check(worst >= 0.15, "기본/저주/위험 중 가장 가까운 쌍 %s 거리 %.3f" % (pair, worst))

# combo 는 색이 아니라 세기로 갈린다
an = render(size, rules, BALL_D, state="normal", gaze=-0.55)[..., 3].sum()
ac = render(size, rules, BALL_D, state="combo", gaze=-0.55)[..., 3].sum()
check(ac > an, "콤보는 기본보다 밝아야 한다 (알파 합 %.0f > %.0f)" % (ac, an))

print("\n[9] 점등하면 밝아지는가")
f = render(size, rules, BALL_D, flash=1.0, gaze=-0.55)
check(float(f[..., 3].sum()) > float(a[..., 3].sum()) * 1.05,
      "점등 알파 합 %.0f vs 평상 %.0f" % (f[..., 3].sum(), a[..., 3].sum()))

print("\n[10] 위상이 흐르면 안개 모양이 바뀌는가")
d1 = render(size, rules, BALL_D, gaze=-0.55, drift=1.5)
check(float(np.abs(d1[..., 3] - a[..., 3]).mean()) > 0.002,
      "위상 1.5rad 차이의 평균 알파 변화 %.4f" % np.abs(d1[..., 3] - a[..., 3]).mean())

print("\n[11] 공 크기가 달라져도 정규화가 유지되는가 (px 하드코딩 없음)")
big = render(int(round(128 * rules["radius_ratio"] * QUAD_PADDING)), rules, 128.0, gaze=-0.55)
bs = big.shape[0]
bc = (bs - 1) / 2.0
byy, bxx = np.mgrid[0:bs, 0:bs].astype(np.float32)
brr = np.hypot(bxx - bc, byy - bc)
ext_big = float(brr[big[..., 3] > 0.05].max()) / (bs / 2.0)
ext_small = ext / (size / 2.0)
check(abs(ext_big - ext_small) < 0.04,
      "정규화 외곽 비율 44px=%.3f vs 128px=%.3f" % (ext_small, ext_big))

print("\n" + "=" * 60)
if FAILS:
	print("FAIL: shader_check (%d)" % len(FAILS))
	for f_ in FAILS:
		print("   -", f_)
	raise SystemExit(1)
print("PASS: shader_check — 실제 .gdshader 를 llvmpipe 로 실행해 11개 항목 통과")
