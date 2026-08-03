---
name: ball-texture-fixed
description: 공 텍스처 확정 — glass_eye_ball.png 하나만 쓴다. VFX 예시 렌더도 반드시 이걸로
type: project
---

# 공 텍스처는 `glass_eye_ball.png` 로 확정 (2026-08-03)

관련: [[ball-glass-eye]], [[vfx01-mist-aura]], [[ball-v6-redesign]]

`Resources/Art/balls/glass_eye_ball.png` — 1024×1024, 알파 bbox 채움률 100%.
`base_ball.tscn` 이 이 파일을 가리킨다.

**형락님 지시: 앞으로 VFX 예시 사진을 보여줄 때 반드시 이 공으로 렌더한다.**
목표 그림·모의 렌더 스크립트(`docs/ball_guides/make_sheet.py` 의 `BALL_PNG`)도 이 파일을 직접 참조한다.
예시용 사본을 따로 만들면 게임 화면과 갈라지므로 만들지 않는다.

## ★ 새 공 이미지를 받으면 반드시 채움률부터 잰다

`pinball.gd` 의 `refresh_ball_size()` 가 **텍스처의 긴 변**으로 나눈다:
`visual_scale = ball_diameter / max(tex.x, tex.y)`. **캔버스 여백이 그대로 표시 크기 손실**이다.

2026-08-03 형락님이 올려준 원본은 1024 캔버스에 공이 **74.6%** 만 채워져 있었다.
그대로 넣었으면 `ball_diameter 44` 지정에도 실제 표시는 **32.8px**, 충돌 44px 과 11px 어긋나 즉시 FAIL이다.
(구 `ball.png` 가 84% 채움으로 똑같이 실패한 이력이 있다 — 같은 함정을 두 번 밟았다는 뜻)

리포의 `glass_eye_ball.png` 는 이미 100%로 잘려 있었으므로 **새로 만들지 말고 그걸 쓴다.**
별도 보정본(`eye_ball_v6.png`)을 만들었다가 중복이라 지웠다.

검사 한 줄:

```python
a = np.asarray(Image.open(p).convert("RGBA"))[..., 3]
ys, xs = np.where(a > 8)
fill = (xs.max()-xs.min()+1) / a.shape[1] * 100   # 100% 여야 한다
```

## 디자인

캣츠아이(아몬드 코어)가 아니라 **둥근 동공의 눈**으로 회귀했다 → [[ball-v6-redesign]]
잉크 외곽선 / 아이보리 유리 테 / 청록 홍채 + 링 음영 / 큰 검은 동공 / 큰 흰 하이라이트 1 + 작은 것 1.
주황은 없다(플리퍼 축 눈과의 구분 규칙 유지).

## 보상 공 5종은 이 껍질을 재사용한다

`docs/ball_guides/variants/extract.py` 가 확정본에서 손그림 윤곽선을 각도별 배열로 뽑아
5종에 그대로 쓴다. 새로 5번 생성하지 않는다 → [[ball-reward-variants]]
