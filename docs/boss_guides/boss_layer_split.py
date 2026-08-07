"""보스 확정 아트를 애니메이션용 레이어로 분리한다.

## 왜 필요한가

기획서 8-2 의 팔 충돌체는 **캡슐**이고 공격 회전 범위가 **80~90°** 다.
즉 팔은 코드가 어깨 피벗에서 **회전**시키는 것이지 프레임을 넘기는 것이 아니다.
한 장짜리 스프라이트로 두면 충돌체만 돌고 그림은 안 돌아서, 공이 보이지 않는
팔에 맞는다. 가이드 20절의 즉시 반려 기준 "팔 공격 방향을 VFX 만 보고 알 수 없음"
에 정면으로 걸린다.

하트형 저주핵도 마찬가지다. 페이즈 전환·암전에서 밝아져야 하는데 몸에 그려져
있으면 따로 못 만진다.

## 어떻게 가르는가

**잉크 외곽선을 칸막이로 쓴다.** 이 아트는 팔과 몸통 사이에 굵은 잉크선이
완전히 그어져 있어서, 어두운 픽셀을 빼고 연결 성분을 세면 팔이 어깨부터
손끝까지 통째로 떨어진다. 좌표로 오려내는 것보다 훨씬 정확하다.

얼굴과 몸통은 **중앙 봉제선** 때문에 좌우로 쪼개진다. 이건 다시 합친다.

## 구멍이 안 나는 이유

톱니바퀴의 작은 기어는 뒤의 큰 기어가 안 그려져 있어 오려내면 구멍이 났다.
여기는 다르다. 팔이 몸통 **옆에** 그려져 있어 겹치는 폭이 30px 안팎뿐이고,
몸통 성분 자체가 이미 닫힌 형태다.

경계 잉크선은 **양쪽 레이어에 모두** 넣는다. 한쪽에만 주면 다른 쪽 테두리가
사라져 팔을 돌렸을 때 잘린 단면이 보인다.

## 정규화하지 않는다

레이어별로 알파 bbox 를 맞추면 정렬이 깨진다. 전부 같은 캔버스에 같은 원점으로
남긴다. 북 머리/테, 톱니바퀴 이빨/링에서 같은 이유로 정규화를 뺐다.

실행:
    python docs/boss_guides/boss_layer_split.py

결과: docs/boss_guides/layers/
"""

from __future__ import annotations

import os
from collections import deque

import numpy as np
from PIL import Image

SRC = os.path.join(
    os.path.dirname(__file__), "candidates", "unmasked", "idle_r3_1.jpg"
)
OUT = os.path.join(os.path.dirname(__file__), "layers")

# 배경 플러드 필 허용 색거리. 배경이 단색이라 넉넉해도 안전하다.
BG_TOL = 42
# 잉크 판정 밝기. 전경 밝기 분위수를 실측해 정했다
# (잉크 0~2, 몸통 채움 ~40, 배꼽·패치 65~80).
INK_LUM = 22
# 이보다 작은 연결 성분은 무늬로 보고 가까운 레이어에 붙인다.
MIN_REGION = 4000
# --------------------------------------------------------------------------
# 인게임 크기 정합
# --------------------------------------------------------------------------
# 기획서 18절 비주얼 크기. 세로를 기준으로 맞춘다.
# 세로가 기준인 이유: "보스 충돌체와 하단 플리퍼 사이 최소 220px" 라는 레벨
# 규칙이 세로에 걸려 있다. 가로는 넓어져도 좌우 통로 규칙에만 영향을 준다.
GAME_W, GAME_H = 520, 620
# 저장 배율. 범퍼 아트도 표시 크기보다 큰 원본을 두고 씬에서 줄인다.
OUT_SCALE = 2

# 팔을 골라내는 씨앗 행. **몸통이 끝나고 팔만 남는 높이**여야 한다.
# 행별 런 개수를 실측해 정했다 (y 890 부터 팔이 갈리고 1040 부터 몸통이 없다).
SEED_ROW = 1100

# 눈구멍 판정. 얼굴에서 가장 어두운 큰 덩어리 두 개다.
# 실측 왼쪽 5,275px(117×124) / 오른쪽 6,617px(117×142), 잉크 외곽선은 26,949px.
FACE_BOTTOM = 520
EYE_LUM = 30
EYE_MIN_PX = 2500
EYE_MAX_PX = 12000

