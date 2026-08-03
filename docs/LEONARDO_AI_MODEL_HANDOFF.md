# Leonardo.Ai Pro 및 핀볼로그 아트 제작 인계 문서

> 대상: 이 프로젝트를 이어서 작업할 Claude 또는 다른 AI 에이전트
> 최종 검증일: 2026-08-03 (Asia/Seoul)
> 검증 자료: Leonardo.Ai 공식 REST API 문서, 사용자의 Leonardo Pro 생성 화면, 최신 기획 PDF 3종 전체 페이지

## 1. 목적과 필수 작업 원칙

이 문서는 Leonardo.Ai 모델별 설정과 핀볼로그의 최신 아트·보드·공·VFX·SFX 규격을 혼동하지 않고 이어서 작업하기 위한 인계 자료다.

반드시 다음 원칙을 지킨다.

1. 사용자의 명시적인 지시 전에는 이미지, 프롬프트, 에셋을 임의로 생성하거나 수정하지 않는다.
2. Jira는 이 작업 범위에서 제외한다.
3. 사용 모델을 먼저 확정하고 그 모델이 실제로 지원하는 옵션만 안내한다.
4. Leonardo 웹 UI에 입력란이 보인다는 이유만으로 모델의 네이티브 기능이라고 단정하지 않는다.
5. 정확한 좌표·크기·각도는 AI 생성 이미지가 아니라 최신 PDF의 수치표를 기준으로 한다.
6. 보드 아트, 고정벽, 플리퍼, 게임 오브젝트, 외부 배경, VFX는 서로 다른 레이어와 리소스로 제작한다.
7. 모델과 UI는 변경될 수 있으므로 실제 생성 직전에 현재 UI와 공식 문서를 다시 확인한다.

## 2. 자료 우선순위

자료가 충돌하면 다음 순서로 판단한다.

1. 사용자가 가장 최근에 제공한 명시적 지시
2. 2026-08-03 최신 비주얼·사운드 방향성 가이드의 확정 수치와 체크리스트
3. 다각형 외곽 플리퍼 시스템 기획서
4. 핀볼로그 컨셉기획서
5. 최신 보드 규격 이미지
6. 분위기·스타일 레퍼런스 이미지
7. 과거 대화에서 사용된 임시 수치와 AI 생성 결과

과거의 `1912×1072`, 외곽 여백 `4px`, 대각 `17.1도` 보드 규격은 폐기한다. 최신 기준은 `2240×1260`, 외곽 여백 `0px`다.

## 3. 원본 자료

### 3.1 최신 기획 PDF

- 비주얼·사운드 방향성 가이드: `docs/source_materials/pdfs/pinball_visual_sound_direction_guide_2026-08-03.pdf`
- 플리퍼 시스템 기획서: `docs/source_materials/pdfs/polygon_flipper_system_plan_v2.pdf`
- 컨셉기획서: `docs/source_materials/pdfs/pinballogue_concept_plan_v0.1.pdf`

### 3.2 2026-08-03 PDF 비교 결과

- 플리퍼 시스템 기획서 `(1)`은 기존 파일과 파일 크기 및 SHA-256 해시가 완전히 동일하다.
- 컨셉기획서 `(1)`은 기존 파일과 파일 크기 및 SHA-256 해시가 완전히 동일하다.
- 비주얼·사운드 방향성 가이드는 22쪽에서 75쪽으로 확장됐다.
- 최신 가이드의 1~20쪽은 기존 가이드와 동일하다.
- 기존의 `3. 공 (예정)`이 공 비주얼·VFX·SFX 완성 규격으로 대체됐다.
- `4. 보드/벽/보드 밖 배경` 장이 새로 추가됐다.

### 3.3 주요 이미지 레퍼런스

- 비주얼 가이드: `docs/source_materials/images/visual_direction_guide.png`
- 비주얼 가이드 및 플리퍼 컨셉 시트: `docs/source_materials/images/visual_and_flipper_concept_sheet.png`
- 현재 게임 플리퍼: `docs/source_materials/images/current_game_flipper.png`
- 과거 보드 도식: `docs/source_materials/images/legacy_board_diagram.png`

위 자료는 저장소 안에 보관한다. 파일이 없으면 사용자에게 다시 첨부해 달라고 요청하고 임의 대체하지 않는다. 좌표는 레퍼런스 PNG보다 최신 PDF를 우선한다.

