from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "pdf"
OUT.mkdir(parents=True, exist_ok=True)

FONT_DIR = Path(r"C:\Windows\Fonts")
pdfmetrics.registerFont(TTFont("Malgun", str(FONT_DIR / "malgun.ttf")))
pdfmetrics.registerFont(TTFont("MalgunBold", str(FONT_DIR / "malgunbd.ttf")))

NAVY = colors.HexColor("#17324D")
TEAL = colors.HexColor("#2E7775")
MINT = colors.HexColor("#DDF0EC")
INK = colors.HexColor("#20252B")
MUTED = colors.HexColor("#66717B")
LINE = colors.HexColor("#CED7DC")
LIGHT = colors.HexColor("#F3F6F7")
GOLD = colors.HexColor("#B78A36")
TODO_BG = colors.HexColor("#FFF5D9")
TODO_TEXT = colors.HexColor("#795A12")


def make_styles():
    base = getSampleStyleSheet()
    styles = {
        "title": ParagraphStyle(
            "Title",
            parent=base["Normal"],
            fontName="MalgunBold",
            fontSize=25,
            leading=32,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=10,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Malgun",
            fontSize=12.5,
            leading=19,
            textColor=TEAL,
            alignment=TA_CENTER,
            spaceAfter=26,
        ),
        "kicker": ParagraphStyle(
            "Kicker",
            parent=base["Normal"],
            fontName="MalgunBold",
            fontSize=9,
            leading=12,
            textColor=GOLD,
            alignment=TA_CENTER,
            spaceAfter=14,
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=base["Normal"],
            fontName="MalgunBold",
            fontSize=16,
            leading=22,
            textColor=NAVY,
            spaceBefore=16,
            spaceAfter=8,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Normal"],
            fontName="MalgunBold",
            fontSize=12.5,
            leading=18,
            textColor=TEAL,
            spaceBefore=11,
            spaceAfter=6,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["Normal"],
            fontName="Malgun",
            fontSize=10.3,
            leading=16.2,
            textColor=INK,
            spaceAfter=6,
            wordWrap="CJK",
        ),
        "small": ParagraphStyle(
            "Small",
            parent=base["Normal"],
            fontName="Malgun",
            fontSize=8.3,
            leading=12.5,
            textColor=MUTED,
            spaceAfter=4,
            wordWrap="CJK",
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["Normal"],
            fontName="Malgun",
            fontSize=10.1,
            leading=15.7,
            textColor=INK,
            leftIndent=18,
            firstLineIndent=-10,
            bulletIndent=5,
            spaceAfter=4,
            wordWrap="CJK",
        ),
        "todo": ParagraphStyle(
            "Todo",
            parent=base["Normal"],
            fontName="MalgunBold",
            fontSize=9.4,
            leading=14.5,
            textColor=TODO_TEXT,
            spaceAfter=0,
            wordWrap="CJK",
        ),
        "table_header": ParagraphStyle(
            "TableHeader",
            parent=base["Normal"],
            fontName="MalgunBold",
            fontSize=8.8,
            leading=12.5,
            textColor=colors.white,
            alignment=TA_LEFT,
            wordWrap="CJK",
        ),
        "table": ParagraphStyle(
            "TableBody",
            parent=base["Normal"],
            fontName="Malgun",
            fontSize=8.5,
            leading=12.5,
            textColor=INK,
            wordWrap="CJK",
        ),
    }
    return styles


ST = make_styles()


class DraftDocTemplate(BaseDocTemplate):
    def __init__(self, filename: Path, short_title: str):
        super().__init__(
            str(filename),
            pagesize=letter,
            leftMargin=0.82 * inch,
            rightMargin=0.82 * inch,
            topMargin=0.75 * inch,
            bottomMargin=0.72 * inch,
            title=short_title,
            author="Pinball Logue Team",
            subject="NHN NAN 2026 사전 과제 제출 문서 초안",
        )
        self.short_title = short_title
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            leftPadding=0,
            rightPadding=0,
            topPadding=0,
            bottomPadding=0,
        )
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=self._page))

    def _page(self, canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(LINE)
        canvas.setLineWidth(0.5)
        canvas.line(self.leftMargin, 0.53 * inch, letter[0] - self.rightMargin, 0.53 * inch)
        canvas.setFont("Malgun", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(self.leftMargin, 0.32 * inch, f"{self.short_title} | DRAFT 2026-08-07")
        canvas.drawRightString(letter[0] - self.rightMargin, 0.32 * inch, f"{doc.page}")
        canvas.restoreState()


def p(text, style="body"):
    return Paragraph(text, ST[style])


def bullet(text):
    return Paragraph(f"• {text}", ST["bullet"])


def todo(text):
    cell = Table([[Paragraph(f"확정 필요  |  {text}", ST["todo"])]], colWidths=[6.75 * inch])
    cell.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), TODO_BG),
                ("BOX", (0, 0), (-1, -1), 0.7, colors.HexColor("#E7C86F")),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return cell


