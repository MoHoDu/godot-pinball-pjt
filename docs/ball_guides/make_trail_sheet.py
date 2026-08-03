"""VFX ② 이동 꼬리 — 길이 3안 비교 시트 (안개 ① 위에 얹은 상태)"""
import numpy as np
from PIL import Image, ImageDraw
from trail import render_trail
from run_shader import read_rules, render as render_mist, QUAD_PADDING
from make_sheet import ball_img, place, zoom, F, BG, PANEL, INK, DIM


def crop_content(im, pad=6):
	bb = im.split()[3].getbbox()
	if bb is None:
		return im
	x0, y0, x1, y1 = bb
	return im.crop((max(0, x0 - pad), max(0, y0 - pad),
	                min(im.width, x1 + pad), min(im.height, y1 + pad)))

OUT = "/sessions/dreamy-gracious-cori/mnt/outputs"
REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
rules = read_rules()

BALL_G = 44.0
BR = BALL_G / 2.0
MIST_OUTER = BR * rules["radius_ratio"]          # 40px

# 꼬리 색 — 안개와 같은 청록 계열, 뿌리가 밝고 끝이 짙다
TRAIL_COLORS = ((0.498, 0.788, 0.706), (0.184, 0.478, 0.420))

OPTS = [("안 T1   60px  (문서 하한)", 60.0),
        ("안 T2   100px (문서 상한)", 100.0),
        ("안 T3   140px (안개 보상)", 140.0)]


def compose(ball_d, length, kind="curve", angle=0.0, canvas=None, with_mist=True,
            peak=0.72, seed=3):
	"""꼬리 -> 공 -> 안개 순으로 쌓는다. 문서 레이어 순서: 꼬리(공 뒤) < 공 < 발광 테두리."""
	br = ball_d * 0.5
	scale = ball_d / BALL_G
	L = length * scale
	half = max(L + br * 2.4, br * rules["radius_ratio"] * QUAD_PADDING + 4)
	size = int(np.ceil(half * 2)) | 1 if canvas is None else canvas
	c = (size - 1) / 2.0

	# make_path 는 이미 -x(뒤)로 뻗는다. 여기에 pi 를 더하면 진행 방향 앞으로 나가 버린다.
	tr = render_trail(size, br, L, TRAIL_COLORS, kind=kind, angle=angle,
	                  peak=peak, seed=seed)
	im = Image.fromarray((np.clip(tr, 0, 1) * 255).astype(np.uint8), "RGBA")

	b = ball_img(ball_d)
	im.alpha_composite(b, (int(c - b.width / 2) + 1, int(c - b.height / 2) + 1))

	if with_mist:
		m_half = br * rules["radius_ratio"] * QUAD_PADDING
		m_size = int(round(m_half * 2)) | 1
		m = render_mist(m_size, rules, ball_d, gaze=angle)
		mi = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8), "RGBA")
		im.alpha_composite(mi, (int(c - m_size / 2) + 1, int(c - m_size / 2) + 1))
	return im


W, H = 1600, 1560
sh = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(sh)
d.text((26, 18), "VFX ② 이동 꼬리 — ① 형태 단계  ·  길이 3안", font=F(28, True), fill=INK)
d.text((26, 58), "안개 ①(외곽 40px)을 얹은 상태 · 공 44px 실제 크기 기준 · "
                 "꼬리는 공 뒤 레이어", font=F(15), fill=DIM)


def head(y, t):
	d.rectangle([0, y, W, y + 32], fill=(38, 46, 60, 255))
	d.text((24, y + 5), t, font=F(18, True), fill=INK)
	return y + 32


# ── A. 확대 구조 (곡선 궤적)
ya = head(98, "A.   확대 구조   공 지름 132px 로 렌더 — 폭 커브·밴딩·휨 확인용")
ya += 10
CW, CH = W // 3, 430
big_d = 132.0
imgs = [crop_content(compose(big_d, L, kind="curve", angle=0.35)) for _, L in OPTS]
S = min((CW - 40) / max(i.width for i in imgs), (CH - 20) / max(i.height for i in imgs), 1.0)
for i, ((name, L), im) in enumerate(zip(OPTS, imgs)):
	x = CW * i + 8
	# 패널
	sh.alpha_composite(Image.new("RGBA", (CW - 16, CH), PANEL + (255,)), (x, ya))
	im2 = im.resize((int(im.width * S), int(im.height * S)), Image.LANCZOS)
	place(sh, im2, x + (CW - 16) // 2, ya + CH // 2)
	d.text((CW * i + CW // 2, ya + CH + 8), name, font=F(17, True), fill=INK, anchor="ma")
	vis = L - MIST_OUTER
	d.text((CW * i + CW // 2, ya + CH + 32),
	       "안개 밖으로 보이는 길이 %.0fpx" % vis, font=F(14), fill=DIM, anchor="ma")

# ── B. 실제 크기 44px, 궤적 3종
yb = head(ya + CH + 62, "B.   실제 게임 크기 44px   직선 / 곡선 / 튕긴 직후   (오른쪽은 2배 확대)")
yb += 10
RH = 250
for i, (name, L) in enumerate(OPTS):
	x = CW * i + 8
	sh.alpha_composite(Image.new("RGBA", (CW - 16, RH), PANEL + (255,)), (x, yb))
	for j, kind in enumerate(["straight", "curve", "bounce"]):
		im = compose(BALL_G, L, kind=kind, angle=0.3)
		place(sh, im, x + 92, yb + 44 + j * 70)
	im = compose(BALL_G, L, kind="curve", angle=0.3)
	place(sh, zoom(im, 2), x + (CW - 16) - 175, yb + RH // 2)
	d.text((CW * i + CW // 2, yb + RH + 8), name, font=F(16, True), fill=INK, anchor="ma")

# ── C. 보드 위
yc = head(yb + RH + 40, "C.   보드 위 실제 크기 — 여러 방향·속도")
yc += 10
board = Image.open(f"{REPO}/Resources/Art/board/octagonal_dark_wood_board.png").convert("RGBA")
SH = 132
for i, (name, L) in enumerate(OPTS):
	strip = board.crop((300, 320 + i * 150, 300 + 1420, 320 + i * 150 + SH)).copy()
	for j, (px, py, ang) in enumerate([(180, 66, 0.2), (520, 52, -0.5),
	                                   (860, 74, 1.1), (1210, 58, 2.6)]):
		im = compose(BALL_G, L, kind="curve" if j % 2 else "straight", angle=ang)
		place(strip, im, px, py)
	sh.alpha_composite(strip, (26, yc + i * (SH + 6)))
	d.text((W - 34, yc + i * (SH + 6) + 8), name, font=F(15, True), fill=INK, anchor="ra")

sh.convert("RGB").save(f"{OUT}/vfx02_trail_mock.png")
print("saved bottom=", yc + 3 * (SH + 6), "H=", H)