### 3.4 Confluence

- `https://iambiguity.atlassian.net/wiki/spaces/~712020ee2aad7553a24fbdbcd73713654d1e91/pages/15269907/Hire+us+Pls`

필요한 경우 페이지와 하위 페이지를 읽되 Jira 작업은 하지 않는다.

## 4. 전체 아트 방향

핵심은 `아기자기하지만 불길한 저주받은 장난감 핀볼`이다.

- 다크 카툰풍이며 지나치게 사실적이지 않다.
- 작은 디테일보다는 큰 실루엣과 역할이 먼저 읽혀야 한다.
- 완벽한 대칭보다 약간 비뚤어지고 과장된 수작업 형태를 사용한다.
- 눈, 이빨, 가시는 위험 오브젝트와 캐릭터성에 사용할 수 있다.
- 보드 플레이 면에는 세계관 장식을 사용하지 않는다.
- 공 → 선택된 플리퍼 → 공격 대상 → 위험 요소의 순서로 시선이 이동해야 한다.

기능색:

- 청록·아이보리: 공과 플레이어 조작물
- 빨강·핑크: 피해와 위험
- 노랑·금색: 보상과 성공
- 보라·라임: 저주와 특수 상태

화면 색상 비중의 기본 방향:

- 60%: 어두운 배경과 보드
- 25%: 테마 주조색
- 10%: 공·플리퍼 등 조작 피드백
- 5%: 보상·필살·잭팟 연출

## 5. 공 비주얼 규격

### 5.1 정체성과 형태

공은 금속 구슬이 아니라 `플리퍼의 커다란 눈과 같은 장난감에서 떨어져 나온 살아 움직이는 마법 유리눈`이며 플레이어 그 자체다.

- 완전한 원형 외곽 실루엣 유지
- 큰 청록색 홍채
- 검고 둥근 동공
- 아이보리색 외곽
- 크고 강한 흰색 하이라이트 1개
- 짙은 남색 외곽선
- 약간 비뚤어진 수작업 카툰 선
- 사실적인 안구·혈관·고어 표현 금지
- 기본 공에 속눈썹·촉수·가시처럼 외곽을 깨는 장식 금지

플리퍼의 눈과 구분한다.

- 플리퍼 눈: 기계에 박힌 불투명 회전축, 선택 상태 표시
- 플레이어 공: 보드 위를 자유롭게 움직이는 투명·발광 유리구슬, 현재 위치·속도·강화 상태 표시

### 5.2 크기

- 실제 충돌 반지름: 22px
- 공 본체 지름: 약 44px
- VFX 포함 시각 반지름: 약 30px
- VFX 포함 전체 지름: 약 60px
- 22~30px 영역은 글로우·외곽 링·잔상 전용

### 5.3 재질과 생명감

- 사실적 유리 셰이더보다 카툰 유리구슬로 표현한다.
- 큰 하이라이트 1개, 작은 보조 하이라이트 최대 1개
- 내부 홍채가 가려지지 않는 약한 투명도
- 기본 상태 균열은 최대 1~2개이며 프로토타입에서는 제작하지 않는다.
- 동공 이동·깜빡임은 있으면 좋지만 프로토타입 우선순위가 아니다.

## 6. 공 VFX 및 SFX

공 VFX 종류는 다음 세 묶음으로 제한한다.

1. 발광 테두리: 공 위치와 상태 표시, 항상 유지
2. 이동 꼬리: 이동 방향과 속도 표시
3. 패링 원형 파동: 정확한 패링 성공 순간에만 사용

새 상태마다 VFX 종류를 계속 추가하지 않는다. 색상·밝기·길이·형태만 조절한다.

### 6.1 발광 테두리

- 공 외곽 반지름 약 28~30px
- 원형으로 읽혀야 한다.
- 카툰식으로 약간 끊기고 흔들리는 전기 링은 허용한다.
- 큰 가시나 번개가 공 실루엣을 깨면 안 된다.

### 6.2 이동 꼬리

- 여러 공 복사본보다 하나의 연속된 혜성 꼬리로 제작한다.
- 일반 이동 권장 길이: 60~100px
- 공 뒤에서 시작해 끝으로 갈수록 가늘고 투명해진다.
- 실제 이동 경로를 따라 휘어져야 한다.
- 멈춤·발사 대기 중에는 꼬리를 표시하지 않는다.

