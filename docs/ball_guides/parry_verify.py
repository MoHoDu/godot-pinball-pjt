import sys; import pathlib; sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import numpy as np
from PIL import Image
from parry_shader_check import read_tres, uniforms_at, render, TRES, quad_radius_ratio

r = read_tres(TRES); DUR=r['duration']; BR=22.0
fails=[]
def ck(c,m):
    print(("  OK  " if c else "  FAIL") + "  " + m)
    if not c: fails.append(m)

print("== 1. 쿼드 경계 잘림 ==")
worst=0
for sec in [0.0,0.02,0.05,0.08,0.11,0.14,0.159]:
    u=uniforms_at(r, sec/DUR); n=int(round(u['quad_radius_px']*2))
    a=np.array(render(u,n))[...,3]
    edge=max(a[0].max(),a[-1].max(),a[:,0].max(),a[:,-1].max())
    worst=max(worst,int(edge))
ck(worst==0, f"쿼드 네 변의 알파가 0이어야 한다 (최대 {worst})")

print("== 2. 원으로 읽히는가 ==")
u=uniforms_at(r,0.5); n=int(round(u['quad_radius_px']*2))
img=np.array(render(u,n)); a=img[...,3]/255.0
cy=cx=(n-1)/2.0; Y,X=np.mgrid[0:n,0:n]; R=np.hypot(X-cx,Y-cy); TH=np.arctan2(Y-cy,X-cx)
peaks=[]
for k in range(72):
    lo,hi=k*np.pi/36-np.pi, (k+1)*np.pi/36-np.pi
    m=(TH>=lo)&(TH<hi)&(a>0.35)
    if m.any(): peaks.append(R[m].max())
peaks=np.array(peaks); dev=float(peaks.std()/peaks.mean()*100)
ck(dev<10.0, f"각도별 외곽 반경 편차 {dev:.1f}% < 10% (원으로 읽혀야 한다)")

print("== 3. 도달 반경 ==")
u0=uniforms_at(r,0.0); u1=uniforms_at(r,1.0)
q=BR*quad_radius_ratio(r)
r0=u0['main_r']*q; r1=u1['main_r']*q
ck(abs(r0-27)<0.5, f"시작 {r0:.2f}px = 27px")
ck(abs(r1-95)<0.5, f"종료 {r1:.2f}px = 95px")

print("== 4. 가독성 우선순위 ==")
ball=np.array(Image.open(str(pathlib.Path(__file__).resolve().parents[2]/'Resources/Art/balls/glass_eye_ball.png')).convert('RGBA')).astype(float)/255
ba=ball[...,3]; bl=(0.2126*ball[...,0]+0.7152*ball[...,1]+0.0722*ball[...,2])[ba>0.5].max()
worst_l=0
for sec in [0.0,0.02,0.05,0.08,0.11]:
    u=uniforms_at(r,sec/DUR); n=int(round(u['quad_radius_px']*2))
    im=np.array(render(u,n)).astype(float)/255; al=im[...,3]
    L=(0.2126*im[...,0]+0.7152*im[...,1]+0.0722*im[...,2])
    if (al>0.5).any(): worst_l=max(worst_l,float(L[al>0.5].max()))
ck(worst_l<bl, f"파동 최대 휘도 {worst_l:.3f} < 공 본체 {bl:.3f}")

print("== 5. 화면에 안 남는가 ==")
u=uniforms_at(r,1.0); n=int(round(u['quad_radius_px']*2))
a=np.array(render(u,n))[...,3]
ck(a.max()==0, f"t=1.0 에서 완전히 사라져야 한다 (최대 알파 {a.max()})")

print("== 6. 화면 점유 ==")
u=uniforms_at(r,0.62); n=int(round(u['quad_radius_px']*2))
a=np.array(render(u,n))[...,3]/255.0
area=float(a.sum())/(np.pi*BR**2)
print(f"  정보  파동 면적 / 공 면적 = {area:.1f}배 (이동 꼬리는 5.4배였다)")
print(f"  정보  파동 지름 {r1*2:.0f}px = 보드 폭 2240 의 {r1*2/2240*100:.1f}%")

print("== 7. 동공 가림 (안 A는 의도된 것) ==")
u=uniforms_at(r,0.0); n=int(round(u['quad_radius_px']*2))
a=np.array(render(u,n))[...,3]/255.0
cy=cx=(n-1)/2.0; Y,X=np.mgrid[0:n,0:n]; R=np.hypot(X-cx,Y-cy)
cover=float(a[R<7.0].mean())
print(f"  정보  동공(반경 7px) 위 플래시 알파 평균 {cover:.2f} — 0.045초 동안 덮인다")

print()
print("FAIL 0 — 전부 통과" if not fails else f"FAIL {len(fails)}")
sys.exit(1 if fails else 0)
