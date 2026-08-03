"""
VFX ② 꼬리 — 형태 3단계 (2026-08-03 형락님 "좀 더 사진처럼, 색은 안개와 통일, 형태만")

★ 색은 안개 ①의 팔레트를 그대로 쓴다. 흰색으로 태우지 않는다.
  밝기는 색이 아니라 알파로만 만든다.

★ 비주얼 가이드 3-4 "형태 구성" 이 이미 3층을 규정하고 있다:
    중심      — 가장 밝은 부분, 공의 청록 테두리와 연결, 하나의 선명한 이동 방향
    외곽 글로우 — 중심 리본보다 넓고 투명, 보드와 자연스럽게 섞이게
    보조 입자  — 꼬리 끝에서 분리, 한 번에 2~5개, 공보다 밝지 않게
  즉 "부드럽게 퍼지는 외곽"은 이탈이 아니라 문서가 요구한 것이다. 기존 단일 쐐기가
  오히려 문서에 못 미쳤다.

★ 문서가 금지하는 것 (사진풍의 상한선):
    - 강한 블룸으로 홍채와 동공이 사라지는 표현
    - 한 효과 안에 여러 색을 섞는 무지개
    - 보조 입자가 공보다 밝아지는 것
"""
import numpy as np
from trail import make_path, _smoothstep, TAU

# 안개 ①과 동일한 팔레트 (BallGlowOutlineRules.tres)
C_CORE = (0.498, 0.788, 0.706)      # #7FC9B4  안개 코어
C_MIST = (0.310, 0.651, 0.573)      # #4FA692  안개 본체
C_OUTER = (0.180, 0.378, 0.332)     # 안개 바깥 = mist * 0.58

LEVELS = {
	0: dict(name="S0  현재 — 단일 쐐기", ribbon=0.0, glow=0.0, wedge=1.0,
	        filaments=0, sparks=0, bands=5, peak=0.54),
	1: dict(name="S1  중심 리본 + 외곽 글로우", ribbon=1.0, glow=1.0, wedge=0.0,
	        filaments=0, sparks=4, bands=5, peak=0.60),
	2: dict(name="S2  + 빛 가닥 + 구슬 꼬리", ribbon=1.0, glow=1.0, wedge=0.0,
	        filaments=7, sparks=9, bands=5, peak=0.64),
}

# 문서: "시작 부분은 공 테두리와 같은 굵기" -> 외곽 글로우 뿌리를 공 반지름에 맞춘다
GLOW_ROOT = 0.92
GLOW_TIP = 0.10
RIBBON_ROOT = 0.34
RIBBON_TIP = 0.03


def _dist_field(size, px, py, s):
	"""각 픽셀에서 궤적까지의 거리와 그때의 곡선 위치 t.
	세그먼트를 파이썬 루프로 돌면 가닥 수만큼 곱해져 렌더가 끝나지 않는다.
	세그먼트를 묶어서 벡터화하고, 메모리에 맞게 묶음 크기를 정한다."""
	yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
	fx = xx.ravel()[:, None]
	fy = yy.ravel()[:, None]
	n_px = fx.shape[0]
	ax = px[:-1].astype(np.float32)
	ay = py[:-1].astype(np.float32)
	vx = (px[1:] - px[:-1]).astype(np.float32)
	vy = (py[1:] - py[:-1]).astype(np.float32)
	seg2 = np.maximum(vx * vx + vy * vy, 1e-9)
	t0 = s[:-1].astype(np.float32)
	dt = (s[1:] - s[:-1]).astype(np.float32)

	best_d = np.full(n_px, 1e9, dtype=np.float32)
	best_t = np.zeros(n_px, dtype=np.float32)
	step = max(2, int(4.0e6 / max(n_px, 1)))
	for i in range(0, len(ax), step):
		sl = slice(i, i + step)
		u = np.clip(((fx - ax[sl]) * vx[sl] + (fy - ay[sl]) * vy[sl]) / seg2[sl], 0.0, 1.0)
		d = np.hypot(fx - (ax[sl] + u * vx[sl]), fy - (ay[sl] + u * vy[sl]))
		j = np.argmin(d, axis=1)
		dm = d[np.arange(n_px), j]
		upd = dm < best_d
		best_d = np.where(upd, dm, best_d)
		best_t = np.where(upd, t0[sl][j] + dt[sl][j] * u[np.arange(n_px), j], best_t)
	return best_d.reshape(size, size), best_t.reshape(size, size)


def _taper(t, ball_r, root, tip, power=1.9):
	return ball_r * (tip + (root - tip) * (1.0 - t) ** power)