### 6.3 패링 원형 파동

- 일반 플리퍼 타격에는 사용하지 않는다.
- 시작 반지름: 약 25~30px
- 종료 반지름: 약 90~120px
- 전체 지속 시간: 약 0.12~0.20초
- 중심 플래시: 약 0.03~0.06초
- 주요 링 두께: 약 4~8px
- 주요 색상: 밝은 청록 + 아이보리·금색
- 빨강을 주색으로 쓰면 피해 연출로 오해할 수 있으므로 금지한다.

### 6.4 사운드 우선순위

1. 정확한 패링
2. 보스 타격
3. 플리퍼 타격
4. 공과 주요 범퍼 충돌
5. 일반 벽 충돌
6. 환경음과 장식 장치음

## 7. 공통 캔버스 및 화면 규격

| 항목 | 확정값 |
|---|---:|
| 기준 월드 캔버스 | 2240×1260px |
| 화면 비율 | 16:9 |
| Camera2D Zoom | 0.857 |
| 최종 출력 | 약 1920×1080px |
| 보드 외곽 여백 | 0px |
| 보드 중심 | (1120, 630) |

보드·벽·플리퍼 좌표는 모두 2240×1260 기준으로 작업한다. 보드의 일부 꼭짓점 또는 변이 캔버스 끝에 직접 닿는다.

## 8. 사각형 보드 확정 규격

명칭은 사각형 보드지만 실제로는 8변 구조다.

### 8.1 꼭짓점

| 지점 | 위치 | 좌표 |
|---|---|---:|
| P1 | 상단 좌측 | (770, 0) |
| P2 | 상단 우측 | (1470, 0) |
| P3 | 우측 상단 | (2240, 280) |
| P4 | 우측 하단 | (2240, 980) |
| P5 | 하단 우측 | (1470, 1260) |
| P6 | 하단 좌측 | (770, 1260) |
| P7 | 좌측 하단 | (0, 980) |
| P8 | 좌측 상단 | (0, 280) |

### 8.2 경계

| 구간 | 기능 | 길이 | 각도 |
|---|---|---:|---:|
| P1-P2 | 상단 플리퍼 그룹 | 700px | 0° |
| P2-P3 | 우상단 고정벽 | 약 819.3px | 약 20° |
| P3-P4 | 우측 플리퍼 그룹 | 700px | 90° |
| P4-P5 | 우하단 고정벽 | 약 819.3px | 약 -20° |
| P5-P6 | 하단 플리퍼 그룹 | 700px | 180° |
| P6-P7 | 좌하단 고정벽 | 약 819.3px | 약 20° |
| P7-P8 | 좌측 플리퍼 그룹 | 700px | 90° |
| P8-P1 | 좌상단 고정벽 | 약 819.3px | 약 -20° |

제작 적용값:

- 대각 고정벽 이미지: 820px
- 좌표 계산 길이: 약 819.3px
- 구현 오차: 약 -0.7px
- 플리퍼 그룹: 4개, 각 700px
- 고정벽: 4개

물리는 꼭짓점 좌표를 기준으로 하고 아트 리소스는 820px로 제작해도 된다.

## 9. 삼각형 보드 확정 규격

명칭은 삼각형 보드지만 실제로는 6변 구조다.

### 9.1 꼭짓점

| 지점 | 위치 | 좌표 |
|---|---|---:|
| P1 | 상단 좌측 | (509, 0) |
| P2 | 상단 우측 | (1731, 0) |
| P3 | 우측 중앙 | (2240, 509) |
| P4 | 하단 우측 | (1450, 1260) |
| P5 | 하단 좌측 | (790, 1260) |
| P6 | 좌측 중앙 | (0, 509) |

### 9.2 경계

| 구간 | 기능 | 길이 | 각도 |
|---|---|---:|---:|
| P1-P2 | 상단 고정벽 W1 | 1222px | 0° |
| P2-P3 | 우상단 플리퍼 그룹 | 약 719.8px | 45° |
| P3-P4 | 우하단 고정벽 W2 | 약 1090px | 43.5° |
| P4-P5 | 하단 플리퍼 그룹 | 660px | 0° |
| P5-P6 | 좌하단 고정벽 W3 | 약 1090px | 43.5° |
| P6-P1 | 좌상단 플리퍼 그룹 | 약 719.8px | 45° |

