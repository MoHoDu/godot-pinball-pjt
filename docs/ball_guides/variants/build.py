"""보상 공 5종 — 공통 껍질 재사용 + 공별 홍채/동공/내부 장식"""
from PIL import Image, ImageDraw
import numpy as np, math, os

M=1024; C=511.5; SS=3; N=M*SS; NA=1440
cz=np.load('/tmp/var/contours.npz')
PUP, IIN, IOUT = cz['pupil'], cz['iris_in'], cz['iris_out']
shell=Image.open('/tmp/var/shell.png').convert('RGBA')
hlmask=np.array(Image.open('/tmp/var/hl_mask.png'))>128

IVORY=(240,224,195); TEAL=(79,166,146); TEAL_L=(127,201,180)

V={
 'Clockwork': dict(kr='정속 태엽눈', outline=(43,27,18), base=(227,166,63), light=(246,196,110),
                   deep=(176,126,44), shadow=(96,62,32), pupil=(30,20,12), hl=(246,235,210),
                   accent=(200,146,54), iris_scale=1.0),
 'Rubber':    dict(kr='고무막 유리눈', outline=(58,26,34), base=(232,118,58), light=(244,164,98),
                   deep=(128,58,28), shadow=(96,42,20), pupil=(34,16,18), hl=(255,246,236),
                   accent=(244,164,98), iris_scale=1.0),
 'Gel':       dict(kr='완충 젤 유리눈', outline=(42,48,56), base=(169,200,124), light=(222,230,184),
                   deep=(112,134,84), shadow=(80,96,60), pupil=(22,28,34), hl=(251,251,240),
                   accent=(222,230,184), iris_scale=1.0),
 'Lead':      dict(kr='납심 유리눈', outline=(8,12,22), base=(110,114,124), light=(150,154,164),
                   deep=(56,61,74), shadow=(40,44,56), pupil=(14,16,26), hl=(240,216,154),
                   accent=(200,162,68), iris_scale=0.90),
 'HollowBell':dict(kr='속빈 방울눈', outline=(23,18,36), base=(198,178,222), light=(226,214,240),
                   deep=(104,72,140), shadow=(74,50,104), pupil=(20,14,32), hl=(253,248,255),
                   accent=(217,179,76), iris_scale=1.0),
}

def contour_pts(arr, scale=1.0, off=0.0):
    return [( (C+(arr[i]*scale+off)*math.cos(2*math.pi*i/NA))*SS,
              (C+(arr[i]*scale+off)*math.sin(2*math.pi*i/NA))*SS ) for i in range(NA)]
def circ(d,cx,cy,r,f): d.ellipse([(cx-r)*SS,(cy-r)*SS,(cx+r)*SS,(cy+r)*SS],fill=f)
def ring(d,cx,cy,ro,ri,f):
    d.ellipse([(cx-ro)*SS,(cy-ro)*SS,(cx+ro)*SS,(cy+ro)*SS],fill=f)
    d.ellipse([(cx-ri)*SS,(cy-ri)*SS,(cx+ri)*SS,(cy+ri)*SS],fill=(0,0,0,0))
def arc_band(d,cx,cy,r,half_w,a0,a1,f,steps=90):
    up=[];dn=[]
    for i in range(steps+1):
        t=i/steps; a=math.radians(a0+(a1-a0)*t); tp=math.sin(math.pi*t)**0.4
        up.append(((cx+(r+half_w*tp)*math.cos(a))*SS,(cy+(r+half_w*tp)*math.sin(a))*SS))
        dn.append(((cx+(r-half_w*tp)*math.cos(a))*SS,(cy+(r-half_w*tp)*math.sin(a))*SS))
    d.polygon(up+dn[::-1],fill=f)
