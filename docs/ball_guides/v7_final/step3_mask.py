"""
STEP 3 — 원형 마스킹
1) 생성물 원 서브픽셀 적합  2) 마스터 원(중심 511.5, 반지름 512)에 맞추고 3px 인셋
3) JPEG 노이즈 제거를 위한 소프트 팔레트 스냅  4) 가장자리 결손만 잉크로 메움
5) 알파 마스크 → 1024x1024 RGBA (알파 bbox = 캔버스 전체)
"""
from PIL import Image, ImageDraw
import numpy as np, math, os

SRC='/sessions/great-nifty-brahmagupta/mnt/uploads/23c71c22-7fdb-4992-9e92-5c510dd71344-1785739939032_nano-banana-2_A_single_glass_eye_marble_from_a_cursed_toy_drawn_as_flat_2D_dark-cartoon_game_a-1.jpg'
OUT='/tmp/mask'; M=1024; INSET=3.0
CX,CY,R = 508.94, 510.81, 363.86

PAL = {'ink':(14,14,20), 'ivory':(240,224,195), 'ivory_d':(219,202,173),
       'teal_l':(127,201,180), 'teal':(79,166,146), 'teal_d':(47,122,105),
       'white':(255,251,252)}

src=Image.open(SRC).convert('RGB'); W,H=src.size
bg=np.array([22.,24.,36.])

# ── 1. 변환
scale=(M/2 + INSET)/R
newW,newH=int(round(W*scale)),int(round(H*scale))
big=src.resize((newW,newH), Image.LANCZOS)
ncx,ncy=CX*scale, CY*scale
left,top=int(round(ncx-(M-1)/2)), int(round(ncy-(M-1)/2))
canvas=Image.new('RGB',(M,M),tuple(bg.astype(int)))
canvas.paste(big,(-left,-top))
a=np.array(canvas).astype(float)
print(f'스케일 {scale:.4f} ({W}→{newW}px) · 공 지름 {R*2*scale:.1f}px · 인셋 {INSET}px(원본 {INSET/scale:.1f}px)')

yy,xx=np.mgrid[0:M,0:M]; rad=np.hypot(xx-(M-1)/2, yy-(M-1)/2)

# ── 2. 스냅 전 표면 품질 측정 (생성물 자체의 품질)
lum0=.2126*a[...,0]+.7152*a[...,1]+.0722*a[...,2]
tsel=(np.sqrt(((a-np.array([79.,166.,146.]))**2).sum(-1))<34)&(rad<430)
print(f'생성물 청록 표면 밝기 표준편차 {lum0[tsel].std():.2f}  (보드 원판 FAIL 15.5 / 이전 공 통과 2.6)')

# ── 3. 소프트 팔레트 스냅
names=list(PAL); cols=np.array([PAL[k] for k in names],float)
d=np.sqrt(((a[:,:,None,:]-cols[None,None,:,:])**2).sum(-1))
idx=d.argmin(-1); dmin=d.min(-1)
snap=dmin<58.0
raw_fg = np.sqrt(((a-bg)**2).sum(-1))>26        # 스냅 전 전경
a[snap]=cols[idx[snap]]
print(f'팔레트 스냅 {snap.mean()*100:.1f}% (나머지는 경계 안티에일리어싱이라 원본 유지)')

# ── 4. 알파 마스크
SSAA=4
mi=Image.new('L',(M*SSAA,M*SSAA),0)
ImageDraw.Draw(mi).ellipse([0,0,M*SSAA-1,M*SSAA-1],fill=255)
mask=np.array(mi.resize((M,M),Image.LANCZOS)).astype(float)/255.

# ── 5. 가장자리 결손만 메움 (r>470 링에서, 스냅 전 배경이었던 곳)
gap=(mask>0.35)&(~raw_fg)&(rad>470)
print(f'가장자리 결손 {gap.sum()}개 ({gap.sum()/max((mask>0.35).sum(),1)*100:.2f}%) → 잉크로 메움')
a[gap]=PAL['ink']

out=np.dstack([a,(mask*255)]).clip(0,255).astype(np.uint8)
im=Image.fromarray(out,'RGBA'); im.save(f'{OUT}/ball_v7_final_1024.png')

# ── 6. 검증
al=np.array(im)[:,:,3]; ys,xs=np.where(al>8)
print(f'\n알파 bbox {xs.max()-xs.min()+1} x {ys.max()-ys.min()+1}  (요구: 1024 x 1024)')
rgb=np.array(im)[:,:,:3].astype(float); m=al>200; tot=m.sum()
dd=np.sqrt(((rgb[:,:,None,:]-cols[None,None,:,:])**2).sum(-1)); ii=dd.argmin(-1)
print('팔레트 면적 배분')
for j,k in enumerate(names):
    f=((ii==j)&m).sum()/tot*100
    if f>0.4: print(f'  {k:9s} #{PAL[k][0]:02X}{PAL[k][1]:02X}{PAL[k][2]:02X}  {f:5.1f}%')
print(f'  목표 팔레트 반경 26 안 {(dd.min(-1)[m]<26).mean()*100:.1f}%  (이전 공 86.9%)')

# 외곽선 두께 (붓 변동 유지 여부)
ink=(np.sqrt(((rgb-np.array(PAL["ink"],float))**2).sum(-1))<45)&m
th=[]
for i in range(720):
    ang=2*math.pi*i/720; cnt=0
    for r in np.arange(420,512,0.5):
        x=int(round(511.5+r*math.cos(ang))); y=int(round(511.5+r*math.sin(ang)))
        if 0<=x<M and 0<=y<M and ink[y,x]: cnt+=1
    th.append(cnt*0.5)
th=np.array(th); th=th[th>1]
print(f'\n외곽 잉크선 두께 {th.min():.1f} ~ {th.max():.1f}px (평균 {th.mean():.1f}, {th.max()/max(th.min(),0.5):.1f}배 변동)')
print(f'  44px 환산 {th.mean()/23.27:.2f}px')
# 동공 중심
pup=(np.sqrt(((rgb-np.array([12.,12.,16.]))**2).sum(-1))<26)&m&(rad<300)
if pup.sum():
    print(f'동공 중심 오프셋 X {xx[pup].mean()-511.5:+.1f}px  Y {yy[pup].mean()-511.5:+.1f}px  (요구: 정중앙)')
