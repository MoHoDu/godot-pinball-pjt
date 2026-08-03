"""형락님이 올린 배경 제거본 → 캔버스 내접 + 얇은 외곽선"""
from PIL import Image, ImageDraw
import numpy as np, math, glob, os

SRC=sorted(glob.glob('/sessions/great-nifty-brahmagupta/mnt/uploads/*'),key=os.path.getmtime)[-1]
M=1024; INSET=2.0
PAL={'ink':(14,14,20),'ivory':(240,224,195),'ivory_d':(219,202,173),
     'teal_l':(127,201,180),'teal':(79,166,146),'teal_d':(47,122,105),'white':(255,251,252)}
PRESS_DIR=math.radians(232)

src=Image.open(SRC).convert('RGBA'); W,H=src.size
sa=np.array(src); fg=sa[...,3]>128
ys,xs=np.where(fg); cx0,cy0=xs.mean(),ys.mean()

def edge_r(cx,cy,ang,rmax):
    lo,hi=rmax*0.4,rmax*1.3
    for _ in range(44):
        m=(lo+hi)/2; x,y=int(round(cx+m*math.cos(ang))),int(round(cy+m*math.sin(ang)))
        v=fg[y,x] if 0<=x<W and 0<=y<H else False
        if v: lo=m
        else: hi=m
    return lo
def fit(cx,cy,rmax,n=1440):
    P=np.array([[cx+edge_r(cx,cy,2*math.pi*i/n,rmax)*math.cos(2*math.pi*i/n),
                 cy+edge_r(cx,cy,2*math.pi*i/n,rmax)*math.sin(2*math.pi*i/n)] for i in range(n)])
    A=np.c_[2*P[:,0],2*P[:,1],np.ones(len(P))]; b=(P**2).sum(1)
    s,*_=np.linalg.lstsq(A,b,rcond=None)
    r=math.sqrt(s[2]+s[0]**2+s[1]**2)
    res=np.hypot(P[:,0]-s[0],P[:,1]-s[1])-r
    return s[0],s[1],r,res
rmax=max(xs.max()-xs.min(),ys.max()-ys.min())/2
cx,cy,r,res=fit(cx0,cy0,rmax); cx,cy,r,res=fit(cx,cy,r)
print(f'업로드본 적합 원 중심 ({cx:.2f},{cy:.2f}) 반지름 {r:.2f}px · 잔차 평균 {abs(res).mean():.2f}px 최대 {abs(res).max():.2f}px')

# 변환
scale=(M/2+INSET)/r
big=src.resize((int(round(W*scale)),int(round(H*scale))),Image.LANCZOS)
left,top=int(round(cx*scale-(M-1)/2)),int(round(cy*scale-(M-1)/2))
cv=Image.new('RGBA',(M,M),(0,0,0,0)); cv.paste(big,(-left,-top))
a=np.array(cv).astype(float)
print(f'스케일 {scale:.4f} · 공 지름 {r*2*scale:.1f}px')

# 팔레트 스냅 (알파 있는 곳만)
names=list(PAL); cols=np.array([PAL[k] for k in names],float)
op=a[...,3]>200
d=np.sqrt(((a[:,:,None,:3]-cols[None,None,:,:])**2).sum(-1))
idx=d.argmin(-1); snap=(d.min(-1)<58.0)&op
rgb=a[...,:3].copy(); rgb[snap]=cols[idx[snap]]
print(f'팔레트 스냅 {snap.sum()/op.sum()*100:.1f}%')

# 원형 알파 마스크
SS=4; mi=Image.new('L',(M*SS,M*SS),0)
ImageDraw.Draw(mi).ellipse([0,0,M*SS-1,M*SS-1],fill=255)
mask=np.array(mi.resize((M,M),Image.LANCZOS)).astype(float)/255.
yy,xx=np.mgrid[0:M,0:M]; rad=np.hypot(xx-(M-1)/2,yy-(M-1)/2)
gap=(mask>0.35)&(a[...,3]<128)&(rad>460)
rgb[gap]=PAL['ink']
print(f'가장자리 결손 {gap.sum()}개 → 잉크로 메움')
base=Image.fromarray(np.dstack([rgb,mask*255]).clip(0,255).astype(np.uint8),'RGBA')
base.save('/tmp/mask/thin_base.png')

# 얇은 외곽선
rng=np.random.default_rng(7); PH=rng.uniform(0,2*math.pi,6)
WAVES=((2,.30),(3,.22),(5,.16),(8,.10),(13,.06),(21,.03))
def add_outline(T0,TVAR,TPRESS,TMIN):
    N=M*SS; STEPS=2880; pts=[]
    for i in range(STEPS):
        ang=2*math.pi*i/STEPS
        w=sum(math.sin(k*ang+p)*t for (k,t),p in zip(WAVES,PH))
        th=max(TMIN,T0+TVAR*w+TPRESS*math.cos(ang-PRESS_DIR))
        rr=M/2-th
        pts.append((M/2+rr*math.cos(ang), M/2+rr*math.sin(ang)))
    ring=Image.new('RGBA',(N,N),(0,0,0,0)); rd=ImageDraw.Draw(ring)
    rd.ellipse([0,0,N-1,N-1],fill=PAL['ink']+(255,))
    rd.polygon([(x*SS,y*SS) for x,y in pts],fill=(0,0,0,0))
    ring=ring.resize((M,M),Image.LANCZOS)
    out=base.copy(); out.alpha_composite(ring)
    q=np.array(out); q[...,3]=np.array(base)[...,3]
    return Image.fromarray(q,'RGBA')

def measure(im):
    q=np.array(im).astype(float); al=q[...,3]; g=q[...,:3]
    lum=.2126*g[...,0]+.7152*g[...,1]+.0722*g[...,2]; c=511.5; th=[]
    for i in range(1440):
        ang=2*math.pi*i/1440; o=n=None
        for rr in np.arange(511.5,420.,-0.25):
            x,y=int(round(c+rr*math.cos(ang))),int(round(c+rr*math.sin(ang)))
            if not(0<=x<M and 0<=y<M): continue
            dk=al[y,x]>190 and lum[y,x]<70
            if o is None and dk: o=rr
            if o is not None and not dk: n=rr; break
        th.append((o-n) if (o and n) else 0.0)
    return np.array(th)

LV={'T1':(7.0,1.6,2.6,4.0),'T2':(11.0,2.4,3.8,6.0),'T3':(15.0,3.2,5.2,8.0),'T4':(20.0,4.2,6.8,10.0)}
for k,(a1,b1,c1,d1) in LV.items():
    im=add_outline(a1,b1,c1,d1); th=measure(im); im.save(f'/tmp/mask/thin_{k}.png')
    print(f'{k}  두께 {th.min():4.1f} ~ {th.max():4.1f}px @1024  평균 {th.mean():4.1f}  '
          f'44px 환산 {th.min()/23.27:.2f}~{th.max()/23.27:.2f} (평균 {th.mean()/23.27:.2f})  끊김 {(th<1).sum()}')