def bar(d,cx,cy,ang,length,width,f):
    a=math.radians(ang); ux,uy=math.cos(a),math.sin(a); px,py=-uy,ux
    p=[(cx+ux*length/2+px*width/2, cy+uy*length/2+py*width/2),
       (cx+ux*length/2-px*width/2, cy+uy*length/2-py*width/2),
       (cx-ux*length/2-px*width/2, cy-uy*length/2-py*width/2),
       (cx-ux*length/2+px*width/2, cy-uy*length/2+py*width/2)]
    d.polygon([(x*SS,y*SS) for x,y in p],fill=f)
def star(d,cx,cy,r,f,n=4):
    p=[]
    for i in range(n*2):
        rr=r if i%2==0 else r*0.34; a=math.pi*i/n-math.pi/2
        p.append(((cx+rr*math.cos(a))*SS,(cy+rr*math.sin(a))*SS))
    d.polygon(p,fill=f)

def draw_iris(name,v):
    """홍채 레이어 (SS 캔버스). 홍채 잉크 안쪽 윤곽까지만 채운다."""
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    s=v['iris_scale']
    d.polygon(contour_pts(IIN,s), fill=v['base']+(255,))
    if name=='Clockwork':
        d.polygon(contour_pts(IIN,s*0.80), fill=v['deep']+(255,))
        for k in range(8):                                   # 균일 간격 눈금 8개
            a=k*45+11
            bar(d, C+math.cos(math.radians(a))*312*s, C+math.sin(math.radians(a))*312*s, a, 104*s, 30*s, v['accent']+(255,))
        ring(d,C,C,258*s,222*s, TEAL+(255,))                 # 얇은 청록 소유 링
        circ(d,C,C,206*s, v['shadow']+(255,))
    elif name=='Rubber':
        ring(d,C,C,336*s,298*s, v['light']+(255,))           # 둥근 팽창 링
        ring(d,C,C,270*s,240*s, v['light']+(255,))
        arc_band(d,C,C,352*s,20*s,  24,100, TEAL+(255,))     # 짧은 청록 고무 밴드
        arc_band(d,C,C,352*s,20*s, 204,280, TEAL+(255,))
        ring(d,C,C,244*s,216*s, TEAL+(255,))                 # 청록 소유 링
        circ(d,C,C,206*s, v['deep']+(255,))
    elif name=='Gel':
        circ(d,C,C,318*s, v['light']+(255,))                 # 백탁 젤
        ring(d,C,C,348*s,318*s, TEAL+(255,))                 # 선명한 청록 소유 링
        circ(d,C-118*s,C-92*s, 46*s, (245,248,232,255))      # 기포 2개
        circ(d,C+134*s,C+70*s, 30*s, (245,248,232,255))
        circ(d,C,C,236*s, v['base']+(255,))
    elif name=='Lead':
        d.polygon(contour_pts(IIN,s*0.82), fill=v['deep']+(255,))
        bar(d,C,C,90, 520*s, 96*s, v['accent']+(255,))       # 금빛 추 (세로)
        circ(d,C,C-236*s, 56*s, v['accent']+(255,))
        ring(d,C,C,308*s,278*s, TEAL+(255,))                 # 얇은 청록 각인 링
        circ(d,C,C,214*s, v['shadow']+(255,))
    elif name=='HollowBell':
        circ(d,C,C,318*s, (236,224,206,255))                 # 속 빈 유리 (아이보리 비침)
        ring(d,C,C,318*s,300*s, v['deep']+(255,))
        ring(d,C,C,296*s,260*s, TEAL+(255,))                 # 청록 소유 링
        circ(d,C-150*s,C+118*s, 44*s, v['accent']+(255,))    # 금빛 방울
        star(d,C+164*s,C-128*s, 52*s, v['accent']+(255,))    # 별 조각
        circ(d,C,C,220*s, v['base']+(255,))
    return im

