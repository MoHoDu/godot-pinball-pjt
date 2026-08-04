"""VFX 3 패링 원형 파동 - 1 형태 단계 검수 시트 생성.

시트 생성 코드는 반드시 __main__ 아래에 둔다 (vfx02 교훈).
모듈 수준에 두면 import 하는 것만으로 전체가 다시 그려진다.
"""

from __future__ import annotations

import numpy as np
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from parry_wave import (  # noqa: I001
    BALL_PNG, REPO,
    AURA_R, AURA_REACH, BALL_R, CANDIDATES, CENTER_SHIFT, DURATION,
    FLASH_TIME, GOLD, IVORY, RING_W, R_END, R_START, TEAL, TEAL_DEEP,
    ball_layer, ease_out, wave_rgba,
)

FONT_PATH = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
FONT_BOLD = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
KR_INDEX = 2  # ttc 안에서 KR 페이스

BG = (18, 22, 30)
FG = (226, 232, 240)
DIM = (140, 152, 170)
ACCENT = (111, 227, 200)
GOLD_UI = (255, 199, 31)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_PATH, size, index=KR_INDEX)


def rgb255(c):
    return tuple(int(round(v * 255)) for v in c)


# 시간축 -- 실제 초 단위. DURATION 0.16s 기준
FRAMES = [0.0, 0.02, 0.04, 0.07, 0.11, 0.16]

CELL = 330
SCALE = 1.15
PAD = 40
LABEL_W = 300