# 어깨 캡. 팔이 회전하면 잘린 단면이 드러나므로 둥글게 마감한다.
# 피벗은 팔 마스크 위쪽 띠의 중심을 실측한 값이다.
# 팔 귀속 후보의 크기 상한. 실측: 팔 패치 5.1k~5.7k, 하트 4.9k, 몸통 52k~86k.
PATCH_MAX_PX = 20000
# 왼 옆구리 물린 구간(원본 px). 팔이 몸통을 덮고 있던 유일한 곳을 실측했다.
BITE_Y0 = 500
BITE_Y1 = 700
# 복원 곡선을 바깥으로 볼록하게 미는 양(px). 배 옆구리의 원래 흐름을 따른다.
BITE_BULGE = 10.0
SHOULDER_LEFT = (258.0, 417.0)
SHOULDER_RIGHT = (591.0, 406.0)
INK_WIDTH = 7.0
INK_RGB = np.array([16, 20, 27])


def load() -> tuple[np.ndarray, np.ndarray]:
    img = Image.open(SRC).convert("RGB")
    rgb = np.asarray(img).astype(int)
    h, w, _ = rgb.shape

    # 테두리에서 배경색을 번지게 한다. 안쪽의 같은 색은 살아남는다.
    bg = rgb[8, 8].copy()
    seen = np.zeros((h, w), bool)
    q: deque = deque()

    def push(y: int, x: int) -> None:
        if not seen[y, x]:
            seen[y, x] = True
            q.append((y, x))

    for x in range(w):
        push(0, x)
        push(h - 1, x)
    for y in range(h):
        push(y, 0)
        push(y, w - 1)
    while q:
        y, x = q.popleft()
        if np.sqrt(((rgb[y, x] - bg) ** 2).sum()) > BG_TOL:
            continue
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx]:
                if np.sqrt(((rgb[ny, nx] - bg) ** 2).sum()) <= BG_TOL:
                    seen[ny, nx] = True
                    q.append((ny, nx))
    return rgb, ~seen


def label(core: np.ndarray) -> np.ndarray:
    h, w = core.shape
    lab = np.zeros((h, w), np.int32)
    cur = 0
    for y in range(h):
        for x in range(w):
            if core[y, x] and lab[y, x] == 0:
                cur += 1
                lab[y, x] = cur
                q: deque = deque([(y, x)])
                while q:
                    cy, cx = q.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if (
                            0 <= ny < h and 0 <= nx < w
                            and core[ny, nx] and lab[ny, nx] == 0
                        ):
                            lab[ny, nx] = cur
                            q.append((ny, nx))
    return lab


def grow(mask: np.ndarray, allow: np.ndarray, steps: int) -> np.ndarray:
    """`allow` 안에서만 `mask` 를 넓힌다. 경계 잉크선을 삼키는 데 쓴다."""
    out = mask.copy()
    for _ in range(steps):
        up = np.zeros_like(out)
        up[1:] |= out[:-1]
        up[:-1] |= out[1:]
        up[:, 1:] |= out[:, :-1]
        up[:, :-1] |= out[:, 1:]
        out |= up & allow
    return out


def assign_by_nearest(
    fg: np.ndarray, cores: list[np.ndarray]
) -> np.ndarray:
    """전경의 모든 픽셀을 **가장 가까운 코어**에 배정한다 (다중 시작점 BFS).

    팔-몸통 경계의 잉크·안티에일리어싱·잔조각을 성장 휴리스틱으로 나누면
    한쪽으로 길게 딸려 간다. 목선 잉크가 팔에 갈고리로 매달리고(어깨),
    팔 안쪽 조각이 몸통에 남는(배) 사고가 실제로 났다 (2026-08-07).
    거리 기준으로 나누면 경계 잉크가 **중간에서** 갈라져 양쪽 다 자연스럽다.

    반환: fg 와 같은 크기의 int 배열. 0 = 미배정(고립 조각), 1.. = cores 순서.
    """
    h, w = fg.shape
    owner = np.zeros((h, w), np.int32)
    q: deque = deque()
    for idx, core in enumerate(cores, start=1):
        ys, xs = np.where(core & fg)
        for y, x in zip(ys.tolist(), xs.tolist()):
            if owner[y, x] == 0:
                owner[y, x] = idx
                q.append((y, x))
    while q:
        y, x = q.popleft()
        o = owner[y, x]
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and owner[ny, nx] == 0:
                owner[ny, nx] = o
                q.append((ny, nx))
    return owner


