"""
공 마스터 v7 — 굶지마풍 거친 잉크 붓선
★ 외곽 실루엣은 여전히 수학적 완벽한 원 (PL 지시)
★ 대신 잉크선의 '안쪽' 경계를 크게 흔들어 두께가 2~3배로 널뛰게 한다 = 붓 느낌
★ 홍채·동공 잉크선도 같은 방식. 끝이 뾰족하게 빠지는 스트로크 몇 개 추가
"""
from PIL import Image, ImageDraw
import numpy as np, math, os

SS, M = 4, 1024
N = M*SS; c = M/2; R = M/2

INK     = (14, 14, 20, 255)
IVORY   = (240, 224, 195, 255)
IVORY_D = (219, 202, 173, 255)
T_LIGHT = (127, 201, 180, 255)
T_BASE  = (79, 166, 146, 255)
T_DEEP  = (47, 122, 105, 255)
PUPIL   = (11, 11, 12, 255)

OUTLINE = 42
GLASS_R = R - OUTLINE
IRIS_R  = 346
PUP_R   = IRIS_R*0.47

def new(): im=Image.new("RGBA",(N,N),(0,0,0,0)); return im, ImageDraw.Draw(im)
def circ(d,cx,cy,r,f): d.ellipse([(cx-r)*SS,(cy-r)*SS,(cx+r)*SS,(cy+r)*SS],fill=f)
def poly(d,p,f): d.polygon([(x*SS,y*SS) for x,y in p],fill=f)

PRESS_DIR = math.radians(232)   # 붓 압력이 실리는 방향 (좌하단이 굵다) — 전 요소 공통

def rough(cx, cy, r, amp, seed, steps=720, press=0.0,
          waves=((2,.30),(3,.22),(5,.16),(8,.10),(13,.06),(21,.03))):
    """거친 붓 윤곽. press = 한 방향으로 실리는 붓 압력(손그림 특유의 비대칭 굵기)."""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 2*math.pi, len(waves)); o=[]
    for i in range(steps):
        a = 2*math.pi*i/steps
        w = sum(math.sin(k*a+p)*t for (k,t),p in zip(waves,ph))
        rr = r + amp*w - press*math.cos(a - PRESS_DIR)
        o.append((cx+rr*math.cos(a), cy+rr*math.sin(a)))
    return o

def taper(d, cx, cy, r0, a0, a1, w, f, bend=0.0, steps=120):
    """끝이 뾰족하게 빠지는 붓 스트로크."""
    up,dn=[],[]
    for i in range(steps+1):
        t=i/steps; a=a0+(a1-a0)*t
        sh=math.sin(math.pi*t)**0.55
        rr=r0+bend*math.sin(math.pi*t)
        hw=w*sh
        up.append((cx+(rr+hw)*math.cos(a), cy+(rr+hw)*math.sin(a)))
        dn.append((cx+(rr-hw)*math.cos(a), cy+(rr-hw)*math.sin(a)))
    poly(d, up+dn[::-1], f)

def crescent_mask(cx,cy,ro,ri,dx,dy,amp_o,amp_i,so,si):
    l=Image.new("L",(N,N),0); ld=ImageDraw.Draw(l)
    ld.polygon([(x*SS,y*SS) for x,y in rough(cx,cy,ro,amp_o,so)],fill=255)
    ld.polygon([(x*SS,y*SS) for x,y in rough(cx+dx,cy+dy,ri,amp_i,si)],fill=0)
    return l

def lighten(img,mask,k,protect=True):
    a=np.array(img).astype(np.float32); m=(np.array(mask).astype(np.float32)/255.)*k
    if protect:
        lum=.2126*a[...,0]+.7152*a[...,1]+.0722*a[...,2]
        m=m*np.clip((lum-38.)/58.,0.,1.)
    a[...,:3]=a[...,:3]+(255.-a[...,:3])*m[...,None]
    return Image.fromarray(a.clip(0,255).astype(np.uint8))

