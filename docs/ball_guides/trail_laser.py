"""
VFX ② 이동 꼬리 — 2겹 구조 (2026-08-03 형락님 스케치)

꼬리는 **VFX 두 개**로 이루어진다:
  ① 안쪽 = 레이저.  가늘고 흰색. 경계가 또렷하다. 방향을 만드는 건 이쪽이다.
  ② 바깥 = 블룸.    그 레이저를 감싸는 안개. 넓고 흐리다. 끝에서 투명해진다.

밝기는 길이 방향으로 **계단식 4단**으로 떨어진다 (스케치의 노랑→주황→초록→파랑):
  공 바로 뒤가 제일 밝고, 끝은 "투명 상태의 블룸"만 남는다.

색: 레이저는 흰색~아이보리, 블룸은 안개 ①과 같은 청록.
    아이보리·청록 모두 기능색 규칙(공·조작물) 안에 있다.
"""
import numpy as np
from trail import make_path, _smoothstep, TAU
from trail_glow import _dist_field, _taper

# 레이저 : 흰색 -> 아이보리 (공의 하이라이트 색과 연결)
LASER_HOT = (1.000, 1.000, 0.996)
LASER_TIP = (0.941, 0.878, 0.765)     # #F0E0C3 아이보리

# 블룸 : 안개 ①과 동일 팔레트
BLOOM_IN = (0.498, 0.788, 0.706)      # #7FC9B4
BLOOM_MID = (0.310, 0.651, 0.573)     # #4FA692
BLOOM_OUT = (0.180, 0.378, 0.332)     # 안개 바깥

# (이름, 레이저 뿌리폭, 레이저 끝폭, 블룸 뿌리폭, 블룸 알파, 레이저 알파)
BALANCE = {
	# 2026-08-03 형락님: "레이저도 조금 더 두껍고 그에 맞게 블룸도 넓게"
	# 레이저를 키우면 블룸도 같이 키워야 2겹으로 읽힌다 (블룸/레이저 >= 2.5배 유지).
	# ★ 2026-08-03 형락님 확정본. 뿌리 기준 레이저 9px / 블룸 60px (공 44px 대비).
	#   core_root 0.20 x 22 x 2 = 8.8px,  bloom_root 1.35 x 22 x 2 = 59.4px
	#   ("60px"은 뿌리 폭이다. 꼬리 중간으로 갈수록 테이퍼로 좁아진다)
	"D1": dict(name="D1  레이저 9px / 블룸 60px  [확정]",
	           core_root=0.20, core_tip=0.024, bloom_root=1.35, bloom_a=0.80, core_a=0.95),
	"D2": dict(name="D2  레이저 11px / 블룸 68px",
	           core_root=0.26, core_tip=0.030, bloom_root=1.55, bloom_a=0.84, core_a=0.95),
	"D3": dict(name="D3  레이저 14px / 블룸 79px",
	           core_root=0.32, core_tip=0.038, bloom_root=1.80, bloom_a=0.88, core_a=0.95),
}

STEPS = 4          # 스케치의 4단 (노랑 / 주황 / 초록 / 투명 블룸)


def _step_curve(t, steps=STEPS, gamma=1.15):
	"""길이 방향 계단식 감쇠. 공 쪽이 1, 끝이 0."""
	a = np.clip(1.0 - t, 0.0, 1.0) ** gamma
	return np.ceil(a * steps) / steps


def render_layers(size, ball_r, length, balance="B",
                  kind="curve", angle=0.0, seed=3, wobble=0.05, samples=140):
	"""레이저 층과 블룸 층을 따로 돌려준다. 시트에서 분해해 보여주려고 나눈다."""
	cfg = BALANCE[balance]
	c = (size - 1) / 2.0
	rng = np.random.default_rng(seed)

	pts, s = make_path(kind, length, ball_r, samples=samples)
	ca, sa = np.cos(angle), np.sin(angle)
	px = pts[:, 0] * ca - pts[:, 1] * sa + c
	py = pts[:, 0] * sa + pts[:, 1] * ca + c
	d, t = _dist_field(size, px, py, s)

	wob = np.zeros_like(t)
	for h in (3.0, 5.0):
		wob += np.sin(h * t * TAU + rng.uniform(0, TAU)) / h
	wob = 1.0 + wobble * wob

	step = _step_curve(t)

	# ── ② 블룸 : 넓고 흐리게, 끝으로 갈수록 투명
	bw = _taper(t, ball_r, cfg["bloom_root"], 0.14, power=1.6) * wob
	# 지수 감쇠 두 겹 — 안쪽이 조금 진하고 바깥이 길게 깔린다
	b1 = np.exp(-(np.maximum(d, 0.0) / np.maximum(bw * 0.52, 0.4)) ** 1.9)
	b2 = np.exp(-(np.maximum(d, 0.0) / np.maximum(bw, 0.5)) ** 1.5)
	bloom_a = np.clip((b1 * 0.62 + b2 * 0.48) * step * cfg["bloom_a"], 0.0, 1.0)

	u = np.clip(d / np.maximum(bw, 1e-3), 0, 1)[..., None]
	bloom_rgb = np.where(
		u < 0.45,
		np.array(BLOOM_MID, np.float32) + (np.array(BLOOM_IN, np.float32)
		                                   - np.array(BLOOM_MID, np.float32)) * (1 - u / 0.45),
		np.array(BLOOM_OUT, np.float32) + (np.array(BLOOM_MID, np.float32)
		                                   - np.array(BLOOM_OUT, np.float32))
		* (1 - (u - 0.45) / 0.55))
	bloom = np.zeros((size, size, 4), np.float32)
	bloom[..., :3] = np.clip(bloom_rgb, 0, 1)
	bloom[..., 3] = bloom_a

	# ── ① 레이저 : 가늘고 또렷하게. 경계를 1px 안에서 끊는다
	cw = _taper(t, ball_r, cfg["core_root"], cfg["core_tip"], power=1.35) * wob
	core_edge = _smoothstep(cw, cw - 0.9, d)
	# 코어 바로 옆의 아주 좁은 번짐 — 레이저가 유리처럼 보이게
	core_halo = np.exp(-(np.maximum(d - cw, 0.0) / np.maximum(cw * 1.6, 0.5)) ** 2) * 0.45
	core_a = np.clip((core_edge + core_halo) * step * cfg["core_a"], 0.0, 1.0)

	cu = np.clip(t, 0, 1)[..., None]
	core_rgb = (np.array(LASER_HOT, np.float32)
	            + (np.array(LASER_TIP, np.float32) - np.array(LASER_HOT, np.float32)) * cu)
	laser = np.zeros((size, size, 4), np.float32)
	laser[..., :3] = core_rgb
	laser[..., 3] = core_a

	return laser, bloom


def over(top, bottom):
	"""top 을 bottom 위에 알파 합성."""
	a = top[..., 3:4] + bottom[..., 3:4] * (1 - top[..., 3:4])
	rgb = (top[..., :3] * top[..., 3:4]
	       + bottom[..., :3] * bottom[..., 3:4] * (1 - top[..., 3:4])) / np.maximum(a, 1e-5)
	out = np.zeros_like(top)
	out[..., :3] = np.clip(rgb, 0, 1)
	out[..., 3] = np.clip(a[..., 0], 0, 1)
	return out


def render_trail_laser(size, ball_r, length, balance="B", **kw):
	laser, bloom = render_layers(size, ball_r, length, balance=balance, **kw)
	return over(laser, bloom)