제작 적용값:

- W1 상단 고정벽: 1222px
- W2·W3 하단 대각 고정벽: 각 1090px
- 상단 좌우 플리퍼 그룹: 각 720px, ±45°
- 하단 플리퍼 그룹: 660px
- 고정벽: 3개
- 플리퍼 그룹: 3개

## 10. 보드 표면 비주얼 규칙

보드는 공의 위치·이동 방향·빈 경로·충돌 경계를 보여주는 저대비 플레이 면이다. 세계관 설명이나 캐릭터성을 담당하지 않는다.

허용:

- 단색 또는 매우 약한 명도 변화
- 저대비 무광 재질
- 벽 인접 영역의 부드러운 음영
- 넓고 흐릿한 색 얼룩
- 화면 전체 대비 3~5% 이내의 약한 질감
- 외곽으로 갈수록 조금 어두워지는 그라데이션
- 플레이 영역을 구분하는 외곽 마스킹

금지:

- 눈, 이빨, 입, 촉수
- 별, 달, 카드, 서커스 문양
- 단추, 나사, 봉제선
- 저주 균열, 마법진
- 판자 틈, 강한 나뭇결
- 긴 스크래치
- 화살표처럼 보이는 장식
- 공 잔상처럼 보이는 밝은 선
- 중앙 방사형 패턴
- 보스·캐릭터·장난감·제단·범퍼·타깃을 보드 베이스에 합치는 것

보드 색상은 선명한 청록이 아니라 `청록을 줄인 짙고 탁한 먹빛 청회색`으로 제작한다.

시각 우선순위:

1. 공
2. 선택된 플리퍼
3. 공격 대상·위험 요소
4. 범퍼·게임 장치
5. 고정벽 안쪽 경계
6. 보드
7. 보드 밖 배경

## 11. 고정벽 제작 규격과 9-slice

고정벽은 세계관 장식보다 충돌 경계 전달을 우선한다.

| 항목 | 제작 기준 |
|---|---:|
| 벽 시각 두께 | 40px |
| 기본 충돌체 두께 | 24px |
| 안쪽 경계선 | 4px |
| 바깥 그림자 | 6px |
| 꼭짓점 커넥터 | 64×64px |
| 반복 몸통 마스터 | 256×40px |
| 끝 캡 | 64×40px, 2종 |

적용 방식:

- 벽 길이별 완성 이미지를 전부 생성하지 않는다.
- 반복 가능한 몸통 타일 + 양 끝 캡 + 꼭짓점 커넥터로 구성한다.
- 구간 길이에 맞게 Godot에서 타일링 또는 9-slice를 적용한다.
- Leonardo.Ai가 9-slice 마진과 엔진 데이터를 자동 생성하지는 않는다.
- Leonardo에서는 반복 가능한 벽 몸통, 끝 캡, 코너를 각각 생성·정리한다.
- 실제 9-slice 마진은 Godot `NinePatchRect` 또는 `StyleBoxTexture`에서 설정한다.
- 삼각형의 경사각처럼 기하가 중요한 전체 보드에는 9-slice를 적용하지 않는다.

안쪽 충돌면:

- 평평하고 일정한 어두운 색면
- 4px 얇은 경계선
- 짧고 낮은 대비의 마모
- 충돌 순간의 짧은 점등

금지:

- 안쪽으로 돌출되는 눈·이빨
- 공처럼 보이는 원형 장식
- 충돌면을 침범하는 나사
- 별·달·저주 문양
- 긴 밝은 균열
- 반복되는 얼굴
- 실제 충돌체와 다른 굴곡

### 11.1 벽 충돌 SFX

- 기본 음원: 3종
- 길이: 0.06~0.14초
- 피치 랜덤: ±5%
- 최대 동시 재생: 4개
- 동일 공 재생 간격: 최소 0.04초
- 패링음 대비 볼륨: 약 -8~-10dB
- 잔향 없음 또는 극소량
- 연속 충돌 두 번째 소리부터 약 3dB 감소

무거운 금속 쾅, 폭발음, 긴 금속 잔향, 강한 저음, 매 충돌 전기음은 금지한다.

## 12. 보드 밖 배경

