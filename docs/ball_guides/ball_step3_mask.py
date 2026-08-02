"""이상치를 잘라내며 원을 재적합하고, 원본에 이상 영역이 있는지 확인"""
from PIL import Image
import numpy as np, math

SRC = ("/mnt/user-data/uploads/godot-pinball-pjt/docs/ball_guides/"
       "nano-banana-2_A_single_cursed_cat_s-eye_gemstone_drawn_as_flat_2D_"
       "dark-cartoon_game_art_center-2.jpg")
im = Image.open(SRC).convert("RGB")
a = np.array(im).astype(float)
H, W, _ = a.shape
bg = np.array([29., 26., 42.])
dist = np.linalg.norm(a - bg, axis=2)

cx0, cy0 = 2052.0, 2047.0


def edge_along(cx, cy, ang, rmax=2000):
    ca, sa = math.cos(ang), math.sin(ang)
    prev, r = None, rmax * 0.6
    while r < rmax:
        xi, yi = int(round(cx + ca * r)), int(round(cy + sa * r))
        if not (0 <= xi < W and 0 <= yi < H):
            return None
        d = dist[yi, xi]
        if prev is not None and prev >= 14 > d:
            t = (prev - 14) / (prev - d)
            return r - 0.25 + t * 0.25
        prev = d
        r += 0.25
    return None


N = 1440
raw = []
for i in range(N):
    ang = 2 * math.pi * i / N
    e = edge_along(cx0, cy0, ang)
    if e:
        raw.append((ang, e))
angs = np.array([r[0] for r in raw]); rads = np.array([r[1] for r in raw])
pts = np.c_[cx0 + np.cos(angs) * rads, cy0 + np.sin(angs) * rads]

keep = np.ones(len(pts), bool)
for it in range(6):
    P = pts[keep]
    A = np.c_[2 * P[:, 0], 2 * P[:, 1], np.ones(len(P))]
    b = (P ** 2).sum(axis=1)
    sol, *_ = np.linalg.lstsq(A, b, rcond=None)
    cx, cy = sol[0], sol[1]
    R = math.sqrt(sol[2] + cx * cx + cy * cy)
    res = np.abs(np.linalg.norm(pts - [cx, cy], axis=1) - R)
    s = res[keep].std()
    keep = res < max(3.0, 2.5 * s)
    print(f"  iter{it}: 중심({cx:.2f},{cy:.2f}) R={R:.2f} "
          f"유지 {keep.sum()}/{len(pts)} 잔차평균 {res[keep].mean():.2f} 최대 {res[keep].max():.2f}")

print(f"\n확정 원  중심 ({cx:.2f}, {cy:.2f})  반지름 {R:.2f}")
print(f"버려진 각도 구간(이상치): ", end="")
bad = np.degrees(angs[~keep])
if len(bad):
    bad.sort()
    groups, cur = [], [bad[0]]
    for v in bad[1:]:
        if v - cur[-1] <= 2.0:
            cur.append(v)
        else:
            groups.append(cur); cur = [v]
    groups.append(cur)
    print(", ".join(f"{g[0]:.0f}~{g[-1]:.0f}deg({len(g)})" for g in groups))
np.save("/home/claude/circle.npy", np.array([cx, cy, R]))

# 이상 영역 확인용 크롭
Image.open(SRC).crop((3400, 1400, 4096, 2700)).resize((490, 916)).save("/home/claude/out_right.png")
"""STEP 3-2 : 원형 마스킹 → 1024x1024 RGBA 최종본"""
from PIL import Image
import numpy as np, math

SRC = ("/mnt/user-data/uploads/godot-pinball-pjt/docs/ball_guides/"
       "nano-banana-2_A_single_cursed_cat_s-eye_gemstone_drawn_as_flat_2D_"
       "dark-cartoon_game_art_center-2.jpg")
OUT = "/home/claude/final3"
import os; os.makedirs(OUT, exist_ok=True)

cx, cy, R = np.load("/home/claude/circle.npy")
im = Image.open(SRC).convert("RGB")

# ── 방사 프로파일 : 바깥 60px 구조 확인 ──────────────────────
a = np.array(im).astype(float)
prof = []
for r in np.arange(R - 60, R + 6, 1.0):
    vals = []
    for i in range(360):
        ang = 2 * math.pi * i / 360
        xi, yi = int(round(cx + math.cos(ang) * r)), int(round(cy + math.sin(ang) * r))
        vals.append(a[yi, xi])
    prof.append((r - R, np.median(vals, axis=0)))
print("  r-R    R    G    B")
for d, v in prof[::6]:
    print(f"{d:+6.0f}  {v[0]:4.0f} {v[1]:4.0f} {v[2]:4.0f}")

# ── 크롭 : 안쪽으로 INSET 파고들어 가장자리 프린지 제거 ─────
INSET_1024 = 3.0                     # 최종 1024 기준 3px
M = 1024
scale = R / (M / 2)                  # 원본 px / 최종 px
inset = INSET_1024 * scale
Rc = R - inset
S = 2 * Rc

crop = im.transform(
    (M, M), Image.AFFINE,
    (S / M, 0, cx - Rc, 0, S / M, cy - Rc),
    resample=Image.BICUBIC)

# ── 해석적 원형 알파 (LANCZOS 링잉 회피) ────────────────────
yy, xx = np.mgrid[0:M, 0:M]
d = np.sqrt((xx + 0.5 - M / 2) ** 2 + (yy + 0.5 - M / 2) ** 2)
alpha = np.clip((M / 2 - d) / 1.1 + 0.5, 0, 1)

rgba = np.dstack([np.array(crop).astype(float), alpha * 255]).astype(np.uint8)
out = Image.fromarray(rgba, "RGBA")
out.save(f"{OUT}/cats_eye_ball.png")

# ── 검증 ────────────────────────────────────────────────────
al = np.array(out)[:, :, 3]
ys, xs = np.where(al > 8)
print(f"\n알파 bbox {xs.max()-xs.min()+1} x {ys.max()-ys.min()+1} / 캔버스 {M}")
print(f"인셋 {INSET_1024}px(최종) = {inset:.1f}px(원본), 크롭 반지름 {Rc:.1f}")

# 팔레트 실측
px = np.array(out)[:, :, :3]
solid = al > 250
def near(hexs):
    c = np.array([int(hexs[i:i+2], 16) for i in (0, 2, 4)])
    m = (np.linalg.norm(px.astype(float) - c, axis=2) < 26) & solid
    return m.sum(), (px[m].mean(axis=0).astype(int) if m.sum() else None)
for name, h in [("잉크 0B0B0C", "0B0B0C"), ("아이보리 F0E0C3", "F0E0C3"),
                ("청록밝음 7FC9B4", "7FC9B4"), ("청록 4FA692", "4FA692"),
                ("짙은청록 2F7A69", "2F7A69")]:
    n, mean = near(h)
    pct = 100 * n / solid.sum()
    print(f"  {name:18s} {pct:5.1f}%  실측 {mean}")
