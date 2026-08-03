"""VFX ② 꼬리 — 형태 3단계 비교 (T3 140px 확정 · 색은 안개와 동일)

★ 시트 생성 코드는 반드시 __main__ 아래에 둔다.
  모듈 수준에 두면 compose 를 import 하는 것만으로 시트 전체가 다시 그려져 멈춘 것처럼 보인다.
"""
import numpy as np
from PIL import Image, ImageDraw
from trail_glow import render_trail_shape, LEVELS
from run_shader import read_rules, render as render_mist, QUAD_PADDING
from make_sheet import ball_img, place, zoom, F, BG, PANEL, INK, DIM

OUT = "/sessions/dreamy-gracious-cori/mnt/outputs"
REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
rules = read_rules()
BALL_G, LEN = 44.0, 140.0
BR = BALL_G / 2.0
MIST_OUTER = BR * rules["radius_ratio"]


def crop_content(im, pad=6):
	bb = im.split()[3].getbbox()
	if bb is None:
		return im
	x0, y0, x1, y1 = bb
	return im.crop((max(0, x0 - pad), max(0, y0 - pad),
	                min(im.width, x1 + pad), min(im.height, y1 + pad)))


def compose(ball_d, level, kind="curve", angle=0.0, with_mist=True, seed=3):
	br = ball_d * 0.5
	sc = ball_d / BALL_G
	L = LEN * sc
	half = max(L + br * 2.6, br * rules["radius_ratio"] * QUAD_PADDING + 4)
	size = int(np.ceil(half * 2)) | 1
	c = (size - 1) / 2.0
	tr = render_trail_shape(size, br, L, level=level, kind=kind, angle=angle, seed=seed)
	im = Image.fromarray((np.clip(tr, 0, 1) * 255).astype(np.uint8), "RGBA")
	b = ball_img(ball_d)
	im.alpha_composite(b, (int(c - b.width / 2) + 1, int(c - b.height / 2) + 1))
	if with_mist:
		ms = int(round(br * rules["radius_ratio"] * QUAD_PADDING * 2)) | 1
		m = render_mist(ms, rules, ball_d, gaze=angle)
		mi = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8), "RGBA")
		im.alpha_composite(mi, (int(c - ms / 2) + 1, int(c - ms / 2) + 1))
	return im


def build():
	W, H = 1600, 1440
	sh = Image.new("RGBA", (W, H), BG + (255,))
	d = ImageDraw.Draw(sh)
	d.text((26, 18), "VFX ② 꼬리 — 형태 3단계  ·  길이 T3 140px 확정",
	       font=F(28, True), fill=INK)
	d.text((26, 58), "색은 안개 ①과 완전히 동일 (#7FC9B4 / #4FA692 / 바깥 0.58배) · 형태만 다름 · "
	                 "가이드 3-4 '형태 구성' 기준", font=F(15), fill=DIM)

	def put_clipped(dst, im, panel_xy, panel_wh, cx, cy):
		"""패널 밖으로 삐져나가면 옆 칸을 침범한다. 패널 크기로 잘라 붙인다."""
		pw, ph = panel_wh
		lay = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
		lay.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))
		dst.alpha_composite(lay, panel_xy)

	def head(y, t):
		d.rectangle([0, y, W, y + 32], fill=(38, 46, 60, 255))
		d.text((24, y + 5), t, font=F(18, True), fill=INK)
		return y + 32

	CW = W // 3
	ya = head(98, "A.   확대 구조   공 지름 96px — 중심 리본 / 외곽 글로우 / 빛 가닥 / 구슬")
	ya += 10
	CH = 430
	imgs = [crop_content(compose(96.0, lv, kind="curve", angle=0.32)) for lv in (0, 1, 2)]
	S = min((CW - 34) / max(i.width for i in imgs),
	        (CH - 18) / max(i.height for i in imgs), 1.0)
	for i, lv in enumerate((0, 1, 2)):
		x = CW * i + 8
		sh.alpha_composite(Image.new("RGBA", (CW - 16, CH), PANEL + (255,)), (x, ya))
		im = imgs[i].resize((int(imgs[i].width * S), int(imgs[i].height * S)), Image.LANCZOS)
		place(sh, im, x + (CW - 16) // 2, ya + CH // 2)
		d.text((CW * i + CW // 2, ya + CH + 8), LEVELS[lv]["name"],
		       font=F(17, True), fill=INK, anchor="ma")

	yb = head(ya + CH + 44, "B.   실제 게임 크기 44px   직선 / 곡선 / 튕긴 직후")
	yb += 10
	RH = 250
	for i, lv in enumerate((0, 1, 2)):
		x = CW * i + 8
		sh.alpha_composite(Image.new("RGBA", (CW - 16, RH), PANEL + (255,)), (x, yb))
		for j, kind in enumerate(["straight", "curve", "bounce"]):
			put_clipped(sh, compose(BALL_G, lv, kind=kind, angle=0.3, seed=3 + j),
			            (x, yb), (CW - 16, RH), (CW - 16) // 2, 44 + j * 70)
		d.text((CW * i + CW // 2, yb + RH + 8), LEVELS[lv]["name"],
		       font=F(16, True), fill=INK, anchor="ma")

	yc = head(yb + RH + 40, "C.   보드 위 실제 크기 — 여러 방향")
	yc += 10
	board = Image.open(
		f"{REPO}/Resources/Art/board/octagonal_dark_wood_board.png").convert("RGBA")
	SHh = 130
	for i, lv in enumerate((0, 1, 2)):
		strip = board.crop((300, 330 + i * 150, 300 + 1420, 330 + i * 150 + SHh)).copy()
		for j, (ppx, ppy, ang) in enumerate([(200, 66, 0.15), (560, 54, -0.45),
		                                     (900, 72, 1.0), (1240, 58, 2.5)]):
			place(strip, compose(BALL_G, lv, kind="curve" if j % 2 else "straight",
			                     angle=ang, seed=3 + j), ppx, ppy)
		sh.alpha_composite(strip, (26, yc + i * (SHh + 6)))
		d.text((W - 34, yc + i * (SHh + 6) + 8), LEVELS[lv]["name"],
		       font=F(15, True), fill=INK, anchor="ra")

	sh.convert("RGB").save(f"{OUT}/vfx02_trail_shape.png")
	print("saved bottom=", yc + 3 * (SHh + 6), "H=", H)


if __name__ == "__main__":
	build()
