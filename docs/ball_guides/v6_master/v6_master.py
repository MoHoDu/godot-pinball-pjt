"""
공 마스터 — V4 큰 홍채 (기획서 원안 회귀)
★ 외곽 잉크 실루엣 = 수학적 완벽한 원
★ 그 안쪽의 선은 전부 손그림. 바깥/안쪽 윤곽에 서로 다른 위상의 흔들림을 줘
  선 두께가 붓펜처럼 변한다
★ 반사면·하이라이트는 알파 덮기가 아니라 "밝히기"로 합성 — 회색 때가 앉지 않고 유리로 읽힌다
1024x1024 RGBA / 원이 캔버스에 정확히 내접 / +X = 진행방향
"""
from PIL import Image, ImageDraw
import numpy as np, math, os

SS, M = 4, 1024
N = M*SS; c = M/2; R = M/2

INK     = (12, 16, 26, 255)      # 짙은 남색 외곽선
IVORY   = (240, 224, 195, 255)
IVORY_D = (219, 202, 173, 255)
T_LIGHT = (127, 201, 180, 255)
T_BASE  = (79, 166, 146, 255)
T_DEEP  = (47, 122, 105, 255)
PUPIL   = (11, 11, 12, 255)

OUTLINE = 34
GLASS_R = R - OUTLINE            # 478
IRIS_R  = 346                    # 큰 홍채 (공 지름의 67%)
IRIS_OX = 84                     # 홍채 전진량 — 앞쪽 아이보리 테를 22px 남긴다
PUP_R   = IRIS_R * 0.47
PUP_OX  = 52

def new():
    im = Image.new("RGBA",(N,N),(0,0,0,0)); return im, ImageDraw.Draw(im)
def circ(d,cx,cy,r,f): d.ellipse([(cx-r)*SS,(cy-r)*SS,(cx+r)*SS,(cy+r)*SS],fill=f)
def poly(d,p,f): d.polygon([(x*SS,y*SS) for x,y in p],fill=f)

def hand(cx, cy, r, amp, seed, steps=560, wave=(2,3,5,7)):
    """손그림 흔들림 윤곽 — 저주파만 섞어 원으로 읽히게 유지."""
    rng = np.random.default_rng(seed); ph = rng.uniform(0,2*math.pi,4)
    wt = (0.50,0.30,0.14,0.07); o=[]
    for i in range(steps):
        a = 2*math.pi*i/steps
        w = sum(math.sin(k*a+p)*t for k,p,t in zip(wave,ph,wt))
        rr = r + amp*w
        o.append((cx+rr*math.cos(a), cy+rr*math.sin(a)))
    return o

def crescent_mask(cx, cy, ro, ri, dx, dy, amp_o, amp_i, so, si):
    """초승달 알파 마스크 — 두 윤곽 모두 손그림."""
    l = Image.new("L",(N,N),0); ld = ImageDraw.Draw(l)
    ld.polygon([(x*SS,y*SS) for x,y in hand(cx,cy,ro,amp_o,so)], fill=255)
    ld.polygon([(x*SS,y*SS) for x,y in hand(cx+dx,cy+dy,ri,amp_i,si)], fill=0)
    return l

def lighten(img, mask, k, protect_ink=True):
    """유리 반사 — 밑색을 흰쪽으로 끌어올린다. 색상 유지, 회색 막 없음.
    protect_ink: 잉크선·동공은 반사면이 밝히지 않는다. 안 막으면 회색 얼룩이 된다."""
    a = np.array(img).astype(np.float32)
    m = (np.array(mask).astype(np.float32)/255.0)*k
    if protect_ink:
        lum = 0.2126*a[...,0] + 0.7152*a[...,1] + 0.0722*a[...,2]
        m = m * np.clip((lum-38.0)/58.0, 0.0, 1.0)
    a[...,:3] = a[...,:3] + (255.0-a[...,:3])*m[...,None]
    return Image.fromarray(a.clip(0,255).astype(np.uint8))

def build():
    img, d = new()

    # ── 1. 외곽선 = 수학적 완벽한 원 (여기만 흔들지 않는다)
    circ(d, c, c, R, INK)
    circ(d, c, c, GLASS_R, IVORY)

    # ── 2. 유리 안쪽 경계 — 손그림
    poly(d, hand(c, c, GLASS_R-32, 9.0, 41), IVORY_D)

    ix = c + IRIS_OX

    # ── 3. 홍채 잉크선 — 바깥/안쪽 위상이 달라 두께가 붓펜처럼 변한다
    poly(d, hand(ix, c, IRIS_R+26, 9.0, 11), INK)
    poly(d, hand(ix, c, IRIS_R,     8.0, 29), T_BASE)

    # ── 4. 홍채 짙은 안쪽 (평탄 셀 2단)
    poly(d, hand(ix, c, IRIS_R*0.74, 7.0, 23), T_DEEP)

    # ── 5. 동공 — 둥글되 잉크 테는 손그림
    px = ix + PUP_OX
    poly(d, hand(px, c, PUP_R+18, 6.0, 71), INK)
    poly(d, hand(px, c, PUP_R,    5.0, 83), PUPIL)

    img = img.resize((M,M), Image.LANCZOS)

    # ── 6. 홍채 앞쪽 굴절 — 밝히기 (균열처럼 안 보이게 넓은 면으로)
    mk = crescent_mask(ix, c, IRIS_R-8, IRIS_R*0.74, -IRIS_R*0.30, IRIS_R*0.12,
                       7.0, 7.0, 53, 67).resize((M,M), Image.LANCZOS)
    img = lighten(img, mk, 0.22)

    # ── 7. 외곽 한쪽 두꺼운 반사면 (뒤쪽) — 밝히기. 홍채가 비쳐 보인다
    mk = crescent_mask(c, c, GLASS_R-8, GLASS_R-116, 132, -70,
                       8.0, 9.0, 97, 101).resize((M,M), Image.LANCZOS)
    img = lighten(img, mk, 0.52)

    # ── 8. 큰 하이라이트 1개 — 홍채 경계에 걸치게 놓아 대비를 확보
    d2 = ImageDraw.Draw(img)
    def blob(deg, dist, r, seed):
        a = math.radians(deg)
        pts = hand(c+math.cos(a)*dist, c+math.sin(a)*dist, r, r*0.09, seed,
                   steps=200, wave=(2,3,4,6))
        d2.polygon(pts, fill=(255,251,252,255))
    blob(-153, 268, 74, 131)   # 홍채 경계에 걸쳐 대비 확보
    # ── 9. 작은 보조 하이라이트 1개
    blob(68, 392, 24, 137)
    return img

os.makedirs("/tmp/ballv4/final", exist_ok=True)
im = build()
im.save("/tmp/ballv4/final/ball_v6_master_1024.png")
a=np.array(im); al=a[:,:,3]; ys,xs=np.where(al>8)
print("alpha bbox:", xs.max()-xs.min()+1, "x", ys.max()-ys.min()+1)
cx=cy=511.5; rs=[]
for i in range(1440):
    ang=2*math.pi*i/1440; lo,hi=400.0,520.0
    for _ in range(38):
        mid=(lo+hi)/2
        x=int(round(cx+mid*math.cos(ang))); y=int(round(cy+mid*math.sin(ang)))
        v=al[y,x] if 0<=x<1024 and 0<=y<1024 else 0
        if v>128: lo=mid
        else: hi=mid
    rs.append(lo)
rs=np.array(rs)
print(f"외곽 원 반지름 {rs.mean():.2f} ± {rs.std():.3f}px")
