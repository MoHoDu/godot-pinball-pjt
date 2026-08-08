# -*- coding: utf-8 -*-
"""cursed_circus_outside_background.png 에서 배경 데코 패치를 추출한다.

배경 앰비언트(별 회전·반짝임·구름 숨쉬기)용 재현 스크립트.

별을 "돌아가게" 하려면(2026-08-08 지시) 원본 위 겹침만으로는 안 된다 —
회전한 오버레이 밑으로 원본 별이 비쳐 이중상이 생긴다. 그래서 별마다 3종을 뽑는다:

- StarCover_XX: 원본 별 자리를 주변 무늬로 메운(확산 인페인팅) 사각 패치.
  별 영역 밖 픽셀은 원본과 완전히 동일해서 이음매가 없다. 원본 별을 "지운다".
- StarBody_XX: 별 모양만 정밀 마스킹한 스프라이트. 이게 천천히 회전한다.
- StarGlint_XX: StarBody 를 밝힌 버전. 회전하는 본체의 자식으로 알파 맥동 = 반짝임.
- 구름: 네 모서리 덩어리를 안쪽 변만 페더로 잘라 원본 그대로 저장한다.
  코너 고정 확대(1.0~1.02x)로 숨쉬게 한다. 현재는 꺼져 있다.

실행: python docs/ambient_guides/extract_bg_decor.py  (저장소 루트에서)
출력: Resources/Art/backgrounds/ambient_decor/*.png + 좌표 표 stdout
"""
import math
import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage

SRC = os.path.join(
    "Resources", "Art", "backgrounds", "cursed_circus_outside_background.png"
)
OUT_DIR = os.path.join("Resources", "Art", "backgrounds", "ambient_decor")

# 별: (중심x, 중심y, 패치 지름px). detect 스크립트 후보를 병합·선별했다.
STARS = [
    (1406, 125, 96),   # 우상단 큰 별
    (1370, 857, 92),   # 우하단 큰 별
    (495, 66, 80),     # 상단 중앙좌측 별
    (1330, 140, 100),  # 우상단 별 무리
    (1590, 665, 92),   # 우측 하단 별 무리
    (434, 866, 84),    # 하단 좌측 별
    (183, 152, 96),    # 좌상단 별 무리
    (205, 775, 68),    # 좌하단 붉은 별
    (1580, 296, 60),   # 우측 상단 작은 별
    (125, 712, 80),    # 좌측 하단 별 무리
    (62, 546, 48),     # 좌측 가장자리 점
    (1638, 560, 48),   # 우측 가장자리 점
    (154, 827, 48),    # 좌하단 코너 별
    (1528, 98, 64),    # 우상단 코너 별
]

# 별 밝힘 배율. 게임에서 알파 맥동으로 겹치면 국소 +30% 안팎의 글린트가 된다.
STAR_BRIGHTEN = 1.6

# 구름: (이름, x0, y0, x1, y1, 고정 코너). 코너는 스케일 기준점이 된다.
CLOUDS = [
    ("Cloud_TL", 0, 0, 360, 320, "tl"),
    ("Cloud_TR", 1300, 0, 1672, 300, "tr"),
    ("Cloud_BL", 0, 620, 400, 941, "bl"),
    ("Cloud_BR", 1280, 580, 1672, 941, "br"),
]

CLOUD_FEATHER = 60.0