def title_block(kicker, title, subtitle):
    return [
        Spacer(1, 0.7 * inch),
        p(kicker.upper(), "kicker"),
        p(title, "title"),
        p(subtitle, "subtitle"),
        Spacer(1, 0.05 * inch),
    ]


def table(headers, rows, widths):
    data = [[Paragraph(h, ST["table_header"]) for h in headers]]
    data += [[Paragraph(str(v), ST["table"]) for v in row] for row in rows]
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                ("GRID", (0, 0), (-1, -1), 0.45, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT]),
            ]
        )
    )
    return t


def build_game_guide():
    out = OUT / "Pinball_Logue_게임소개및설명서_DRAFT.pdf"
    doc = DraftDocTemplate(out, "게임 소개 및 설명서")
    s = title_block(
        "NAN 2026 · 사전 과제 제출 문서",
        "PINBALL LOGUE",
        "눈을 잃은 장난감의 내부로 유리눈을 발사해 저주를 수리하는 다크 판타지 핀볼 로그라이트",
    )
    s += [
        todo("최종 표기 게임명, 팀명, 버전, GitHub Pages URL, YouTube URL을 입력해야 합니다."),
        Spacer(1, 18),
        p("문서 상태", "h2"),
        p("저장소의 메인 씬과 현재 구현 코드를 기준으로 작성한 제출용 초안입니다. 미완성 또는 향후 구현 범위는 확정 기능처럼 서술하지 않았습니다."),
        PageBreak(),
        p("1. 게임 개요", "h1"),
        p("Pinball Logue는 플레이어가 마법 유리눈을 조준·발사하고, 장난감 내부의 범퍼와 플리퍼를 이용해 연쇄 충돌과 콤보를 만드는 핀볼 로그라이트입니다. 웨이브마다 목표 점수를 달성해 저주를 해제하고, 마지막 근원 저주를 제거해 장난감에게 눈을 되돌려주는 과정을 다룹니다."),
        p("핵심 플레이 경험", "h2"),
        bullet("발사 각도와 세기를 정해 유리눈의 초기 경로를 설계합니다."),
        bullet("범퍼 연쇄 충돌로 점수와 콤보를 쌓습니다."),
        bullet("플리퍼를 선택·작동해 공의 경로를 바꾸고 정확한 패링을 노립니다."),
        bullet("서로 다른 물성을 가진 공과 수리 부품을 활용해 웨이브를 공략합니다."),
        p("세계관과 시각 방향", "h2"),
        p("한쪽 눈을 잃고 저주에 잠식된 장난감이 하나의 스테이지가 됩니다. 유리눈은 단순한 공이 아니라 장난감 내부를 보고 저주에 직접 닿을 수 있는 플레이어의 핵심 수단입니다. 둥근 장난감 형태와 큰 눈, 이빨, 태엽을 이용해 ‘귀엽지만 불길한’ 다크 카툰 분위기를 구성합니다."),
        p("2. 게임 목표와 진행", "h1"),
        table(
            ["단계", "플레이어 행동", "판정"],
            [
                ["수리 부품 배치", "보드 소켓과 사용할 부품을 선택", "배치 결과가 다음 플레이에 반영"],
                ["공 선택", "보유한 3개의 공 중 이번에 사용할 공을 선택", "각 공은 웨이브에서 1회 사용"],
                ["조준·발사", "좌우로 각도, 상하로 발사 세기를 조정 후 확정", "유리눈이 보드에 진입"],
                ["핀볼 진행", "플리퍼를 선택·작동하며 범퍼 연쇄 충돌 유도", "점수·콤보 누적"],
                ["웨이브 결과", "목표 점수 도달 여부 확인", "달성 시 다음 단계, 공 소진 시 실패"],
                ["스테이지 진행", "일반 웨이브 3회 이후 보스 단계 진행", "보스 완료 시 스테이지 완료"],
            ],
            [1.25 * inch, 3.45 * inch, 2.05 * inch],
        ),
        Spacer(1, 8),
        p("현재 메인 씬의 웨이브 목표 점수는 250,000 / 400,000 / 650,000점으로 설정되어 있으며, 보유 공은 가벼운 공·보통 공·무거운 공으로 구성됩니다."),
        p("승리·실패 조건", "h2"),
        bullet("승리: 웨이브 목표 점수에 도달하면 해당 웨이브를 클리어합니다."),
        bullet("실패: 목표 점수에 도달하지 못한 채 웨이브의 공을 모두 소진하면 실패합니다."),
        bullet("스테이지 완료: 일반 웨이브 3개와 보스 단계를 완료하면 스테이지가 종료됩니다."),
        PageBreak(),
        p("3. 조작 방법", "h1"),
        table(
            ["상황", "키", "기능"],
            [
                ["공 선택", "A / D 또는 ← / →", "이전·다음 공으로 이동"],
                ["공 선택", "Space", "선택한 공 확정"],
                ["발사 준비", "A / D 또는 ← / →", "발사 각도 조절"],
                ["발사 준비", "W / S 또는 ↑ / ↓", "발사 세기 조절"],
                ["발사 준비", "Space", "현재 설정으로 공 발사"],
                ["핀볼 진행", "WASD 또는 방향키", "작동할 플리퍼 선택"],
                ["핀볼 진행", "Space", "선택된 플리퍼 작동"],
                ["단계 화면", "화면 버튼/Space", "다음 단계 진행"],
            ],
            [1.3 * inch, 2.0 * inch, 3.45 * inch],
        ),
        Spacer(1, 8),
        todo("최종 웹 빌드에서 모든 입력을 다시 확인하고, 실제 화면의 안내 문구와 문서 조작표를 일치시켜야 합니다."),
        p("4. 실행 방법", "h1"),
        p("웹 플레이", "h2"),
        bullet("GitHub Pages 링크를 Chrome, Edge 또는 Firefox 최신 버전에서 엽니다."),
        bullet("페이지 로딩이 끝나면 게임 화면을 한 번 클릭해 키보드 입력 포커스를 활성화합니다."),
        bullet("별도의 유료 라이선스나 설치 없이 브라우저에서 플레이합니다."),
        todo("플레이 URL: https://[GitHub-Pages-주소]"),
        p("소스 코드 실행", "h2"),
        bullet("Godot 4.7.1 호환 환경에서 저장소의 project.godot 파일을 엽니다."),
        bullet("프로젝트 실행(F6이 아닌 전체 프로젝트 실행)을 선택합니다."),
        bullet("메인 씬은 res://scenes/wave/wave.tscn 입니다."),
        todo("저장소 URL: https://github.com/[계정]/[저장소]"),
        p("5. 제출 링크", "h1"),
        table(
            ["항목", "링크", "공개 상태"],
            [
                ["웹 플레이", "https://[GitHub-Pages-주소]", "접근 확인 필요"],
                ["전체 소스", "https://github.com/[계정]/[저장소]", "Public 또는 심사 계정 초대"],
                ["플레이 영상", "https://youtu.be/[영상-ID]", "공개 또는 일부 공개"],
            ],
            [1.25 * inch, 4.15 * inch, 1.35 * inch],
        ),
        Spacer(1, 10),
        todo("최종 PDF에는 실제 게임 화면 2~4장을 추가하고, 모든 링크를 클릭해 접근 가능 여부를 검수해야 합니다."),
    ]
    doc.build(s)
    return out