def draw_pupil(name,v):
    im=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(im)
    s=v['iris_scale']
    d.polygon(contour_pts(PUP,s), fill=v['pupil']+(255,))
    if name=='Clockwork':
        bar(d,C,C,  0, 250*s, 34*s, v['accent']+(255,))      # 십자 나사
        bar(d,C,C, 90, 250*s, 34*s, v['accent']+(255,))
        circ(d,C,C, 40*s, v['light']+(255,))
    elif name=='Rubber':
        ring(d,C,C,116*s,74*s, v['light']+(255,))            # 둥근 고무 링
    elif name=='Gel':
        circ(d,C-26*s,C-18*s, 78*s, v['light']+(255,))       # 젤 캡슐
        circ(d,C+64*s,C+72*s, 26*s, (245,248,232,255))
    elif name=='Lead':
        bar(d,C,C, 90, 268*s, 62*s, v['accent']+(255,))      # 수직 추
        circ(d,C,C+96*s, 46*s, v['accent']+(255,))
    elif name=='HollowBell':
        circ(d,C-34*s,C+24*s, 62*s, v['accent']+(255,))      # 금빛 방울
        star(d,C+62*s,C-56*s, 40*s, v['light']+(255,))
    return im

def recolor_shell(v):
    a=np.array(shell).astype(float); g=a[...,:3]
    for src,dst in [((14,14,20), v['outline']), ((255,251,252), v['hl'])]:
        m=np.sqrt(((g-np.array(src,float))**2).sum(-1))<46
        g[m]=dst
    a[...,:3]=g
    return Image.fromarray(a.clip(0,255).astype(np.uint8),'RGBA')

os.makedirs('/tmp/var/out',exist_ok=True)
res={}
for name,v in V.items():
    s=v['iris_scale']
    canvas=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(canvas)
    d.polygon(contour_pts(IOUT,s), fill=v['outline']+(255,))     # 홍채 잉크 링
    canvas.alpha_composite(draw_iris(name,v))
    canvas.alpha_composite(draw_pupil(name,v))
    body=canvas.resize((M,M),Image.LANCZOS)
    out=Image.new('RGBA',(M,M),(0,0,0,0))
    out.alpha_composite(body)
    out.alpha_composite(recolor_shell(v))
    # 하이라이트를 맨 위에
    q=np.array(out); q[hlmask,:3]=v['hl']; q[hlmask,3]=255
    # 원형 알파 마스크 재적용
    base_al=np.array(shell)[...,3]
    yy,xx=np.mgrid[0:M,0:M]; rad=np.hypot(xx-C,yy-C)
    mi=Image.new('L',(M*4,M*4),0); ImageDraw.Draw(mi).ellipse([0,0,M*4-1,M*4-1],fill=255)
    mk=np.array(mi.resize((M,M),Image.LANCZOS))
    q[...,3]=mk
    fin=Image.fromarray(q,'RGBA'); fin.save(f'/tmp/var/out/Ball_{name}_Body.png')
    # 동공 분리본
    pup=draw_pupil(name,v).resize((M,M),Image.LANCZOS)
    pup.save(f'/tmp/var/out/Ball_{name}_Pupil.png')
    # 검증
    gg=q[...,:3].astype(float); m=q[...,3]>200
    tl=np.sqrt(((gg-np.array(TEAL,float))**2).sum(-1))<40
    tl|=np.sqrt(((gg-np.array(TEAL_L,float))**2).sum(-1))<40
    iv=np.sqrt(((gg-np.array(IVORY,float))**2).sum(-1))<40
    ys,xs=np.where(q[...,3]>8)
    res[name]=(tl[m].mean()*100, iv[m].mean()*100, xs.max()-xs.min()+1, ys.max()-ys.min()+1)
    print(f"{name:<11} {v['kr']:<9} 청록 {res[name][0]:5.1f}%  아이보리 {res[name][1]:5.1f}%  bbox {res[name][2]}x{res[name][3]}")
print('\n문서 기준: 청록 5~10% 권장, 아이보리는 유리 외곽·하이라이트로 유지')
