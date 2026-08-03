"""보상 공 5종 VFX 아트 — 꼬리 리본 / 패링 파동 / 전용 입자"""
from PIL import Image, ImageDraw
import numpy as np, math, os

IVORY=(240,224,195); TEAL=(79,166,146); TEAL_L=(127,201,180)
V={
 'Clockwork': dict(kr='정속 태엽눈', main=(227,166,63), sub=(200,146,54), deep=(96,62,32),
                   hl=(246,235,210), parts=['gear','dust']),
 'Rubber':    dict(kr='고무막 유리눈', main=(232,118,58), sub=(244,164,98), deep=(128,58,28),
                   hl=(255,246,236), parts=['drop','drop_s']),
 'Gel':       dict(kr='완충 젤 유리눈', main=(169,200,124), sub=(222,230,184), deep=(112,134,84),
                   hl=(251,251,240), parts=['bubble','bubble_s']),
 'Lead':      dict(kr='납심 유리눈', main=(110,114,124), sub=(200,162,68), deep=(56,61,74),
                   hl=(240,216,154), parts=['flake','flake_s']),
 'HollowBell':dict(kr='속빈 방울눈', main=(198,178,222), sub=(217,179,76), deep=(104,72,140),
                   hl=(253,248,255), parts=['ring','prism','star']),
}
OUT='/tmp/var/vfx'; os.makedirs(OUT,exist_ok=True)
SS=4

def wob(n, amp, seed, waves=((2,.4),(3,.3),(5,.2),(9,.1))):
    rng=np.random.default_rng(seed); ph=rng.uniform(0,2*math.pi,len(waves))
    return np.array([sum(math.sin(k*2*math.pi*i/n+p)*t for (k,t),p in zip(waves,ph)) for i in range(n)])*amp

# ───────── 1. 이동 꼬리 리본 (Line2D.texture) 512x128, 왼쪽=머리
def trail(name,v):
    W,H=512,128; N,Nh=W*2,H*2
    im=Image.new('RGBA',(N,Nh),(0,0,0,0)); d=ImageDraw.Draw(im)
    wobo=wob(N,7.0,hash(name)%99); wobi=wob(N,4.0,(hash(name)+7)%99)
    for x in range(N):
        t=x/(N-1)                      # 0=머리 1=꼬리끝
        a_out=int(215*(1-t)**1.25)
        a_mid=int(240*(1-t)**1.05)
        a_core=int(255*(1-t)**0.85)
        ho=(Nh/2)*(1-t)**0.55           # 반폭
        if ho<0.7: continue
        cy=Nh/2
        d.line([(x,cy-ho+wobo[x]),(x,cy+ho+wobo[x])], fill=v['main']+(a_out,))
        h2=ho*0.62
        d.line([(x,cy-h2+wobi[x]),(x,cy+h2+wobi[x])], fill=v['sub']+(a_mid,))
        h3=ho*0.24
        d.line([(x,cy-h3+wobi[x]),(x,cy+h3+wobi[x])], fill=IVORY+(a_core,))
        if t<0.42:                      # 청록 소유색 (머리 쪽 얇은 심)
            h4=ho*0.10
            d.line([(x,cy-h4+wobi[x]),(x,cy+h4+wobi[x])], fill=TEAL+(int(230*(1-t/0.42)),))
    return im.resize((W,H),Image.LANCZOS)