def panel_candidates() -> Image.Image:
    w = LABEL_W + CELL * len(FRAMES)
    h = 70 + CELL * len(CANDIDATES)
    im = Image.new("RGBA", (w, h), BG + (255,))
    d = ImageDraw.Draw(im)

    for i, sec in enumerate(FRAMES):
        x = LABEL_W + i * CELL
        d.text((x + CELL // 2, 26), f"{sec:.2f}s", font=font(24, True),
               fill=FG, anchor="mm")
        sub = ""
        if sec <= FLASH_TIME:
            sub = "중심 플래시 구간"
        elif sec >= DURATION:
            sub = "소멸"
        if sub:
            d.text((x + CELL // 2, 52), sub, font=font(17), fill=DIM, anchor="mm")

    for j, key in enumerate(["A", "B", "C"]):
        cfg = CANDIDATES[key]
        y = 70 + j * CELL
        d.text((PAD, y + 40), cfg["name"], font=font(27, True), fill=ACCENT)
        for li, line in enumerate(_wrap(cfg["note"], 17)):
            d.text((PAD, y + 82 + li * 30), line, font=font(19), fill=DIM)

        for i, sec in enumerate(FRAMES):
            t = min(sec / DURATION, 1.0)
            x = LABEL_W + i * CELL
            cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            cell.alpha_composite(ball_layer(CELL, SCALE))
            if sec < DURATION * 1.001:
                cell.alpha_composite(wave_rgba(CELL, SCALE, cfg, t))
            im.alpha_composite(cell, (x, y))
            d.rectangle([x, y, x + CELL - 1, y + CELL - 1], outline=(38, 46, 60))

    return im


def panel_ingame() -> Image.Image:
    """1:1 실제 게임 픽셀. vfx02 교훈 -- 화면 점유는 비율이 아니라 절대 크기가 지배한다."""
    w = LABEL_W + CELL * len(FRAMES)
    h = 500
    im = Image.new("RGBA", (w, h), BG + (255,))
    d = ImageDraw.Draw(im)

    d.text((PAD, 26), "1:1 실제 게임 픽셀 (공 44px)", font=font(27, True), fill=FG)
    d.text((PAD, 62), "확대 없음. 인게임에서 보이는 크기 그대로다. "
           "오른쪽 둘은 기존 ParryRing 텍스처를 같은 반지름으로 늘린 것이다.",
           font=font(19), fill=DIM)

    t_peak = 0.62
    r_peak = R_START + (R_END - R_START) * ease_out(t_peak)
    box = 300
    labels = [
        "공만 (44px)",
        "공 + 안개 오라",
        f"파동 0.10s (지름 {r_peak * 2:.0f}px)",
        "겹친 최종",
        f"기존 PNG를 r{R_START:.0f}로",
        f"기존 PNG를 r{r_peak:.0f}로",
    ]
    tex = Image.open(
        REPO / "Resources" / "Art" / "vfx" / "balls" / "ParryRing_Clockwork.png"
    ).convert("RGBA")

    for i, lab in enumerate(labels):
        x = PAD + i * (box + 24)
        y = 100
        cell = Image.new("RGBA", (box, box), (0, 0, 0, 0))
        if i == 0:
            ball = Image.open(BALL_PNG).convert("RGBA").resize(
                (44, 44), Image.LANCZOS)
            cell.alpha_composite(ball, ((box - 44) // 2, (box - 44) // 2))
        elif i == 1:
            cell.alpha_composite(ball_layer(box, 1.0))
        elif i == 2:
            cell.alpha_composite(wave_rgba(box, 1.0, CANDIDATES["C"], t_peak))
        elif i == 3:
            cell.alpha_composite(ball_layer(box, 1.0))
            cell.alpha_composite(wave_rgba(box, 1.0, CANDIDATES["C"], t_peak))
        else:
            r = R_START if i == 4 else r_peak
            side = int(round(r * 2))
            side = min(side, box)
            sc = tex.resize((side, side), Image.LANCZOS)
            cell.alpha_composite(ball_layer(box, 1.0))
            cell.alpha_composite(sc, ((box - side) // 2, (box - side) // 2))
        im.alpha_composite(cell, (x, y))
        d.rectangle([x, y, x + box - 1, y + box - 1], outline=(38, 46, 60))
        d.text((x + box // 2, y + box + 26), lab, font=font(20), fill=DIM, anchor="mm")

    d.text((PAD + 4 * (box + 24), 100 + box + 56),
           "→ 한 장짜리 정지 프레임이라 링 두께가 크기를 따라 같이 커진다. "
           "중심 플래시도 계속 켜져 있다.",
           font=font(19), fill=GOLD_UI)
    return im


def panel_timeline() -> Image.Image:
    """반경-시간 도식. 안개에 묻히는 구간이 얼마나 되는지 눈으로 본다."""
    w = LABEL_W + CELL * len(FRAMES)
    h = 400
    im = Image.new("RGBA", (w, h), BG + (255,))
    d = ImageDraw.Draw(im)

    d.text((PAD, 26), "반경 · 시간 도식", font=font(27, True), fill=FG)
    d.text((PAD, 62), "파동이 안개 오라 밖으로 나오기까지 걸리는 시간을 본다.",
           font=font(19), fill=DIM)

    x0, y0 = PAD + 90, 120
    x1, y1 = w - PAD - 520, h - 70
    r_max = 130.0

    def px(sec):
        return x0 + (x1 - x0) * (sec / DURATION)

    def py(r):
        return y1 - (y1 - y0) * (r / r_max)

    # 축
    d.line([x0, y0, x0, y1], fill=(60, 70, 88), width=2)
    d.line([x0, y1, x1, y1], fill=(60, 70, 88), width=2)
    for r in (0, 22, 36, 60, 90, 105, 120):
        d.line([x0 - 8, py(r), x1, py(r)], fill=(32, 40, 52), width=1)
        d.text((x0 - 16, py(r)), f"{r}", font=font(17), fill=DIM, anchor="rm")
    for sec in (0.0, 0.04, 0.08, 0.12, 0.16):
        d.text((px(sec), y1 + 20), f"{sec:.2f}s", font=font(17), fill=DIM, anchor="mm")

    # 공 / 안개 영역
    d.rectangle([x0, py(BALL_R), x1, y1], fill=(30, 48, 46))
    d.rectangle([x0, py(AURA_REACH), x1, py(BALL_R)], fill=(24, 40, 40))
    d.text((x1 - 10, py(BALL_R) + 4), "공 본체 22px", font=font(17),
           fill=(120, 160, 150), anchor="rt")
    d.text((x1 - 10, py(AURA_REACH) + 4), "안개 오라 도달 36px", font=font(17),
           fill=(120, 160, 150), anchor="rt")
    d.line([x0, py(AURA_R), x1, py(AURA_R)], fill=(70, 100, 96), width=1)
    d.text((x1 - 10, py(AURA_R) - 20), "안개 명목 40px", font=font(16),
           fill=(90, 130, 124), anchor="rt")

    # 플래시 구간
    d.rectangle([x0, y0, px(FLASH_TIME), y1], fill=(44, 40, 28))
    d.text((px(FLASH_TIME) - 8, y0 + 8), "중심 플래시 0.045s", font=font(17),
           fill=GOLD_UI, anchor="rt")

    # 주 링 / 보조 링 곡선
    pts_main, pts_sub = [], []
    for k in range(121):
        t = k / 120.0
        sec = t * DURATION
        pts_main.append((px(sec), py(R_START + (R_END - R_START) * ease_out(t))))
        ts = max(t - 0.18, 0.0) / 0.82
        pts_sub.append((px(sec), py(R_START + (R_END - R_START) * ease_out(ts))))
    d.line(pts_sub, fill=GOLD_UI, width=4, joint="curve")
    d.line(pts_main, fill=ACCENT, width=5, joint="curve")

    # 안개 밖으로 나오는 시점
    cross = 1.0 - np.sqrt(1.0 - (AURA_REACH - R_START) / (R_END - R_START))
    d.line([px(cross * DURATION), y0, px(cross * DURATION), y1],
           fill=(230, 120, 120), width=2)
    d.text((px(cross * DURATION) + 8, y0 + 8),
           f"안개 밖으로 = {cross * DURATION * 1000:.0f}ms", font=font(18),
           fill=(230, 140, 140))

    # 범례
    lx = x1 + 50
    d.text((lx, y0), "주요 링 (밝은 청록)", font=font(20, True), fill=ACCENT)
    d.text((lx, y0 + 32), f"{R_START:.0f}px → {R_END:.0f}px, 두께 {RING_W:.0f}→3.9px",
           font=font(18), fill=DIM)
    d.text((lx, y0 + 74), "보조 링 (금색)", font=font(20, True), fill=GOLD_UI)
    d.text((lx, y0 + 106), "18% 지연 추격. 성공 포인트", font=font(18), fill=DIM)
    d.text((lx, y0 + 148), "곡선은 ease-out 지수 2.0", font=font(18), fill=DIM)
    d.text((lx, y0 + 176), "빠르게 커지고 사라진다 (가이드 3-5)", font=font(18), fill=DIM)

    return im


def panel_numbers(stats: dict) -> Image.Image:
    w = LABEL_W + CELL * len(FRAMES)
    # 마지막 원소 True = 확인이 필요한 항목 (금색 강조)
    rows = [
        ("시작 반지름", f"{R_START:.0f}px", "권장 25~30", "범위 안", False),
        ("종료 반지름", f"{R_END:.0f}px", "권장 90~120", "범위 안", False),
        ("전체 지속", f"{DURATION:.2f}s", "권장 0.12~0.20", "범위 안", False),
        ("중심 플래시", f"{FLASH_TIME:.3f}s", "권장 0.03~0.06", "범위 안", False),
        ("주요 링 두께", f"{RING_W:.0f} → 3.9px", "권장 4~8",
         "★ 끝에서 하한 아래", True),
        ("중심 이동", f"{CENTER_SHIFT:.0f}px", "권장 2~5", "안 C만 적용", False),
        ("파동 지름 / 공 지름", f"{stats['diam_ratio']:.1f}배", "기준 없음",
         "상태 보고", False),
        ("파동 면적 / 공 면적", f"{stats['area_ratio']:.1f}배",
         "이동 꼬리는 5.4배였다", "상태 보고", False),
        ("보드 폭 2240 대비", f"{stats['board_pct']:.1f}%", "기준 없음",
         "상태 보고", False),
        ("최대 휘도 (파동)", f"{stats['wave_lum']:.3f}",
         f"공 본체 {stats['ball_lum']:.3f}",
         "통과 — 공보다 어둡다" if stats["wave_lum"] < stats["ball_lum"]
         else "★ 공보다 밝다", stats["wave_lum"] >= stats["ball_lum"]),
        ("안개 밖 노출까지", f"{stats['out_ms']:.0f}ms",
         f"전체의 {stats['out_pct']:.0f}%", "묻히는 구간 거의 없음", False),
    ]
    h = 100 + len(rows) * 40 + 40
    im = Image.new("RGBA", (w, h), BG + (255,))
    d = ImageDraw.Draw(im)
    d.text((PAD, 26), "확정 수치 · 실측", font=font(27, True), fill=FG)
    d.text((PAD, 62), "수치는 상태 보고다. 기준을 벗어났다고 결함이 아니다. ★ 만 판단이 필요하다.",
           font=font(19), fill=DIM)

    cols = [PAD, PAD + 430, PAD + 700, PAD + 1060]
    heads = ["항목", "이 시안", "가이드 권장", "판정"]
    for c, head in zip(cols, heads):
        d.text((c, 100), head, font=font(20, True), fill=(150, 165, 185))
    for i, row in enumerate(rows):
        y = 136 + i * 40
        flag = row[4]
        for c, val, f_ in zip(cols, row[:4],
                              [font(21), font(21, True), font(20), font(20)]):
            fill = GOLD_UI if (flag and c == cols[3]) else FG
            d.text((c, y), val, font=f_, fill=fill)
    return im


def measure() -> dict:
    """실측. 눈이 아니라 픽셀로 확인한다."""
    size, scale = 320, 1.0
    wave = np.array(wave_rgba(size, scale, CANDIDATES["C"], 0.62)).astype(np.float64) / 255.0
    wa = wave[..., 3]
    lum_w = (0.2126 * wave[..., 0] + 0.7152 * wave[..., 1] + 0.0722 * wave[..., 2])
    wave_lum = float(lum_w[wa > 0.5].max()) if (wa > 0.5).any() else 0.0

    ball = np.array(Image.open(BALL_PNG).convert("RGBA")).astype(np.float64) / 255.0
    ba = ball[..., 3]
    lum_b = 0.2126 * ball[..., 0] + 0.7152 * ball[..., 1] + 0.0722 * ball[..., 2]
    ball_lum = float(lum_b[ba > 0.5].max())

    # 파동이 실제로 덮는 면적 (알파 가중)
    wave_area = float(wa.sum())
    ball_area = np.pi * BALL_R ** 2
    r_out = R_END * 1.30  # 방사선 끝
    cross = 1.0 - np.sqrt(1.0 - (AURA_REACH - R_START) / (R_END - R_START))

    return dict(
        diam_ratio=(R_END * 2) / (BALL_R * 2),
        area_ratio=wave_area / ball_area,
        board_pct=100.0 * (R_END * 2) / 2240.0,
        wave_lum=wave_lum,
        ball_lum=ball_lum,
        lum_verdict="공보다 밝음" if wave_lum > ball_lum else "공보다 어두움",
        out_ms=cross * DURATION * 1000.0,
        out_pct=cross * 100.0,
        r_out=r_out,
    )


def _wrap(text: str, n: int):
    out, cur = [], ""
    for word in text.split(" "):
        if len(cur) + len(word) + 1 > n:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        out.append(cur)
    return out


def header(w: int) -> Image.Image:
    im = Image.new("RGBA", (w, 150), BG + (255,))
    d = ImageDraw.Draw(im)
    d.text((PAD, 32), "VFX ③ 패링 성공 원형 파동 — ① 형태 단계 목표 그림",
           font=font(40, True), fill=FG)
    d.text((PAD, 88),
           "비주얼 가이드 3-5 수치 그대로. 정확한 패링(PERFECT)에만 발생. "
           "공 44px 기준. 형태만 확정하고 구현은 승인 후.",
           font=font(21), fill=DIM)
    d.line([PAD, 140, w - PAD, 140], fill=(46, 56, 72), width=2)
    return im


if __name__ == "__main__":
    stats = measure()
    parts = [
        header(LABEL_W + CELL * len(FRAMES)),
        panel_candidates(),
        panel_ingame(),
        panel_timeline(),
        panel_numbers(stats),
    ]
    w = max(p.width for p in parts)
    h = sum(p.height for p in parts)
    sheet = Image.new("RGBA", (w, h), BG + (255,))
    y = 0
    for p in parts:
        sheet.alpha_composite(p, (0, y))
        y += p.height
    out = Path(__file__).with_name("vfx03_parry_shape.png")
    sheet.convert("RGB").save(out)
    print("sheet", sheet.size)
    for k, v in stats.items():
        print(f"  {k}: {v}")
