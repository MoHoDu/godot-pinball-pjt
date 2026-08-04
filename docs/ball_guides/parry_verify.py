"""패링 파동 수치 검수. ball_parry_wave.gd 하나만 읽는다.

엔진 없이 확인할 수 있는 전부다. 씬 트리·시그널·물리는 여기서 못 본다.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
from parry_shader_check import (
    BALL_RADIUS, extract_shader, extract_values, quad_radius_ratio,
    read_source, render, uniforms_at, visible_frames,
)

SRC = read_source()
SH = extract_shader(SRC)
V = extract_values(SRC)
DUR = V["DEFAULT_DURATION"]
QUAD = BALL_RADIUS * quad_radius_ratio(V)

fails = []
def ck(cond, msg):
    print(("  OK  " if cond else "  FAIL") + "  " + msg)
    if not cond:
        fails.append(msg)

def shot(t):
    u = uniforms_at(V, t)
    n = int(round(u["quad_radius_px"] * 2))
    return np.array(render(u, n, SH)), n

print("== 1. 쿼드 경계 잘림 ==")
worst = 0
for t in [0.0, 0.1, 0.25, 0.4, 0.6, 0.8, 0.99]:
    a, _ = shot(t); a = a[..., 3]
    worst = max(worst, int(max(a[0].max(), a[-1].max(), a[:, 0].max(), a[:, -1].max())))
ck(worst == 0, f"쿼드 네 변의 알파가 0이어야 한다 (최대 {worst})")

print("== 2. 원으로 읽히는가 ==")
img, n = shot(0.5); a = img[..., 3] / 255.0
c = (n - 1) / 2.0
Y, X = np.mgrid[0:n, 0:n]
R = np.hypot(X - c, Y - c); TH = np.arctan2(Y - c, X - c)
peaks = []
for k in range(72):
    lo, hi = k * np.pi / 36 - np.pi, (k + 1) * np.pi / 36 - np.pi
    m = (TH >= lo) & (TH < hi) & (a > 0.35)
    if m.any():
        peaks.append(R[m].max())
dev = float(np.std(peaks) / np.mean(peaks) * 100)
ck(dev < 12.0, f"각도별 외곽 반경 편차 {dev:.1f}% < 12% (원으로 읽혀야 한다)")

print("== 3. 도달 반경 ==")
r0 = uniforms_at(V, 0.0)["main_r"] * QUAD
r1 = uniforms_at(V, 1.0)["main_r"] * QUAD
ck(abs(r0 - V["DEFAULT_START_RADIUS_RATIO"] * BALL_RADIUS) < 0.5, f"시작 {r0:.2f}px")
ck(abs(r1 - V["DEFAULT_END_RADIUS_RATIO"] * BALL_RADIUS) < 0.5, f"종료 {r1:.2f}px")

print("== 4. 가독성 우선순위 ==")
b = np.array(Image.open(REPO / "Resources/Art/balls/glass_eye_ball.png").convert("RGBA")).astype(float) / 255
ba = b[..., 3]
bl = float((0.2126 * b[..., 0] + 0.7152 * b[..., 1] + 0.0722 * b[..., 2])[ba > 0.5].max())
wl = 0.0
for t in [0.0, 0.1, 0.3, 0.5, 0.7]:
    im, _ = shot(t); im = im.astype(float) / 255
    al = im[..., 3]
    L = 0.2126 * im[..., 0] + 0.7152 * im[..., 1] + 0.0722 * im[..., 2]
    if (al > 0.5).any():
        wl = max(wl, float(L[al > 0.5].max()))
ck(wl < bl, f"파동 최대 휘도 {wl:.3f} < 공 본체 {bl:.3f}")

print("== 5. 화면에 안 남는가 ==")
a, _ = shot(1.0)
ck(a[..., 3].max() == 0, f"t=1.0 에서 완전히 사라져야 한다 (최대 알파 {a[..., 3].max()})")

print("== 6. 가시성 ==")
vf = visible_frames(V)
ck(vf >= 10.0, f"60fps 에서 잘 보이는 구간 {vf:.1f}프레임 >= 10 (개정 전 5.9였다)")

print("== 7. 화면 점유 ==")
a, _ = shot(V["DEFAULT_FADE_START"])
area = float((a[..., 3] / 255.0).sum()) / (np.pi * BALL_RADIUS ** 2)
print(f"  정보  파동 면적 / 공 면적 = {area:.1f}배 (이동 꼬리는 5.4배였다)")
print(f"  정보  파동 지름 {r1 * 2:.0f}px = 보드 폭 2240 의 {r1 * 2 / 2240 * 100:.1f}%")

print()
print("FAIL 0 — 전부 통과" if not fails else f"FAIL {len(fails)}")
sys.exit(1 if fails else 0)
