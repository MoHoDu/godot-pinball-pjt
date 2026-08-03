from PIL import Image
import numpy as np, os

CUR = '/sessions/great-nifty-brahmagupta/mnt/godot-pinball-pjt/Resources/Art/balls/cats_eye_ball.png'
files = [('현재본 cats_eye', CUR)] + [(k, f'/tmp/ballv4/out/{k}.png')
         for k in ['V1_standard','V2_strong','V3_pupilonly','V4_bigiris']]

def metrics(path, size=44):
    im = Image.open(path).convert('RGBA').resize((size,size), Image.LANCZOS)
    a = np.array(im).astype(float)
    rgb, al = a[...,:3], a[...,3]/255
    lum = 0.2126*rgb[...,0]+0.7152*rgb[...,1]+0.0722*rgb[...,2]
    m = al > 0.5
    yy,xx = np.mgrid[0:size,0:size]
    cxy = (size-1)/2
    ln = lum.copy(); ln[~m] = np.nan
    lo, hi = np.nanmin(ln), np.nanmax(ln)
    dark = np.clip((hi-ln)/(hi-lo), 0, 1); dark[~m]=0
    bright = np.clip((ln-lo)/(hi-lo), 0, 1); bright[~m]=0
    dcx = (dark*(xx-cxy)).sum()/dark.sum()
    bcx = (bright*(xx-cxy)).sum()/bright.sum()
    # 강한 어둠(동공)만
    hard = (ln < lo + (hi-lo)*0.28) & m
    hcx = (xx[hard]-cxy).mean() if hard.sum() else 0.0
    # 3단 명도 분리도
    return dict(dark_cx=dcx, bright_cx=bcx, sep=bcx-dcx, pupil_cx=hcx,
                pupil_px=int(hard.sum()), lum_range=hi-lo)

print(f"{'시안':<18}{'어두운무게중심':>14}{'밝은무게중심':>13}{'앞뒤분리':>10}{'동공중심':>10}{'동공px':>8}")
for name, p in files:
    r = metrics(p)
    print(f"{name:<18}{r['dark_cx']:>14.2f}{r['bright_cx']:>13.2f}{r['sep']:>10.2f}{r['pupil_cx']:>10.2f}{r['pupil_px']:>8}")
