"""공 v5 — 원안 요소 유지 + 플리퍼 축 눈과 지배색을 뒤집어 구분
축 눈 = 아이보리 소켓 지배 / 공 = 청록 유리 지배 + 얇은 아이보리 테
"""
from PIL import Image, ImageDraw
import numpy as np, math, os
SS,M=4,1024; N=M*SS; c=M/2; R=M/2
INK=(12,16,26,255); IVORY=(240,224,195,255); WHITE=(255,251,252,255)
T_LIGHT=(127,201,180,255); T_BASE=(79,166,146,255); T_DEEP=(47,122,105,255)
PUPIL=(11,11,12,255); OUTLINE=34; GLASS_R=R-OUTLINE

def new(): im=Image.new("RGBA",(N,N),(0,0,0,0)); return im,ImageDraw.Draw(im)
def circ(d,cx,cy,r,f): d.ellipse([(cx-r)*SS,(cy-r)*SS,(cx+r)*SS,(cy+r)*SS],fill=f)
def poly(d,p,f): d.polygon([(x*SS,y*SS) for x,y in p],fill=f)
def wob(cx,cy,r,amp=6.0,seed=3,steps=420):
    rng=np.random.default_rng(seed); ph=rng.uniform(0,2*math.pi,4); o=[]
    for i in range(steps):
        a=2*math.pi*i/steps
        w=(math.sin(2*a+ph[0])*.5+math.sin(3*a+ph[1])*.3+math.sin(5*a+ph[2])*.15+math.sin(7*a+ph[3])*.08)
        rr=r+amp*w; o.append((cx+rr*math.cos(a),cy+rr*math.sin(a)))
    return o
def band(cx,cy,ro,ri,dx,dy,f):
    l=Image.new("RGBA",(N,N),(0,0,0,0)); ld=ImageDraw.Draw(l)
    ld.ellipse([(cx-ro)*SS,(cy-ro)*SS,(cx+ro)*SS,(cy+ro)*SS],fill=f)
    ld.ellipse([(cx+dx-ri)*SS,(cy+dy-ri)*SS,(cx+dx+ri)*SS,(cy+dy+ri)*SS],fill=(0,0,0,0))
    return l

def build(rim=46, iris_ox=54, pupil_r=176, pupil_ox=118, refl_a=150, refl_w=112,
          teal_step=True, rim_crescent=False, seed=3):
    img,d=new()
    circ(d,c,c,R,INK)                                  # 완벽한 원 외곽선
    circ(d,c,c,GLASS_R,IVORY)                          # 아이보리 외곽
    if rim_crescent:                                   # 아이보리를 뒤쪽 초승달로만
        img.alpha_composite(band(c,c,GLASS_R-2,GLASS_R-rim,0,0,(0,0,0,0)))
        d=ImageDraw.Draw(img)
        circ(d,c,c,GLASS_R,IVORY)
    iris_r=GLASS_R-rim
    ix=c+(iris_ox if not rim_crescent else rim*0.9)
    poly(d,wob(ix,c,iris_r,6.5,seed),T_BASE)           # 큰 청록 홍채 = 유리 몸체
    if teal_step:
        poly(d,wob(ix,c,iris_r*0.74,5.5,seed+7),T_DEEP)
    img.alpha_composite(band(ix,c,iris_r-8,iris_r*0.78,-iris_r*0.26,iris_r*0.12,(127,201,180,110)))
    d=ImageDraw.Draw(img)
    poly(d,wob(ix+pupil_ox,c,pupil_r+16,4.0,seed+3),INK)   # 동공 잉크 테
    circ(d,ix+pupil_ox,c,pupil_r,PUPIL)                    # 둥근 검은 동공
    if refl_a>0:
        img.alpha_composite(band(c,c,GLASS_R-6,GLASS_R-refl_w,132,-70,(255,251,252,refl_a)))
        d=ImageDraw.Draw(img)
    a=math.radians(-140); circ(d,c+math.cos(a)*306,c+math.sin(a)*306,80,WHITE)
    a2=math.radians(72);  circ(d,c+math.cos(a2)*376,c+math.sin(a2)*376,26,WHITE)
    return img

V={
 "G_thin_rim":     dict(),
 "H_thin_refl":    dict(refl_a=205, refl_w=146),
 "I_mid_rim":      dict(rim=96, iris_ox=44, pupil_ox=104, pupil_r=162),
 "J_flat_teal":    dict(teal_step=False, refl_a=170),
 "K_rim_back":     dict(rim=104, rim_crescent=True, pupil_ox=128, pupil_r=170),
 "L_pupil_big":    dict(pupil_r=214, pupil_ox=102),
}
os.makedirs("/tmp/ballv4/v5out",exist_ok=True)
for k,kw in V.items():
    im=build(**kw).resize((M,M),Image.LANCZOS)
    a=np.array(im)[:,:,3]; ys,xs=np.where(a>8)
    print(f"{k}: bbox {xs.max()-xs.min()+1}x{ys.max()-ys.min()+1}")
    im.save(f"/tmp/ballv4/v5out/{k}.png")
