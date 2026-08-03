"""VFX ② 꼬리 — 2겹(레이저 + 블룸) 구조 시트"""
import numpy as np
from PIL import Image, ImageDraw
from trail_laser import render_layers, over, BALANCE
from run_shader import read_rules, render as render_mist, QUAD_PADDING
from make_sheet import ball_img, place, zoom, F, BG, PANEL, INK, DIM

OUT = "/sessions/dreamy-gracious-cori/mnt/outputs"
REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
rules = read_rules()
BALL_G, LEN = 44.0, 140.0
BR = BALL_G / 2.0


def to_img(a):
	return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")


def crop_content(im, pad=8):
	bb = im.split()[3].getbbox()
	if bb is None:
		return im
	x0, y0, x1, y1 = bb
	return im.crop((max(0, x0 - pad), max(0, y0 - pad),
	                min(im.width, x1 + pad), min(im.height, y1 + pad)))


def parts(ball_d, balance="B", kind="curve", angle=0.0, seed=3):
	br = ball_d * 0.5
	L = LEN * (ball_d / BALL_G)
	half = max(L + br * 2.6, br * rules["radius_ratio"] * QUAD_PADDING + 4)
	size = int(np.ceil(half * 2)) | 1
	laser, bloom = render_layers(size, br, L, balance=balance, kind=kind,
	                             angle=angle, seed=seed)
	return laser, bloom, size


def compose(ball_d, balance="B", kind="curve", angle=0.0, seed=3,
            show="both", with_ball=True, with_mist=True):
	laser, bloom, size = parts(ball_d, balance, kind, angle, seed)
	if show == "laser":
		a = laser
	elif show == "bloom":
		a = bloom
	else:
		a = over(laser, bloom)
	im = to_img(a)
	c = (size - 1) / 2.0
	if with_ball:
		b = ball_img(ball_d)
		im.alpha_composite(b, (int(c - b.width / 2) + 1, int(c - b.height / 2) + 1))
	if with_mist:
		ms = int(round(ball_d * 0.5 * rules["radius_ratio"] * QUAD_PADDING * 2)) | 1
		m = render_mist(ms, rules, ball_d, gaze=angle)
		im.alpha_composite(to_img(m), (int(c - ms / 2) + 1, int(c - ms / 2) + 1))
	return im


def build():
	W, H = 1600, 1330
	sh = Image.new("RGBA", (W, H), BG + (255,))
	d = ImageDraw.Draw(sh)
	d.text((26, 18), "VFX ② 꼬리 — 2겹 구조  ·  안쪽 흰 레이저 + 바깥 청록 블룸",
	       font=F(27, True), fill=INK)
	d.text((26, 56), "길이 140px · 밝기는 길이 방향 4단 계단 (공 뒤가 제일 밝고 끝은 투명 블룸) · "
	                 "레이저=흰색~아이보리, 블룸=안개 ①과 동일 청록", font=F(15), fill=DIM)

	def head(y, t):
		d.rectangle([0, y, W, y + 32], fill=(38, 46, 60, 255))
		d.text((24, y + 5), t, font=F(18, True), fill=INK)
		return y + 32

	def clip_put(im, panel_xy, panel_wh, cx, cy):
		pw, ph = panel_wh
		lay = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
		lay.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))
		sh.alpha_composite(lay, panel_xy)

	# ── A. 레이어 분해
	CW = W // 3
	ya = head(94, "A.   레이어 분해   ① 레이저만 / ② 블룸만 / 합성   (D2 기준 · 공 지름 96px)")
	ya += 10
	CH = 380
	imgs = [crop_content(compose(96.0, "D2", angle=0.32, show=s, with_ball=(s == "both"),
	                             with_mist=(s == "both")))
	        for s in ("laser", "bloom", "both")]
	S = min((CW - 34) / max(i.width for i in imgs),
	        (CH - 18) / max(i.height for i in imgs), 1.0)
	names = ["① 레이저 — 가늘고 흰색, 경계 또렷",
	         "② 블룸 — 넓고 흐리게 감싼다",
	         "합성 (+ 공 + 안개 ①)"]
	for i, im in enumerate(imgs):
		x = CW * i + 8
		sh.alpha_composite(Image.new("RGBA", (CW - 16, CH), PANEL + (255,)), (x, ya))
		im2 = im.resize((int(im.width * S), int(im.height * S)), Image.LANCZOS)
		place(sh, im2, x + (CW - 16) // 2, ya + CH // 2)
		d.text((CW * i + CW // 2, ya + CH + 8), names[i], font=F(16, True),
		       fill=INK, anchor="ma")

	# ── B. 밸런스 3안, 실제 크기
	yb = head(ya + CH + 42, "B.   밸런스 3안 (레이저·블룸 동반 확대) — 실제 게임 크기 44px")
	yb += 10
	RH = 250
	for i, key in enumerate(("D1", "D2", "D3")):
		x = CW * i + 8
		sh.alpha_composite(Image.new("RGBA", (CW - 16, RH), PANEL + (255,)), (x, yb))
		for j, kind in enumerate(["straight", "curve", "bounce"]):
			clip_put(compose(BALL_G, key, kind=kind, angle=0.3, seed=3 + j),
			         (x, yb), (CW - 16, RH), (CW - 16) // 2, 44 + j * 70)
		d.text((CW * i + CW // 2, yb + RH + 8), BALANCE[key]["name"],
		       font=F(16, True), fill=INK, anchor="ma")

	# ── C. 보드 위
	yc = head(yb + RH + 40, "C.   보드 위 실제 크기 — 여러 방향")
	yc += 10
	board = Image.open(
		f"{REPO}/Resources/Art/board/octagonal_dark_wood_board.png").convert("RGBA")
	SHh = 130
	for i, key in enumerate(("D1", "D2", "D3")):
		strip = board.crop((300, 330 + i * 150, 300 + 1420, 330 + i * 150 + SHh)).copy()
		for j, (ppx, ppy, ang) in enumerate([(200, 66, 0.15), (560, 54, -0.45),
		                                     (900, 72, 1.0), (1240, 58, 2.5)]):
			place(strip, compose(BALL_G, key, kind="curve" if j % 2 else "straight",
			                     angle=ang, seed=3 + j), ppx, ppy)
		sh.alpha_composite(strip, (26, yc + i * (SHh + 6)))
		d.text((W - 34, yc + i * (SHh + 6) + 8), BALANCE[key]["name"],
		       font=F(15, True), fill=INK, anchor="ra")

	sh.convert("RGB").save(f"{OUT}/vfx02_trail_laser_v2.png")
	print("saved bottom=", yc + 3 * (SHh + 6), "H=", H)


if __name__ == "__main__":
	build()
