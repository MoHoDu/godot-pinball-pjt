"""
VFX (1) 발광 테두리 리디자인 — "마법의 안개 오라" 목표 그림 렌더러

셰이더로 그대로 이식할 수 있게 프래그먼트 단위 연산만 쓴다.
  UV -> 극좌표 -> 혓바닥(각도별 길이) -> 방사 falloff -> 극좌표 노이즈(방사 결)
       -> 밴딩(한 번만) -> 색

★ 밴딩은 반드시 "누적된 최종 알파"에 한 번만 건다.
  층마다 따로 걸어서 겹치면 계단이 서로 어긋나 다시 매끈한 그라디언트가 된다.

길이는 전부 "공 반지름 대비 비율"로 다룬다. 44px / 64px 문제 때문에 px 하드코딩 금지.
"""
import numpy as np

TAU = 2.0 * np.pi


def _smoothstep(e0, e1, x):
	"""e0 > e1 (내림차순)도 지원해야 한다. 분모를 max()로 클램프하면 부호가 뒤집힌다."""
	den = e1 - e0
	den = np.where(np.abs(den) < 1e-6, 1e-6, den)
	t = np.clip((x - e0) / den, 0.0, 1.0)
	return t * t * (3 - 2 * t)


def _theta_wave(theta, k, seed, phase=0.0):
	"""주기 2pi 를 정확히 지키는 부드러운 1D 노이즈. 셰이더에서는 sin 합으로 재현된다."""
	rng = np.random.default_rng(seed)
	out = np.zeros_like(theta)
	amp = 0.0
	for h in range(1, k + 1):
		a = rng.uniform(0.5, 1.0) / (h ** 0.8)
		out += a * np.sin(h * theta + rng.uniform(0, TAU) + phase * h * 0.3)
		amp += a
	return out / amp                       # -1 ~ 1


def _polar_noise(theta, rn, nt, nr, seed, octaves=3, spin=0.0):
	"""
	극좌표(theta, r) 격자 위의 value noise.
	nt(각도 분할) >> nr(반경 분할) 로 두면 반경 방향으로 길쭉한 결 = 방사형 안개 가닥이 나온다.
	theta 는 모듈로로 감아서 이음매가 안 생긴다.
	"""
	rng = np.random.default_rng(seed)
	acc = np.zeros(theta.shape, dtype=np.float32)
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		NT = max(3, nt * (2 ** o))
		NR = max(1, nr * (2 ** o))
		g = rng.random((NR + 1, NT)).astype(np.float32)
		tt = ((theta / TAU + spin) % 1.0) * NT
		rr = np.clip(rn, 0.0, 1.0) * NR
		t0 = np.floor(tt).astype(np.int32) % NT
		t1 = (t0 + 1) % NT
		r0 = np.clip(np.floor(rr).astype(np.int32), 0, NR - 1)
		r1 = r0 + 1
		ft = tt - np.floor(tt); ft = ft * ft * (3 - 2 * ft)
		fr = np.clip(rr - np.floor(rr), 0, 1); fr = fr * fr * (3 - 2 * fr)
		top = g[r0, t0] + (g[r0, t1] - g[r0, t0]) * ft
		bot = g[r1, t0] + (g[r1, t1] - g[r1, t0]) * ft
		acc += amp * (top + (bot - top) * fr)
		tot += amp
		amp *= 0.5
	return acc / tot                       # 0 ~ 1


