"""공 v6 — 축 눈과 구조 자체를 가른다 (밝기 / 동공비율 / 아이보리 유무)"""
from PIL import Image, ImageDraw
import numpy as np, math, os
SS,M=4,1024; N=M*SS; c=M/2; R=M/2
INK=(12,16,26,255); IVORY=(240,224,195,255); WHITE=(255,251,252,255)
T_XL=(168,224,206,255); T_LIGHT=(127,201,180,255); T_BASE=(79,166,146,255)
T_DEEP=(47,122,105,255); PUPIL=(11,11,12,255); OUTLINE=34; GLASS_R=R-OUTLINE

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

def build(rim=46, rim_col=IVORY, body=T_BASE, body2=T_DEEP,
          pupil_r=176, pupil_ox=118, iris_ox=54, refl_a=150, refl_w=112,
          pupil_core=None, rim_crescent=False, seed=3):
    img,d=new()
    circ(d,c,c,R,INK)
    circ(d,c,c,GLASS_R,rim_col)
    if rim_crescent:
        img.alpha_composite(band(c,c,GLASS_R,GLASS_R-rim,-70,26,(0,0,0,0))); d=ImageDraw.Draw(img)
    ir=GLASS_R-rim; ix=c+iris_ox
    poly(d,wob(ix,c,ir,6.5,seed),body)
    if body2: poly(d,wob(ix,c,ir*0.72,5.5,seed+7),body2)
    img.alpha_composite(band(ix,c,ir-8,ir*0.78,-ir*0.26,ir*0.12,(255,255,255,60))); d=ImageDraw.Draw(img)
    px=ix+pupil_ox
    poly(d,wob(px,c,pupil_r+16,4.0,seed+3),INK)
    circ(d,px,c,pupil_r,PUPIL)
    if pupil_core: circ(d,px+pupil_r*0.18,c,pupil_r*0.34,pupil_core)
    if refl_a>0:
        img.alpha_composite(band(c,c,GLASS_R-6,GLASS_R-refl_w,132,-70,(255,251,252,refl_a))); d=ImageDraw.Draw(img)
    a=math.radians(-140); circ(d,c+math.cos(a)*306,c+math.sin(a)*306,80,WHITE)
    a2=math.radians(72);  circ(d,c+math.cos(a2)*376,c+math.sin(a2)*376,26,WHITE)
    return img

V={
 "M_bright_glass": dict(body=T_LIGHT, body2=T_BASE),
 "N_big_pupil":    dict(pupil_r=250, pupil_ox=86, body2=None),
 "O_no_ivory":     dict(rim=46, rim_col=T_XL, body=T_LIGHT, body2=T_BASE, refl_a=185),
 "P_cursed_core":  dict(body=T_LIGHT, body2=T_BASE, pupil_core=(168,224,206,255)),
 "Q_bright_big":   dict(body=T_LIGHT, body2=None, pupil_r=248, pupil_ox=84, refl_a=175),
 "R_rim_back":     dict(body=T_LIGHT, body2=T_BASE, rim=112, rim_crescent=True, pupil_ox=126),
}
os.makedirs("/tmp/ballv4/v6out",exist_ok=True)
for k,kw in V.items():
    im=build(**kw).resize((M,M),Image.LANCZOS)
    a=np.array(im)[:,:,3]; ys,xs=np.where(a>8)
    print(f"{k}: bbox {xs.max()-xs.min()+1}x{ys.max()-ys.min()+1}")
    im.save(f"/tmp/ballv4/v6out/{k}.png")
