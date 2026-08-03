from PIL import Image, ImageDraw, ImageFont
import numpy as np, math
ROOT='/sessions/great-nifty-brahmagupta/mnt/godot-pinball-pjt'
BOARD=f'{ROOT}/Resources/Art/board/octagonal_dark_wood_board.png'
FLIP=f'{ROOT}/Resources/Art/flippers/Flipper_cartoon.png'
BASE=f'{ROOT}/Resources/Art/balls/glass_eye_ball.png'
KR='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'; KRB='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def F(s,b=False): return ImageFont.truetype(KRB if b else KR,s,index=1)
_fl=Image.open(FLIP).convert('RGBA').crop((482,615,982,1115))
_a=np.array(_fl); yy,xx=np.mgrid[0:500,0:500]
_a[...,3]=np.where(np.hypot(xx-250,yy-250)<=250,_a[...,3],0); pivot=Image.fromarray(_a)
BGC=(28,33,46);PANEL=(38,45,60);TXT=(233,226,212);DIM=(148,158,174);ACC=(255,196,110)
OK=(140,230,190);WARN=(238,150,120);MID=(240,210,140)
W,H=1640,2320
sh=Image.new('RGB',(W,H),BGC); dr=ImageDraw.Draw(sh)
def panel(x,y,w,h): dr.rounded_rectangle([x,y,x+w,y+h],radius=10,fill=PANEL)
def chip(im,x,y,size,px,bg=(46,58,71)):
    z=im.convert('RGBA').resize((px,px),Image.LANCZOS).resize((size,size),Image.NEAREST)
    b=Image.new('RGB',(size,size),bg); b.paste(z,(0,0),z); sh.paste(b,(x,y))

dr.text((40,28),'보상 공 5종 — 1차 시안',TXT,font=F(34,True))
dr.text((40,76),'Pinball_Logue / 2026-08-03 / 기준 화면 1920×1080 · 공 본체 44px · 텍스처 1024×1024 RGBA',DIM,font=F(16))

# 1. 제작 방식
y=112; panel(30,y,1580,180)
dr.text((56,y+16),'1.  제작 방식 — 껍질은 확정본을 그대로 재사용했다',ACC,font=F(22,True))
dr.text((56,y+56),'외곽 잉크선 · 아이보리 유리 외곽 · 두꺼운 반사면 · 하이라이트는 확정된 기본 공에서 픽셀째 가져왔다.',TXT,font=F(17))
dr.text((56,y+84),'손그림 윤곽선도 확정본에서 추출해 썼다 — 동공 반지름 192 ± 3px, 홍채 잉크 링 372~384px. 그래서 5종이 같은 계열로 읽힌다.',TXT,font=F(17))
dr.text((56,y+118),'공별로 새로 만든 것: 홍채 구조와 색, 동공 내부 장식, 외곽선 색, 하이라이트 색.',(200,210,225),font=F(17))
dr.text((56,y+146),'★ 장식 크기 기준은 44px이다. 22px 칸은 흐린 눈 테스트용이며 거기서 사라지는 것은 허용한다.',ACC,font=F(17,True))

# 2. 5종
y=310; panel(30,y,1580,330)
dr.text((56,y+16),'2.  5종',ACC,font=F(22,True))
rows=[('Clockwork','정속 태엽눈','앰버·황동','눈금 8개 / 십자 나사'),
      ('Rubber','고무막 유리눈','탠저린','팽창 링 / 고무 링'),
      ('Gel','완충 젤 유리눈','피스타치오','백탁 젤 / 젤 캡슐'),
      ('Lead','납심 유리눈','스모크·금','두꺼운 림 / 수직 추'),
      ('HollowBell','속빈 방울눈','라벤더·금','속 빈 유리 / 방울·별')]
b=Image.open(BASE).convert('RGBA')
chip(b,56,y+68,140,44); dr.text((56,y+214),'기본 공 (기준)',(200,210,225),font=F(15,True))
dr.text((56,y+238),'청록 62%',DIM,font=F(14))
for i,(k,kr,col,dec) in enumerate(rows):
    im=Image.open(f'/tmp/var/out/Ball_{k}_Body.png').convert('RGBA')
    x=250+i*272
    chip(im,x,y+58,160,160)
    chip(im,x+168,y+58,76,44); chip(im,x+168,y+142,76,22)
    dr.text((x+168,y+220),'44 / 22px',DIM,font=F(13))
    dr.text((x,y+228),kr,TXT,font=F(18,True))
    dr.text((x,y+256),col,(200,210,225),font=F(15))
    dr.text((x,y+280),dec,DIM,font=F(14))

