"""② 텍스처 단계 결과 — 실제 .gdshader 출력 vs 승인받은 목표 그림"""
import numpy as np
from PIL import Image, ImageDraw
from run_shader import read_rules, render, QUAD_PADDING
from make_sheet import ball_img, place, zoom, F, BG, PANEL, INK, DIM, STATES, cell, BALL_G

OUT = "/sessions/dreamy-gracious-cori/mnt/outputs"
REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
rules = read_rules()
BR = BALL_G / 2.0
OUTER = BR * rules["radius_ratio"]


def shader_cell(ball_d, **kw):
	half = ball_d * 0.5 * rules["radius_ratio"] * QUAD_PADDING
	size = int(round(half * 2)) | 1
	a = render(size, rules, ball_d, **kw)
	im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
	b = ball_img(ball_d)
	im.alpha_composite(b, ((size - b.width) // 2, (size - b.height) // 2))
	return im


W, H = 1560, 1330
sh = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(sh)
d.text((26, 18), "VFX ① 안개 오라 — ② 텍스처 단계 (실제 셰이더 출력)", font=F(28, True), fill=INK)
d.text((26, 58), "Resources/shaders/ball_mist_aura.gdshader 를 llvmpipe 로 실행한 결과 · "
                 "안 B 외곽 40px 확정본", font=F(15), fill=DIM)


def head(y, t):
	d.rectangle([0, y, W, y + 32], fill=(38, 46, 60, 255))
	d.text((24, y + 5), t, font=F(18, True), fill=INK)
	return y + 32


# ── A. 목표 그림 vs 셰이더
ya = head(98, "A.   목표 그림(파이썬 모의) vs 셰이더(실제 구현)   — 같은 성질이 나오는지")
ya += 10
CW, CH = W // 2, 400
for i, (label, im) in enumerate([
	("승인받은 목표 그림  (모의 렌더)", cell(200.0, 40.0 * 200 / 44, STATES["NORMAL"],
	                                    gaze=-0.55, seed=11)),
	("실제 셰이더 출력  (llvmpipe)", shader_cell(200.0, gaze=-0.55)),
]):
	x = CW * i + 8
	sh.alpha_composite(Image.new("RGBA", (CW - 16, CH), PANEL + (255,)), (x, ya))
	s = min((CW - 60) / im.width, (CH - 24) / im.height, 1.0)
	im2 = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
	place(sh, im2, x + (CW - 16) // 2, ya + CH // 2)
	d.text((CW * i + CW // 2, ya + CH + 8), label, font=F(17, True), fill=INK, anchor="ma")

# ── B. 상태 4종 (셰이더)
yb = head(ya + CH + 42, "B.   상태 4종 — 셰이더 실제 출력   확대본 + 실제 게임 크기 44px")
yb += 10
QW, QH = W // 4, 250
for i, st in enumerate(["normal", "combo", "curse", "danger"]):
	x = QW * i + 8
	sh.alpha_composite(Image.new("RGBA", (QW - 16, QH), PANEL + (255,)), (x, yb))
	big = shader_cell(200.0, state=st, gaze=-0.55)
	s = (QH - 22) / big.height
	big = big.resize((int(big.width * s), int(big.height * s)), Image.LANCZOS)
	place(sh, big, x + 118, yb + QH // 2)
	sm = shader_cell(BALL_G, state=st, gaze=-0.55)
	place(sh, sm, x + 300, yb + QH // 2)
	d.text((QW * i + QW // 2, yb + QH + 8), st.upper(), font=F(17, True), fill=INK, anchor="ma")

# ── C. 보드 위 + 위상 흐름
yc = head(yb + QH + 40, "C.   보드 위 실제 크기 — 위상이 흐르며 안개가 소용돌이친다 (drift 0→2.5rad)")
yc += 10
board = Image.open(f"{REPO}/Resources/Art/board/octagonal_dark_wood_board.png").convert("RGBA")
strip = board.crop((330, 420, 330 + 1500, 420 + 110)).copy()
for j in range(6):
	im = shader_cell(BALL_G, gaze=-0.4 + j * 0.35, drift=j * 0.5)
	place(strip, im, 130 + j * 250, 55)
sh.alpha_composite(strip, (26, yc))

# ── D. 점등
yd = yc + 120
d.text((26, yd), "D.   점등 (정확한 패링)", font=F(18, True), fill=INK)
yd += 28
sh.alpha_composite(Image.new("RGBA", (W - 52, 150), PANEL + (255,)), (26, yd))
for j, (lab, fl) in enumerate([("평상", 0.0), ("일반 패링 0.45", 0.45), ("정확한 패링 1.0", 1.0)]):
	im = shader_cell(150.0, flash=fl, gaze=-0.55)
	s = 138 / im.height
	im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
	place(sh, im, 150 + j * 250, yd + 75)
	d.text((150 + j * 250, yd + 152), lab, font=F(15, True), fill=INK, anchor="ma")

sh.convert("RGB").save(f"{OUT}/vfx01_mist_shader_result.png")
print('saved bottom=', yd + 175, 'H=', H)
