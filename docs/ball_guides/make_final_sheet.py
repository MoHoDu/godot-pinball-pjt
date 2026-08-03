"""VFX ② 꼬리 — D1 확정본 시트"""
import numpy as np
from PIL import Image, ImageDraw
from trail_laser import BALANCE
from make_laser_sheet import compose, crop_content, BALL_G, LEN, rules
from make_sheet import place, zoom, F, BG, PANEL, INK, DIM

OUT = "/sessions/dreamy-gracious-cori/mnt/outputs"
REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
K = "D1"
cfg = BALANCE[K]
BR = BALL_G / 2.0

W, H = 1600, 1330
sh = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(sh)
d.text((26, 16), "VFX ② 이동 꼬리 — 확정본  ·  2겹 (흰 레이저 + 청록 블룸)",
       font=F(27, True), fill=INK)
d.text((26, 54), "길이 140px · 레이저 뿌리 9px / 블룸 뿌리 60px · 밝기 4단 계단 · "
                 "레이저=순백~아이보리, 블룸=안개 ①과 동일 청록", font=F(15), fill=DIM)


def head(y, t):
	d.rectangle([0, y, W, y + 32], fill=(38, 46, 60, 255))
	d.text((24, y + 5), t, font=F(18, True), fill=INK)
	return y + 32


def clip_put(im, xy, wh, cx, cy):
	lay = Image.new("RGBA", wh, (0, 0, 0, 0))
	lay.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))
	sh.alpha_composite(lay, xy)


CW = W // 3
ya = head(92, "A.   레이어 분해   ① 레이저만 / ② 블룸만 / 합성   (공 지름 96px)")
ya += 10
CH = 400
imgs = [crop_content(compose(96.0, K, angle=0.32, show=s, with_ball=(s == "both"),
                             with_mist=(s == "both"))) for s in ("laser", "bloom", "both")]
S = min((CW - 34) / max(i.width for i in imgs), (CH - 18) / max(i.height for i in imgs), 1.0)
names = ["① 레이저 — 뿌리 9px, 순백, 경계 또렷",
         "② 블룸 — 뿌리 60px, 흐리게 감싼다",
         "합성 (+ 공 + 안개 ①)"]
for i, im in enumerate(imgs):
	x = CW * i + 8
	sh.alpha_composite(Image.new("RGBA", (CW - 16, CH), PANEL + (255,)), (x, ya))
	im2 = im.resize((int(im.width * S), int(im.height * S)), Image.LANCZOS)
	place(sh, im2, x + (CW - 16) // 2, ya + CH // 2)
	d.text((CW * i + CW // 2, ya + CH + 8), names[i], font=F(16, True), fill=INK, anchor="ma")

yb = head(ya + CH + 42, "B.   실제 게임 크기 44px   직선 / 곡선 / 튕긴 직후   (오른쪽 2배 확대)")
yb += 10
RH = 250
x = 8
sh.alpha_composite(Image.new("RGBA", (W - 16, RH), PANEL + (255,)), (x, yb))
for j, kind in enumerate(["straight", "curve", "bounce"]):
	clip_put(compose(BALL_G, K, kind=kind, angle=0.3, seed=3 + j),
	         (x, yb), (W - 16, RH), 300, 44 + j * 70)
z = zoom(compose(BALL_G, K, kind="curve", angle=0.3), 2)
clip_put(z, (x, yb), (W - 16, RH), 1080, RH // 2)

yc = head(yb + RH + 36, "C.   보드 위 실제 크기 — 여러 방향 · 공이 가까이 붙은 경우 포함")
yc += 10
board = Image.open(f"{REPO}/Resources/Art/board/octagonal_dark_wood_board.png").convert("RGBA")
SHh = 150
# 위: 넉넉히 떨어진 경우 / 아래: 가까이 붙어 꼬리가 겹치는 경우
layouts = [
	("떨어져 있을 때", [(200, 74, 0.15), (620, 60, -0.45), (1010, 80, 1.0), (1330, 64, 2.5)]),
	("가까이 붙었을 때 — 겹침 확인", [(300, 70, 0.2), (400, 92, -0.3), (505, 62, 0.9),
	                                (860, 76, 2.4), (950, 58, 1.4), (1250, 74, -1.1)]),
]
for i, (lab, pts) in enumerate(layouts):
	strip = board.crop((300, 330 + i * 170, 300 + 1420, 330 + i * 170 + SHh)).copy()
	for j, (ppx, ppy, ang) in enumerate(pts):
		place(strip, compose(BALL_G, K, kind="curve" if j % 2 else "straight",
		                     angle=ang, seed=3 + j), ppx, ppy)
	sh.alpha_composite(strip, (26, yc + i * (SHh + 8)))
	d.text((W - 34, yc + i * (SHh + 8) + 8), lab, font=F(15, True), fill=INK, anchor="ra")

sh.convert("RGB").save(f"{OUT}/vfx02_trail_final.png")
print("saved bottom=", yc + 2 * (SHh + 8), "H=", H)