# 3. 검수 대조
y=658; panel(30,y,1580,700)
dr.text((56,y+16),'3.  문서 12-7 최종 검수 체크리스트 대조',ACC,font=F(22,True))
sec=[('공 종류 구분',[
    ('기본 청록 공과 보상 공 5종이 즉시 구분되는가','PASS','기본 공 청록 62% vs 보상 공 주색은 전부 청록 외 계열',OK),
    ('다섯 공이 색상만 다른 동일 스킨처럼 보이지 않는가','PASS','홍채 구조·동공 장식이 전부 다름. 22px 상호 색차 평균 20.1',OK),
    ('모든 공에 청록색과 아이보리색이 일부 남아 있는가','PASS','청록 5.3~8.4% (권장 5~10%) · 아이보리 31~38%',OK),
    ('공별 재질과 내부 구조가 구분되는가','PASS','태엽 눈금 / 고무 링 / 젤 기포 / 금빛 추 / 방울·별',OK),
    ('하드코어 공이 특별하고 소장 가치 있게 보이는가','조건부','납심 금빛 추는 44px에서 확실. 속빈 방울 별·방울은 더 키워야 함',MID)]),
  ('실루엣과 재질',[
    ('모든 공이 완전한 원형으로 읽히는가','PASS','외곽 경계 511.45 ± 0.114px — 확정본 껍질 그대로',OK),
    ('사실적 안구보다 장난감 유리눈으로 보이는가','PASS','평탄 셀 · 반사면 · 하이라이트 1+1 공통 유지',OK),
    ('동공의 기본 형태가 유지되는가','PASS','전 종 원형, 반지름 192px 동일',OK),
    ('추가 재질을 사용해도 유리공으로 인식되는가','PASS','유리 껍질이 5종 공통이라 재질만 얹힌 형태',OK),
    ('작은 크기에서도 핵심 장식이 남는가','조건부','44px 기준으로는 전 종 남음. 22px에서는 젤 기포·방울/별 소실',MID)]),
  ('가독성',[
    ('먹빛 청회색 보드 위에서 공이 가장 먼저 보이는가','PASS','아이보리 외곽 31~38% 유지',OK),
    ('플리퍼 눈 장식과 플레이어 공이 혼동되지 않는가','PASS','혼동도 29.3~31.6 — 기본 공 25.1보다 전부 높음',OK),
    ('44px에서 홍채·동공·하이라이트가 구분되는가','조건부','완충 젤 명도차 14.2로 가장 낮음 (다른 공 23.9~49.2)',MID),
    ('최고 속도에서도 위치와 진행 방향이 보이는가','미착수','이동 꼬리 VFX 담당 — 아직 제작 전',DIM),
    ('글로우가 실제 충돌 크기를 오해하게 하지 않는가','미착수','발광 테두리 프리셋 5종 제작 전',DIM)]),
  ('VFX · SFX',[
    ('발광 테두리 / 이동 꼬리 / 패링 파동 프리셋 5종','미착수','12-1 MUST. 본체 확정 후 착수',DIM),
    ('공별 SFX 재질음 3종 + 패링 악센트 1종','미착수','12-1 MUST',DIM)])]
yy2=y+56
for title,items in sec:
    dr.text((56,yy2),title,(200,210,225),font=F(18,True)); yy2+=30
    for t,v,note,c in items:
        dr.text((76,yy2),'•',DIM,font=F(15))
        dr.text((96,yy2),t,TXT,font=F(15))
        dr.text((700,yy2),v,c,font=F(15,True))
        dr.text((790,yy2),note,c if c!=OK else (190,200,215),font=F(14))
        yy2+=26
    yy2+=8