보드 밖 배경은 분위기와 보드 외부 영역 분리를 담당한다. 구체적인 세계관 오브젝트를 배치하지 않는다.

확정 규격:

- 리소스 크기: 2240×1260px
- 방사 중심: (1120, 630)
- 방사 조각: 24개, 어두운 12개 + 상대적으로 밝은 12개
- 기본 애니메이션 없음
- 카메라 패럴랙스 없음
- 웨이브 변화는 색상·명도·채도만 사용
- 배경은 전체 캔버스에 배치하고 불투명 보드 마스크가 위에서 가린다.

팔레트:

- 먹색·남색 55%
- 버건디·짙은 보라 30%
- 탁한 아이보리 10%
- 미세한 포인트색 5%

금지:

- 큰 눈·얼굴·캐릭터
- 움직이는 촉수·장난감 부품
- 공처럼 보이는 원형 오브젝트
- 밝은 저주 코어
- 선명한 빨강·순백색의 높은 대비
- 청록 방사선
- 회전·지속 확대·축소
- 보드 내부에 방사형 패턴이 보이는 것

## 13. 웨이브별 변화

보드 표면은 모든 웨이브에서 같은 색상과 밝기를 유지한다. 같은 리소스에 색상 프리셋과 셰이더 값만 변경한다.

| 레이어 | 색상 변화 강도 |
|---|---:|
| 보드 밖 배경 | 100% |
| 벽 외측 | 50% |
| 벽 안쪽 충돌면 | 10~15% |
| 보드 표면 | 0% |
| 공 | 0% |
| 선택된 플리퍼 | 0% |
| 공격 가능 목표물 | 자체 상태 사용 |

프리셋:

- 웨이브 1: 기본 남색 + 탁한 버건디
- 웨이브 2: 보라·버건디 증가, 배경 밝기 -5%, 비네트 약 8% 강화
- 웨이브 3: 짙은 보라·버건디, 배경 밝기 -10%, 비네트 약 15% 강화
- 보스: 먹색 + 짙은 진홍, 배경 밝기 -15%, 비네트 약 25% 강화
- 클리어: 벽 기본 남색 복귀, 따뜻한 아이보리·금색 플래시 0.5~1초 후 웨이브 1로 안정

## 14. 권장 구현 레이어

1. OutsideBackground
2. OutsideBackgroundVignette
3. BoardBase
4. FixedWallBase
5. FixedWallOuterTint
6. FlipperGroups
7. GameplayObjects
8. Ball
9. GameplayVFX
10. UI

구현 원칙:

- 보드마다 별도 Polygon2D 또는 보드 마스크 사용
- 외부 배경은 공통 리소스 하나를 재사용
- 웨이브 변화는 배경과 벽 외측에만 적용
- 전체 CanvasModulate로 공과 플리퍼까지 어둡게 하지 않음
- 색상 변화는 셰이더 파라미터 또는 `self_modulate` 사용

## 15. 레퍼런스 이미지 해석 규칙

최신 PDF에 추가된 레퍼런스는 다음처럼 해석한다.

### 공·VFX 레퍼런스

- 참고: 전기 원형 링, 공을 감싸는 발광, 긴 이동 꼬리, 패링 원형 파동의 방향
- 복사 금지: 사실적 광원, 모든 색을 한 공에 동시에 쓰는 무지개 효과, 공보다 강한 파티클
- 기본 공은 청록·아이보리이며 금색은 성공 상태에 제한한다.

### 외부 배경 레퍼런스

- 참고: 다크 서커스 방사형 구도, 오래된 천막·종이 질감, 외곽 비네트
- 복사 금지: 밝은 빨강·순백색, 보드 내부까지 침범하는 방사 패턴, 회전 애니메이션

### 보드·벽 레퍼런스

- 참고: 넓고 빈 플레이 면, 모듈형 벽 몸통·끝 캡·코너, 어두운 장난감 프레임
- 복사 금지: 보드 위 눈·별·해골·장난감·문양·나사·장식 오브젝트
- 레퍼런스 이미지에 장식이 있어도 최신 텍스트 규격의 `보드에는 세계관 장식을 넣지 않는다`가 우선한다.

## 16. 2026-08-02 확인 Leonardo Pro 모델 목록

Featured:

