"""외곽 잉크선 두께 단계별 생성 — 바깥 경계는 항상 완벽한 원, 두께만 스케일"""
from PIL import Image, ImageDraw
import numpy as np, math

M=1024; SS=4; N=M*SS; c=M/2
INK=(14,14,20,255); PRESS_DIR=math.radians(232)
BASE=dict(T0=50.0, TVAR=10.0, TPRESS=16.0, TMIN=24.0)   # 현재 = s 1.0
rng=np.random.default_rng(7); PH=rng.uniform(0,2*math.pi,6)
WAVES=((2,.30),(3,.22),(5,.16),(8,.10),(13,.06),(21,.03))

def build(s):
    T0,TV,TP,TM = BASE['T0']*s, BASE['TVAR']*s, BASE['TPRESS']*s, BASE['TMIN']*s
    STEPS=2880; pts=[]
    for i in range(STEPS):
        a=2*math.pi*i/STEPS
        w=sum(math.sin(k*a+p)*t for (k,t),p in zip(WAVES,PH))
        th=max(TM, T0+TV*w+TP*math.cos(a-PRESS_DIR))
        r=M/2-th
        pts.append((c+r*math.cos(a), c+r*math.sin(a)))
    base=Image.open('/tmp/mask/ball_v7_final_1024.png').convert('RGBA')
    ring=Image.new('RGBA',(N,N),(0,0,0,0)); rd=ImageDraw.Draw(ring)
    rd.ellipse([0,0,N-1,N-1],fill=INK)
    rd.polygon([(x*SS,y*SS) for x,y in pts],fill=(0,0,0,0))
    ring=ring.resize((M,M),Image.LANCZOS)
    out=base.copy(); out.alpha_composite(ring)
    a=np.array(out); a[...,3]=np.array(base)[...,3]
    return Image.fromarray(a,'RGBA')

def measure(im):
    a=np.array(im).astype(float); al=a[...,3]; rgb=a[...,:3]
    lum=.2126*rgb[...,0]+.7152*rgb[...,1]+.0722*rgb[...,2]
    th=[]
    for i in range(1440):
        ang=2*math.pi*i/1440; o=None; n=None
        for r in np.arange(511.5,400.,-0.25):
            x,y=int(round(c+r*math.cos(ang))), int(round(c+r*math.sin(ang)))
            if not(0<=x<M and 0<=y<M): continue
            dark = al[y,x]>190 and lum[y,x]<70
            if o is None and dark: o=r
            if o is not None and not dark: n=r; break
        th.append((o-n) if (o and n) else 0.0)
    th=np.array(th); return th

LV={'L1':0.30,'L2':0.42,'L3':0.53,'L4':0.70,'현재':1.00}
res={}
for k,s in LV.items():
    im=build(s); th=measure(im)
    res[k]=(im,th,s)
    im.save(f'/tmp/mask/outline_{k}.png')
    print(f'{k:>4} (s={s:.2f})  두께 {th.min():5.1f} ~ {th.max():5.1f}px  평균 {th.mean():5.1f}  '
          f'44px 환산 {th.min()/23.27:.2f}~{th.max()/23.27:.2f} (평균 {th.mean()/23.27:.2f})  끊김 {(th<1).sum()}')
print('\n참고: 구본 캣츠아이 외곽 잉크선 25.7px @1024 = 44px 환산 1.10px')
