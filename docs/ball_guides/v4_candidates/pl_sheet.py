from PIL import Image, ImageDraw, ImageFont
import numpy as np, math
ROOT='/sessions/great-nifty-brahmagupta/mnt/godot-pinball-pjt'
FLIP=f'{ROOT}/Resources/Art/flippers/Flipper_cartoon.png'
BOARD=f'{ROOT}/Resources/Art/board/octagonal_dark_wood_board.png'
KR='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'; KRB='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def F(s,b=False): return ImageFont.truetype(KRB if b else KR,s,index=1)

_fl=Image.open(FLIP).convert('RGBA').crop((482,615,982,1115))
_a=np.array(_fl); yy,xx=np.mgrid[0:500,0:500]
_a[...,3]=np.where(np.hypot(xx-250,yy-250)<=250,_a[...,3],0)
pivot=Image.fromarray(_a)
Q=Image.open('/tmp/ballv4/v6out/Q_bright_big.png').convert('RGBA')
Morig=Image.open('/tmp/ballv4/v6out/M_bright_glass.png').convert('RGBA')
CUR=Image.open(f'{ROOT}/Resources/Art/balls/cats_eye_ball.png').convert('RGBA')

BGC=(28,33,46); PANEL=(38,45,60); TXT=(233,226,212); DIM=(148,158,174)
GOOD=(140,230,190); WARN=(238,150,120); ACC=(255,196,110)
W,H=1560,2290
sh=Image.new('RGB',(W,H),BGC); dr=ImageDraw.Draw(sh)
f_ti,f_h,f_b,f_s,f_n=F(34,True),F(23,True),F(18,True),F(17),F(15)

def panel(x,y,w,h,c=PANEL,r=10): dr.rounded_rectangle([x,y,x+w,y+h],radius=r,fill=c)
def chip(im,x,y,size,px,label=None,lc=DIM,bg=(46,58,71)):
    z=im.resize((px,px),Image.LANCZOS).resize((size,size),Image.NEAREST)
    b=Image.new('RGB',(size,size),bg); b.paste(z,(0,0),z); sh.paste(b,(x,y))
    if label: dr.text((x,y+size+6),label,lc,font=f_n)

dr.text((44,34),'공 아트 리디자인 — 원안과 “축 눈과 달라야 함”의 충돌 해소안',TXT,font=f_ti)
dr.text((44,80),'Pinball_Logue / 2026-08-03 / 실제 게임 크기 기준 (공 44px · 플리퍼 축 눈 47px, 인게임 실측)',DIM,font=f_s)

# ── 1. 문제
y=124; panel(44,y,1472,320)
dr.text((66,y+18),'1.  기획서 원안은 플리퍼 축 눈과 같은 설계도다',ACC,font=f_h)
dr.text((66,y+56),'“큰 청록 홍채 + 검고 둥근 동공 + 아이보리 외곽” — 이 세 줄이 축 눈의 구성과 정확히 일치한다.',TXT,font=f_s)
dr.text((66,y+84),'색만 바꿔서는 갈라지지 않는다. 아이보리 비중을 11%~24%까지 흔들어봤지만 혼동도는 27.8~30.3에서 거의 안 움직였다.',DIM,font=f_s)
chip(pivot,80,y+140,150,47,'플리퍼 축 눈  47px',ACC)
chip(Morig,262,y+140,150,44,'원안 충실형  44px',WARN)
lx=452
for i,(t,d1,d2) in enumerate([('아이보리 외곽','있음 (소켓)','있음 (테)'),
                              ('청록 홍채','큼','큼'),
                              ('검고 둥근 동공','있음 (중앙)','있음'),
                              ('흰 하이라이트','있음','있음')]):
    yy2=y+152+i*38
    dr.text((lx,yy2),t,DIM,font=f_s); dr.text((lx+230,yy2),d1,ACC,font=f_s)
    dr.text((lx+400,yy2),d2,WARN,font=f_s); dr.text((lx+570,yy2),'→  겹침',WARN,font=f_b)
dr.text((lx,y+124),'구조 분해',DIM,font=f_n)
dr.text((lx+230,y+124),'축 눈',DIM,font=f_n); dr.text((lx+400,y+124),'원안 공',DIM,font=f_n)

# ── 2. 흐린 눈 테스트
y=472; panel(44,y,1472,336)
dr.text((66,y+18),'2.  갈라지는 건 색이 아니라 덩어리 구조였다  —  22px 흐린 눈 테스트',ACC,font=f_h)
dr.text((66,y+56),'22px까지 뭉개면 축 눈은 “링”으로, 동공을 키운 공은 “초승달”로 읽힌다. 이게 유일하게 확실히 갈리는 축이다.',TXT,font=f_s)
sets=[(pivot,'축 눈  =  링',ACC,47),(Morig,'원안 충실형  =  링  (겹침)',WARN,44),(Q,'제안 Q  =  초승달  (갈림)',GOOD,44)]
for i,(im,lab,col,px) in enumerate(sets):
    x=90+i*470
    chip(im,x,y+104,150,px); chip(im,x+170,y+104,150,22)
    dr.text((x,y+264),lab,col,font=f_b)
    dr.text((x,y+292),'44px 원본        22px 뭉갬',DIM,font=f_n)