- Auto
- GPT Image 2
- Nano Banana 2
- Nano Banana 2 Lite
- Krea 2 Turbo
- Seedream 5.0 Pro
- Lucid Origin
- Nano Banana Pro

Other:

- Ideogram 4.0
- Recraft V4 / Recraft V4 Pro
- Seedream 4.5 / 4.0
- FLUX.2 Pro
- GPT Image-1.5 / GPT Image-1
- Nano Banana
- Lucid Realism
- Ideogram 3.0
- FLUX.1 Kontext Max / Kontext
- FLUX Dev / Schnell
- Phoenix 1.0 / 0.9
- Anime, Cinematic Kino, Concept Art, Graphic Design, Illustrative Albedo
- Leonardo Lightning, Lifelike Vision, Portrait Perfect, Stock Photography

## 17. 모델별 Reference 체계

### 17.1 역할 분리형

Phoenix 1.0 / 0.9:

- Image-to-Image 최대 1장, `LOW/MID/HIGH`
- Content Reference 최대 1장, `LOW/MID/HIGH`
- Character Reference 최대 1장, `LOW/MID/HIGH`
- Style Reference 최대 4장, `LOW/MID/HIGH/ULTRA/MAX`

Lucid Origin / Lucid Realism:

- Content Reference 최대 1장, `LOW/MID/HIGH`
- Style Reference 최대 1장, `LOW/MID/HIGH/ULTRA/MAX`

### 17.2 통합 Image Reference형

| 모델 | 최대 장수 | Strength |
|---|---:|---|
| GPT Image 2 | 6 | 없음 |
| GPT Image-1.5 | 6 | LOW/MID/HIGH |
| Nano Banana 2 / Lite / Pro / 기본 | 6 | LOW/MID/HIGH |
| Seedream 5.0 Pro | 10 | LOW/MID/HIGH |
| Seedream 4.5 / 4.0 | 6 | LOW/MID/HIGH |
| FLUX.2 Pro | 4 | LOW/MID/HIGH |
| FLUX.1 Kontext Max / Kontext | 4 | LOW/MID/HIGH |

통합형은 Content와 Style 슬롯이 분리되지 않는다. 프롬프트에 이미지별 역할을 명시한다.

예:

- Reference 1: exact geometry and silhouette only
- Reference 2: palette and surface treatment only
- Reference 3: line quality and dark-cartoon mood only
- Do not copy objects, eyes, toys, symbols, text, or scenery from style references

GPT Image 2에는 Reference Strength를 안내하면 안 된다.

## 18. 주요 Leonardo 모델 설정

| 모델 | 주요 설정 | 16:9 UI 해상도 또는 공식 제한 |
|---|---|---|
| GPT Image 2 | Prompt Enhance, Style, Quality Low/Medium/High, 수량 1~8, Image Ref 6장, Seed 없음 | 1376×768 / 2048×1136 / 3584×2016 |
| Nano Banana 2 | Prompt Enhance, Style, Fixed Seed, 수량 1~8, Image Ref 6장 | 1376×768 / 2752×1536 / 5504×3072 |
| Lucid Origin | Prompt Enhance, Style, Fast/Ultra, Fixed Seed, Content 1 + Style 1 | 1376×768 / 1600×896 / 1920×1088 |
| Phoenix 1.0 | Prompt Enhance, Style, Contrast, Fast/Quality/Ultra, Fixed Seed, Negative | 1184×672 / 1376×768 / 1472×832 |
| Krea 2 Turbo | Prompt Enhance, 해상도, 수량; Style·Quality·Reference·Seed 없음 | 1376×768 / 2064×1152 / 2752×1536 |
| Seedream 5.0 Pro | Image Ref 10장, Prompt Enhance, Seed, PNG/JPEG, 수량 1~6 | Width/Height 768~2048 |
| FLUX.2 Pro | Image Ref 4장, Prompt Enhance, Style, Seed | 공식 16:9 1440×810 |
| GPT Image-1.5 | Image Ref 6장, Quality, Prompt Enhance, Seed | 1024×1024 / 1024×1536 / 1536×1024, 16:9 없음 |
| Recraft V4 | Prompt Enhance, 수량 1~6, 고정 해상도 | 1344×768 |
| Recraft V4 Pro | Prompt Enhance, 수량 1~6, 고정 해상도 | 2688×1536 |
| Ideogram 4.0 | Prompt Enhance, Quality, Custom Dimensions, 수량 1~4 | UI에서 선택 |

