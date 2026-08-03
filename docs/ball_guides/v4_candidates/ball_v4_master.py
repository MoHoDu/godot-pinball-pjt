"""
공 v4 — 기획서 원안 회귀 + 진행방향 가독성
큰 청록 홍채 / 둥근 검은 동공 / 아이보리 외곽 / 강한 하이라이트 1 + 보조 1
외곽 한쪽 두꺼운 반사면 / 유리 안쪽에 살짝 떠 있는 홍채·동공 / 약한 투명도
★ 외곽 실루엣은 완벽한 원. 손그림 흔들림은 내부 홍채선에만 (PL 정정)
+X = 진행방향
"""
from PIL import Image, ImageDraw
import numpy as np, math, os

SS, M = 4, 1024
N = M * SS
c = M / 2
R = M / 2

INK     = (12, 16, 26, 255)      # 짙은 남색 외곽선 (원안)
IVORY   = (240, 224, 195, 255)
IVORY_D = (212, 195, 166, 255)   # 유리 안쪽 그늘 (반사면 대비용)
WHITE   = (255, 251, 252, 255)
T_LIGHT = (127, 201, 180, 255)
T_BASE  = (79, 166, 146, 255)
T_DEEP  = (47, 122, 105, 255)
PUPIL   = (11, 11, 12, 255)

OUTLINE = 34
GLASS_R = R - OUTLINE            # 478

def new(): 
    im = Image.new("RGBA", (N, N), (0,0,0,0)); return im, ImageDraw.Draw(im)
def circ(d, cx, cy, r, fill):
    d.ellipse([(cx-r)*SS,(cy-r)*SS,(cx+r)*SS,(cy+r)*SS], fill=fill)
def poly(d, pts, fill):
    d.polygon([(x*SS,y*SS) for x,y in pts], fill=fill)

def wob(cx, cy, r, amp=6.0, seed=3, steps=420):
    """손그림 흔들림 원 — 내부 선 전용. 저주파만 섞어 원으로 읽히게."""
    rng = np.random.default_rng(seed); ph = rng.uniform(0,2*math.pi,4)
    out=[]
    for i in range(steps):
        a = 2*math.pi*i/steps
        w = (math.sin(2*a+ph[0])*0.5 + math.sin(3*a+ph[1])*0.3
             + math.sin(5*a+ph[2])*0.15 + math.sin(7*a+ph[3])*0.08)
        rr = r + amp*w
        out.append((cx+rr*math.cos(a), cy+rr*math.sin(a)))
    return out

def band(cx, cy, r_out, r_in, dx, dy, fill):
    """외곽 한쪽 두꺼운 반사면 — 큰 원에서 밀린 원을 빼 만든 초승달 (하드 엣지)."""
    lay = Image.new("RGBA",(N,N),(0,0,0,0)); ld = ImageDraw.Draw(lay)
    ld.ellipse([(cx-r_out)*SS,(cy-r_out)*SS,(cx+r_out)*SS,(cy+r_out)*SS], fill=fill)
    ld.ellipse([(cx+dx-r_in)*SS,(cy+dy-r_in)*SS,(cx+dx+r_in)*SS,(cy+dy+r_in)*SS], fill=(0,0,0,0))
    return lay

def build(iris_ox, iris_r, pupil_extra, deep_edge=True, seed=3):
    img, d = new()

    # ── 1. 완벽한 원: 잉크 외곽선 + 아이보리 유리 몸체
    circ(d, c, c, R, INK)
    circ(d, c, c, GLASS_R, IVORY)
    circ(d, c, c, GLASS_R-30, IVORY_D)          # 유리 안쪽 = 살짝 그늘

    ix = c + iris_ox

    # ── 2. 홍채 (유리 안쪽에 떠 있다) — 잉크선만 약간 비대칭
    poly(d, wob(ix, c, iris_r+22, amp=7.0, seed=seed), INK)
    poly(d, wob(ix, c, iris_r,    amp=6.0, seed=seed), T_BASE)
    if deep_edge:                                # 홍채 가장자리 얇은 짙은 링
        poly(d, wob(ix, c, iris_r-34, amp=5.0, seed=seed+7), T_BASE)
        lay = band(ix, c, iris_r, iris_r-34, 0, 0, T_DEEP)
        img.alpha_composite(lay); d = ImageDraw.Draw(img)
    # 홍채 앞쪽 굴절 밝은 호
    lay = band(ix, c, iris_r-6, iris_r*0.80, -iris_r*0.30, iris_r*0.10, (127,201,180,120))
    img.alpha_composite(lay); d = ImageDraw.Draw(img)

    # ── 3. 동공 — 검고 둥글게, 진행방향으로 밀림
    circ(d, ix+pupil_extra, c, iris_r*0.46, PUPIL)

    # ── 4. 외곽 한쪽 두꺼운 반사면 (뒤쪽) — 약한 투명도로 홍채가 비쳐 보임
    lay = band(c, c, GLASS_R-6, GLASS_R-104, 128, -66, (255,251,252,140))
    img.alpha_composite(lay); d = ImageDraw.Draw(img)

    # ── 5. 큰 하이라이트 1개 + 보조 1개
    a = math.radians(-138); circ(d, c+math.cos(a)*300, c+math.sin(a)*300, 78, WHITE)
    a2 = math.radians(74);  circ(d, c+math.cos(a2)*372, c+math.sin(a2)*372, 26, WHITE)
    return img

VARIANTS = {
 "V1_standard":  dict(iris_ox=70,  iris_r=300, pupil_extra=44),
 "V2_strong":    dict(iris_ox=124, iris_r=286, pupil_extra=62),
 "V3_pupilonly": dict(iris_ox=0,   iris_r=330, pupil_extra=136),
 "V4_bigiris":   dict(iris_ox=96,  iris_r=362, pupil_extra=48, deep_edge=False),
}
os.makedirs("/tmp/ballv4/out", exist_ok=True)
for k,kw in VARIANTS.items():
    im = build(**kw).resize((M,M), Image.LANCZOS)
    a = np.array(im)[:,:,3]; ys,xs = np.where(a>8)
    print(f"{k}: alpha bbox {xs.max()-xs.min()+1}x{ys.max()-ys.min()+1}")
    im.save(f"/tmp/ballv4/out/{k}.png")