# 4. 수치
y=1376; panel(30,y,1580,300)
dr.text((56,y+16),'4.  수치 근거',ACC,font=F(22,True))
hdr=[(76,'공'),(300,'청록 면적'),(460,'아이보리'),(620,'동공-홍채 명도차'),(840,'축 눈 혼동도'),(1030,'22px 최근접 공'),(1330,'색차')]
for x,t in hdr: dr.text((x,y+58),t,DIM,font=F(15))
data=[('정속 태엽눈','6.3%','37.7%','49.2','31.5','고무막','12.2',MID),
      ('고무막 유리눈','8.4%','31.4%','30.9','31.6','정속 태엽눈','12.2',MID),
      ('완충 젤 유리눈','7.8%','33.7%','14.2','29.3','속빈 방울','18.4',WARN),
      ('납심 유리눈','5.3%','31.4%','23.9','30.9','속빈 방울','16.5',OK),
      ('속빈 방울눈','7.3%','31.4%','39.8','31.2','납심','16.5',OK),
      ('(기준) 기본 공','62.3%','13.9%','—','25.1','—','—',DIM)]
for i,(n,a,bv,c,d2,e,f2,col) in enumerate(data):
    yy3=y+92+i*32
    for x,t in zip([76,300,460,620,840,1030,1330],[n,a,bv,c,d2,e,f2]):
        dr.text((x,yy3),t,col,font=F(15))
dr.text((76,y+272),'혼동도·색차 = 22px로 뭉갠 뒤 Lab 색차 평균. 클수록 덜 헷갈린다. 명도차 = 44px에서 홍채 L* − 동공 L*.',DIM,font=F(14))

# 5. 미해결
y=1694; panel(30,y,1580,240)
dr.text((56,y+16),'5.  아직 걸리는 것 — PL 판단 필요',WARN,font=F(22,True))
issues=[('완충 젤의 동공/홍채 명도차 14.2','44px에서 동공이 젤에 묻힌다. 젤을 더 밝게 하거나 동공을 더 어둡게 해야 한다.'),
        ('정속 태엽눈 ↔ 고무막 22px 색차 12.2','둘 다 따뜻한 주황 계열이라 흐린 눈으로 보면 붙는다. 눈금을 어둡게 바꾸면 갈릴 수 있다.'),
        ('고무막의 동심원이 과녁처럼 보인다','팽창 링 2겹 + 고무 링 + 청록 링이 겹쳐 표적판이 됐다. 링 수를 줄여야 한다.')]
for i,(t,n) in enumerate(issues):
    dr.text((76,y+62+i*56),f'{i+1}.  {t}',WARN,font=F(17,True))
    dr.text((100,y+86+i*56),n,(200,210,225),font=F(15))

# 6. 산출물
y=1952; panel(30,y,1580,340)
dr.text((56,y+16),'6.  산출물과 다음 단계',ACC,font=F(22,True))
dr.text((56,y+58),'제작 완료 (문서 12-1 MUST 중 2개)',(200,210,225),font=F(17,True))
files=['Ball_Clockwork_Body.png / _Pupil.png','Ball_Rubber_Body.png / _Pupil.png','Ball_Gel_Body.png / _Pupil.png',
       'Ball_Lead_Body.png / _Pupil.png','Ball_HollowBell_Body.png / _Pupil.png']
for i,f2 in enumerate(files): dr.text((80,y+90+i*24),'• '+f2,(190,200,215),font=F(15))
dr.text((700,y+58),'남은 MUST',(200,210,225),font=F(17,True))
todo=['발광 테두리 프리셋 5종','이동 꼬리 프리셋 5종','정확한 패링 프리셋 5종','공별 SFX (재질음 3종 + 패링 악센트 1종)']
for i,t in enumerate(todo): dr.text((724,y+90+i*24),'• '+t,(190,200,215),font=F(15))
dr.text((700,y+196),'선행 확인 필요',(200,210,225),font=F(17,True))
pre=['기존 변종 6종(dead/rubber/super, heavy/light/normal)과의 매핑','정속 태엽눈이 새 씬인지, super_ball·normal_ball의 처리',
     'BallVisual 노드 구조 변경 (12-3) — 현재는 Sprite2D 하나']
for i,t in enumerate(pre): dr.text((724,y+228+i*24),'• '+t,ACC,font=F(15))
dr.text((56,y+300),'질감 단계: 확정 후 홍채 디스크만 Leonardo로 손그림 잉크 질감을 입힌다. 껍질·동공·합성·마스킹은 절차적으로 처리한다.',DIM,font=F(15))
sh.save('/tmp/var/PL_variants_proposal.png'); print('ok')
