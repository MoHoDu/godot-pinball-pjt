from PIL import Image, ImageDraw, ImageFont
import numpy as np, math
ROOT='/sessions/great-nifty-brahmagupta/mnt/godot-pinball-pjt'
BOARD=f'{ROOT}/Resources/Art/board/octagonal_dark_wood_board.png'
KR='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'; KRB='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def F(s,b=False): return ImageFont.truetype(KRB if b else KR,s,index=1)
KEYS=[('Clockwork','정속 태엽눈','직선 스파크 8개 — 규칙적'),('Rubber','고무막 유리눈','둥근 튀김 — 탄력'),
      ('Gel','완충 젤 유리눈','뭉툭한 번짐 — 완충'),('Lead','납심 유리눈','날카로운 4방향 — 정밀'),
      ('HollowBell','속빈 방울눈','고리 파편 — 혼돈')]
BGC=(28,33,46);PANEL=(38,45,60);TXT=(233,226,212);DIM=(148,158,174);ACC=(255,196,110)
W,H=1700,1540
sh=Image.new('RGB',(W,H),BGC); dr=ImageDraw.Draw(sh)
def panel(x,y,w,h): dr.rounded_rectangle([x,y,x+w,y+h],radius=10,fill=PANEL)
dr.text((40,26),'보상 공 5종 — 상태·연출 아트',TXT,font=F(31,True))
dr.text((40,72),'문서 12-2 SHOULD: 고속 이동 VFX · 공별 콤보 단계 · 저주 상태 공통 오버레이. 여기에 공별 충돌 입자(3-4)를 더했다.',DIM,font=F(16))
board=Image.open(BOARD).convert('RGB')
y0=110; rh=250
for i,(k,kr,hitnote) in enumerate(KEYS):
    y=y0+i*rh; panel(30,y,1640,rh-16)
    dr.text((54,y+14),kr,TXT,font=F(21,True))
    dr.text((54,y+46),f'TrailFast_{k}.png / HitSpark_{k}.png / ComboStar_{k}.png',DIM,font=F(13))
    b=Image.open(f'/tmp/var/out/Ball_{k}_Body.png').convert('RGBA').resize((110,110),Image.LANCZOS)
    bb=Image.new('RGB',(110,110),(46,58,71)); bb.paste(b,(0,0),b); sh.paste(bb,(54,y+74))
    dr.text((54,y+190),'본체',DIM,font=F(13))
    # 일반 vs 고속 꼬리 (보드 위 실크기)
    for j,(fn,lab) in enumerate([(f'Trail_{k}.png','일반 이동'),(f'TrailFast_{k}.png','고속 이동')]):
        tr=Image.open(f'/tmp/var/vfx/{fn}.'.replace('.png..','.png')) if False else Image.open(f'/tmp/var/vfx/{fn}')
        tr=tr.convert('RGBA')
        tile=board.crop((300,320,1180,420)).resize((640,56))
        wpx=520 if j==0 else 600
        trs=tr.resize((wpx,48),Image.LANCZOS).transpose(Image.FLIP_LEFT_RIGHT)
        tile.paste(trs,(640-wpx-40,4),trs)
        b44=Image.open(f'/tmp/var/out/Ball_{k}_Body.png').convert('RGBA').resize((44,44),Image.LANCZOS)
        tile.paste(b44,(640-46,28-22),b44)
        sh.paste(tile,(184,y+70+j*74)); dr.text((184,y+128+j*74),lab,(200,210,225),font=F(13))
    dr.text((184,y+218),'꼬리 512×128 / 고속 768×128 — 보드 위 실크기',DIM,font=F(13))
    # 충돌 스파크
    hs=Image.open(f'/tmp/var/vfx/HitSpark_{k}.png').convert('RGBA')
    tile2=board.crop((400,340,700,480)).resize((150,150))
    z=hs.resize((110,110),Image.LANCZOS); tile2.paste(z,(20,20),z)
    b44=Image.open(f'/tmp/var/out/Ball_{k}_Body.png').convert('RGBA').resize((44,44),Image.LANCZOS)
    tile2.paste(b44,(53,53),b44)
    sh.paste(tile2,(848,y+74)); dr.text((848,y+232),'충돌 스파크 192²',DIM,font=F(13))
    dr.text((848,y+206),hitnote,(200,210,225),font=F(14))
    z2=hs.resize((130,130),Image.LANCZOS); zb=Image.new('RGB',(130,130),(46,58,71)); zb.paste(z2,(0,0),z2)
    sh.paste(zb,(1012,y+82))
    # 콤보 별
    cs=Image.open(f'/tmp/var/vfx/ComboStar_{k}.png').convert('RGBA')
    tile3=board.crop((500,340,760,480)).resize((150,150))
    z3=cs.resize((120,120),Image.LANCZOS); tile3.paste(z3,(15,15),z3)
    tile3.paste(b44,(53,53),b44)
    sh.paste(tile3,(1176,y+74)); dr.text((1176,y+232),'최고 콤보 잔상 128²',DIM,font=F(13))
    # 상태 오버레이
    for j,(fn,lab,col) in enumerate([('Overlay_Curse.png','저주',(176,214,92)),('Overlay_Danger.png','피격',(255,150,170))]):
        ov=Image.open(f'/tmp/var/vfx/{fn}').convert('RGBA')
        base=Image.open(f'/tmp/var/out/Ball_{k}_Body.png').convert('RGBA').resize((120,120),Image.LANCZOS)
        cm=Image.new('RGBA',(120,120),(0,0,0,0)); cm.alpha_composite(base); cm.alpha_composite(ov.resize((120,120),Image.LANCZOS))
        bg=Image.new('RGB',(120,120),(46,58,71)); bg.paste(cm,(0,0),cm)
        sh.paste(bg,(1348+j*140,y+74)); dr.text((1348+j*140,y+200),lab+' 오버레이',col,font=F(13))
dr.text((40,y0+5*rh-6),'상태 오버레이는 공통 1024² 2종이다. 중심을 비워 동공 가독성을 지키고, 프로토타입 금지 항목인 균열 대신 작은 점 6개를 쓴다.',DIM,font=F(15))
sh.save('/tmp/var/vfx2_sheet.png'); print('ok')
