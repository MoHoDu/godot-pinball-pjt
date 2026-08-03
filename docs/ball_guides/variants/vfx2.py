"""공별 고속 꼬리 / 충돌 스파크 / 콤보 잔상 / 상태 오버레이"""
from PIL import Image, ImageDraw
import numpy as np, math, os
IVORY=(240,224,195); TEAL=(79,166,146); TEAL_L=(127,201,180)
V={
 'Clockwork': dict(kr='정속 태엽눈', main=(227,166,63), sub=(200,146,54), hit='line'),
 'Rubber':    dict(kr='고무막 유리눈', main=(232,118,58), sub=(244,164,98), hit='splash'),
 'Gel':       dict(kr='완충 젤 유리눈', main=(169,200,124), sub=(222,230,184), hit='blob'),
 'Lead':      dict(kr='납심 유리눈', main=(110,114,124), sub=(200,162,68), hit='cross'),
 'HollowBell':dict(kr='속빈 방울눈', main=(198,178,222), sub=(217,179,76), hit='shard'),
}
OUT='/tmp/var/vfx'; SS=4
def wob(n,amp,seed,waves=((2,.4),(3,.3),(5,.2),(9,.1))):
    rng=np.random.default_rng(seed); ph=rng.uniform(0,2*math.pi,len(waves))
    return np.array([sum(math.sin(k*2*math.pi*i/n+p)*t for (k,t),p in zip(waves,ph)) for i in range(n)])*amp

# ── 고속 이동 꼬리 : 길게, 코어 강화, 감쇠 완만
def trail_fast(name,v):
    W,H=768,128; N,Nh=W*2,H*2
    im=Image.new('RGBA',(N,Nh),(0,0,0,0)); d=ImageDraw.Draw(im)
    wo=wob(N,5.0,hash(name)%97); wi=wob(N,3.0,(hash(name)+11)%97)
    for x in range(N):
        t=x/(N-1)
        ho=(Nh/2)*(1-t)**0.42                     # 더 길게 끌린다
        if ho<0.7: continue
        cy=Nh/2
        d.line([(x,cy-ho+wo[x]),(x,cy+ho+wo[x])], fill=v['main']+(int(210*(1-t)**0.95),))
        h2=ho*0.55
        d.line([(x,cy-h2+wi[x]),(x,cy+h2+wi[x])], fill=v['sub']+(int(238*(1-t)**0.75),))
        h3=ho*0.26
        d.line([(x,cy-h3+wi[x]),(x,cy+h3+wi[x])], fill=IVORY+(int(255*(1-t)**0.55),))
        if t<0.55:
            h4=ho*0.11
            d.line([(x,cy-h4+wi[x]),(x,cy+h4+wi[x])], fill=TEAL_L+(int(240*(1-t/0.55)),))
    return im.resize((W,H),Image.LANCZOS)

# ── 충돌 스파크 : 공별 형태 (문서 3-4 충돌 입자 방향·길이 차등)
def hitspark(name,v):
    S=192; N=S*SS; c=N/2
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    k=v['hit']; M=v['main']+(240,); Sc=v['sub']+(235,); I=IVORY+(220,)
    def spike(a,r0,r1,w,f):
        A=math.radians(a); ux,uy=math.cos(A),math.sin(A); px,py=-uy,ux
        d.polygon([(c+ux*r1, c+uy*r1),
                   (c+ux*r0+px*w, c+uy*r0+py*w),
                   (c+ux*r0-px*w, c+uy*r0-py*w)], fill=f)
    if k=='line':                                  # 태엽 — 규칙적인 직선 스파크 8개
        for i in range(8): spike(i*45+8, c*0.20, c*0.86, c*0.055, M)
        for i in range(4): spike(i*90+30, c*0.18, c*0.56, c*0.040, Sc)
    elif k=='splash':                              # 고무 — 둥근 튀김
        for i in range(6):
            a=math.radians(i*60+14); r=c*0.62
            rr=c*0.13
            d.ellipse([c+r*math.cos(a)-rr,c+r*math.sin(a)-rr,c+r*math.cos(a)+rr,c+r*math.sin(a)+rr],fill=M)
        for i in range(6):
            a=math.radians(i*60+44); r=c*0.40; rr=c*0.075
            d.ellipse([c+r*math.cos(a)-rr,c+r*math.sin(a)-rr,c+r*math.cos(a)+rr,c+r*math.sin(a)+rr],fill=Sc)
    elif k=='blob':                                # 젤 — 뭉툭하게 번짐
        for i in range(5):
            a=math.radians(i*72+18); r=c*0.46; rr=c*0.20
            d.ellipse([c+r*math.cos(a)-rr,c+r*math.sin(a)-rr*0.8,
                       c+r*math.cos(a)+rr,c+r*math.sin(a)+rr*0.8],fill=M)
        d.ellipse([c-c*0.26,c-c*0.26,c+c*0.26,c+c*0.26],fill=Sc)
    elif k=='cross':                               # 납심 — 날카로운 4방향
        for i in range(4): spike(i*90+45, c*0.10, c*0.92, c*0.052, Sc)
        for i in range(4): spike(i*90,    c*0.10, c*0.44, c*0.032, M)
    elif k=='shard':                               # 속빈 — 고리 파편
        for i in range(5):
            a=math.radians(i*72+11); r=c*0.58; rr=c*0.15
            lay=Image.new('RGBA',(N,N),(0,0,0,0)); ld=ImageDraw.Draw(lay)
            ld.ellipse([c+r*math.cos(a)-rr,c+r*math.sin(a)-rr,c+r*math.cos(a)+rr,c+r*math.sin(a)+rr],fill=M)
            ld.ellipse([c+r*math.cos(a)-rr*0.55,c+r*math.sin(a)-rr*0.55,
                        c+r*math.cos(a)+rr*0.55,c+r*math.sin(a)+rr*0.55],fill=(0,0,0,0))
            im.alpha_composite(lay); d=ImageDraw.Draw(im)
        for i in range(4):
            a=math.radians(i*90+40); r=c*0.36; rr=c*0.085
            d.polygon([(c+r*math.cos(a),c+r*math.sin(a)-rr),
                       (c+r*math.cos(a)+rr,c+r*math.sin(a)+rr),
                       (c+r*math.cos(a)-rr,c+r*math.sin(a)+rr)],fill=Sc)
    d.ellipse([c-c*0.13,c-c*0.13,c+c*0.13,c+c*0.13],fill=I)
    return im.resize((S,S),Image.LANCZOS)