모델별 상세 공식 문서는 23절 링크를 확인한다.

## 19. Negative Prompt와 Prompt Enhance

Phoenix 1.0 / 0.9는 공식 API에 `negative_prompt`가 명시되어 있다. 일부 레거시 모델도 지원한다.

다음 최신 모델은 UI에 Negative Prompt 입력란이 남아 있어도 네이티브 지원을 단정하지 않는다.

- GPT Image 계열
- Nano Banana 계열
- Seedream 계열
- Krea 2 Turbo
- Recraft V4 계열
- FLUX 계열
- Lucid 계열

핵심 금지 조건은 Positive Prompt에도 자연어 문장으로 작성한다.

```text
Keep the entire board surface empty and unobstructed. Do not add flippers,
walls, rails, bumpers, targets, eyes, characters, symbols, text, props,
wooden plank seams, ritual markings, or raised objects to the board base.
```

정확한 기하와 빈 보드 작업에서는 Prompt Enhance를 `Off`로 둔다.

- On: 프롬프트 확장으로 장식이 추가될 위험이 있음
- Auto: 짧은 프롬프트가 확장될 수 있음
- Off: 작성한 제약을 그대로 전달하기 가장 유리

## 20. 프롬프트 길이

| 모델 | 확인된 최대 길이 |
|---|---:|
| Phoenix 1.0 / 0.9 | 2,000자 |
| Lucid Origin | 2,000자 |
| Lucid Realism | 9,999자 |
| FLUX.1 Kontext Max | 9,999자 |
| Krea 2 Turbo | UI 9,999자 |
| Ideogram 4.0 | UI 10,000자 |

나머지 모델은 추측하지 않고 실제 입력창 `maxlength`나 공식 문서를 확인한다.

## 21. 모델 선택과 Reference 배치

### Phoenix 1.0

- 확정 보드 도식 → Content Reference `HIGH`
- 비주얼 가이드 → Style Reference `LOW/MID`
- Prompt Enhance `Off`
- 탐색 `Fast`, 후보 확정 후 `Quality/Ultra`
- 네이티브 Negative Prompt 사용 가능

### Lucid Origin

- 확정 보드 도식 → Content Reference `HIGH`
- 가장 적합한 스타일 이미지 한 장 → Style Reference `MID`
- Style Reference는 한 장만 가능
- Prompt Enhance `Off`

### GPT Image 2

- 도식과 스타일 가이드를 모두 Image Reference로 추가
- Strength를 지정하지 않음
- 프롬프트에서 각 Reference 역할을 순서대로 명시
- Prompt Enhance `Off`
- 구조 검증 `Medium`, 최종 후보 `High`

### Nano Banana 2

- 확정 보드 도식 → Image Reference `HIGH`
- 스타일 가이드 → `LOW/MID`
- Prompt Enhance `Off`
- Fixed Seed는 동일 구도의 변형 비교에만 사용

AI 모델은 좌표를 정확히 보존하는 CAD 도구가 아니다. 최종 보드 마스크와 벽 좌표는 Godot의 Polygon2D·CollisionPolygon2D에서 수치로 구현한다.

## 22. 검수 체크리스트

### 공통 화면

- 기준 캔버스가 2240×1260인가?
- Camera2D Zoom 0.857 기준인가?
- 보드 외곽 여백이 0px인가?
- 모든 꼭짓점이 확정 좌표와 일치하는가?

### 사각형 보드

- 상·하·좌·우 플리퍼 그룹이 각각 700px인가?
- 네 대각 고정벽이 약 819.3px인가?
- 제작 적용 길이가 820px인가?
- 대각 각도가 약 20°인가?

### 삼각형 보드

- 상단 고정벽이 1222px인가?
- 하단 대각 고정벽이 각각 1090px인가?
- 상단 좌우 플리퍼가 약 720px, ±45°인가?
- 하단 플리퍼가 660px인가?
- 하단 벽 각도가 약 43.5°인가?

### 보드 표면

- 보드에 세계관 장식이 없는가?
- 눈·별·마법진·나사·판자 틈이 없는가?
- 공의 경로로 오해할 밝은 선이 없는가?
- 저대비 청회색 무광 면인가?
- 플리퍼·벽·범퍼·VFX가 별도 레이어인가?

