"""보상 카드용 정지 프리뷰 5종 (문서 12-2 SHOULD)"""
from PIL import Image, ImageDraw, ImageFont
import numpy as np, math, os
KR='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'; KRB='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def F(s,b=False): return ImageFont.truetype(KRB if b else KR,s,index=1)
OUT='/tmp/var/cards'; os.makedirs(OUT,exist_ok=True)
V={
 'Clockwork': ('정속 태엽눈','좋은 성능 · 안정형','일정한 템포, 경로 읽기',(227,166,63),(200,146,54),(96,62,32),(43,27,18)),
 'Rubber':    ('고무막 유리눈','좋은 성능 · 폭발형','높은 탄성, 연쇄 충돌',(232,118,58),(244,164,98),(128,58,28),(58,26,34)),
 'Gel':       ('완충 젤 유리눈','중간 성능 · 완충형','낮은 탄성, 안정적인 생존',(169,200,124),(222,230,184),(112,134,84),(42,48,56)),
 'Lead':      ('납심 유리눈','하드코어 · 정밀형','높은 관성, 직선 경로 유지',(110,114,124),(200,162,68),(56,61,74),(8,12,22)),
 'HollowBell':('속빈 방울눈','하드코어 · 혼돈형','낮은 관성, 큰 방향 변화',(198,178,222),(217,179,76),(104,72,140),(23,18,36)),
}
W,H=480,640
for k,(kr,cls,play,main,sub,deep,line) in V.items():
    card=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(card)
    bgs=tuple(int(x*0.30+22*0.70) for x in deep)
    d.rounded_rectangle([0,0,W-1,H-1],radius=26,fill=bgs+(255,))
    d.rounded_rectangle([6,6,W-7,H-7],radius=21,outline=line+(255,),width=5)
    # 방사 배경 (보드 밖 배경 언어 차용, 저채도)
    lay=Image.new('RGBA',(W*2,H*2),(0,0,0,0)); ld=ImageDraw.Draw(lay)
    cx,cy=W,int(H*0.72)
    for i in range(24):
        if i%2: continue
        a0,a1=math.radians(i*15-7),math.radians(i*15+7)
        ld.polygon([(cx,cy),(cx+1600*math.cos(a0),cy+1600*math.sin(a0)),(cx+1600*math.cos(a1),cy+1600*math.sin(a1))],
                   fill=tuple(int(x*0.55+bgs[j]*0.45) for j,x in enumerate(deep))+(70,))
    lay=lay.resize((W,H),Image.LANCZOS)
    msk=Image.new('L',(W,H),0); ImageDraw.Draw(msk).rounded_rectangle([8,8,W-9,H-9],radius=19,fill=255)
    card.paste(lay,(0,0),Image.fromarray(np.minimum(np.array(lay)[...,3],np.array(msk))))
    d=ImageDraw.Draw(card)
    # 공
    ball=Image.open(f'/tmp/var/out/Ball_{k}_Body.png').convert('RGBA').resize((300,300),Image.LANCZOS)
    card.alpha_composite(ball,(90,86))
    # 텍스트
    d.text((W//2,420),kr,(240,232,218),font=F(34,True),anchor='ma')
    d.text((W//2,466),cls,main+(255,),font=F(19,True),anchor='ma')
    d.text((W//2,498),play,(178,188,204),font=F(17),anchor='ma')
    d.line([(120,534),(W-120,534)],fill=line+(200,),width=2)
    for i,col in enumerate([main,sub,deep,(240,224,195),(79,166,146)]):
        x=W//2-5*30+i*60+15
        d.rounded_rectangle([x,556,x+46,586],radius=7,fill=col+(255,),outline=line+(180,),width=2)
    d.text((W//2,600),'주색 · 보조 · 그림자 · 아이보리 · 청록',(150,160,178),font=F(14),anchor='ma')
    card.save(f'{OUT}/Card_{k}.png')
    print(f'{k:<11} {kr}  480x640')
