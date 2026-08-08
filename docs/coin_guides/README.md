# 코인 아트

> 2026-08-08 · Leonardo Nano Banana 2, 1배치(320 크레딧), 후보 4 중 2번 확정.

## 최종본

- `Resources/Art/coin/coin.png` — 1024×1024, **알파 bbox == 캔버스**
- 사본: `docs/coin_guides/final/coin.png` · 후보 전량: `candidates/unmasked/`

## 컨셉

낡은 오락기 토큰. 세계관("고장난 장난감 오락기 + 태엽 기계")의 재화라서
중앙 각인은 **태엽 열쇠**다. 기능색 원칙(보상·성공 = 금색)에 맞는
저채도 골드/황동이고, 무딘 톱니 림과 흠집 몇 개로 낡음을 만든다.

**28px 로 표시되는 오브젝트다.** 그래서 굵은 엠블럼 하나만 넣고 잔디테일을
금지했다. 후보 4장 중 28px 축소 대조에서 가장 잘 읽히는 것을 골랐다
(0번은 측면 두께가 보여 top-down 위반, 1번은 톱니가 뭉개짐).

## 적용 방법 (코인 시스템 담당자에게)

`scripts/coin_system/coin_pickup.gd` 가 "아트 확정 전이라 _draw() 자리표시자"
라고 적어 뒀다 — 이 파일이 그 확정본이다. 코인 시스템은 main 에 있고
`resource/art` 에는 없어서 씬 수정은 그쪽에서 해야 한다.

```gdscript
# coin_pickup.tscn 에 Sprite2D 를 추가하고:
texture = res://Resources/Art/coin/coin.png
scale = Vector2.ONE * (visual_radius * 2.0 / 1024.0)   # 기본 28/1024
# _draw() 자리표시자는 제거하거나 texture 유무로 분기
```

bbox == 캔버스라 `visual_radius * 2 / 텍스처 긴 변` 계산이 그대로 맞는다
(범퍼·공과 같은 규약). 여백이 없으므로 표시 지름 = 충돌 지름이다.
