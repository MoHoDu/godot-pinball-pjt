"""
공 v3 — "눈처럼 생긴 수정/보석". 눈다움은 흰자가 아니라 코어 실루엣에서 나온다.
아이보리 테두리를 두껍게 해 어두운 보드 위 시인성을 되찾는다.
"""
from PIL import Image, ImageDraw
import numpy as np, math, os

SS, M = 4, 1024
N = M * SS

INK     = (11, 11, 12, 255)
IVORY   = (240, 224, 195, 255)
WHITE   = (255, 251, 252, 255)
T_LIGHT = (127, 201, 180, 255)
T_BASE  = (79, 166, 146, 255)
T_DEEP  = (47, 122, 105, 255)
T_CORE  = (22, 66, 60, 255)

R, OUTLINE, RIM = M / 2, 30, 46          # 잉크 1.9px / 아이보리 2.9px @64
c = M / 2


def circ(d, cx, cy, r, fill):
    d.ellipse([(cx-r)*SS, (cy-r)*SS, (cx+r)*SS, (cy+r)*SS], fill=fill)


def poly(d, pts, fill):
    d.polygon([(x*SS, y*SS) for x, y in pts], fill=fill)


def ngon(cx, cy, r, n, rot=0.0):
    return [(cx + r*math.cos(rot + i*2*math.pi/n), cy + r*math.sin(rot + i*2*math.pi/n))
            for i in range(n)]


def almond(cx, cy, half_len, half_wid, steps=140):
    """두 원호가 만나는 렌즈(아몬드)형. 장축은 +X."""
    pts = []
    for i in range(steps + 1):
        t = -1 + 2 * i / steps
        pts.append((cx + t * half_len, cy - half_wid * (1 - t * t) ** 0.62))
    for i in range(steps + 1):
        t = 1 - 2 * i / steps
        pts.append((cx + t * half_len, cy + half_wid * (1 - t * t) ** 0.62))
    return pts


def shell(d):
    circ(d, c, c, R, INK)
    circ(d, c, c, R - OUTLINE, IVORY)
    circ(d, c, c, R - OUTLINE - RIM, T_LIGHT)
    circ(d, c, c, R - OUTLINE - RIM - 40, T_BASE)


def hl(d, cx, cy, deg, dist, r):
    a = math.radians(deg)
    circ(d, cx + math.cos(a)*dist, cy + math.sin(a)*dist, r, WHITE)


def new():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ── A  수정구슬 : 완전 동심원, 방향성 없음 ─────────────────
def A():
    img, d = new()
    shell(d)
    circ(d, c, c, 292, T_DEEP)
    circ(d, c, c, 180, INK)
    circ(d, c, c, 160, T_CORE)
    circ(d, c-46, c-46, 40, T_DEEP)     # 코어 안 미세 글린트 (구멍처럼 안 보이게)
    hl(d, c, c, -52, 292, 60)
    hl(d, c, c, 128, 322, 23)
    return img


# ── B  캣츠아이 : 아몬드 코어가 진행방향을 겨눈다 ───────────
def B():
    img, d = new()
    shell(d)
    circ(d, c, c, 300, T_DEEP)
    ox = c + 40
    poly(d, almond(ox, c, 296, 176), INK)
    poly(d, almond(ox, c, 274, 158), T_CORE)
    circ(d, ox + 52, c, 104, INK)      # 전방으로 밀린 짙은 동공
    # 샤토양시 광선 — 장축을 따라 흐르는 가는 밝은 선 (후방에 치우쳐 방향을 강조)
    poly(d, almond(ox - 62, c, 176, 26), T_LIGHT)
    poly(d, almond(ox - 66, c, 138, 13), IVORY)
    hl(d, c, c, -56, 300, 58)
    hl(d, c, c, 126, 330, 22)
    return img


# ── C  컷젬 : 각진 보석 컷 + 아몬드 코어 ────────────────────
def C():
    img, d = new()
    shell(d)
    ox = c + 30
    RG = 308
    poly(d, ngon(ox, c, RG + 20, 6, math.pi/6), INK)
    poly(d, ngon(ox, c, RG, 6, math.pi/6), T_DEEP)
    v = ngon(ox, c, RG, 6, math.pi/6)
    for i in (0, 2, 4):
        poly(d, [(ox, c), v[i], v[(i+1) % 6]], T_LIGHT)
    poly(d, almond(ox + 26, c, 226, 130), INK)
    poly(d, almond(ox + 26, c, 204, 112), T_CORE)
    circ(d, ox + 78, c, 74, INK)
    poly(d, almond(ox - 30, c, 110, 20), IVORY)
    hl(d, c, c, -54, 298, 56)
    hl(d, c, c, 126, 326, 22)
    return img


os.makedirs("/home/claude/out3", exist_ok=True)
for k, fn in (("A", A), ("B", B), ("C", C)):
    im = fn().resize((M, M), Image.LANCZOS)
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 8)
    print(f"{k}: bbox {xs.max()-xs.min()+1}x{ys.max()-ys.min()+1}")
    im.save(f"/home/claude/out3/ball_v3_{k}.png")
