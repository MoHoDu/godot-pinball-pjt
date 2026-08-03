"""VFX ① 안개 오라 — 목표 그림 비교 시트"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from mist_aura import mist_aura, line2d_rings

REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
OUT = "/sessions/dreamy-gracious-cori/mnt/outputs"
# 2026-08-03 형락님 확정 — 앞으로 모든 VFX 예시는 이 공으로 렌더한다.
# base_ball.tscn 이 실제로 쓰는 파일을 그대로 참조한다. 예시용 사본을 따로 두면 갈라진다.
BALL_PNG = f"{REPO}/Resources/Art/balls/glass_eye_ball.png"
BOARD_PNG = f"{REPO}/Resources/Art/board/octagonal_dark_wood_board.png"

BG = (22, 25, 37)
PANEL = (46, 58, 71)
INK = (240, 224, 195)
DIM = (146, 162, 178)

_KR = "/usr/share/fonts/opentype/noto/NotoSansCJK-%s.ttc"
_cache = {}
def F(sz, bold=False):
	key = (sz, bold)
	if key not in _cache:
		f = ImageFont.truetype(_KR % ("Bold" if bold else "Regular"), sz)
		try:
			f.set_variation_by_name("KR")
		except Exception:
			pass
		_cache[key] = f
	return _cache[key]

def hx(s):
	return tuple(int(s[i:i + 2], 16) / 255 for i in (0, 2, 4))

STATES = {
	"NORMAL": (hx("7FC9B4"), hx("4FA692"), hx("2F7A69")),
	"PARRY":  (hx("F0E0C3"), hx("9BD9C4"), hx("4FA692")),
	"CURSE":  (hx("B0D65C"), hx("8A63C9"), hx("4A3576")),
	"DANGER": (hx("FF96AA"), hx("D63E60"), hx("7A1F33")),
}
CUR = ((0.498, 0.788, 0.706, 0.80), (0.310, 0.651, 0.573, 0.44))

_ball_src = Image.open(BALL_PNG).convert("RGBA")
def ball_img(d):
	return _ball_src.resize((int(round(d)), int(round(d))), Image.LANCZOS)

def to_img(a):
	return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")

def cell(ball_d, outer_r, colors, mode="mist", pad=1.16, **kw):
	"""공+VFX 를 자연 크기 RGBA 로. 캔버스는 outer_r 로부터 계산해 절대 안 잘리게."""
	br = ball_d / 2.0
	size = int(np.ceil(max(outer_r * pad, br * 1.4) * 2)) | 1
	if mode == "mist":
		a = mist_aura(size, br, outer_r, colors, **kw)
	else:
		a = line2d_rings(size, br, CUR, **kw)
	im = to_img(a)
	b = ball_img(ball_d)
	im.alpha_composite(b, ((size - b.width) // 2, (size - b.height) // 2))
	return im

def place(dst, im, cx, cy):
	dst.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))

def zoom(im, k):
	return im.resize((im.width * k, im.height * k), Image.NEAREST)

# 안: (라벨, 실제 게임 44px 기준 외곽 반경 px)
OPTS = [("현재 구현  Line2D 링", None), ("안 A   외곽 30px", 30.0),
        ("안 B   외곽 40px", 40.0), ("안 C   외곽 52px", 52.0)]
BALL_G = 44.0   # 실제 게임 크기
BIG = 200.0     # 확대 렌더용 공 지름
K = BIG / BALL_G

W, H = 1600, 1980
sheet = Image.new("RGBA", (W, H), BG + (255,))
d = ImageDraw.Draw(sheet)
d.text((28, 20), "VFX ① 발광 테두리 리디자인  —  마법의 안개 오라", font=F(30, True), fill=INK)
d.text((28, 62), "실제 게임 공 44px 기준 · 외곽 반경 3안 비교 · 맨 왼쪽은 현재 구현(비교용)",
       font=F(16), fill=DIM)

def head(y, txt):
	d.rectangle([0, y, W, y + 34], fill=(38, 46, 60, 255))
	d.text((26, y + 6), txt, font=F(19, True), fill=INK)
	return y + 34

CW = W // 4

# ================================================================ A. 확대 구조
ya = head(104, "A.   확대 구조    공 지름 200px 으로 렌더 — 안개 결·밴딩·혓바닥 확인용")
ya += 12
CH = 372
# ★ 셀마다 따로 스케일하면 안 C 의 공만 작아져 비교가 성립하지 않는다.
#   가장 큰 안(외곽 52px)에 맞춘 공통 배율을 전부에 적용한다.
_big = cell(BIG, 52.0 * K, STATES["NORMAL"], gaze=-0.55, seed=11)
S_A = min((CW - 40) / _big.width, (CH - 20) / _big.height, 1.0)
for i, (name, outer) in enumerate(OPTS):
	x = CW * i + 8
	sheet.alpha_composite(Image.new("RGBA", (CW - 16, CH), PANEL + (255,)), (x, ya))
	if outer is None:
		im = cell(BIG, BIG * 1.24 / 2, None, mode="ring")
	else:
		im = cell(BIG, outer * K, STATES["NORMAL"], gaze=-0.55, seed=11)
	im = im.resize((max(1, int(im.width * S_A)), max(1, int(im.height * S_A))), Image.LANCZOS)
	place(sheet, im, x + (CW - 16) // 2, ya + CH // 2)
	cx = CW * i + CW // 2
	d.text((cx, ya + CH + 10), name, font=F(18, True), fill=INK, anchor="ma")
	sub = ("외곽 27.3px · 전체 54.6px  (문서 30px 이내)" if outer is None
	       else f"공 지름의 {outer * 2 / 44:.2f}배 · 전체 {int(outer * 2)}px"
	            + ("  ← 문서 상한" if outer == 30 else ""))
	d.text((cx, ya + CH + 34), sub, font=F(14), fill=DIM, anchor="ma")

# ================================================================ B. 실제 크기
yb = head(ya + CH + 66, "B.   실제 게임 크기 44px    네이티브 렌더 · 오른쪽은 같은 픽셀을 3배 확대")
yb += 12
CH2 = 396
for i, (name, outer) in enumerate(OPTS):
	x = CW * i + 8
	sheet.alpha_composite(Image.new("RGBA", (CW - 16, CH2), PANEL + (255,)), (x, yb))
	if outer is None:
		im = cell(BALL_G, BALL_G * 1.24 / 2, None, mode="ring")
	else:
		im = cell(BALL_G, outer, STATES["NORMAL"], gaze=-0.55, seed=11)
	place(sheet, im, x + 74, yb + CH2 // 2)
	place(sheet, zoom(im, 3), x + (CW - 16) - 130, yb + CH2 // 2)
	d.text((CW * i + CW // 2, yb + CH2 + 10), name, font=F(17, True), fill=INK, anchor="ma")

# ================================================================ C. 보드 합성
yc = head(yb + CH2 + 44, "C.   보드 위 실제 크기    실제 보드 텍스처 · 같은 공이 위상만 다르게")
yc += 10
board = Image.open(BOARD_PNG).convert("RGBA")
SH = 100
for i, (name, outer) in enumerate(OPTS):
	strip = board.crop((330, 300 + i * 118, 330 + 1400, 300 + i * 118 + SH)).copy()
	for j, (px, py) in enumerate([(150, 50), (450, 38), (760, 60), (1080, 44), (1310, 56)]):
		if outer is None:
			im = cell(BALL_G, BALL_G * 1.24 / 2, None, mode="ring", phase=j * 1.1)
		else:
			im = cell(BALL_G, outer, STATES["NORMAL"], seed=11 + j,
			          gaze=-0.5 + j * 0.45, drift=j * 0.31)
		place(strip, im, px, py)
	sheet.alpha_composite(strip, (26, yc + i * (SH + 8)))
	d.text((W - 26, yc + i * (SH + 8) + SH // 2 - 9), name, font=F(16, True), fill=INK, anchor="ra")

# ================================================================ D. 상태 4종
yd = head(yc + 4 * (SH + 8) + 16, "D.   상태 4종    안 B(외곽 40px) 기준 · 확대본 + 실제 크기 + 3배 확대")
yd += 12
CH3 = 268
for i, (sname, cols) in enumerate(STATES.items()):
	x = CW * i + 8
	sheet.alpha_composite(Image.new("RGBA", (CW - 16, CH3), PANEL + (255,)), (x, yd))
	g = 1.30 if sname == "PARRY" else 1.0
	big = cell(BIG, 40 * K, cols, gaze=-0.55, seed=11, core_gain=g, alpha_gain=g)
	s = (CH3 - 24) / big.height
	big = big.resize((int(big.width * s), int(big.height * s)), Image.LANCZOS)
	place(sheet, big, x + 118, yd + CH3 // 2)
	sm = cell(BALL_G, 40.0, cols, gaze=-0.55, seed=11, core_gain=g, alpha_gain=g)
	place(sheet, sm, x + 248, yd + CH3 // 2)
	place(sheet, zoom(sm, 2), x + (CW - 16) - 110, yd + CH3 // 2)
	d.text((CW * i + CW // 2, yd + CH3 + 8), sname, font=F(19, True), fill=INK, anchor="ma")

sheet.convert("RGB").save(f"{OUT}/vfx01_mist_aura_mock.png")
print("saved", sheet.size, "bottom used:", yd + CH3 + 34)