# ---------------------------------------------------------------- 안개 오라
def mist_aura(
	size, ball_r, outer_r, colors,
	seed=7,
	peak=0.60,               # 안개가 가장 진한 곳의 알파 (공 표면 바로 바깥)
	bands=5,                 # 명도 단차 수 — 다크 카툰의 핵심
	falloff_exp=0.85,        # 클수록 바깥이 빨리 옅어진다 = "은은하게"
	plume=0.14,              # 각도별 혓바닥 길이 편차
	plume_k=5,               # 혓바닥 개수 (저주파여야 44px에서 읽힌다)
	wisp=0.75,               # 방사형 결의 세기
	wisp_nt=11,              # 결 개수(각도 분할)
	wisp_nr=1,               # 반경 분할 — 작을수록 결이 길쭉해진다
	inner_bloom=0.30,        # 공 바로 바깥을 한 겹 더 진하게
	drift=0.0,               # 위상 (애니메이션)
	gaze=None,               # 진행방향(rad) — 그쪽으로 안개가 길어진다
	gaze_stretch=0.10,
	core_alpha=0.72,         # 코어 링 알파. 공 아이보리 테보다 밝으면 안 됨
	core_w_ratio=0.062,
	core_gain=1.0,
	alpha_gain=1.0,
	wobble=0.05,
):
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
	dx = xx - c; dy = yy - c
	r = np.hypot(dx, dy)
	theta = np.arctan2(dy, dx)

	# --- 1) 각도별 혓바닥 : 이게 "글로우"와 "안개"를 가른다
	#     ★ 정규화 필수. 혓바닥·응시 늘림이 곱해지면 실제 외곽이 outer_r 을 크게 넘는다.
	#       (plume .32 + gaze .18 이면 1.56배 = "40px" 라고 적고 62px 을 그리게 된다)
	#       최대 배율로 나눠서 outer_r 이 진짜 최대 도달 반경이 되게 한다.
	tongue = 0.5 + 0.5 * _theta_wave(theta, plume_k, seed + 13, drift * 2.0)
	norm = (1.0 + plume) * (1.0 + (gaze_stretch if gaze is not None else 0.0))
	edge = outer_r * (1.0 - plume + 2.0 * plume * tongue) / norm
	if gaze is not None:
		edge = edge * (1.0 + gaze_stretch * np.cos(theta - gaze))
	edge = np.maximum(edge, ball_r * 1.12)

	# --- 2) 방사 falloff : 공 표면 1 -> 혓바닥 끝 0
	fall = _smoothstep(edge, ball_r * 0.98, r) ** falloff_exp
	# ★ 안쪽 겹은 반드시 edge 기준으로. ball_r 배수로 박아두면 작은 안(외곽 30px)에서
	#   안개 끝보다 더 밖까지 번져 나가 A 와 B 가 같은 크기로 측정된다.
	bloom_edge = ball_r + 0.45 * (edge - ball_r)
	fall = fall + inner_bloom * np.clip(_smoothstep(bloom_edge, ball_r * 0.98, r) - fall, 0, None)

	# --- 3) 방사형 결 : 극좌표 노이즈 (반경으로 길쭉하게)
	rn = np.clip(r / np.maximum(outer_r, 1e-3), 0, 1)
	w = _polar_noise(theta, rn, wisp_nt, wisp_nr, seed + 31, octaves=3, spin=drift * 0.08)
	dens = (1.0 - wisp) + wisp * 2.0 * w      # 평균 1 근처

	# --- 4) 밴딩은 최종 알파에 딱 한 번
	a = np.clip(fall * dens, 0.0, 1.0)
	a = np.ceil(a * bands) / bands
	fog = np.clip(a * peak * alpha_gain, 0.0, 1.0)

	# --- 5) 코어 링 : 실루엣을 못 박는 얇고 밝은 테두리 ("원으로 읽힐 것")
	ring_c = ball_r * 1.09 * (1.0 + wobble * _theta_wave(theta, 4, seed + 91))
	ring_w = max(ball_r * core_w_ratio, 0.85)
	ring = np.exp(-((r - ring_c) / ring_w) ** 2) * core_alpha * core_gain

	# --- 6) 색 : 안쪽 core -> 중간 mid -> 바깥 outer
	col_core = np.array(colors[0], dtype=np.float32)
	col_mid = np.array(colors[1], dtype=np.float32)
	col_out = np.array(colors[2], dtype=np.float32)
	u = np.clip((r - ball_r) / max(outer_r - ball_r, 1e-3), 0, 1)[..., None]
	rgb = np.where(u < 0.5,
	               col_mid + (col_core - col_mid) * (1 - u * 2),
	               col_out + (col_mid - col_out) * (2 - u * 2))

	total = np.clip(fog + ring * (1.0 - fog), 0, 1)
	mix = np.clip(ring * (1.0 - fog) / np.maximum(total, 1e-4), 0, 1)[..., None]
	rgb = rgb + (col_core - rgb) * mix

	out = np.zeros((size, size, 4), dtype=np.float32)
	out[..., :3] = np.clip(rgb, 0, 1)
	# 공 안쪽은 비운다 — 공 본체가 가독성 1순위
	out[..., 3] = total * np.clip((r - ball_r * 0.90) / (ball_r * 0.16), 0, 1)
	return out


# ---------------------------------------------------------------- 현재 구현(비교용)
def line2d_rings(size, ball_r, colors, seed=7,
                 radius_ratio=1.24, core_w=0.059, glow_w=0.282,
                 gap_half=0.06, gap_soft=0.55, wobble=0.04, phase=0.0):
	"""기존 BallGlowOutline — Line2D 2겹 + 알파 갭. 리디자인 전 상태."""
	c = (size - 1) / 2.0
	yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
	dx = xx - c; dy = yy - c
	r = np.hypot(dx, dy); theta = np.arctan2(dy, dx)
	rr = ball_r * radius_ratio * (1.0 + wobble * _theta_wave(theta, 4, seed))

	gate = np.ones_like(theta)
	for gc in (0.0, np.pi):
		dd = np.abs(np.arctan2(np.sin(theta - gc - phase), np.cos(theta - gc - phase)))
		gate = np.minimum(gate, _smoothstep(gap_half, gap_half + gap_soft, dd))

	out = np.zeros((size, size, 4), dtype=np.float32)
	for w_ratio, col in ((glow_w, colors[1]), (core_w, colors[0])):
		w = max(ball_r * w_ratio, 0.8)
		a = np.exp(-((r - rr) / w) ** 2) * col[3] * gate
		src = np.array(col[:3], dtype=np.float32)
		na = np.clip(out[..., 3] + a * (1 - out[..., 3]), 0, 1)
		safe = np.maximum(na, 1e-4)[..., None]
		out[..., :3] = (out[..., :3] * out[..., 3][..., None]
		                + src * (a * (1 - out[..., 3]))[..., None]) / safe
		out[..., 3] = na
	return out
