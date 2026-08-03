"""
VFX ② 이동 꼬리 — 목표 그림 렌더러

문서 규격:
  - 여러 공 복사본이 아니라 **하나의 연속된 혜성 꼬리**
  - 공 뒤에서 시작해 끝으로 갈수록 가늘고 투명
  - **실제 이동 경로를 따라 휘어져야** 한다
  - 멈춤·발사 대기 중에는 표시하지 않는다
  - 레이어는 공 뒤

화풍은 VFX ① 안개와 통일한다 — 매끈한 그라디언트가 아니라 **밴딩된 셀**.
Line2D 링버퍼로 구현할 것을 미리 그려보는 용도라, 폭·알파를 곡선 길이 t(0=공, 1=끝)의
함수로 정의한다. 이 함수가 그대로 Line2D 의 width_curve / gradient 가 된다.
"""
import numpy as np

TAU = 2.0 * np.pi


def _smoothstep(e0, e1, x):
	den = e1 - e0
	den = np.where(np.abs(den) < 1e-6, 1e-6, den)
	t = np.clip((x - e0) / den, 0.0, 1.0)
	return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- 궤적
def make_path(kind, length, ball_r, samples=220):
	"""공 중심(0,0)에서 뒤로 뻗는 궤적. +x 방향으로 진행 중이라고 본다."""
	s = np.linspace(0.0, 1.0, samples)
	d = s * length
	if kind == "straight":
		x, y = -d, np.zeros_like(d)
	elif kind == "curve":
		# 플리퍼로 튕겨 휜 경로. 곡률은 길이에 비례해 같은 모양이 유지되게 한다.
		# 너무 세게 휘면 경로가 아니라 낫처럼 보인다. 끝에서 20도 정도가 적당하다.
		k = 0.70 / max(length, 1.0)
		x = -d * np.cos(k * d * 0.5)
		y = d * np.sin(k * d * 0.5)
	else:  # bounce — 벽에 맞고 꺾인 직후
		x = -d
		y = np.where(d < length * 0.45, 0.0, (d - length * 0.45) * 0.85)
		x = np.where(d < length * 0.45, x, -length * 0.45 - (d - length * 0.45) * 0.5)
	return np.stack([x, y], axis=1), s


def width_at(t, ball_r, root_ratio=0.58, tip_ratio=0.04):
	"""곡선 길이 t(0=공, 1=끝)에서의 반폭. Line2D width_curve 가 될 함수.
	뿌리가 공만큼 두꺼우면 꼬리가 아니라 덩어리로 보인다. 공 반지름의 60% 이하로 둔다."""
	# 뿌리에서 살짝 부풀었다가 끝으로 갈수록 뾰족하게 — 혜성 형태
	swell = 1.0 + 0.14 * np.exp(-((t - 0.12) / 0.16) ** 2)
	taper = (1.0 - t) ** 1.9
	w = ball_r * (tip_ratio + (root_ratio - tip_ratio) * taper) * swell
	return w


def alpha_at(t, bands=5, peak=0.54, root_fade=0.22):
	"""곡선 길이 t 에서의 알파. 안개와 같은 밴딩을 건다."""
	a = (1.0 - t) ** 1.25
	# 뿌리는 공에 바로 붙어 답답해 보이므로 살짝 눌러준다
	a = a * (1.0 - root_fade * np.exp(-(t / 0.10) ** 2))
	a = np.ceil(np.clip(a, 0, 1) * bands) / bands
	return a * peak


# ---------------------------------------------------------------- 렌더
def render_trail(
	size, ball_r, length, colors,
	kind="curve",
	bands=5,
	peak=0.54,
	root_ratio=0.58,
	tip_ratio=0.04,
	center=None,
	angle=0.0,
	wobble=0.05,
	seed=3,
):
	"""
	궤적을 따라 폭·알파가 변하는 리본을 그린다.
	거리장으로 그리므로 Line2D 의 결과(두꺼운 폴리라인)와 형태가 같다.
	"""
	if center is None:
		center = ((size - 1) / 2.0, (size - 1) / 2.0)
	cx, cy = center

	pts, s = make_path(kind, length, ball_r)
	# 진행 방향으로 회전
	ca, sa = np.cos(angle), np.sin(angle)
	rot = np.stack([pts[:, 0] * ca - pts[:, 1] * sa, pts[:, 0] * sa + pts[:, 1] * ca], axis=1)
	px = rot[:, 0] + cx
	py = rot[:, 1] + cy

	half_w = width_at(s, ball_r, root_ratio, tip_ratio)
	a_line = alpha_at(s, bands, peak)

	yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)

	# 각 픽셀에서 가장 가까운 궤적 점을 찾는다 (세그먼트 수가 적어 브루트포스로 충분)
	best_d = np.full((size, size), 1e9, dtype=np.float32)
	best_t = np.zeros((size, size), dtype=np.float32)
	for i in range(len(px) - 1):
		ax, ay = px[i], py[i]
		bx, by = px[i + 1], py[i + 1]
		vx, vy = bx - ax, by - ay
		seg2 = vx * vx + vy * vy
		if seg2 < 1e-9:
			continue
		u = ((xx - ax) * vx + (yy - ay) * vy) / seg2
		u = np.clip(u, 0.0, 1.0)
		qx = ax + u * vx
		qy = ay + u * vy
		d = np.hypot(xx - qx, yy - qy)
		t_here = s[i] + (s[i + 1] - s[i]) * u
		upd = d < best_d
		best_d = np.where(upd, d, best_d)
		best_t = np.where(upd, t_here, best_t)

	# 폭·알파를 t 로 되짚어 본다
	w_map = np.interp(best_t, s, half_w)
	a_map = np.interp(best_t, s, a_line)

	# 손그림 흔들림 — 폭을 저주파로 흔든다
	rng = np.random.default_rng(seed)
	wob = np.zeros_like(best_t)
	for h, ph in [(3.0, rng.uniform(0, TAU)), (5.0, rng.uniform(0, TAU))]:
		wob += np.sin(h * best_t * TAU + ph) / h
	w_map = w_map * (1.0 + wobble * wob)

	# 경계는 1px 정도만 부드럽게 — 셀 화풍이라 넓게 번지면 안 된다
	edge = _smoothstep(w_map, w_map - 1.2, best_d)
	alpha = np.clip(a_map * edge, 0.0, 1.0)

	# 색: 뿌리(밝은 청록) -> 끝(짙은 청록)
	c_root = np.array(colors[0], dtype=np.float32)
	c_tip = np.array(colors[1], dtype=np.float32)
	u = np.clip(best_t, 0, 1)[..., None]
	rgb = c_root + (c_tip - c_root) * u

	out = np.zeros((size, size, 4), dtype=np.float32)
	out[..., :3] = rgb
	out[..., 3] = alpha
	return out
