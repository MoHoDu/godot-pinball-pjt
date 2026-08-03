"""
마스킹 결과에 외곽 잉크선 복원
★ 바깥 경계 = 수학적 완벽한 원 (반지름 512, 변동 0)
★ 안쪽 경계만 흔들되 두께에 하한을 걸어 어느 방향에서도 잉크가 끊기지 않게 한다
"""
from PIL import Image, ImageDraw
import numpy as np, math

M=1024; SS=4; N=M*SS; c=M/2
INK=(14,14,20,255)
PRESS_DIR=math.radians(232)

T0, TVAR, TPRESS = 50.0, 10.0, 16.0     # 두께 = T0 + TVAR*noise + TPRESS*cos(a-232도)
TMIN = 24.0                              # 하한 (44px 환산 1.03px)

def thickness(a, ph, waves=((2,.30),(3,.22),(5,.16),(8,.10),(13,.06),(21,.03))):
    w=sum(math.sin(k*a+p)*t for (k,t),p in zip(waves,ph))
    return max(TMIN, T0 + TVAR*w + TPRESS*math.cos(a-PRESS_DIR))

rng=np.random.default_rng(7); PH=rng.uniform(0,2*math.pi,6)
STEPS=2880
inner=[(c+(M/2-thickness(2*math.pi*i/STEPS,PH))*math.cos(2*math.pi*i/STEPS),
        c+(M/2-thickness(2*math.pi*i/STEPS,PH))*math.sin(2*math.pi*i/STEPS))
       for i in range(STEPS)]

base=Image.open('/tmp/mask/ball_v7_final_1024.png').convert('RGBA')
ring=Image.new('RGBA',(N,N),(0,0,0,0)); rd=ImageDraw.Draw(ring)
rd.ellipse([0,0,N-1,N-1],fill=INK)                    # 바깥 = 완벽한 원
rd.polygon([(x*SS,y*SS) for x,y in inner],fill=(0,0,0,0))
ring=ring.resize((M,M),Image.LANCZOS)

out=base.copy(); out.alpha_composite(ring)
a=np.array(out); a[...,3]=np.array(base)[...,3]        # 알파는 원본 마스크 유지
out=Image.fromarray(a,'RGBA')
out.save('/tmp/mask/ball_v7_final_outlined_1024.png')

# ── 검증
al=a[...,3].astype(float); rgb=a[...,:3].astype(float)
lum=.2126*rgb[...,0]+.7152*rgb[...,1]+.0722*rgb[...,2]
ys,xs=np.where(al>8); print(f'알파 bbox {xs.max()-xs.min()+1} x {ys.max()-ys.min()+1}')
outer_r=[];  inner_r=[]
for i in range(1440):
    ang=2*math.pi*i/1440
    o=None; n=None
    for r in np.arange(511.5, 400.0, -0.25):
        x,y=int(round(c+r*math.cos(ang))), int(round(c+r*math.sin(ang)))
        if not(0<=x<M and 0<=y<M): continue
        dark = al[y,x]>190 and lum[y,x]<70
        if o is None and dark: o=r
        if o is not None and not dark: n=r; break
    outer_r.append(o if o else np.nan); inner_r.append(n if n else np.nan)
outer_r=np.array(outer_r,float); inner_r=np.array(inner_r,float)
th=outer_r-inner_r
print(f'잉크 바깥 경계 {np.nanmean(outer_r):.2f} ± {np.nanstd(outer_r):.4f}px   결손 {np.isnan(outer_r).sum()}/1440')
print(f'잉크 두께 {np.nanmin(th):.1f} ~ {np.nanmax(th):.1f}px (평균 {np.nanmean(th):.1f}, {np.nanmax(th)/np.nanmin(th):.1f}배 변동)')
print(f'  44px 환산 {np.nanmin(th)/23.27:.2f} ~ {np.nanmax(th)/23.27:.2f}px · 끊긴 방향 {(th<1).sum()}/1440')