### 고정벽

- 안쪽 충돌면이 평평하고 명확한가?
- 시각 두께 40px, 충돌체 24px 기준인가?
- 안쪽 경계선 4px이 공·선택 플리퍼보다 어두운가?
- 타일·캡·커넥터가 끊김 없이 연결되는가?
- 실제 충돌체와 아트 굴곡이 일치하는가?

### 공·VFX

- 실제 게임 크기에서 공이 가장 먼저 보이는가?
- 플리퍼의 눈과 공이 구분되는가?
- 공 본체와 VFX 중심이 일치하는가?
- 최고 속도에도 이동 방향을 읽을 수 있는가?
- 일반 충돌과 정확한 패링이 시각·사운드로 구분되는가?

### 외부 배경

- 방사 중심이 (1120, 630)인가?
- 방사 패턴이 보드 밖에서만 보이는가?
- 24분할 저채도 패턴인가?
- 공·플리퍼·보스보다 어두운가?
- 회전·패럴랙스·지속 애니메이션이 없는가?

## 23. Leonardo 공식 문서

- Phoenix: https://docs.leonardo.ai/docs/phoenix
- Lucid Origin: https://docs.leonardo.ai/docs/lucid-origin
- Lucid Realism: https://docs.leonardo.ai/me/docs/lucid-realism
- GPT Image 2: https://docs.leonardo.ai/me/docs/gpt-image-2
- GPT Image-1.5: https://docs.leonardo.ai/me/docs/gpt-image-1-5
- Nano Banana 2: https://docs.leonardo.ai/docs/nano-banana-2
- Nano Banana 2 Lite: https://docs.leonardo.ai/docs/nano-banana-2-lite
- Nano Banana Pro: https://docs.leonardo.ai/me/docs/nano-banana-pro
- Seedream 5.0 Pro: https://docs.leonardo.ai/docs/seedream-50-pro
- Seedream 4.5: https://docs.leonardo.ai/me/docs/seedream-4-5
- Seedream 4.0: https://docs.leonardo.ai/docs/seedream-4-0
- FLUX.2 Pro: https://docs.leonardo.ai/docs/flux-2-pro
- FLUX.1 Kontext Max: https://docs.leonardo.ai/docs/flux1-kontext-max
- Krea 2 Turbo: https://docs.leonardo.ai/docs/krea-2-turbo
- Ideogram 3.0: https://docs.leonardo.ai/docs/ideogram-30
- Recraft V4: https://docs.leonardo.ai/v1.0/docs/recraft-v4
- Recraft V4 Pro: https://docs.leonardo.ai/v1.0/docs/recraft-v4-pro
- Image Guidance: https://docs.leonardo.ai/docs/generate-images-using-image-to-image-guidance

## 24. 작업 절차와 불확실성 처리

새 이미지 작업을 요청받으면 다음 순서를 따른다.

1. 결과물이 보드 베이스, 벽, 플리퍼, 공, 범퍼, VFX, 외부 배경 중 무엇인지 확인한다.
2. 좌표가 필요한 구조물은 Godot 수치 구현과 AI 생성 영역을 구분한다.
3. 사용할 Leonardo 모델을 명시한다.
4. 해당 모델의 현재 UI에서 지원 옵션을 재확인한다.
5. Reference 역할과 장수 제한을 확인한다.
6. Prompt Enhance, Style, Quality/Mode, 해상도, 수량, Seed를 모델에 맞게 제안한다.
7. 입력 한도 안에서 Positive Prompt를 작성한다.
8. 네이티브 Negative Prompt 지원 여부를 구분한다.
9. 사용자의 승인 또는 명시적 생성 지시 전에는 생성하지 않는다.

불확실성 처리:

- 공식 문서와 UI가 다르면 실제 Pro UI에 노출된 설정을 우선하되 차이를 기록한다.
- API에 없는 UI 옵션은 프런트엔드 래퍼일 수 있으므로 네이티브 기능이라고 표현하지 않는다.
- 공식 문서에 없는 Strength·Seed·해상도·글자 수를 추측하지 않는다.
- 모델 업데이트 후 검증 날짜와 변경 내용을 갱신한다.
- 사용자가 최신 스펙이나 레퍼런스를 새로 제공하면 이 문서보다 최신 사용자 자료를 우선한다.
