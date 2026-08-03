---
name: prompt-style-drift
description: 사진풍 레퍼런스를 말로 그대로 옮기면 카툰 방향을 잃는다 — 2026-08-02 실수와 교정
type: feedback
---

# 레퍼런스를 묘사하지 말고 화풍 언어로 번역하라

2026-08-02, 형락님이 "난 카툰 풍을 원했는데"라고 지적. 내가 쓴 보드 텍스처 프롬프트가 사진풍 결과를 냈다.

## 무엇이 잘못됐나

형락님이 준 보드 레퍼런스 8장이 대부분 사진풍·페인터리였다. 나는 그 표면을 **문자 그대로 묘사**해서 프롬프트를 썼다:

> `worn chalkboard`, `chalky mottling`, `broad worn patches where the paint has thinned`, `weathered painted panel`

이 단어들이 전부 사실적 질감 쪽으로 모델을 끌어당겼다. **프로젝트 방향은 처음부터 "다크 카툰"** 이었는데 레퍼런스에 휩쓸려 거기서 벗어났다.

## 규칙

**레퍼런스에서 가져올 것은 팔레트와 낡은 정도지, 렌더링 방식이 아니다.**

Why: 형락님이 레퍼런스를 주는 건 "이 분위기"라는 뜻이지 "이 그림체"라는 뜻이 아니다. 확정된 화풍(다크 카툰, 굵은 잉크선, 평탄 셀)이 이미 있으면 그게 상위 규칙이다.

How to apply:
1. 레퍼런스를 보고 **팔레트·명도·낡은 정도**만 뽑는다
2. 그걸 프로젝트의 화풍 언어로 **번역**해서 쓴다 — `flat cel`, `hand-inked`, `vector-like solid fills`, `individually countable hand-drawn strokes`
3. 사실적 질감 단어를 **금지 문단으로 명시**한다 — `no photographic texture, no grunge overlay, no dirt map, no noise, no rendering, no painterly blending`
4. 화풍이 목적이면 **화풍 레퍼런스가 Reference 1(HIGH)** 이어야 한다. 사진풍 원판을 Reference로 넣으면 계속 사진풍으로 끌려간다

## 부수 교훈

구도만 필요한 레퍼런스는 **이미지가 아니라 한 문장**으로 대체할 수 있는지 먼저 따진다.

2026-08-03 VFX 레퍼런스 5장도 전부 블룸 기반이었다. 구조(끊긴 원형 링, 흐르는 빛, 방사선, 혜성 꼬리)만 가져오고
소프트 글로우 대신 **알파가 다른 평탄한 링 2겹**으로 번역했다. 같은 규칙이 계속 통한다.

## 대응 산출물

`docs/board_guides/카툰_판자_목표.png` — 확정 플리퍼 팔레트로 **직접 그린** 목표 상태.
말로만 설명하지 말고 목표를 그려서 보여주면 레퍼런스로도 쓰이고 검수 기준도 된다.

관련: [[pinball-logue]], [[board-texture-direction]], [[workflow-rules]]