def build_ai_tech():
    out = OUT / "Pinball_Logue_AI활용기술서_DRAFT.pdf"
    doc = DraftDocTemplate(out, "AI 활용 기술서")
    s = title_block(
        "NAN 2026 · 사전 과제 제출 문서",
        "AI 활용 기술서",
        "Pinball Logue의 기획·개발·아트·사운드 제작에서 AI를 사용한 방식과 검증 절차",
    )
    s += [
        todo("사용자별 AI 도구·계정·사용 기간과 외부 에셋 라이선스는 팀 확인 후 확정해야 합니다."),
        Spacer(1, 18),
        p("작성 원칙", "h2"),
        p("AI가 생성한 결과를 그대로 완성품으로 간주하지 않고, 사람이 요구사항을 정의하고 결과를 선별·가공·구현·검증한 과정을 중심으로 정리합니다."),
        PageBreak(),
        p("1. AI 활용 개요", "h1"),
        p("Pinball Logue에서는 AI를 아이디어 발산에만 사용하지 않고, 기획 문서화, Godot 구현 보조, 2D 에셋 시안 제작, 효과음 재질 생성, 테스트 설계와 반복 검수까지 연결했습니다. 최종 게임 규칙과 채택 기준은 팀이 결정했으며, AI 산출물은 프로젝트 규격에 맞도록 후처리했습니다."),
        table(
            ["도구", "주요 활용", "최종 책임"],
            [
                ["OpenAI Codex / ChatGPT", "Godot 코드 작성·검토, 테스트 설계, 문서화, 이미지 생성 지시", "팀원이 코드 리뷰와 실행 테스트"],
                ["Claude", "일부 개발·분석 작업과 협업 보조", "팀원이 변경 범위와 결과 검증"],
                ["OpenAI image_gen", "공 선택 UI 등 2D 에셋 생성", "팀원이 프롬프트 설계·투명화·런타임 적용"],
                ["Leonardo.Ai", "보드·공의 형태 및 손그림 질감 후보 생성", "팀원이 기하 고정·후보 선별·레이어 합성"],
                ["Nano Banana 계열", "참조 이미지 기반 형태·질감 탐색", "팀원이 규격 적합성 측정·보정"],
                ["ElevenLabs", "태엽·유리 등 짧은 효과음의 재질 후보 생성", "팀원이 구간 추출·절차적 레이어와 합성"],
            ],
            [1.35 * inch, 3.25 * inch, 2.15 * inch],
        ),
        p("2. 활용 구조", "h1"),
        p("기획·개발", "h2"),
        bullet("AI에게 기능 요구사항과 금지 조건을 함께 전달해 구현 범위를 제한했습니다."),
        bullet("Godot 씬·스크립트 구조를 분석한 뒤, 공 물리·플리퍼·범퍼·콤보·웨이브·수리 부품 시스템을 모듈 단위로 구현·검토했습니다."),
        bullet("회귀 테스트와 테스트 전용 씬을 통해 충돌, 패링, 웨이브 전환과 HUD 상태를 반복 확인했습니다."),
        p("아트", "h2"),
        bullet("형태를 고정해야 하는 부분은 도면·마스크·실루엣을 먼저 제작하고, AI는 손그림 질감과 표면 변주에 제한적으로 사용했습니다."),
        bullet("생성 결과는 크로마키 제거, RGBA 변환, 크기 보정, 레이어 분리와 작은 해상도 가독성 확인을 거쳐 Godot에 적용했습니다."),
        bullet("프롬프트에는 색상 팔레트, 개수, 실루엣, 금지 요소와 인게임 판독 크기를 명시했습니다."),
        p("사운드", "h2"),
        bullet("ElevenLabs에는 태엽 걸림쇠, 유리구슬, 작은 황동 장치처럼 재질 특성이 필요한 짧은 원음을 생성하도록 지시했습니다."),
        bullet("AI 원음 전체를 그대로 사용하지 않고 필요한 재질 구간만 추출해 절차적으로 만든 어택·엔벨로프·잔향 레이어와 합성했습니다."),
        PageBreak(),
        p("3. 대표 프롬프트와 지시 방식", "h1"),
        p("UI 에셋 프롬프트 구성", "h2"),
        p("예시: ‘짙은 청록 원형 소켓, 비뚤어진 아이보리 이중 테두리, 민트색 나사 2개, 정면 구도, 평면 2D 컷페이퍼 스타일, #00ff00 단색 배경. 공·눈·텍스트·그라디언트·그림자·3D 표현은 제외.’"),
        p("이 지시는 에셋의 역할, 필수 조형, 정확한 요소 수, 색상, 배경 제거 방식, 금지 요소와 128px 가독성까지 한 번에 정의합니다."),
        p("사운드 프롬프트 구성", "h2"),
        p("예시: ‘작은 황동 태엽 탈진기의 마른 클릭 한 번. 가까이 녹음한 장난감 크기의 메커니즘. 매우 짧은 황동 울림. 리버브·공간음·음악·반복 없이 한 번의 클릭 뒤 무음.’"),
        p("생성 모델이 산업 기계음으로 치우치지 않도록 metal clang, industrial, heavy, factory, cinematic 등의 단어를 금지했습니다."),
        p("코드 작업 지시 구성", "h2"),
        bullet("목표 동작과 성공 조건을 먼저 정의"),
        bullet("수정 가능한 파일과 건드리지 말아야 할 영역을 지정"),
        bullet("기존 Godot 노드·신호·리소스 구조를 유지하도록 요구"),
        bullet("구현 후 테스트 명령 또는 재현 절차와 결과를 함께 기록"),
        todo("실제 사용 대화에서 대표 개발 프롬프트 2~3개를 선별해 원문 또는 요약본을 추가해야 합니다."),
        p("4. 사람의 판단과 후처리", "h1"),
        table(
            ["단계", "AI 결과", "사람이 수행한 작업"],
            [
                ["기획", "컨셉·규칙 후보", "핵심 루프 선택, 범위 축소, 최종 명칭과 밸런스 결정"],
                ["코드", "구현·리팩터링 후보", "코드 리뷰, 충돌 범위 확인, Godot 실행 테스트, 회귀 수정"],
                ["이미지", "다수의 시안", "형태 측정, 실패안 폐기, 마스크·투명화·레이어 합성"],
                ["사운드", "0.5초 이상의 재질 원음", "짧은 구간 추출, 레이어 합성, 음량·길이·잔향 조절"],
                ["문서", "초안·요약", "실제 구현과 대조, 과장 표현 제거, 제출 요구사항 검수"],
            ],
            [1.05 * inch, 2.3 * inch, 3.4 * inch],
        ),
        p("5. 검증과 한계 대응", "h1"),
        bullet("생성 이미지의 기하 왜곡은 기준 도면과 픽셀 단위로 비교했습니다."),
        bullet("AI가 텍스트·워터마크·불필요한 장식을 그리는 경우 마스크와 금지 프롬프트를 강화했습니다."),
        bullet("효과음의 반복·잔향·산업적 질감은 채택 기준에 따라 폐기했습니다."),
        bullet("코드 변경은 테스트 씬과 회귀 테스트로 동작을 확인하고, 실제 메인 씬 통합 상태를 별도로 점검했습니다."),
        bullet("기획상 목표와 현재 구현 상태가 다를 수 있으므로 제출 문서에는 실제 빌드에서 확인된 기능만 기재합니다."),
        PageBreak(),
        p("6. 외부 에셋·오픈소스 출처", "h1"),
        p("제출 전 프로젝트에 포함된 모든 이미지·폰트·사운드·애드온·코드 라이브러리를 아래 형식으로 전수 조사해야 합니다. AI 생성물도 사용 서비스, 모델, 생성일, 후처리 여부를 기록합니다."),
        table(
            ["대상", "출처/도구", "라이선스·이용 조건", "수정·사용 위치"],
            [
                ["Godot Engine", "공식 프로젝트", "정확한 버전과 배포 고지 확인 필요", "게임 엔진"],
                ["Jolt Physics", "Godot 3D 물리 설정", "프로젝트 포함 방식과 고지 확인 필요", "물리 엔진 설정"],
                ["AI 생성 이미지", "OpenAI image_gen / Leonardo.Ai", "사용 계정의 생성물 이용 조건 확인", "UI·보드·공·VFX"],
                ["AI 생성 효과음", "ElevenLabs", "사용 플랜의 상업 이용 조건 확인", "공 충돌 및 재질 효과음"],
                ["외부 이미지·폰트·사운드", "[전수 조사 필요]", "원본 URL·저작자·라이선스 입력", "리소스별 경로 입력"],
            ],
            [1.25 * inch, 1.65 * inch, 2.0 * inch, 1.85 * inch],
        ),
        Spacer(1, 9),
        todo("저장소에 통합 LICENSE/CREDITS 문서가 확인되지 않았습니다. 최종 제출 전 외부 에셋 원본 URL과 라이선스를 반드시 확정해야 합니다."),
        p("7. 근거 자료", "h1"),
        bullet("Resources/Art/ui/select_ball/IMAGEGEN_MANIFEST.md"),
        bullet("docs/LEONARDO_AI_MODEL_HANDOFF.md"),
        bullet("docs/ball_guides/ball_production_guide.md"),
        bullet("docs/ball_guides/sfx/sfx_elevenlabs_prompts.md"),
        bullet("docs/ai_memory/ 프로젝트별 작업 기록"),
    ]
    doc.build(s)
    return out