# ───────── 2. 패링 파동 링 256x256 — 문서 공별 서술대로 구조를 가른다
def parry(name,v):
    S=256; N=S*SS
    im=Image.new('RGBA',(N,N),(0,0,0,0)); c=N/2
    def ring(ro,ri,f,amp,seed,ex=1.0,ey=1.0):
        w1=wob(720,amp,seed); w2=wob(720,amp*0.8,seed+3)
        po=[];pi=[]
        for i in range(720):
            a=2*math.pi*i/720
            po.append((c+(ro+w1[i])*math.cos(a)*ex, c+(ro+w1[i])*math.sin(a)*ey))
            pi.append((c+(ri+w2[i])*math.cos(a)*ex, c+(ri+w2[i])*math.sin(a)*ey))
        lay=Image.new('RGBA',(N,N),(0,0,0,0)); ld=ImageDraw.Draw(lay)
        ld.polygon(po,fill=f); ld.polygon(pi,fill=(0,0,0,0))
        im.alpha_composite(lay)
    d=ImageDraw.Draw(im)
    def spokes(n,r0,r1,w,f,off=0):
        for k in range(n):
            a=math.radians(k*360/n+off)
            d.line([(c+r0*math.cos(a),c+r0*math.sin(a)),(c+r1*math.cos(a),c+r1*math.sin(a))],
                   fill=f, width=int(w*SS))
    if name=='Clockwork':                       # 일정 간격 짧은 방사선 + 청록 눈금 조각
        ring(c*0.96,c*0.80, v['main']+(255,), 5*SS, 11)
        ring(c*0.78,c*0.71, IVORY+(200,),     4*SS, 23)
        for k in range(12):                     # 청록 눈금 조각
            a=math.radians(k*30+6)
            r0,r1=c*0.62,c*0.70
            d.line([(c+r0*math.cos(a),c+r0*math.sin(a)),(c+r1*math.cos(a),c+r1*math.sin(a))],
                   fill=TEAL+(230,), width=int(7*SS))
        spokes(8, c*0.40, c*0.56, 5, IVORY+(190,), 9)
    elif name=='Rubber':                        # 메인 링이 타원으로 늘어남 + 청록 중심 플래시
        ring(c*0.96,c*0.78, v['main']+(255,), 9*SS, 11, ex=1.0, ey=0.80)
        ring(c*0.74,c*0.66, v['sub']+(190,),  8*SS, 23, ex=1.0, ey=0.84)
        ring(c*0.60,c*0.54, TEAL+(220,),      7*SS, 31, ex=1.0, ey=0.88)
    elif name=='Gel':                           # 부드러운 파동 — 방사선 없음, 링 두껍고 완만
        ring(c*0.96,c*0.74, v['main']+(230,), 4*SS, 11)
        ring(c*0.70,c*0.58, v['sub']+(190,),  4*SS, 23)
        ring(c*0.54,c*0.46, TEAL+(215,),      4*SS, 31)
    elif name=='Lead':                          # 정제된 금빛 원형 면 + 날카로운 방향선 4개
        ring(c*0.96,c*0.82, v['sub']+(255,), 3*SS, 11)
        ring(c*0.80,c*0.74, TEAL+(210,),     3*SS, 23)
        ring(c*0.72,c*0.50, v['main']+(120,),3*SS, 31)
        spokes(4, c*0.30, c*0.94, 8, v['sub']+(220,), 45)
    elif name=='HollowBell':                    # 라벤더 메인 + 금빛 방울 스파크 + 청록 중심
        ring(c*0.96,c*0.80, v['main']+(245,), 11*SS, 11)
        ring(c*0.76,c*0.68, TEAL+(215,),       9*SS, 23)
        for k in range(6):                      # 금빛 방울 스파크
            a=math.radians(k*60+13); r=c*0.60
            rr=c*0.09
            d.ellipse([c+r*math.cos(a)-rr, c+r*math.sin(a)-rr, c+r*math.cos(a)+rr, c+r*math.sin(a)+rr],
                      fill=v['sub']+(240,))
    # 중심 플래시 — 밝게 (문서: 짧고 밝은 중심 플래시)
    fl=Image.new('RGBA',(N,N),(0,0,0,0)); fd=ImageDraw.Draw(fl)
    r=c*0.34 if name!='Lead' else c*0.26
    fd.ellipse([c-r,c-r,c+r,c+r], fill=(v['hl'] if name!='Rubber' else TEAL_L)+(235,))
    r2=r*0.55
    fd.ellipse([c-r2,c-r2,c+r2,c+r2], fill=(255,252,248,255))
    im.alpha_composite(fl)
    return im.resize((S,S),Image.LANCZOS)

