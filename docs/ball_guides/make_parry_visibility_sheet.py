"""가시성 3단계 비교 — 인게임 1:1, 실제 보드 배경 위.

2026-08-04 형락님 인게임 피드백: "가시성이 너무 없어 잘 안 보인다.
유지 시간을 길게 하거나 이펙트의 가시성을 높혀달라."

★ vfx02 교훈: 수치가 통과해도 인게임에서 나쁠 수 있다. 확대 없이 1:1 로 봐야 한다.
★ vfx02 교훈: 두께는 1.5배 단위로 올린다. 3배는 시도했다가 롤백했다.

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
from parry_shader_check import read_tres, uniforms_at, render, TRES, BALL_RADIUS
from parry_wave import ball_layer

FONT="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
BOLD="/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
KR=2
BG=(18,22,30); FG=(226,232,240); DIM=(140,152,170); AC=(111,227,200); GD=(255,199,31)
def f(s,b=False): return ImageFont.truetype(BOLD if b else FONT,s,index=KR)

BASE = read_tres(TRES)

# 세 단계. 기준(현재) 대비 바꾸는 항목만 적는다.
LEVELS = [
    # ★ BASE 는 이미 채택본이다. "개정 전"은 여기에 옛 값을 명시해 둔다.
    ("개정 전 (0.16s / 링 6→3.9px)", dict(
        duration=0.16, flash_time=0.045, end_radius_ratio=4.773,
        ring_width_ratio=0.273, ring_width_shrink=0.35,
        fade_start=0.45, expand_exp=2.0,
        gap_count=3, gap_width=0.16, band_count=6,
        spoke_count=12, spoke_width_deg=1.1,
        spark_length_ratio=0.364, spark_width_ratio=0.100,
        quad_padding=1.06,
    ), DIM),
    ("안 1 — 가이드 범위 안에서 최대", dict(
        duration=0.20, flash_time=0.06, end_radius_ratio=4.318,
        ring_width_ratio=0.364, ring_width_shrink=0.15,
        fade_start=0.62, expand_exp=1.7,
        gap_count=2, gap_width=0.12, band_count=5,
        spoke_count=10, spoke_width_deg=1.8,
        spark_length_ratio=0.455, spark_width_ratio=0.145,
    ), AC),
    ("안 2 — 채택본 ✔ (가이드 상한 초과)", {}, GD),
]

CELL=300; PAD=40; LBL=430


def board_bg(size: int) -> Image.Image:
    """실제 보드 텍스처의 한 조각. 인게임에서 파동이 얹히는 바탕 그대로."""
    src = Image.open(REPO/"Resources"/"Art"/"board"/"octagonal_dark_wood_board.png").convert("RGB")
    w, h = src.size
    box = (w//2 - size//2, h//2 - size//2, w//2 + size - size//2, h//2 + size - size//2)
    return src.crop(box).convert("RGBA")


def visible_frames(r: dict, threshold: float = 0.8, fps: float = 60.0) -> float:
    """fade 가 threshold 이상인 구간이 60fps 로 몇 프레임인지."""
    span = max(1.0 - r["fade_start"], 0.001)
    x = (1.0 - threshold) ** (1.0 / r["fade_exp"])
    t = min(r["fade_start"] + span * x, 1.0)
    return t * r["duration"] * fps


def measure(r: dict) -> dict:
    peak_t = min(r["fade_start"], 0.99)
    u = uniforms_at(r, peak_t)
    n = int(round(u["quad_radius_px"] * 2))
    a = np.array(render(u, n))[..., 3] / 255.0
    return dict(
        frames=visible_frames(r),
        area=float(a.sum()) / (np.pi * BALL_RADIUS ** 2),
        end_px=r["end_radius_ratio"] * BALL_RADIUS,
        w0=r["ring_width_ratio"] * BALL_RADIUS,
        w1=r["ring_width_ratio"] * (1 - r["ring_width_shrink"]) * BALL_RADIUS,
        dur=r["duration"],
    )


def build():
    secs_of = lambda r: [0.0, r["duration"]*0.18, r["duration"]*0.36,
                         r["duration"]*0.58, r["duration"]*0.80, r["duration"]*0.97]
    w = LBL + CELL*6
    h = 150 + 60 + CELL*len(LEVELS) + 250
    im = Image.new("RGBA",(w,h),BG+(255,)); d = ImageDraw.Draw(im)
    d.text((PAD,32),"VFX ③ 패링 파동 — 가시성 3단계 (인게임 1:1, 실제 보드 위)",font=f(38,True),fill=FG)
    d.text((PAD,86),"확대 없음. 공 44px. 배경은 실제 보드 텍스처다. "
           "각 줄은 자기 지속 시간을 6등분한 시점이라 서로 다른 초를 본다.",font=f(20),fill=DIM)
    d.line([PAD,140,w-PAD,140],fill=(46,56,72),width=2)
    for i,lab in enumerate(["시작","18%","36%","58%","80%","97%"]):
        d.text((LBL+i*CELL+CELL//2,172),lab,font=f(22,True),fill=FG,anchor="mm")

    stats=[]
    bg = board_bg(CELL)
    for j,(label,over,col) in enumerate(LEVELS):
        r = dict(BASE); r.update(over)
        stats.append((label,col,measure(r)))
        y = 200 + j*CELL
        for li,line in enumerate(_wrap(label,20)):
            d.text((PAD,y+34+li*32),line,font=f(24,True),fill=col)
        m = stats[-1][2]
        d.text((PAD,y+34+32*len(_wrap(label,20))+10),
               "지속 %.2fs · 링 %.1f→%.1fpx · 종료 r%.0fpx" % (m["dur"],m["w0"],m["w1"],m["end_px"]),
               font=f(18),fill=DIM)
        d.text((PAD,y+34+32*len(_wrap(label,20))+38),
               "잘 보이는 구간 %.1f프레임 (60fps)" % m["frames"],font=f(18),fill=col)

        for i,sec in enumerate(secs_of(r)):
            t=min(sec/r["duration"],1.0); x=LBL+i*CELL
            cell = bg.copy()
            cell.alpha_composite(ball_layer(CELL,1.0))
            u=uniforms_at(r,t); n=int(round(u["quad_radius_px"]*2))
            img=render(u,n)
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
        ("지속 시간","0.16s","0.20s (가이드 상한)","0.26s (상한 초과)"),
        ("잘 보이는 프레임","%.1f"%stats[0][2]["frames"],"%.1f"%stats[1][2]["frames"],"%.1f"%stats[2][2]["frames"]),
        ("링 두께 시작→끝","6.0→3.9px","8.0→6.8px","9.0→7.9px"),
        ("종료 반지름","105px","95px","95px"),
        ("소멸 시작","진행 45%","진행 62%","진행 70%"),
        ("링 끊김","3군데","2군데","1군데"),
        ("방사선","12개 1.1°","10개 1.8°","10개 2.6°"),
        ("파동 면적 / 공","%.1f배"%stats[0][2]["area"],"%.1f배"%stats[1][2]["area"],"%.1f배"%stats[2][2]["area"]),
    ]
    cols=[PAD,PAD+380,PAD+700,PAD+1060]
    for c,head,col in zip(cols,["항목","개정 전","안 1","안 2 ✔ 채택"],[FG,DIM,AC,GD]):
        d.text((c,y+44),head,font=f(21,True),fill=col)
    for k,row in enumerate(rows):
        yy=y+82+k*34
        for c,val,col in zip(cols,row,[FG,DIM,AC,GD]):
            d.text((c,yy),val,font=f(20),fill=col)

    d.text((PAD+1400,y+44),"핵심",font=f(22,True),fill=FG)
    for k,t in enumerate([
        "종료 반지름을 105 → 95px 로 **줄였다**.",
        "같은 잉크를 좁은 둘레에 모아야 선이 굵게 읽힌다.",
        "크게 만드는 것과 잘 보이는 것은 반대 방향이었다.",
        "",
        "이동 꼬리는 5.4배였다. 안 2도 그보다 작다.",
        "두께는 1.5배 단위로만 올렸다 (6 → 9px).",
    ]):
        d.text((PAD+1408,y+84+k*30),t,font=f(19),fill=DIM)
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
    for label,_,m in stats:
        print(f"  {label}: {m['frames']:.1f}프레임, 면적 {m['area']:.1f}배, "
              f"링 {m['w0']:.1f}->{m['w1']:.1f}px, 종료 r{m['end_px']:.0f}px")