def build_team_roles():
    out = OUT / "Pinball_Logue_팀원롤기술서_DRAFT.pdf"
    doc = DraftDocTemplate(out, "팀원 롤 기술서")
    s = title_block(
        "NAN 2026 · 사전 과제 제출 문서",
        "팀원 롤 기술서",
        "Pinball Logue 팀의 역할, 실제 구현 영역 및 협업 방식",
    )
    s += [
        todo("팀원 실명·역할·실제 담당 기능은 당사자 확인 없이는 작성할 수 없습니다. 아래 표를 팀 정보로 교체해야 합니다."),
        Spacer(1, 18),
        p("작성 기준", "h2"),
        p("직함이나 희망 역할이 아니라 실제로 구현·제작·검수한 영역을 기록합니다. 공동 작업은 주 담당자와 지원자를 구분하고, AI가 보조한 부분은 각 팀원의 최종 책임과 함께 명시합니다."),
        PageBreak(),
        p("1. 팀 구성", "h1"),
        table(
            ["팀원", "주 역할", "담당 영역", "주요 결과물"],
            [
                ["[이름 1]", "[예: 기획/개발]", "[실제 담당 시스템]", "[씬·스크립트·문서]"],
                ["[이름 2]", "[예: 개발/QA]", "[실제 담당 시스템]", "[씬·스크립트·테스트]"],
                ["[이름 3]", "[예: 아트/AI]", "[실제 담당 에셋]", "[이미지·VFX·SFX]"],
            ],
            [1.05 * inch, 1.35 * inch, 2.25 * inch, 2.1 * inch],
        ),
        p("2. 팀원별 실제 구현 영역", "h1"),
        p("[이름 1]", "h2"),
        bullet("담당 역할: [입력]"),
        bullet("직접 구현: [구체적인 기능·씬·스크립트 입력]"),
        bullet("AI 활용: [도구와 활용 범위 입력]"),
        bullet("검증·의사결정: [리뷰·테스트·밸런스 결정 입력]"),
        p("[이름 2]", "h2"),
        bullet("담당 역할: [입력]"),
        bullet("직접 구현: [구체적인 기능·씬·스크립트 입력]"),
        bullet("AI 활용: [도구와 활용 범위 입력]"),
        bullet("검증·의사결정: [리뷰·테스트·밸런스 결정 입력]"),
        p("[이름 3]", "h2"),
        bullet("담당 역할: [입력]"),
        bullet("직접 구현: [구체적인 기능·씬·스크립트 입력]"),
        bullet("AI 활용: [도구와 활용 범위 입력]"),
        bullet("검증·의사결정: [리뷰·테스트·밸런스 결정 입력]"),
        p("3. 협업·분업 방식", "h1"),
        bullet("기획 문서와 시스템 요구사항을 기준으로 기능 단위를 분리했습니다."),
        bullet("공 물리, 플리퍼, 범퍼, 콤보, 웨이브, 수리 부품, UI·아트·사운드를 모듈별로 작업했습니다."),
        bullet("공유 씬에 통합하기 전 테스트 씬과 회귀 테스트로 개별 기능을 검증했습니다."),
        bullet("AI 산출물은 담당 팀원이 검토하고, 프로젝트 규격에 맞는 결과만 반영했습니다."),
        todo("실제 사용한 협업 도구, 리뷰 방식, 작업 인계 방식과 팀 내 의사결정 절차로 위 문장을 교정해야 합니다."),
        p("4. 역할 기술 시 확인 사항", "h1"),
        bullet("각 팀원의 설명에 실제 파일·기능·화면 등 확인 가능한 결과물을 2개 이상 연결"),
        bullet("공동 구현은 주 담당/지원 담당을 구분"),
        bullet("AI가 작성한 코드·이미지·사운드도 최종 검수와 수정 책임자를 기재"),
        bullet("커밋 수만으로 기여도를 표현하지 않고 실제 난이도와 책임 범위를 설명"),
        bullet("팀원 전원이 최종 문구를 확인한 뒤 PDF 확정"),
    ]
    doc.build(s)
    return out


if __name__ == "__main__":
    outputs = [build_game_guide(), build_ai_tech(), build_team_roles()]
    for output in outputs:
        print(output)