def build():
    img,d=new()
    # ── 외곽: 실루엣은 완벽한 원, 안쪽 경계만 크게 흔들어 두께 널뛰기
    circ(d,c,c,R,INK)
    poly(d, rough(c,c,GLASS_R,20.0,7,press=26.0), IVORY)
    # 유리 안쪽 그늘
    poly(d, rough(c,c,GLASS_R-40,12.0,41), IVORY_D)
    # ── 홍채
    poly(d, rough(c,c,IRIS_R+36,14.0,11), INK)
    poly(d, rough(c,c,IRIS_R,   13.0,29,press=20.0), T_BASE)
    poly(d, rough(c,c,IRIS_R*0.72,10.0,23), T_DEEP)
    # ── 동공
    poly(d, rough(c,c,PUP_R+28,10.0,71), INK)
    poly(d, rough(c,c,PUP_R,    9.0,83,press=13.0), PUPIL)
    # ── 붓 스트로크 — 잉크선을 덧그은 흔적 (외곽 안쪽에만)
    taper(d,c,c,R-20, math.radians(196), math.radians(256), 15, INK, bend=-6)
    taper(d,c,c,R-18, math.radians(38),  math.radians(74),  12, INK, bend=-4)
    taper(d,c,c,IRIS_R+16, math.radians(112), math.radians(158), 11, INK, bend=-4)

    img=img.resize((M,M),Image.LANCZOS)
    # ── 유리 반사 (밝히기, 잉크 보호)
    mk=crescent_mask(c,c,IRIS_R-10,IRIS_R*0.74,-IRIS_R*0.30,IRIS_R*0.12,10.,10.,53,67).resize((M,M),Image.LANCZOS)
    img=lighten(img,mk,0.22)
    mk=crescent_mask(c,c,GLASS_R-10,GLASS_R-120,132,-70,12.,13.,97,101).resize((M,M),Image.LANCZOS)
    img=lighten(img,mk,0.52)
    # ── 하이라이트 (살짝 찌그러진 손그림)
    d2=ImageDraw.Draw(img)
    def blob(deg,dist,r,seed):
        a=math.radians(deg)
        d2.polygon(rough(c+math.cos(a)*dist,c+math.sin(a)*dist,r,r*0.13,seed,steps=240),fill=(255,251,252,255))
    blob(-150,262,74,131); blob(68,392,24,137)
    return img

os.makedirs("/tmp/ballv4/final",exist_ok=True)
im=build(); im.save("/tmp/ballv4/final/ball_v7_rough_1024.png")
a=np.array(im); al=a[:,:,3]; ys,xs=np.where(al>8)
print("alpha bbox:",xs.max()-xs.min()+1,"x",ys.max()-ys.min()+1)
cx=cy=511.5; rs=[]
for i in range(1440):
    ang=2*math.pi*i/1440; lo,hi=400.,520.
    for _ in range(38):
        mid=(lo+hi)/2
        x=int(round(cx+mid*math.cos(ang))); y=int(round(cy+mid*math.sin(ang)))
        v=al[y,x] if 0<=x<1024 and 0<=y<1024 else 0
        if v>128: lo=mid
        else: hi=mid
    rs.append(lo)
rs=np.array(rs); print(f"외곽 원 반지름 {rs.mean():.2f} ± {rs.std():.3f}px")
# 외곽 잉크선 두께 변동
rgb=a[...,:3].astype(int); ink=(np.abs(rgb-np.array([14,14,20])).sum(-1)<45)&(al>128)
th=[]
for i in range(720):
    ang=2*math.pi*i/720; cnt=0
    for r in np.arange(440,512,0.5):
        x=int(round(511.5+r*math.cos(ang))); y=int(round(511.5+r*math.sin(ang)))
        if 0<=x<1024 and 0<=y<1024 and ink[y,x]: cnt+=1
    th.append(cnt*0.5)
th=np.array(th); th=th[th>1]
print(f"외곽 잉크선 두께 @1024: {th.min():.1f} ~ {th.max():.1f}px (평균 {th.mean():.1f}, 최대/최소 {th.max()/max(th.min(),0.5):.1f}배)")