# ───────── 3. 전용 입자 64x64
def particle(kind,v):
    S=64; N=S*SS
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im); c=N/2
    M=v['main']+(255,); Sc=v['sub']+(255,); I=IVORY+(255,)
    if kind=='gear':
        r=c*0.62
        pts=[]
        for i in range(60):
            a=2*math.pi*i/60
            rr=r*(1.0 if (i//5)%2==0 else 0.76)
            pts.append((c+rr*math.cos(a), c+rr*math.sin(a)))
        d.polygon(pts,fill=Sc); d.ellipse([c-r*0.28,c-r*0.28,c+r*0.28,c+r*0.28],fill=(0,0,0,0))
    elif kind=='dust':
        d.ellipse([c-c*0.26,c-c*0.26,c+c*0.26,c+c*0.26],fill=M)
    elif kind=='drop':
        d.ellipse([c-c*0.58,c-c*0.40,c+c*0.58,c+c*0.40],fill=M)
        d.ellipse([c-c*0.30,c-c*0.22,c-c*0.02,c+c*0.02],fill=I)
    elif kind=='drop_s':
        d.ellipse([c-c*0.34,c-c*0.24,c+c*0.34,c+c*0.24],fill=Sc)
    elif kind=='bubble':
        d.ellipse([c-c*0.60,c-c*0.60,c+c*0.60,c+c*0.60],fill=Sc)
        d.ellipse([c-c*0.44,c-c*0.44,c+c*0.44,c+c*0.44],fill=(0,0,0,0))
        d.ellipse([c-c*0.36,c-c*0.44,c-c*0.10,c-c*0.18],fill=I)
    elif kind=='bubble_s':
        d.ellipse([c-c*0.30,c-c*0.30,c+c*0.30,c+c*0.30],fill=Sc)
    elif kind=='flake':
        d.polygon([(c-c*0.52,c-c*0.10),(c-c*0.10,c-c*0.54),(c+c*0.50,c-c*0.16),
                   (c+c*0.16,c+c*0.52),(c-c*0.34,c+c*0.30)],fill=Sc)
    elif kind=='flake_s':
        d.polygon([(c-c*0.26,c),(c,c-c*0.30),(c+c*0.28,c+c*0.06),(c,c+c*0.28)],fill=Sc)
    elif kind=='ring':
        d.ellipse([c-c*0.58,c-c*0.58,c+c*0.58,c+c*0.58],fill=Sc)
        d.ellipse([c-c*0.36,c-c*0.36,c+c*0.36,c+c*0.36],fill=(0,0,0,0))
    elif kind=='prism':
        d.polygon([(c,c-c*0.58),(c+c*0.50,c+c*0.40),(c-c*0.50,c+c*0.40)],fill=M)
        d.polygon([(c,c-c*0.30),(c+c*0.24,c+c*0.22),(c-c*0.24,c+c*0.22)],fill=I)
    elif kind=='star':
        pts=[]
        for i in range(8):
            rr=c*0.60 if i%2==0 else c*0.20
            a=math.pi*i/4-math.pi/2
            pts.append((c+rr*math.cos(a),c+rr*math.sin(a)))
        d.polygon(pts,fill=Sc)
    return im.resize((S,S),Image.LANCZOS)

made=[]
for k,v in V.items():
    trail(k,v).save(f'{OUT}/Trail_{k}.png')
    parry(k,v).save(f'{OUT}/ParryRing_{k}.png')
    for p in v['parts']:
        particle(p,v).save(f'{OUT}/Particle_{k}_{p}.png')
        made.append(f'Particle_{k}_{p}.png')
    print(f"{k:<11} {v['kr']:<9} Trail 512x128 · ParryRing 256x256 · 입자 {len(v['parts'])}종")
print(f'\n총 {5*2+len(made)}개 파일')