def fill_holes(mask: np.ndarray) -> np.ndarray:
    """마스크의 닫힌 테두리 **안쪽을 전부** 채운다.

    팔 위에 붙은 천 패치는 팔 성분과 잉크선으로 갈려 따로 잡힌다. 그대로 두면
    "팔이 아닌 것" 으로 분류돼 거기서부터 몸통이 잉크선을 타고 번진다
    (2026-08-07 에 실제로 팔 윤곽이 몸통 레이어에 복사돼 나왔다).
    테두리 안쪽은 무조건 그 레이어 것으로 본다.
    """
    h, w = mask.shape
    # 바깥 한 줄은 **반드시 True** 여야 한다. 여기서 플러드가 출발한다.
    # 0 으로 두면 시작점이 막혀 아무것도 안 퍼지고, 결과가 캔버스 전체가 된다.
    out = np.ones((h + 2, w + 2), bool)
    out[1:-1, 1:-1] = ~mask
    seen = np.zeros_like(out)
    q: deque = deque([(0, 0)])
    seen[0, 0] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h + 2 and 0 <= nx < w + 2 and out[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return mask | ~seen[1:-1, 1:-1]


def save(rgb: np.ndarray, mask: np.ndarray, name: str) -> None:
    """**bbox 정규화를 하지 않는다.** 레이어끼리 정렬이 유지돼야 한다."""
    h, w = mask.shape
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb
    out[..., 3] = np.where(mask, 255, 0)
    path = os.path.join(OUT, f"{name}.png")
    Image.fromarray(out).save(path)
    ys, xs = np.where(mask)
    print(
        f"  {name:<16} {mask.sum():7d}px  "
        f"bbox x{xs.min():4d}-{xs.max():4d} y{ys.min():4d}-{ys.max():4d}"
    )


def _disc(shape: tuple[int, int], cx: float, cy: float, r: float) -> np.ndarray:
    h, w = shape
    yy, xx = np.ogrid[:h, :w]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r


def add_shoulder_cap(
    rgb: np.ndarray, arm: np.ndarray, pivot: tuple[float, float],
    fg: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    """팔 위쪽을 **둥근 어깨**로 마감한다.

    잉크선을 따라 자르면 팔 끝이 폭 5px 짜리 뾰족한 쐐기가 된다. 몸통에 가려져
    있을 때는 안 보이지만, 팔을 들어 올리는 순간 **찢긴 단면**이 그대로 드러난다
    (2026-08-07 형락님 지적).

    부위를 움직일 거면 마스킹도 "움직인 뒤에 어떻게 보이는가" 로 해야 한다.
    어깨 피벗에 팔 두께만 한 원을 얹어 관절처럼 마감한다.
    """
    ys, xs = np.where(arm)
    px, py = pivot
    # 피벗에서 조금 아래의 실제 팔 두께를 잰다. 그 절반이 캡 반지름이다.
    band = arm[int(py) + 90:int(py) + 150]
    width = float(np.median([row.sum() for row in band if row.any()] or [90]))
    radius = width * 0.46

    # 전체 실루엣 밖으로 나가지 않게 자른다. 대기 자세에서 캡이 몸통 가장자리
    # 위로 삐져나오면 옅은 호가 남는다.
    cap = _disc(arm.shape, px, py, radius) & fg
    new = arm | cap

    # 팔 색으로 채운다. 어깨 부근의 중앙값을 쓴다.
    near = arm & _disc(arm.shape, px, py + 120, 60)
    fill = np.median(rgb[near], axis=0).astype(int) if near.any() else rgb[arm].mean(0)
    added = cap & ~arm
    rgb[added] = fill

    # **원 테두리를 통째로 두르지 않는다.** 그러면 리벳처럼 튀는 동그라미가 된다
    # (2026-08-07). 캡을 붙인 뒤의 **바깥 실루엣**만 따라 칠해야 원래 팔의
    # 외곽선과 자연스럽게 이어진다.
    inner = new.copy()
    for _ in range(int(INK_WIDTH)):
        e = inner.copy()
        e[1:] &= inner[:-1]
        e[:-1] &= inner[1:]
        e[:, 1:] &= inner[:, :-1]
        e[:, :-1] &= inner[:, 1:]
        inner = e
    rgb[added & ~inner] = INK_RGB

    # **어깨 위쪽의 잉크 기어오름을 잘라낸다.**
    # 팔 마스크를 잉크선으로 성장시키면 머리와 어깨 사이 홈의 외곽선을 타고
    # 위로 기어 올라가, 갈고리 모양 선이 팔에 매달린다 (2026-08-07 형락님 지적).
    # 캡 위(피벗-6px 위)에 남는 팔 픽셀은 전부 기어오름이다.
    h, w = arm.shape
    rows = np.arange(h)[:, None]
    keep = cap | (new & (rows >= int(py) - 6))
    spill = new & ~keep
    return keep, spill


def erode(mask: np.ndarray, steps: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        e = out.copy()
        e[1:] &= out[:-1]
        e[:-1] &= out[1:]
        e[:, 1:] &= out[:, :-1]
        e[:, :-1] &= out[:, 1:]
        out = e
    return out


def build_body_underlay(
    rgb: np.ndarray, body: np.ndarray, fg: np.ndarray, arms: np.ndarray
) -> np.ndarray:
    """팔이 **원본에서 몸통을 덮고 있던 자리**를 메우는 복원 레이어.

    원본 그림에서 왼팔이 몸통 왼 옆구리를 실제로 가리고 있었고, 가려진 몸통은
    **그려진 적이 없다**. 팔을 들면 그 자리가 물린 자국처럼 빈다
    (2026-08-07 형락님 지적). 톱니바퀴 작은 기어와 같은
    "가려진 부분은 안 그려져 있다" 문제다.

    닫힘 연산(팽창→침식)으로는 얕은 굴곡과 색 경계가 남아서 실패했다.
    대신 **옆구리 외곽선을 물린 구간 위아래에서 이어** 매끈한 2차 곡선으로
    재구성하고, 곡선 안쪽을 몸통색으로 채운 뒤 곡선에 잉크를 두른다.

    별도 레이어인 이유: 몸통에 직접 넣으면 대기 자세에서 몸통이 팔 그림을
    덮어 원본과 달라진다. 원본은 그 자리에서 팔이 앞이었다. z 를 팔보다도
    아래에 깔면 대기에서는 안 보이고 팔이 떠날 때만 드러난다.
    """
    h, w = body.shape
    fill = np.zeros_like(body)

    # 물린 구간의 위아래에서 몸통 왼쪽 외곽 x 를 표본한다.
    def left_edge(y: int) -> int:
        row = np.where(body[y])[0]
        return int(row.min()) if row.size else -1

    y0, y1 = BITE_Y0, BITE_Y1
    x_top = np.median([left_edge(y) for y in range(y0 - 18, y0)])
    x_bot = np.median([left_edge(y) for y in range(y1, y1 + 18)])
    if x_top < 0 or x_bot < 0:
        return fill

    ink_half = int(INK_WIDTH)
    for y in range(y0, y1):
        t = (y - y0) / float(y1 - y0)
        # 위아래를 잇되 가운데를 바깥(왼쪽)으로 살짝 볼록하게. 배 옆구리의
        # 원래 흐름이 볼록이라 직선으로 이으면 깎인 면처럼 보인다.
        x_edge = lerp(x_top, x_bot, t) - BITE_BULGE * 4.0 * t * (1.0 - t)
        x_edge = int(round(x_edge))
        row = np.where(body[y])[0]
        if not row.size:
            continue
        x_body = int(row.min())
        if x_body <= x_edge:
            continue
        # 곡선(잉크 포함)부터 몸통 가장자리까지 채운다.
        # **팔이 있던 자리(fg)** 안으로만 — 배경으로는 절대 안 넘친다.
        span = fg[y, x_edge:x_body]
        xs = np.where(span)[0] + x_edge
        fill[y, xs] = True

    fill &= arms | ~body  # 몸통 픽셀은 건드리지 않는다
    if not fill.any():
        return fill

    # 채움색: 물린 구간 오른쪽(몸통 안쪽)의 밝은 면.
    ring = grow(fill, np.ones_like(fill), 10) & body
    samples = rgb[ring]
    lum_s = samples.sum(axis=1)
    colour = np.median(samples[lum_s >= np.median(lum_s)], axis=0).astype(int)
    rgb[fill] = colour

    # 곡선 잉크: 복원면의 왼쪽 가장자리.
    merged = body | fill
    inner = erode(merged, ink_half)
    rgb[fill & ~inner] = INK_RGB
    print(f"  몸통 복원 레이어 {int(fill.sum())}px (곡선 y{y0}-{y1})")
    return fill


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _face_colour(rgb: np.ndarray, body: np.ndarray) -> np.ndarray:
    """얼굴 바탕색. 눈 사이 이마 부근을 표본으로 쓴다."""
    band = body.copy()
    band[:200] = False
    band[420:] = False
    band[:, :400] = False
    band[:, 500:] = False
    return np.median(rgb[band], axis=0).astype(int)


def _split_eyes(body: np.ndarray, lum: np.ndarray) -> dict[str, np.ndarray]:
    """비어 있는 두 눈구멍을 왼쪽·오른쪽으로 나눠 돌려준다.

    눈구멍은 얼굴에서 가장 어두운 큰 덩어리 두 개다. 실측으로 왼쪽 117×124,
    오른쪽 117×142 였다. 잉크 외곽선은 얼굴 전체에 이어져 있어 훨씬 크므로
    크기 상한으로 걸러진다.
    """
    face = body.copy()
    face[FACE_BOTTOM:] = False
    dark = face & (lum < EYE_LUM)
    lab = label(dark)
    ids, cnt = np.unique(lab[lab > 0], return_counts=True)
    blobs = []
    for i, c in zip(ids, cnt):
        if not (EYE_MIN_PX <= c <= EYE_MAX_PX):
            continue
        yy, xx = np.where(lab == i)
        blobs.append((c, int(xx.mean()), lab == i))
    blobs.sort(reverse=True, key=lambda b: b[0])
    if len(blobs) < 2:
        raise SystemExit(f"눈구멍 두 개를 못 찾았다 (후보 {len(blobs)}개)")
    pair = sorted(blobs[:2], key=lambda b: b[1])
    # 구멍 **안쪽까지** 가져온다. 어두운 테두리만 떼면 안쪽의 옅은 보라 연기가
    # 몸통에 남아, 눈을 옮겨도 원래 자리에 눈이 그대로 보인다 (2026-08-07).
    # 테두리 한 겹도 같이 가져가 잘린 단면이 안 보이게 한다.
    return {
        "left": grow(fill_holes(pair[0][2]), face, 2),
        "right": grow(fill_holes(pair[1][2]), face, 2),
    }


def finalize(
    rgb: np.ndarray,
    layers: dict[str, np.ndarray],
    fg: np.ndarray,
    extra_rgb: dict[str, tuple[np.ndarray, np.ndarray]] | None = None,
) -> None:
    """인게임 비율로 맞춰 저장한다.

    ## 왜 가로를 늘리는가

    아트 실측 791×1171(0.68) 인데 규격은 520×620(0.84) 이다. 세로에 맞추면
    가로가 418 밖에 안 돼 규격보다 100px 좁다.

    가로만 1.24 배 늘려 채운다. 스프라이트라 비균등 배율이 자유롭고, 손그림
    화풍이라 왜곡이 드러나지 않는 것을 눈으로 확인했다. 오히려 가이드 4-1 의
    "머리는 몸에 비해 크고 **옆으로 넓게**", 4-4 의 "몸통은 **넓고** 둔중한
    덩어리" 에 더 가까워진다. 3회차 검수에서 "머리가 넓고 납작하지 않다" 가
    미달 항목이었는데 같이 해소된다.

    ## 왜 레이어마다 따로 자르지 않는가

    **모든 레이어를 전체 실루엣의 같은 상자로** 자른다. 레이어별로 알파 bbox 를
    맞추면 정렬이 깨져 팔이 어깨에서 떨어진다.
    """
    ys, xs = np.where(fg)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    src_w, src_h = box[2] - box[0], box[3] - box[1]
    out_w, out_h = GAME_W * OUT_SCALE, GAME_H * OUT_SCALE
    print(
        f"\n인게임 정합  원본 {src_w}×{src_h}({src_w / src_h:.3f})"
        f" -> {GAME_W}×{GAME_H}({GAME_W / GAME_H:.3f})"
        f"  가로 {GAME_W / (src_w * GAME_H / src_h):.3f} 배 늘림"
    )
    print(f"저장 {out_w}×{out_h} (씬에서 {1 / OUT_SCALE:.2f} 배로 표시)")

    game = os.path.join(OUT, "game")
    os.makedirs(game, exist_ok=True)
    jobs = [(n, rgb, m) for n, m in layers.items()]
    if extra_rgb:
        jobs += [(n, r, m) for n, (r, m) in extra_rgb.items()]
    for name, source, mask in jobs:
        buf = np.zeros(source.shape[:2] + (4,), np.uint8)
        buf[..., :3] = source
        buf[..., 3] = np.where(mask, 255, 0)
        img = Image.fromarray(buf).crop(box).resize((out_w, out_h), Image.LANCZOS)
        img.save(os.path.join(game, f"{name}.png"))
    print(f"  game/ 에 {len(jobs)} 장 저장")

    # 피벗을 인게임 좌표로 옮긴다. 씬에서 바로 쓸 수 있는 값이다.
    def to_game(x: float, y: float) -> tuple[float, float]:
        return (
            (x - box[0]) / src_w * GAME_W,
            (y - box[1]) / src_h * GAME_H,
        )

    print("\n인게임 좌표 (520×620, 원점 좌상단)")
    for label_name, key in (("왼팔 어깨", "boss_arm_left"), ("오른팔 어깨", "boss_arm_right")):
        m = layers[key]
        yy, xx = np.where(m)
        band = yy <= yy.min() + 20
        gx, gy = to_game(xx[band].mean(), yy[band].mean())
        print(f"  {label_name:<12} ({gx:6.1f}, {gy:6.1f})")
    yy, xx = np.where(layers["boss_heart"])
    gx, gy = to_game(xx.mean(), yy.mean())
    print(f"  {'하트핵':<12} ({gx:6.1f}, {gy:6.1f})")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    rgb, fg = load()
    h, w = fg.shape
    print(f"원본 {w}×{h}  전경 {100 * fg.mean():.1f}%")

    lum = rgb.sum(axis=2) / 3.0
    ink = fg & (lum < INK_LUM)
    lab = label(fg & ~ink)

    # 팔은 세로 봉제선·패치 때문에 성분이 여러 조각으로 쪼개진다.
    # x 중심으로 하나만 고르면 팔의 절반만 잡혀 나머지가 몸통에 남는다
    # (2026-08-07 에 실제로 팔 하나가 두 레이어에 걸쳐 나왔다).
    #
    # 대신 **아래쪽 띠**를 씨앗으로 쓴다. 몸통이 끝나는 높이 아래로는
    # 전경에 팔 둘만 남아, 좌우 두 덩어리로 깨끗이 갈린다.
    band = SEED_ROW
    runs = []
    start = None
    for x in range(w):
        if fg[band, x] and start is None:
            start = x
        elif not fg[band, x] and start is not None:
            if x - start > 40:
                runs.append((start, x))
            start = None
    if start is not None and w - start > 40:
        runs.append((start, w))
    if len(runs) != 2:
        raise SystemExit(f"y={band} 에서 팔 두 덩어리가 안 나온다: {runs}")
    print(f"씨앗 행 y={band} 왼팔 x{runs[0]} 오른팔 x{runs[1]}")

    def collect(run: tuple[int, int]) -> np.ndarray:
        """씨앗 구간에 걸친 성분을 **전부** 모아 한 팔로 친다."""
        seeds = {int(v) for v in np.unique(lab[band, run[0]:run[1]]) if v > 0}
        mask = np.zeros_like(fg)
        for s in seeds:
            mask |= lab == s
        return mask

    core_l = collect(runs[0])
    core_r = collect(runs[1])

    # ── 팔 위에 걸친 큰 천 패치를 팔에 귀속시킨다 ────────────────────────
    # 왼팔 팔꿈치 패치(5,741px)는 MIN_REGION 을 넘어 "큰 성분" 장벽이 됐고,
    # 팔에도 몸통에도 못 들어가 부스러기로 **삭제**됐다. 팔을 들면 그 자리가
    # 물어뜯긴 모양이 된다 (2026-08-07 형락님 지적).
    #
    # 성분이 어느 쪽과 더 많이 **맞닿아 있는지**로 소속을 정한다.
    ids0, cnt0 = np.unique(lab[lab > 0], return_counts=True)

    # 몸통의 **닫힌 실루엣** 안에 있는 성분은 몸통 소속이다.
    # 팔꿈치 옆 패치(성분 875)를 접촉량만 보고 팔로 보냈더니, 몸통 아랫배가
    # 패치 모양대로 파여 팔을 들면 물린 자국이 남았다 (2026-08-07 격자 실측:
    # game 170~330 × 780~940 = 정확히 그 패치 자리였다). 접촉량은 어느 쪽에
    # "붙어 있는가" 를 말해 주지 않는다 — 실루엣 포함 여부가 말해 준다.
    pre_body = np.zeros_like(fg)
    for i, c in zip(ids0, cnt0):
        if c >= MIN_REGION:
            m = lab == i
            if not (core_l[m].any() or core_r[m].any()):
                pre_body |= m
    body_hull = fill_holes(pre_body)

    # 몸통 접촉 비교에는 **큰 성분만** 쓴다. 작은 성분(실땀 자국)까지 넣으면
    # 패치 둘레의 실땀이 "몸통 접촉" 으로 오판돼 귀속이 한 번도 안 붙는다
    # (2026-08-07 에 실제로 그랬다).
    big_rest = np.zeros_like(fg)
    for i, c in zip(ids0, cnt0):
        if c >= MIN_REGION:
            m = lab == i
            if not (core_l[m].any() or core_r[m].any()):
                big_rest |= m
    for i, c in zip(ids0, cnt0):
        # 패치 크기 구간만 후보다. 상한이 없으면 몸통 절반(52k~85k)까지
        # "팔에 더 많이 닿았다" 며 팔로 넘어간다 (2026-08-07 에 실제로 그랬다.
        # 몸통-팔 경계가 몸통-머리 경계보다 길기 때문이다).
        if not (MIN_REGION <= c <= PATCH_MAX_PX):
            continue
        m = lab == i
        if core_l[m].any() or core_r[m].any():
            continue
        # 몸통 실루엣 안이면 몸통 것이다. 팔로 보내면 몸통이 파인다.
        if body_hull[m].mean() > 0.5:
            continue
        # 패치와 팔 사이에는 패치의 잉크 테두리(8~12px)가 끼어 있다.
        # 다리를 그보다 넓게 놓아야 접촉이 잡힌다.
        ring = grow(m, np.ones_like(m), 9) & ~m
        contact_l = int((ring & grow(core_l, np.ones_like(m), 9)).sum())
        contact_r = int((ring & grow(core_r, np.ones_like(m), 9)).sum())
        contact_body = int((ring & big_rest & ~m).sum())
        merged = ""
        if contact_l > contact_body and contact_l >= contact_r:
            core_l = core_l | m
            merged = "-> 왼팔"
        elif contact_r > contact_body:
            core_r = core_r | m
            merged = "-> 오른팔"
        if merged:
            print(f"  성분 {i} ({c}px) {merged} 귀속")

    # 몸통 코어 = 팔로 귀속되지 않은 큰 성분 전부.
    body_core = np.zeros_like(fg)
    for i, c in zip(ids0, cnt0):
        if c >= MIN_REGION:
            m = lab == i
            if not (core_l[m].any() or core_r[m].any()):
                body_core |= m

    # 나머지(잉크·안티에일리어싱·작은 조각)는 **가장 가까운 코어**가 가져간다.
    # 경계 잉크가 중간에서 갈라지므로 갈고리·잔류 조각이 생기지 않는다.
    owner = assign_by_nearest(fg, [core_l, core_r, body_core])
    arm_l = owner == 1
    arm_r = owner == 2
    body = owner == 3
    dropped = int((fg & (owner == 0)).sum())
    if dropped:
        print(f"  고립 조각 {dropped}px 폐기 (어느 코어와도 안 닿음)")

    # 팔 위쪽을 둥근 어깨로 마감한다. 회전하면 단면이 드러나기 때문이다.
    #
    # **몸통에서 캡 영역을 빼면 안 된다.** 빼면 가슴에 원형 구멍이 뚫리고,
    # 그 구멍으로 뒤에 있는 밝은 캡이 비쳐 보여 어깨마다 옅은 원이 남는다
    # (2026-08-07 에 실제로 그렇게 나왔다). 몸통이 앞이고 팔이 뒤라 겹쳐도
    # 문제가 없다. 팔이 앞으로 올 때(공격)는 캡이 몸통을 덮는 것이 맞다.
    under = build_body_underlay(rgb, body, fg, arm_l | arm_r)

    arm_l, spill_l = add_shoulder_cap(rgb, arm_l, SHOULDER_LEFT, fg)
    arm_r, spill_r = add_shoulder_cap(rgb, arm_r, SHOULDER_RIGHT, fg)
    # 잘라낸 기어오름은 몸통의 외곽선이었다. 몸통에 돌려주지 않으면
    # 머리-어깨 홈의 테두리에 구멍이 난다.
    body = body | spill_l | spill_r

    # 눈구멍 두 개를 따로 뗀다. 상태별 표정에 쓴다.
    #
    # 가이드 4-2 가 눈에 대해 아주 좁게 못박아 뒀다: 흰자·동공·단추눈·발광 전부
    # 금지, **완전히 비어 있는 검은 구멍**만. 그래서 표정으로 바꿀 수 있는 것은
    # 구멍의 **모양과 기울기**뿐이다. 눈알을 그려 넣으면 즉시 반려다.
    eye_rgb = rgb.copy()
    eyes = _split_eyes(body, lum)
    for key, mask in eyes.items():
        body = body & ~mask
    # 떼어낸 자리는 얼굴 바탕색으로 메운다. 얼굴이 평면 채색이라 단색으로 충분하다.
    face_rgb = _face_colour(rgb, body)
    for mask in eyes.values():
        rgb[mask] = face_rgb

    # 하트형 저주핵은 붉은색이라 색으로 뗀다. 코드가 박동시켜야 한다.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    heart = fg & (r > 80) & (r > g + 28) & (r > b + 14)
    heart = fill_holes(grow(heart, fg & (lum < 70), 5))
    # 몸에서 심장을 뺀다. 남은 구멍은 없다. 심장이 몸 위에 얹혀 있기 때문이다.
    body_no_heart = body & ~heart

    print("\n레이어")
    save(rgb, body_no_heart, "boss_body")
    save(rgb, arm_l, "boss_arm_left")
    save(rgb, arm_r, "boss_arm_right")
    save(rgb, heart, "boss_heart")
    save(rgb, fg, "boss_full")

    layers = {
        "boss_body": body_no_heart,
        "boss_body_under": under,
        "boss_arm_left": arm_l,
        "boss_arm_right": arm_r,
        "boss_heart": heart,
    }
    finalize(rgb, layers, fg, extra_rgb={
        f"boss_eye_{k}": (eye_rgb, m) for k, m in eyes.items()
    })

    # 어깨 피벗. 팔 마스크의 **가장 위쪽 20px 띠의 중심**을 쓴다.
    print("\n어깨 피벗 (원본 픽셀 기준)")
    for name, m in (("왼팔", arm_l), ("오른팔", arm_r)):
        ys, xs = np.where(m)
        top = ys.min()
        band = ys <= top + 20
        print(f"  {name} ({int(xs[band].mean())}, {int(ys[band].mean())})")
    ys, xs = np.where(heart)
    print(f"  하트핵 ({int(xs.mean())}, {int(ys.mean())})")


if __name__ == "__main__":
    main()
