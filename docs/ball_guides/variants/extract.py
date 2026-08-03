"""확정본에서 공통 껍질 + 손그림 윤곽 추출"""
from PIL import Image
import numpy as np, math, json
P='/sessions/great-nifty-brahmagupta/mnt/godot-pinball-pjt/Resources/Art/balls/glass_eye_ball.png'
M=1024; C=511.5; N=1440
im=Image.open(P).convert('RGBA'); a=np.array(im).astype(float)
g=a[...,:3]; al=a[...,3]
lum=.2126*g[...,0]+.7152*g[...,1]+.0722*g[...,2]
dark=(lum<70)&(al>190)

def scan(ang, lo, hi, want_dark, from_out=True):
    rs=np.arange(hi,lo,-0.25) if from_out else np.arange(lo,hi,0.25)
    for r in rs:
        x,y=int(round(C+r*math.cos(ang))),int(round(C+r*math.sin(ang)))
        if not(0<=x<M and 0<=y<M): continue
        if dark[y,x]==want_dark: return r
    return None

pupil=[]; iris_in=[]; iris_out=[]
for i in range(N):
    ang=2*math.pi*i/N
    # 동공 = 중심에서 시작하는 어두운 덩어리의 바깥 경계
    r=0.
    while r<300:
        x,y=int(round(C+r*math.cos(ang))),int(round(C+r*math.sin(ang)))
        if not dark[y,x]: break
        r+=0.25
    pupil.append(r)
    # 홍채 잉크 링 = r 330~430 구간의 어두운 띠
    o=n=None
    for rr in np.arange(430,320,-0.25):
        x,y=int(round(C+rr*math.cos(ang))),int(round(C+rr*math.sin(ang)))
        if not(0<=x<M and 0<=y<M): continue
        if o is None and dark[y,x]: o=rr
        if o is not None and not dark[y,x]: n=rr; break
    iris_out.append(o if o else 388.); iris_in.append(n if n else 368.)
pupil=np.array(pupil); iris_in=np.array(iris_in); iris_out=np.array(iris_out)
print(f'동공 반지름   {pupil.mean():.1f} ± {pupil.std():.1f}  ({pupil.min():.0f}~{pupil.max():.0f})')
print(f'홍채 잉크 안쪽 {iris_in.mean():.1f} ± {iris_in.std():.1f}')
print(f'홍채 잉크 바깥 {iris_out.mean():.1f} ± {iris_out.std():.1f}   두께 평균 {(iris_out-iris_in).mean():.1f}')
np.savez('/tmp/var/contours.npz', pupil=pupil, iris_in=iris_in, iris_out=iris_out)

# 껍질 = 홍채 잉크 바깥보다 밖만 남김
yy,xx=np.mgrid[0:M,0:M]; rad=np.hypot(xx-C,yy-C); ang=np.arctan2(yy-C,xx-C)
idx=((ang%(2*math.pi))/(2*math.pi)*N).astype(int)%N
out_r=iris_out[idx]
shell=a.copy()
inside=rad < (out_r-0.5)
shell[inside,3]=0
Image.fromarray(shell.clip(0,255).astype(np.uint8),'RGBA').save('/tmp/var/shell.png')
print(f'껍질 남은 면적 {(shell[...,3]>200).sum()/(al>200).sum()*100:.1f}%')

# 하이라이트 마스크 (블롭 2개)
from scipy import ndimage
dW=np.sqrt(((g-np.array([255.,251.,252.]))**2).sum(-1))
w=(dW<40)&(al>200); lab,n=ndimage.label(w)
hl=np.zeros((M,M),bool)
for i in range(1,n+1):
    ys,xs=np.where(lab==i)
    if len(xs)<800: continue
    h,wd=ys.max()-ys.min()+1, xs.max()-xs.min()+1
    if 0.7<wd/h<1.4 and max(wd,h)<200:
        hl|=(lab==i)
        print(f'  하이라이트 {len(xs)}px 중심({xs.mean():.0f},{ys.mean():.0f}) r={math.hypot(xs.mean()-C,ys.mean()-C):.0f}')
hl=ndimage.binary_dilation(hl,np.ones((3,3)))
Image.fromarray((hl*255).astype(np.uint8),'L').save('/tmp/var/hl_mask.png')
# 반사면 (껍질에 남아있음) 확인
refl=(dW<40)&(al>200)&~hl
print(f'반사면 화소 {refl.sum()}  그 중 홍채 안쪽(잘림) {(refl&inside).sum()}')
