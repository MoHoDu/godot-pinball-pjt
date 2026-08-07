#!/usr/bin/env python3
"""Leonardo 생성물 후처리 — 배경 제거 + 알파 bbox 정규화.

트랙 B(텍스트만)로 뽑으면 실루엣을 모델이 정하므로 이 공정이 필수다.
빠뜨리면 표시 크기가 충돌 크기와 어긋난다 (공에서 두 번 밟은 지뢰).

하는 일:
  1. 테두리에서 flood fill 로 단색 배경을 지운다. 범퍼는 굵은 잉크 외곽선을
     가지고 있어서 채우기가 그 선에서 멈춘다.
  2. 알파 bbox 를 잘라 정사각으로 패딩한 뒤 1024 로 리사이즈한다.
     `bumper_master.py` 의 finalize() 와 같은 규칙이다.
  3. 채움률을 찍는다. 가로/세로 중 하나가 100% 가 아니면 표시 지름 계산이
     그만큼 어긋나므로 눈으로 확인해야 한다.

입력:  <루트>/candidates/unmasked/<이름>/*.jpg
출력:  <루트>/candidates/masked/<이름>/*.png

실행:
  python docs/bumper_guides/cutout_and_finalize.py                 # 범퍼
  python docs/bumper_guides/cutout_and_finalize.py --root docs/repair_part_guides
  python docs/bumper_guides/cutout_and_finalize.py cotton_r2       # 특정 폴더만
"""

from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
SRC_ROOT = os.path.join(HERE, "candidates", "unmasked")
OUT_ROOT = os.path.join(HERE, "candidates", "masked")

CANVAS = 1024

# flood fill 이 배경으로 인정할 색 차이. 드롭섀도까지 먹으려면 올리고,
# 오브젝트를 갉아먹으면 내린다.
THRESHOLD = 62

# 배경으로 칠할 임시 키 색. 아트 팔레트에 없는 값이어야 한다.
KEY = (255, 0, 255)

# 테두리에서 씨앗을 뽑는 간격(px).
SEED_STEP = 24


def border_seeds(width: int, height: int) -> list[tuple[int, int]]:
    seeds: list[tuple[int, int]] = []
    for x in range(0, width, SEED_STEP):
        seeds.append((x, 0))
        seeds.append((x, height - 1))
    for y in range(0, height, SEED_STEP):
        seeds.append((0, y))
        seeds.append((width - 1, y))
    return seeds


def remove_background(rgb: Image.Image) -> tuple[Image.Image, float]:
    """배경을 지운다.

    1) 테두리에서 flood fill — 단색 배경을 먹는다.
    2) 남은 불투명 영역 중 화면 중앙을 포함한 덩어리만 남긴다 — 배경에 딸려
       그려진 별·공 같은 잡물(bell_2)을 떨어낸다.

    안쪽으로 씨앗을 넣어 액자 테두리 안까지 뚫는 방법도 시도했으나 폐기했다.
    기어의 넓은 황동 면처럼 **오브젝트 내부의 큰 단색 면을 삼켜** 그림이 통째로
    지워졌다(gears_0 98.5% 삭제). 액자가 그려진 생성물은 후보에서 빼는 게 맞다.
    """
    work = rgb.copy()
    width, height = work.size
    total = float(width * height)
    pixels = work.load()

    for seed in border_seeds(width, height):
        if pixels[seed] != KEY:
            ImageDraw.floodfill(work, seed, KEY, thresh=THRESHOLD)

    out = rgb.convert("RGBA")
    dst = out.load()
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == KEY:
                dst[x, y] = (0, 0, 0, 0)

    kept = _keep_center_blob(out)
    return out, (total - kept) / total


def _keep_center_blob(img: Image.Image) -> int:
    """화면 중앙을 포함한 연결 덩어리만 남기고 나머지 불투명 픽셀을 지운다."""
    width, height = img.size
    px = img.load()
    opaque = bytearray(width * height)
    for y in range(height):
        row = y * width
        for x in range(width):
            if px[x, y][3] != 0:
                opaque[row + x] = 1

    # 중앙에서 시작. 중앙이 비었으면 가장 가까운 불투명 픽셀을 찾는다.
    start = None
    cx, cy = width // 2, height // 2
    for radius in range(0, max(width, height) // 2, 4):
        for sx, sy in ((cx + radius, cy), (cx - radius, cy), (cx, cy + radius), (cx, cy - radius)):
            if 0 <= sx < width and 0 <= sy < height and opaque[sy * width + sx]:
                start = (sx, sy)
                break
        if start:
            break
    if start is None:
        return 0

    from collections import deque

    seen = bytearray(width * height)
    queue = deque([start[1] * width + start[0]])
    seen[queue[0]] = 1
    kept = 0
    while queue:
        idx = queue.popleft()
        kept += 1
        y, x = divmod(idx, width)
        if x > 0 and opaque[idx - 1] and not seen[idx - 1]:
            seen[idx - 1] = 1
            queue.append(idx - 1)
        if x < width - 1 and opaque[idx + 1] and not seen[idx + 1]:
            seen[idx + 1] = 1
            queue.append(idx + 1)
        if y > 0 and opaque[idx - width] and not seen[idx - width]:
            seen[idx - width] = 1
            queue.append(idx - width)
        if y < height - 1 and opaque[idx + width] and not seen[idx + width]:
            seen[idx + width] = 1
            queue.append(idx + width)

    for y in range(height):
        row = y * width
        for x in range(width):
            if opaque[row + x] and not seen[row + x]:
                px[x, y] = (0, 0, 0, 0)
    return kept


def finalize(img: Image.Image) -> tuple[Image.Image, float, float]:
    """알파 bbox == 캔버스 강제."""
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("전부 지워졌다. THRESHOLD 를 낮출 것")
    cropped = img.crop(bbox)
    w, h = cropped.size
    side = max(w, h)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(cropped, ((side - w) // 2, (side - h) // 2))
    return square.resize((CANVAS, CANVAS), Image.LANCZOS), w / side, h / side


def process(path: str, out_path: str) -> None:
    rgb = Image.open(path).convert("RGB")
    cut, bg_ratio = remove_background(rgb)
    final, fw, fh = finalize(cut)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    final.save(out_path)

    flag = ""
    if bg_ratio < 0.02:
        flag = "  ← 배경이 거의 안 지워졌다. 확인할 것"
    elif fw < 0.97 or fh < 0.97:
        flag = "  ← 채움률 미달. 표시 지름이 어긋난다"
    print(f"  {os.path.basename(out_path):<22} 배경제거 {bg_ratio:5.1%}  채움 가로 {fw:5.1%} 세로 {fh:5.1%}{flag}")


def main() -> None:
    args = sys.argv[1:]
    src_root, out_root = SRC_ROOT, OUT_ROOT
    if "--root" in args:
        i = args.index("--root")
        root = os.path.abspath(args[i + 1])
        src_root = os.path.join(root, "candidates", "unmasked")
        out_root = os.path.join(root, "candidates", "masked")
        del args[i : i + 2]
    targets = args

    if not os.path.isdir(src_root):
        raise SystemExit(f"입력 폴더가 없다: {src_root}")

    for name in sorted(os.listdir(src_root)):
        folder = os.path.join(src_root, name)
        if not os.path.isdir(folder):
            continue
        if targets and name not in targets:
            continue
        print(f"{name}/")
        for fn in sorted(os.listdir(folder)):
            if not fn.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            src = os.path.join(folder, fn)
            dst = os.path.join(out_root, name, os.path.splitext(fn)[0] + ".png")
            process(src, dst)


if __name__ == "__main__":
    main()