def render_trail_shape(
	size, ball_r, length, level=1,
	kind="curve", angle=0.0, seed=3, wobble=0.05, samples=150,
):
	cfg = LEVELS[level]
	c = (size - 1) / 2.0
	rng = np.random.default_rng(seed)

	pts, s = make_path(kind, length, ball_r, samples=samples)
	ca, sa = np.cos(angle), np.sin(angle)
	px = pts[:, 0] * ca - pts[:, 1] * sa + c
	py = pts[:, 0] * sa + pts[:, 1] * ca + c

	best_d, best_t = _dist_field(size, px, py, s)

	wob = np.zeros_like(best_t)
	for h in (3.0, 5.0):
		wob += np.sin(h * best_t * TAU + rng.uniform(0, TAU)) / h
	wob = 1.0 + wobble * wob

	a_len = (1.0 - best_t) ** 1.25
	a_len = a_len * (1.0 - 0.22 * np.exp(-(best_t / 0.10) ** 2))
	if cfg["bands"] > 0:
		a_len_b = np.ceil(np.clip(a_len, 0, 1) * cfg["bands"]) / cfg["bands"]
	else:
		a_len_b = a_len

	alpha = np.zeros((size, size), dtype=np.float32)
	rgb = np.zeros((size, size, 3), dtype=np.float32)

	def blend(a_new, color):
		"""위에 얹기. 색은 알파 가중 평균."""
		nonlocal alpha, rgb
		na = np.clip(alpha + a_new * (1.0 - alpha), 0.0, 1.0)
		w = (a_new * (1.0 - alpha))[..., None]
		rgb[:] = (rgb * alpha[..., None] + np.asarray(color, np.float32) * w) / np.maximum(
			na[..., None], 1e-5)
		alpha = na

	# ── 외곽 글로우 : 넓고 투명, 보드와 섞이게 (부드러운 지수 감쇠)
	if cfg["glow"] > 0.0:
		gw = _taper(best_t, ball_r, GLOW_ROOT, GLOW_TIP) * wob
		g = np.exp(-(np.maximum(best_d, 0.0) / np.maximum(gw, 0.4)) ** 1.7)
		blend(g * a_len_b * 0.42 * cfg["glow"], C_OUTER)
		g2 = np.exp(-(np.maximum(best_d, 0.0) / np.maximum(gw * 0.55, 0.3)) ** 1.9)
		blend(g2 * a_len_b * 0.40 * cfg["glow"], C_MIST)

	# ── 기존 단일 쐐기 (S0 비교용)
	if cfg["wedge"] > 0.0:
		ww = _taper(best_t, ball_r, 0.58, 0.04) * wob
		blend(a_len_b * _smoothstep(ww, ww - 1.2, best_d), C_MIST)

	# ── 빛 가닥 : 레퍼런스의 가느다란 침 같은 줄기. 형태의 핵심 차이
	if cfg["filaments"] > 0:
		for k in range(cfg["filaments"]):
			frac = rng.uniform(0.45, 1.0)                 # 가닥마다 길이가 다르다
			fan = rng.uniform(-0.42, 0.42)                # 뒤로 갈수록 벌어진다
			n = max(12, int(samples * frac))
			fs = np.linspace(0.0, frac, n)
			fp, _ = make_path(kind, length, ball_r, samples=samples)
			idx = np.clip((fs * (samples - 1)).astype(int), 0, samples - 1)
			bx, by = fp[idx, 0], fp[idx, 1]
			# 진행축에 수직으로 벌린다
			off = fan * (fs / max(frac, 1e-3)) ** 1.4 * length * 0.16
			bx2 = bx - off * np.sin(0.0)
			by2 = by + off
			fx = bx2 * ca - by2 * sa + c
			fy = bx2 * sa + by2 * ca + c
			fd, ft = _dist_field(size, fx, fy, fs / max(frac, 1e-3))
			fw = np.maximum(ball_r * 0.115 * (1.0 - ft) ** 1.3, 0.55)
			fa = (1.0 - ft) ** 1.15 * _smoothstep(fw, fw - 1.0, fd)
			fa = np.ceil(np.clip(fa, 0, 1) * cfg["bands"]) / cfg["bands"]
			blend(fa * 0.80, C_CORE)

	# ── 중심 리본 : 가장 밝은 부분, 하나의 선명한 이동 방향
	if cfg["ribbon"] > 0.0:
		rw = _taper(best_t, ball_r, RIBBON_ROOT, RIBBON_TIP, power=1.5) * wob
		blend(a_len_b * _smoothstep(rw, rw - 1.0, best_d) * 0.92, C_CORE)

	# ── 보조 입자 : 공 뒤를 따라오는 구슬 (PL 요구 — 레퍼런스의 점 꼬리)
	#    레퍼런스에서 점들은 아무데나 흩어져 있지 않고 **궤적 위에 줄지어** 있다.
	#    뒤로 갈수록 간격이 벌어지고 작아지며, 궤적을 벗어나는 건 약간의 흔들림뿐이다.
	if cfg["sparks"] > 0:
		yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
		n = cfg["sparks"]
		for k in range(n):
			# 꼬리 끝을 넘어 더 뒤까지 이어진다 (분리되어 남겨진 흔적)
			u = 0.55 + (k / max(n - 1, 1)) ** 0.85 * 0.85
			i = int(np.clip(u * (len(px) - 1), 0, len(px) - 1))
			jitter = ball_r * 0.14 * (0.4 + u)
			# 궤적을 넘어가는 몫은 마지막 방향으로 연장한다
			if u <= 1.0:
				bx0, by0 = px[i], py[i]
			else:
				ex = px[-1] - px[-2]
				ey = py[-1] - py[-2]
				k_ext = (u - 1.0) * (len(px) - 1)
				bx0, by0 = px[-1] + ex * k_ext, py[-1] + ey * k_ext
			cxs = bx0 + rng.normal(0.0, jitter)
			cys = by0 + rng.normal(0.0, jitter)
			rd = ball_r * (0.135 - 0.070 * min(u, 1.0)) * rng.uniform(0.85, 1.15)
			d = np.hypot(xx - cxs, yy - cys)
			dot = _smoothstep(rd, rd - 1.0, d)
			hal = np.exp(-(d / max(rd * 2.4, 0.9)) ** 2) * 0.30
			blend(np.clip(dot * 0.62 + hal, 0, 1) * (1.0 - 0.32 * min(u, 1.0)), C_CORE)

	out = np.zeros((size, size, 4), dtype=np.float32)
	out[..., :3] = np.clip(rgb, 0, 1)
	out[..., 3] = np.clip(alpha * cfg["peak"] / 0.62, 0.0, 1.0)
	return out
