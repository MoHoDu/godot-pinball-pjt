"""STEP 2 여백판 — 생성물이 프레임에 안 닿게 해서 마스킹 때 8방향이 똑같이 잘리게 한다"""
from PIL import Image, ImageDraw
import numpy as np, math
SRC='/tmp/ballv4/final/ball_v7_rough_1024.png'
M=1024; RATIO=0.74                       # 공이 캔버스의 74%
BG=(22,25,37,255)                        # 프로젝트 배경 #161925

m=Image.open(SRC).convert('RGBA')
d=int(round(M*RATIO)); d+= d%2
ball=m.resize((d,d), Image.LANCZOS)
plate=Image.new('RGBA',(M,M),BG)
off=(M-d)//2
plate.paste(ball,(off,off),ball)
plate.convert('RGB').save('/tmp/ballv4/final/ball_v7_step2_reference_plate.png')
print(f'여백판 {M}x{M} / 공 지름 {d}px ({d/M*100:.1f}%) / 사방 여백 {off}px')
print(f'이론 반지름 {d/2:.1f}px  → 4096 생성 시 {d/2*4:.0f}px')

# 알파 마스크(STEP 3용) — 마스터의 알파를 그대로
alpha=np.array(m)[:,:,3]
print('마스터 알파 bbox:', (alpha>8).any(0).sum(), 'x', (alpha>8).any(1).sum())
