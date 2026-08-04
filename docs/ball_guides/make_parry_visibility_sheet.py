"""가시성 개정 이력 비교 — 인게임 1:1, 실제 보드 배경 위.

★ vfx02 교훈: 수치가 통과해도 인게임에서 나쁠 수 있다. 확대 없이 1:1 로 봐야 한다.
시트 생성 코드는 반드시 __main__ 아래에 둔다.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
from parry_shader_check import (
    BALL_RADIUS, extract_shader, extract_values, quad_radius_ratio,
    read_source, render, uniforms_at, visible_frames,
)
from parry_wave import ball_layer

FONT="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
BOLD="/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
KR=2
BG=(18,22,30); FG=(226,232,240); DIM=(140,152,170); AC=(111,227,200); GD=(255,199,31)
def f(s,b=False): return ImageFont.truetype(BOLD if b else FONT,s,index=KR)

SRC = read_source()
SH = extract_shader(SRC)
BASE = extract_values(SRC)

# 개정 이력. 마지막이 현재 값(BASE)이다.
LEVELS = [
    ("최초 (0.16s / 링 6→3.9px)", dict(
        DEFAULT_DURATION=0.16, DEFAULT_FLASH_TIME=0.045,
        DEFAULT_END_RADIUS_RATIO=4.773, DEFAULT_RING_WIDTH_RATIO=0.273,
        DEFAULT_RING_WIDTH_SHRINK=0.35, DEFAULT_FADE_START=0.45,
        DEFAULT_FADE_EXP=1.3, DEFAULT_EXPAND_EXP=2.0,
        DEFAULT_GAP_COUNT=3.0, DEFAULT_GAP_WIDTH=0.16, DEFAULT_BAND_COUNT=6.0,
        DEFAULT_SPOKE_COUNT=12.0, DEFAULT_SPOKE_WIDTH_DEG=1.1,
        DEFAULT_SPARK_LENGTH_RATIO=0.364, SPARK_WIDTH_RATIO=0.100,
        QUAD_PADDING=1.06,
    ), DIM),
    ("1차 개정 (0.26s / 링 9→7.9px)", dict(
        DEFAULT_DURATION=0.26, DEFAULT_FLASH_TIME=0.06,
        DEFAULT_END_RADIUS_RATIO=4.318, DEFAULT_RING_WIDTH_RATIO=0.409,
        DEFAULT_RING_WIDTH_SHRINK=0.12, DEFAULT_FADE_START=0.70,
        DEFAULT_FADE_EXP=1.3, DEFAULT_EXPAND_EXP=1.5,
        DEFAULT_GAP_COUNT=1.0, DEFAULT_GAP_WIDTH=0.10, DEFAULT_BAND_COUNT=5.0,
        DEFAULT_SPOKE_COUNT=10.0, DEFAULT_SPOKE_WIDTH_DEG=2.6,
        DEFAULT_SPARK_LENGTH_RATIO=0.545,
    ), AC),
    ("2차 개정 — 현재 (0.42s / 링 12→10.8px)", {}, GD),
]

CELL=300; PAD=40; LBL=470


def board_bg(size: int) -> Image.Image:
    src = Image.open(REPO/"Resources"/"Art"/"board"/"octagonal_dark_wood_board.png").convert("RGB")
    w, h = src.size
    return src.crop((w//2 - size//2, h//2 - size//2,
                     w//2 + size - size//2, h//2 + size - size//2)).convert("RGBA")


def build():
    w = LBL + CELL*6
    h = 150 + 60 + CELL*len(LEVELS) + 240
    im = Image.new("RGBA",(w,h),BG+(255,)); d = ImageDraw.Draw(im)
    d.text((PAD,32),"VFX ③ 패링 파동 — 가시성 개정 이력 (인게임 1:1, 실제 보드 위)",
           font=f(36,True),fill=FG)
    d.text((PAD,86),"확대 없음. 공 44px. 각 줄은 자기 지속 시간을 6등분한 시점이라 서로 다른 초를 본다.",
           font=f(20),fill=DIM)
    d.line([PAD,140,w-PAD,140],fill=(46,56,72),width=2)
    for i,lab in enumerate(["시작","18%","36%","58%","80%","97%"]):
        d.text((LBL+i*CELL+CELL//2,172),lab,font=f(22,True),fill=FG,anchor="mm")

    bg = board_bg(CELL)
    stats=[]
    for j,(label,over,col) in enumerate(LEVELS):
        v = dict(BASE); v.update(over)
        vf = visible_frames(v)
        stats.append((label,col,v,vf))
        y = 200 + j*CELL
        for li,line in enumerate(_wrap(label,24)):
            d.text((PAD,y+34+li*32),line,font=f(23,True),fill=col)
        base_y = y+34+32*len(_wrap(label,24))+10
        d.text((PAD,base_y),
               "지속 %.2fs (%.0f프레임) · 종료 r%.0fpx" % (
                   v["DEFAULT_DURATION"], v["DEFAULT_DURATION"]*60,
                   v["DEFAULT_END_RADIUS_RATIO"]*BALL_RADIUS),
               font=f(18),fill=DIM)
        d.text((PAD,base_y+28),"잘 보이는 구간 %.1f프레임" % vf,font=f(19,True),fill=col)

        for i,frac in enumerate([0.0,0.18,0.36,0.58,0.80,0.97]):
            x=LBL+i*CELL
            cell = bg.copy()
            cell.alpha_composite(ball_layer(CELL,1.0))
            u=uniforms_at(v,frac); n=int(round(u["quad_radius_px"]*2))
            img=render(u,n,SH)
            ox,oy=(CELL-n)//2,(CELL-n)//2
            if n<=CELL:
                cell.alpha_composite(img,(ox,oy))
            else:
                cell.alpha_composite(img.crop((-ox,-oy,-ox+CELL,-oy+CELL)),(0,0))
            im.alpha_composite(cell,(x,y))
            d.rectangle([x,y,x+CELL-1,y+CELL-1],outline=(38,46,60))

    y = 200 + len(LEVELS)*CELL + 30
    d.text((PAD,y),"무엇을 바꿨나",font=f(26,True),fill=FG)
    rows=[
        ("지속 시간","0.16s","0.26s","0.42s"),
        ("잘 보이는 프레임","%.1f"%stats[0][3],"%.1f"%stats[1][3],"%.1f"%stats[2][3]),
        ("소멸 시작","진행 45%","진행 70%","진행 78%"),
        ("소멸 곡선 지수","1.3","1.3","2.2 (오래 유지하다 훅)"),
        ("링 두께 시작→끝","6.0→3.9px","9.0→7.9px","12.0→10.8px"),
        ("종료 반지름","105px","95px","90px"),
        ("방사선","12개 1.1°","10개 2.6°","10개 3.4°"),
    ]
    cols=[PAD,PAD+380,PAD+680,PAD+980]
    for c,head,col in zip(cols,["항목","최초","1차","2차 (현재)"],[FG,DIM,AC,GD]):
        d.text((c,y+44),head,font=f(21,True),fill=col)
    for k,row in enumerate(rows):
        yy=y+82+k*34
        for c,val,col in zip(cols,row,[FG,DIM,AC,GD]):
            d.text((c,yy),val,font=f(20),fill=col)

    d.text((PAD+1500,y+44),"바꿀 때 만지는 순서",font=f(22,True),fill=FG)
    for k,t in enumerate([
        "1. fade_start — 가장 크게 먹힌다",
        "2. fade_exp — 밝기를 오래 유지",
        "3. duration — 전체 길이",
        "4. end_radius_ratio — 줄일수록 굵어 보인다",
        "",
        "★ 0.42초 동안 공은 1200px/s 기준 약 500px",
        "   (보드 폭의 22%) 를 간다.",
        "   방해되면 duration 부터 내린다.",
    ]):
        d.text((PAD+1508,y+84+k*30),t,font=f(19),fill=DIM)
    return im, stats


def _wrap(text,n):
    out,cur=[],""
    for wd in text.split(" "):
        if len(cur)+len(wd)+1>n: out.append(cur); cur=wd
        else: cur=(cur+" "+wd).strip()
    if cur: out.append(cur)
    return out


if __name__ == "__main__":
    img, stats = build()
    out = HERE/"vfx03_parry_visibility.png"
    img.convert("RGB").save(out)
    print("saved", out)
    for label,_,v,vf in stats:
        print(f"  {label}: {vf:.1f}프레임 / 지속 {v['DEFAULT_DURATION']}s")