# ── 3. 제안
y=836; panel(44,y,1472,470)
dr.text((66,y+18),'3.  제안 —  Q. 밝은 유리 + 큰 동공',GOOD,font=f_h)
dr.text((66,y+56),'원안 항목은 하나도 버리지 않는다. 동공 비율 하나만 키워 링 구조를 깬다.',TXT,font=f_s)
chip(Q,80,y+96,230,44); dr.text((80,y+336),'제안 Q  44px',GOOD,font=f_b)
chip(Q,80,y+378,58,44); chip(pivot,146,y+376,62,47)
dr.text((80,y+444),'공 44  /  축 눈 47',DIM,font=f_n)
items=[('큰 청록색 홍채','유지  (동공이 커져 링 폭은 감소)',TXT),
 ('검고 둥근 동공','유지 + 확대 + 진행방향으로 이동',GOOD),
 ('아이보리색 외곽','유지',TXT),('크고 강한 흰색 하이라이트 1개','유지',TXT),
 ('작은 보조 하이라이트 1개','유지',TXT),('짙은 남색 외곽선','유지  #0C101A',TXT),
 ('외곽 한쪽 두꺼운 반사면','유지  (뒤쪽 배치 → 진행방향 신호 겸함)',GOOD),
 ('약한 투명도 / 유리 안쪽에 뜬 홍채·동공','유지',TXT),
 ('약간 비뚤어진 수작업 카툰 선','외곽은 완벽한 원, 흔들림은 내부 홍채선에만',GOOD),
 ('균열 1~2개','프로토타입 제외 (문서 지침대로 미제작)',DIM)]
dr.text((350,y+96),'원안·3-6 재질 규격 대조',DIM,font=f_n)
for i,(k,v,col) in enumerate(items):
    yy2=y+124+i*33
    dr.text((350,yy2),'✓',GOOD,font=f_b); dr.text((378,yy2),k,TXT,font=f_s); dr.text((830,yy2),v,col,font=f_s)

# ── 4. 수치
y=1334; panel(44,y,1472,286)
dr.text((66,y+18),'4.  수치 근거',ACC,font=f_h)
cols=[(80,'시안'),(470,'축 눈과의 혼동도 ΔE'),(800,'진행방향 분리폭'),(1120,'판정')]
for x,t in cols: dr.text((x,y+62),t,DIM,font=f_s)
rows=[('제안 Q  밝은 유리 + 큰 동공','31.8','5.92 px','채택',GOOD),
      ('N  큰 동공 (밝기 유지)','30.7','6.11 px','밝기가 축 눈과 같음',TXT),
      ('M  원안 충실형','30.4','4.23 px','링 구조 유지 → 겹침',WARN),
      ('현재본 cats_eye','27.8','0.25 px','방향 판독 불가',WARN)]
for i,(n,a,b,j,col) in enumerate(rows):
    yy2=y+98+i*40
    dr.text((80,yy2),n,col,font=f_s); dr.text((470,yy2),a,col,font=f_s)
    dr.text((800,yy2),b,col,font=f_s); dr.text((1120,yy2),j,col,font=f_s)
dr.text((80,y+262),'혼동도 = 22px로 뭉갠 뒤 축 눈과의 Lab 색차 평균.  분리폭 = 어두운 덩어리와 밝은 덩어리의 진행축 거리.',DIM,font=f_n)

# ── 5. 인게임
y=1648; panel(44,y,1472,420)
dr.text((66,y+18),'5.  실제 보드 위 44px  —  8방향 회전 (노란 화살표 = 진행방향)',ACC,font=f_h)
board=Image.open(BOARD).convert('RGB'); tile=board.crop((300,300,1240,460)).resize((1410,160))
for r,(im,lab,col) in enumerate([(Q,'제안 Q',GOOD),(CUR,'현재본',WARN)]):
    strip=tile.copy(); sd=ImageDraw.Draw(strip); p47=pivot.resize((47,47),Image.LANCZOS)
    for j in range(8):
        ang=j*45
        b=im.rotate(-ang,resample=Image.BICUBIC).resize((44,44),Image.LANCZOS)
        cx=70+j*172; strip.paste(b,(cx-22,80-22),b); strip.paste(p47,(cx+30,80-23),p47)
        a=math.radians(ang)
        sd.line([(cx+math.cos(a)*30,80+math.sin(a)*30),(cx+math.cos(a)*44,80+math.sin(a)*44)],fill=(255,205,70),width=2)
        sd.ellipse([cx+math.cos(a)*44-3,80+math.sin(a)*44-3,cx+math.cos(a)*44+3,80+math.sin(a)*44+3],fill=(255,205,70))
    sh.paste(strip,(80,y+92+r*172)); dr.text((80,y+66+r*172),lab+'  (각 쌍 = 공 + 축 눈)',col,font=f_b)

dr.text((44,2098),'생성 방식: 절차적(Python) 마스터. 확정 후 Leonardo로 손그림 잉크 질감만 입히고 원형 마스킹 — 실루엣은 AI에 맡기지 않는다.',DIM,font=f_s)
dr.text((44,2126),'텍스처 규격: 1024×1024 RGBA, 원이 캔버스에 정확히 내접(알파 bbox = 캔버스 전체). 글로우·트레일은 굽지 않음(VFX가 Line2D로 처리).',DIM,font=f_s)
dr.text((44,2154),'남는 판단: “큰 청록 홍채”에서 링 폭이 줄어드는 것을 PL이 받아들일 수 있는가 — 이것만 확인되면 확정 가능.',ACC,font=f_s)
sh.save('/tmp/ballv4/PL_ball_redesign_proposal.png'); print('ok')