# ── 최고 콤보 전용 별 잔상 (공별 색)
def combostar(name,v):
    S=128; N=S*SS; c=N/2
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    def st(r,f,rot=0,n=4,inner=0.24):
        p=[]
        for i in range(n*2):
            rr=r if i%2==0 else r*inner
            a=math.pi*i/n-math.pi/2+math.radians(rot)
            p.append((c+rr*math.cos(a),c+rr*math.sin(a)))
        d.polygon(p,fill=f)
    st(c*0.94, v['main']+(215,))
    st(c*0.60, v['sub']+(235,), rot=45)
    st(c*0.30, IVORY+(250,))
    return im.resize((S,S),Image.LANCZOS)

# ── 상태 오버레이 (공통 1024, 공 위에 얹는다 / 중심은 비워 동공 가독성 유지)
def overlay(kind):
    S=1024; N=S*SS; c=N/2
    im=Image.new('RGBA',(N,N),(0,0,0,0))
    if kind=='curse': ring_c=(138,99,201); dot_c=(176,214,92)     # 보라 + 라임
    else:             ring_c=(214,62,96);  dot_c=(255,150,170)    # 진홍 + 핫핑크
    def band(ro,ri,f,amp,seed):
        w1=wob(720,amp,seed); w2=wob(720,amp*0.8,seed+5)
        po=[];pi=[]
        for i in range(720):
            a=2*math.pi*i/720
            po.append((c+(ro+w1[i])*math.cos(a), c+(ro+w1[i])*math.sin(a)))
            pi.append((c+(ri+w2[i])*math.cos(a), c+(ri+w2[i])*math.sin(a)))
        lay=Image.new('RGBA',(N,N),(0,0,0,0)); ld=ImageDraw.Draw(lay)
        ld.polygon(po,fill=f); ld.polygon(pi,fill=(0,0,0,0))
        im.alpha_composite(lay)
    band(c*0.99, c*0.86, ring_c+(190,), 14*SS, 11)
    band(c*0.84, c*0.78, ring_c+(120,), 11*SS, 23)
    d=ImageDraw.Draw(im)
    for i in range(6):                                            # 작은 점 (균열 대신)
        a=math.radians(i*60+17); r=c*0.72; rr=c*0.035
        d.ellipse([c+r*math.cos(a)-rr,c+r*math.sin(a)-rr,c+r*math.cos(a)+rr,c+r*math.sin(a)+rr],fill=dot_c+(225,))
    return im.resize((S,S),Image.LANCZOS)

made=0
for k,v in V.items():
    trail_fast(k,v).save(f'{OUT}/TrailFast_{k}.png'); made+=1
    hitspark(k,v).save(f'{OUT}/HitSpark_{k}.png');   made+=1
    combostar(k,v).save(f'{OUT}/ComboStar_{k}.png'); made+=1
    print(f"{k:<11} {v['kr']:<9} TrailFast 768×128 · HitSpark 192² ({v['hit']}) · ComboStar 128²")
overlay('curse').save(f'{OUT}/Overlay_Curse.png')
overlay('danger').save(f'{OUT}/Overlay_Danger.png')
made+=2
print(f'\n상태 오버레이 공통 2종 1024² — 저주(보라·라임) / 피격(진홍·핫핑크). 중심은 비워 동공 가독성 유지')
print(f'총 {made}개 추가')