def star_shape_mask(diff: np.ndarray, cx: int, cy: int, d: int) -> np.ndarray:
    """패치 안에서 별 모양(중심 근처의 밝은 성분)만 골라낸 이진 마스크."""
    h, w = diff.shape
    x0, y0 = max(0, cx - d // 2), max(0, cy - d // 2)
    x1, y1 = min(w, cx + d // 2), min(h, cy + d // 2)
    crop = diff[y0:y1, x0:x1]
    core = crop > 12.0
    labels, count = ndimage.label(core)
    keep = np.zeros_like(core)
    center = np.array([cy - y0, cx - x0], dtype=np.float64)
    for idx in range(1, count + 1):
        component = labels == idx
        if component.sum() < 6:
            continue
        centroid = np.array(ndimage.center_of_mass(component))
        if np.linalg.norm(centroid - center) <= d * 0.45:
            keep |= component
    # 밝은 내부만 잡히므로 어두운 외곽선까지 3px 부풀린다.
    return ndimage.binary_dilation(keep, iterations=3)


def diffusion_inpaint(patch: np.ndarray, hole: np.ndarray) -> np.ndarray:
    """hole 영역을 주변 픽셀 확산으로 메운다. 작은 별 자리에는 충분하다."""
    result = patch.astype(np.float64)
    known = ~hole
    for channel in range(result.shape[2]):
        plane = result[:, :, channel]
        fill = plane.copy()
        fill[hole] = plane[known].mean()
        for _ in range(160):
            blurred = ndimage.uniform_filter(fill, size=5)
            fill[hole] = blurred[hole]
            fill[known] = plane[known]
        result[:, :, channel] = fill
    return np.clip(result, 0.0, 255.0).astype(np.uint8)


def cut_star_set(
    im: Image.Image, diff: np.ndarray, cx: int, cy: int, d: int
) -> tuple:
    """(cover, body, glint) 세 패치를 만든다."""
    w, h = im.size
    x0, y0 = max(0, cx - d // 2), max(0, cy - d // 2)
    x1, y1 = min(w, cx + d // 2), min(h, cy + d // 2)
    patch = np.asarray(im.crop((x0, y0, x1, y1)).convert("RGB"), dtype=np.uint8)

    shape = star_shape_mask(diff, cx, cy, d)

    # 본체 알파: 별 모양 + 가장자리 1.2px 페더
    body_alpha = ndimage.gaussian_filter(shape.astype(np.float64), sigma=1.2)
    body_alpha = np.clip(body_alpha, 0.0, 1.0)
    body = np.dstack([patch, (body_alpha * 255).astype(np.uint8)])

    bright = np.asarray(
        ImageEnhance.Brightness(Image.fromarray(patch)).enhance(STAR_BRIGHTEN),
        dtype=np.uint8,
    )
    glint = np.dstack([bright, (body_alpha * 255).astype(np.uint8)])

    # 지움 패치: 별보다 6px 넓게 메워 원본 별이 한 톨도 안 남게 한다.
    hole = ndimage.binary_dilation(shape, iterations=6)
    cover_rgb = diffusion_inpaint(patch, hole)
    cover = np.dstack([
        cover_rgb,
        np.full(cover_rgb.shape[:2], 255, dtype=np.uint8),
    ])

    return (
        Image.fromarray(cover, "RGBA"),
        Image.fromarray(body, "RGBA"),
        Image.fromarray(glint, "RGBA"),
    )


def cut_cloud(
    im: Image.Image, x0: int, y0: int, x1: int, y1: int, corner: str
) -> Image.Image:
    patch = np.asarray(im.crop((x0, y0, x1, y1)).convert("RGB"), dtype=np.uint8)
    ph, pw = patch.shape[:2]
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float32)
    # 이미지 경계에 붙은 바깥 변은 페더 없음, 안쪽 변만 페더.
    dist = np.full((ph, pw), 1e9, dtype=np.float32)
    if "l" in corner:            # 왼쪽 고정 -> 오른쪽 변이 안쪽
        dist = np.minimum(dist, pw - 1 - xx)
    else:                        # 오른쪽 고정 -> 왼쪽 변이 안쪽
        dist = np.minimum(dist, xx)
    if "t" in corner:            # 위 고정 -> 아래 변이 안쪽
        dist = np.minimum(dist, ph - 1 - yy)
    else:                        # 아래 고정 -> 위 변이 안쪽
        dist = np.minimum(dist, yy)
    mask = np.clip(dist / CLOUD_FEATHER, 0.0, 1.0)
    mask = 0.5 - 0.5 * np.cos(mask * math.pi)
    rgba = np.dstack([patch, (mask * 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    im = Image.open(SRC)
    os.makedirs(OUT_DIR, exist_ok=True)

    gray = np.asarray(im.convert("L"), dtype=np.float64)
    blur = np.asarray(
        im.convert("L").filter(ImageFilter.BoxBlur(25)), dtype=np.float64
    )
    diff = gray - blur

    print("== 별 패치 3종 (텍스처 픽셀 좌표) ==")
    for i, (cx, cy, d) in enumerate(STARS, start=1):
        cover, body, glint = cut_star_set(im, diff, cx, cy, d)
        cover.save(os.path.join(OUT_DIR, f"StarCover_{i:02d}.png"))
        body.save(os.path.join(OUT_DIR, f"StarBody_{i:02d}.png"))
        glint.save(os.path.join(OUT_DIR, f"StarGlint_{i:02d}.png"))
        print(f"Star {i:02d}  center=({cx}, {cy})  d={d}")

    print("== 구름 패치 (코너 고정) ==")
    for name, x0, y0, x1, y1, corner in CLOUDS:
        cut_cloud(im, x0, y0, x1, y1, corner).save(
            os.path.join(OUT_DIR, f"{name}.png")
        )
        print(f"{name}.png  rect=({x0},{y0})-({x1},{y1})  corner={corner}")


if __name__ == "__main__":
    main()
