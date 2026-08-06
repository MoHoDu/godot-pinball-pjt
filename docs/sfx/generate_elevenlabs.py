#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
② 텍스처 단계 — ElevenLabs 재질음 생성

  python generate_elevenlabs.py <그룹> [--variants 4] [--dry-run]

  그룹: wall | flipper | ball_clockwork | parry
  --dry-run 이면 요청 내용과 예상 호출 수만 출력하고 실제로 생성하지 않는다.

★ AI 가 맡는 것은 **재질음뿐**이다.
  어택·총 길이·레이어 밸런스는 절차적 합성(build_*.py)에서 이미 확정됐다.
  duration_seconds 최소가 0.5초라 우리가 필요한 0.06~0.14초를 직접 못 만들고,
  무엇보다 **어택이 어디 찍힐지 제어할 수 없다.** 게임 사운드는 어택 위치가 전부다.
  받은 파일에서 재질 구간만 잘라 확정된 엔벨로프에 얹는다.

★ API 는 요청당 파일 1개를 돌려준다. 변형이 필요하면 같은 프롬프트로 여러 번 부른다.
  (웹 Playground 가 4개를 주는 것과 다르다 — 2026-08-06 문서 확인)

키는 환경변수 ELEVENLABS_API_KEY 또는 저장소 루트의 .env.local 에서 읽는다.
.env.local 은 .gitignore 처리돼 있다. 이 스크립트는 키를 출력하지 않는다.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import wave
from pathlib import Path

from sfx_layout import RAW, ROLES, source_dir  # noqa: E402

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent

API_URL = "https://api.elevenlabs.io/v1/sound-generation"

# 2026-08-06 확인한 현재 규격
MODEL_ID = "eleven_text_to_sound_v2"

# ★ 1차 시도가 전부 탈락한 뒤 바꾼 값들 (2026-08-06)
#
#   길이 0.5 를 요청했는데 전부 0.96초로 왔다. 웹 UI 최소가 1초인 걸 보면
#   그 아래는 클램프되는 것 같다. 지킬 수 없는 값을 요청할 이유가 없어 1.0 으로 둔다.
#   어차피 우리가 쓰는 건 어택 직후 30~60ms 뿐이라 총 길이는 상관없다.
DURATION = 1.0

#   0.7~1.0 이 "정밀 제어" 구간이다. 기본값 0.3 은 창의적 변형용.
#   0.8 로도 프롬프트를 안 지켜서 0.95 로 올린다.
PROMPT_INFLUENCE = 0.95

LOOP = False            # 원샷이다

# 우선순위: PCM 48kHz. 구독 등급이 낮으면 아래로 자동 강등한다
OUTPUT_FORMATS = ["pcm_48000", "pcm_44100", "mp3_44100_192", "mp3_44100_128"]

# 금지 단어 — 폐기된 구 컨셉(산업 호러)으로 모델을 끌어당긴다 (가이드 p.61)
BANNED = [
    "metal clang", "machinery", "industrial", "heavy", "steel", "hammer",
    "factory", "gear grinding", "echo", "hall", "cinematic", "impact boom",
]

# ROLES(각 음원이 게임에서 무엇을 표현하는지)는 sfx_layout.py 로 옮겼다.
# 생성·추출·필터·정리가 전부 같은 표를 봐야 해서다.

GROUPS = {
    "wall": {
        "wall_wood_tok": (
            "A single dry tick of a small wooden toy block tapped against a "
            "hollow painted frame. Tiny, light, close-miked in a dead room. "
            "No reverb, no room tone, one isolated tap then silence."
        ),
        "wall_hollow_duk": (
            "One short muted knock on a hollow lightweight toy frame, like "
            "tapping an empty painted wooden box. Small, dull, close-miked, "
            "completely dry. Single isolated knock, no reverb, silence after."
        ),
        "wall_glass_ting": (
            "One small bright ting of a glass marble grazing a hard smooth "
            "surface. Very short, delicate, close-miked with no room. Single "
            "isolated ting, no reverb, no ringing tail, silence after."
        ),
    },
    # ★ 2차 프롬프트 (2026-08-06). 1차는 전부 탈락했다 — 나무 톡이 14연타로 왔다.
    #
    #   원인은 프롬프트가 **행위**를 묘사한 것이었다.
    #   "a wooden block tapped against a frame" 는 모델에게 "두드리는 소리"로 읽힌다.
    #   그래서 시킨 대로 두드렸다.
    #
    #   고친 방식:
    #     - 행위 동사를 버리고 **"one-shot foley sample"** 이라고 물건 이름으로 지칭한다
    #     - 모델이 오디오 용어를 이해하므로 anechoic · close-miked · dry 를 쓴다
    #     - 부정문("no repetition")보다 **긍정문("then silence")** 을 앞에 둔다
    #     - 450자 제한. 한두 문장으로 끝낸다
    # ★ 4차 (2026-08-06 형락님 지적)
    #   "플리퍼가 움직일 때 **기계음** 소리가 나지 않고 그냥 있는 리소스 재활용 같다"
    #
    #   맞는 지적이다. 절차적 합성본은 모달 감쇠 + 노이즈 + 새추레이션이라는
    #   같은 사슬을 공유해서 서로의 변주처럼 들린다. 특히 **작동음**은 장치가
    #   실제로 움직이는 불규칙한 질감인데 모달 합성으로는 만들 수 없다.
    #
    #   그래서 플리퍼는 AI 로 간다. 방향은 "장난감 태엽 장치가 작동하는 소리".
    #   금지어(machinery / industrial / gear grinding / metal clang / heavy /
    #   steel / hammer / factory)를 피하면서 기계 동작을 서술해야 한다.
    #   → wind-up toy · spring-loaded lever · plastic ratchet · brass escapement
    "flipper": {
        "flipper_select": (
            "One-shot foley sample. A single crisp click of a small plastic "
            "toy toggle switch flipping over. Toy scale, close-miked, "
            "anechoic, completely dry. Exactly one click at the very start, "
            "then silence."
        ),
        "flipper_activate": (
            "One-shot foley sample. A small spring-loaded toy lever snapping "
            "up in one quick motion: a brief spring release with a light "
            "plastic ratchet tick and a faint air swish. Wind-up toy scale, "
            "close-miked, anechoic, completely dry. One motion at the very "
            "start, then silence."
        ),
        "flipper_return": (
            "One-shot foley sample. A small spring-loaded toy lever dropping "
            "back to rest, a soft plastic knock with a faint brass tick. "
            "Wind-up toy scale, very quiet, close-miked, anechoic, completely "
            "dry. One motion at the very start, then silence."
        ),
        # ★ 5차 (2026-08-06). 4차 hit 은 6개 전부 4~10kHz 대역이 0.0% 였다.
        #   유리가 아니라 둔탁한 나무 노크만 나왔다.
        #
        #   같은 배치에서 strong 은 5/6 성공(유리 27~58%)했다. 두 프롬프트의
        #   차이가 원인 전부다:
        #     ① 소리 명사가 "knock" — 나무·문을 강하게 연상시킨다.
        #        strong 의 "crack" 은 그렇지 않다. 문자 그대로 노크를 시킨 것이다
        #     ② "struck by a small paddle" — **두 번째 물체**를 넣었다.
        #        패들은 나무다. strong 은 "struck hard" 로 물체가 하나뿐이다
        #     ③ strong 에는 "never dull or deep" 이라는 음색 가드가 있는데
        #        hit 에는 없었다
        #
        #   그래서 strong 의 성공 공식을 그대로 따른다.
        #   물체는 하나, 소리 명사는 유리를 함의하는 것, 가드를 붙인다.
        #
        # ★ 6차 — 5차에서 유리는 나왔지만(hit_04 유리 60%) 8개 중 5개가
        #   원본 -29~-39dBFS 무음이었다. "lightly struck" 를 의심해 뺐는데
        #   **결과가 그대로였다** (10개 중 5개 무음). 세기 부사는 원인이 아니다.
        #
        #   남은 유력한 원인은 소리 명사 "tick" 이다. strong 의 "crack" 은
        #   5/6 이 정상 음량으로 나왔다. 작은 소리를 뜻하는 명사를 쓰면
        #   모델이 실제로 작게 준다.
        #
        #   다만 이 역할은 hit_04 로 충족됐다. 역할당 필요한 스트림은 하나다.
        #   더 검증하지 않고 남겨둔다 — 다시 뽑을 일이 생기면 "tick" 을
        #   "ping" 이나 "ring" 으로 바꿔보는 것이 다음 수다.
        #
        #   무관하지만 확실한 것 하나: **음량은 런타임 파라미터다.**
        #   속도->음량은 SfxCue 가 재생할 때 건다. AI 에게 작은 소리를
        #   달라고 할 이유가 애초에 없다.
        "flipper_hit": (
            "One-shot foley sample. A single bright glassy tick of a hollow "
            "thin-walled glass ball, struck once. Clear and ringing, never "
            "dull or woody. Toy scale, close-miked, anechoic, completely dry. "
            "Exactly one tick at the very start, then silence."
        ),
        "flipper_strong": (
            "One-shot foley sample. A single sharp glassy crack of a hollow "
            "thin-walled glass ball struck hard. Bright and springy, never "
            "dull or deep. Toy scale, close-miked, anechoic, completely dry. "
            "Exactly one crack at the very start, then silence."
        ),
        "flipper_parry": (
            "One-shot foley sample. A single clean pitched pock of a light "
            "table tennis ball on a wooden paddle, one clear musical note "
            "with a short bounce. Bright, toy-like, close-miked, anechoic, "
            "completely dry. Exactly one pock at the very start, then silence."
        ),
    },
    # ── Tier 3 · 4 (2026-08-06) ────────────────────────────────
    #
    # 검증된 공식을 그대로 쓴다:
    #   "One-shot foley sample. A single [형용사] [소리 명사] of a [물체 하나].
    #    Toy scale, close-miked, anechoic, completely dry.
    #    Exactly one X at the very start, then silence."
    #
    # ★ 지키는 것 세 가지 — 전부 실패에서 배운 것이다
    #   ① 물체는 하나. 둘을 넣으면 모델이 충돌 장면을 만든다 (4차 hit 실패)
    #   ② 소리 명사가 결과를 지배한다. "knock" 을 시키면 나무를 준다
    #   ③ 작은 소리를 달라고 하지 않는다. 음량은 런타임이 건다
    #
    # 컨셉은 "고장 난 장난감 오락기 + 태엽 기계 + 작은 오컬트 의식".
    # 사실적인 쇠구슬이나 무거운 산업 기계음이 아니다 (가이드 p.61).
    "flow": {
        "flow_launch": (
            "One-shot foley sample. A single taut spring release of a small "
            "wind-up toy launcher letting go, bright and springy with a short "
            "whip of air. Toy scale, close-miked, anechoic, completely dry. "
            "Exactly one release at the very start, then silence."
        ),
        "flow_drain": (
            "One-shot foley sample. A single hollow wooden thud of a small "
            "empty toy box, with the pitch sagging downward as it fades. Dull "
            "and sinking, toy scale, close-miked, anechoic, completely dry. "
            "Exactly one thud at the very start, then silence."
        ),
    },
    "combo": {
        # 피치 사다리는 런타임이 만든다. 여기서는 한 음만 필요하다.
        "combo_rise": (
            "One-shot foley sample. A single bright chime of a tiny brass "
            "bell, one clear pitch with a short clean decay. Music-box scale, "
            "close-miked, anechoic, completely dry. Exactly one chime at the "
            "very start, then silence."
        ),
        "combo_tier": (
            "One-shot foley sample. A single bright shimmering chime of a "
            "small crystal glass bell, one clear rising pitch with a short "
            "sparkling decay. Toy scale, close-miked, anechoic, completely "
            "dry. Exactly one chime at the very start, then silence."
        ),
        # ★ 2차 — 1차는 6개 전부 중심 8394~10202Hz 로 나와 탈락했다.
        #   "creak"(삐걱) 은 모델에게 **높은 마찰음**이다. 실패를 알리는
        #   처지는 소리를 원했는데 정반대가 왔다.
        #   소리 명사를 낮은 몸통을 가진 것("thunk")으로 바꾸고,
        #   밝기를 막는 가드를 넣는다.
        "combo_timeout": (
            "One-shot foley sample. A single low dull wooden thunk of a small "
            "toy spring going slack, the pitch sagging downward as it dies. "
            "Dark and deflating, never bright or squeaky. Toy scale, "
            "close-miked, anechoic, completely dry. Exactly one thunk at the "
            "very start, then silence."
        ),
        "combo_target": (
            "One-shot foley sample. A single bright glassy shimmer of a small "
            "crystal chime bar struck once, clear and sparkling with a short "
            "ring. Toy scale, close-miked, anechoic, completely dry. Exactly "
            "one shimmer at the very start, then silence."
        ),
    },
    "wave": {
        "wave_win": (
            "One-shot foley sample. A single warm bright chime of a small "
            "music box comb tine plucked once, one clear pitch with a gentle "
            "ring. Toy scale, close-miked, anechoic, completely dry. Exactly "
            "one chime at the very start, then silence."
        ),
        # ★ 2차 — 1차는 6개 전부 중심 6362~9381Hz. combo_timeout 과 같은 원인이다.
        #   "groan" 도 모델에게는 높은 마찰음이었다.
        #   음정이 분명한 낮은 것("hum")으로 바꾸고 가드를 넣는다.
        "wave_lose": (
            "One-shot foley sample. A single low slow descending hum of a "
            "small music box winding down to a stop, one dark pitch sliding "
            "downward. Never bright or squeaky. Toy scale, close-miked, "
            "anechoic, completely dry. Exactly one hum at the very start, "
            "then silence."
        ),
    },
    "bumper": {
        "bumper_button": (
            "One-shot foley sample. A single crisp snap of a large plastic "
            "toy button being pressed down. Hard and clicky, toy scale, "
            "close-miked, anechoic, completely dry. Exactly one snap at the "
            "very start, then silence."
        ),
        "bumper_cotton": (
            "One-shot foley sample. A single soft muffled pouf of a small "
            "cotton stuffed toy being squashed, airy and dull with almost no "
            "ring. Toy scale, close-miked, anechoic, completely dry. Exactly "
            "one pouf at the very start, then silence."
        ),
        "bumper_spring": (
            "One-shot foley sample. A single boingy twang of a small coiled "
            "toy spring released, one wobbling pitch that settles fast. Toy "
            "scale, close-miked, anechoic, completely dry. Exactly one twang "
            "at the very start, then silence."
        ),
        # ★ 2차 — 1차는 6개 전부 원본 -32~-41dBFS 였다. 저역 100%·배음 99% 라
        #   북은 맞는데 레벨이 없다. "hollow tap"(속 빈 톡) 이 모델에게
        #   **아주 작은 소리**로 읽혔다. 그 상태로 증폭하면 노이즈만 커진다.
        #   때리는 동작과 가죽 면을 명시해 어택이 찍히게 한다.
        "bumper_drum": (
            "One-shot foley sample. A single firm strike on the taut skin of "
            "a small toy drum, a clear attack with a short round body. Toy "
            "scale, close-miked, anechoic, completely dry. Exactly one strike "
            "at the very start, then silence."
        ),
        "bumper_cannon_click": (
            "One-shot foley sample. A single dry ratchet click of a small "
            "wind-up toy crank catching one notch. Tight and brassy, toy "
            "scale, close-miked, anechoic, completely dry. Exactly one click "
            "at the very start, then silence."
        ),
        "bumper_cannon_fire": (
            "One-shot foley sample. A single soft pop of a toy cork cannon "
            "firing, round and airy with a short puff. Toy scale, "
            "close-miked, anechoic, completely dry. Exactly one pop at the "
            "very start, then silence."
        ),
        "bumper_destroy": (
            "One-shot foley sample. A single dry splintering crack of a small "
            "painted wooden toy breaking apart, with a brief scatter of tiny "
            "fragments. Toy scale, close-miked, anechoic, completely dry. "
            "Exactly one crack at the very start, then silence."
        ),
        "bumper_respawn": (
            "One-shot foley sample. A single short rising whirr of a small "
            "toy spring being wound up, brassy and ticking as it tightens. "
            "Toy scale, close-miked, anechoic, completely dry. Exactly one "
            "whirr at the very start, then silence."
        ),
    },
    "parry": {
        "parry_glass_ting": (
            "One bright clear ping of a small glass bead struck once, with a "
            "very short shimmering ring. Delicate, toy-like, recorded very "
            "close with no room. Single isolated ping, no reverb, no echo, "
            "silence after."
        ),
        "parry_bell": (
            "A single soft chime of a tiny brass bell, one clear pitch with a "
            "short decay. Small music-box scale, close-miked, dry. One strike "
            "only, no ringing sequence, no reverb."
        ),
    },
    "ball_clockwork": {
        "ball_clockwork_escapement": (
            "A single dry click of a small brass clockwork escapement, one "
            "tooth slipping past the pallet. Tiny wind-up toy mechanism, "
            "close-miked in a dead room. Bright metallic tick with a very "
            "short brass ring. No reverb, no room tone, no music, no "
            "repetition — one isolated click then silence."
        ),
        "ball_clockwork_glass_pin": (
            "One short tick of a small brass pin tapping a hollow glass "
            "marble. Toy-sized, delicate, close-miked, completely dry. Clear "
            "glassy ping with a fast decay. Single isolated hit, no reverb, "
            "no echo, no background noise, silence after."
        ),
        "ball_clockwork_detent": (
            "The single detent click of a wind-up music box spring catching. "
            "Small, light, wooden-and-brass, recorded very close with no room. "
            "One crisp snap only, no ratcheting sequence, no reverb, no hum, "
            "silence before and after."
        ),
    },
}


def read_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key, "환경변수"

    env_file = REPO / ".env.local"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            name, _, value = line.partition("=")
            if name.strip() == "ELEVENLABS_API_KEY":
                return value.strip().strip('"').strip("'"), str(env_file)

    return "", ""


def check_banned(prompts):
    """
    금지 단어가 프롬프트에 섞이지 않았는지 본다. 돈 쓰기 전에 거른다.

    ★ 부분 문자열로 찾으면 안 된다. 'anechoic'(무향실 — 우리가 원하는 것) 안의
      'echo' 를 금지어로 잡아 전량이 막혔다. 단어 경계로 찾는다.
    """
    bad = []
    for name, text in prompts.items():
        low = text.lower()
        for word in BANNED:
            if re.search(r"\b" + re.escape(word) + r"\b", low):
                bad.append((name, word))
    return bad


def generate(key, prompt, out_path, fmt):
    body = json.dumps({
        "text": prompt,
        "model_id": MODEL_ID,
        "duration_seconds": DURATION,
        "prompt_influence": PROMPT_INFLUENCE,
        "loop": LOOP,
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{API_URL}?output_format={fmt}",
        data=body,
        headers={"xi-api-key": key, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as res:
        data = res.read()

    if fmt.startswith("pcm"):
        write_pcm_as_mono_wav(data, out_path, int(fmt.split("_")[1]))
    else:
        out_path.write_bytes(data)

    return out_path


def write_pcm_as_mono_wav(data, out_path, rate):
    """
    ★ pcm_* 응답은 **헤더 없는 16bit 스테레오 raw PCM** 이다. 함정이 둘이다.

      1. 헤더가 없다  → 그대로 .wav 로 저장하면 재생이 안 된다
      2. 스테레오다   → 모노로 읽으면 길이가 2배가 되고 **한 옥타브 낮게** 재생된다

    2번을 놓쳐서 1차·2차 생성분을 전부 잘못된 소리로 검수했다(2026-08-06).
    짝수·홀수 샘플 상관이 +0.9975 라 좌우가 사실상 같은 신호다. 평균으로 모노화한다.
    """
    import array

    samples = array.array("h")
    samples.frombytes(data[:len(data) // 2 * 2])

    if len(samples) >= 2:
        left = samples[0::2]
        right = samples[1::2]
        n = min(len(left), len(right))
        mono = array.array("h", [(left[i] + right[i]) // 2 for i in range(n)])
    else:
        mono = samples

    with wave.open(str(out_path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(mono.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("group", choices=sorted(GROUPS))
    ap.add_argument("--variants", type=int, default=4,
                    help="프롬프트당 생성 개수 (API 는 호출당 1개를 준다)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="이미 받은 변형도 다시 생성한다 (크레딧을 또 쓴다)")
    # ★ 한 역할만 다시 뽑을 때 쓴다. 없으면 그룹 전체를 돌면서
    #   이미 걸러내고 지운 반려본 자리까지 다시 채워 크레딧을 낭비한다.
    ap.add_argument("--only", nargs="+", metavar="역할",
                    help="이 역할만 생성한다 (예: --only flipper_hit)")
    args = ap.parse_args()

    prompts = GROUPS[args.group]
    if args.only:
        unknown = [n for n in args.only if n not in prompts]
        if unknown:
            print(f"★ 그룹 {args.group} 에 없는 역할: {', '.join(unknown)}")
            print(f"   가능한 역할: {', '.join(prompts)}")
            return 1

        prompts = {n: prompts[n] for n in args.only}

    calls = len(prompts) * args.variants

    bad = check_banned(prompts)
    if bad:
        for name, word in bad:
            print(f"★ 금지 단어 '{word}' 가 {name} 프롬프트에 있다 (가이드 p.61)")
        return 1

    print(f"그룹 {args.group} — 프롬프트 {len(prompts)}개 × 변형 {args.variants} = "
          f"호출 {calls}회")
    print(f"설정  model={MODEL_ID}  duration={DURATION}s  "
          f"prompt_influence={PROMPT_INFLUENCE}  loop={LOOP}")
    for name, text in prompts.items():
        print(f"\n  [{name}]")
        print("   " + text.replace("\n", "\n   "))

    if args.dry_run:
        print("\n(dry-run — 실제로 생성하지 않았다)")
        return 0

    key, source = read_key()
    if not key:
        print("\n★ API 키가 없다. 아래 중 하나로 넣어달라 — 이 스크립트는 키를 출력하지 않는다.")
        print(f"   1) 저장소 루트에 .env.local 파일을 만들고 한 줄:")
        print(f"      ELEVENLABS_API_KEY=발급받은키")
        print(f"      (경로: {REPO / '.env.local'} · .gitignore 처리됨)")
        print("   2) 또는 환경변수 ELEVENLABS_API_KEY 설정")
        return 1

    print(f"\n키 출처: {source}")

    # ★ 역할마다 폴더를 따로 쓴다 (2026-08-06). 한 폴더에 평평하게 쌓으면
    #   나중에 무엇을 재생해야 할지 알 수 없다. 생성 원본은 _source/ 에 두고,
    #   재생할 추출본은 그 위 폴더에 놓는다.
    group_dir = RAW / args.group
    fmt = OUTPUT_FORMATS[0]
    made = 0
    skipped = 0
    for name, text in prompts.items():
        out_dir = source_dir(args.group, name)
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n[{out_dir.parent.name}] {ROLES.get(name, '(용도 미기재)')}")

        for i in range(1, args.variants + 1):
            # 이미 받은 변형은 건너뛴다. 다시 부르면 크레딧을 또 쓴다.
            existing = [e for e in ("wav", "mp3")
                        if (out_dir / f"{name}_{i:02d}.{e}").exists()]
            if existing and not args.force:
                skipped += 1
                continue

            ext = "wav" if fmt.startswith("pcm") else "mp3"
            path = out_dir / f"{name}_{i:02d}.{ext}"
            for _ in range(len(OUTPUT_FORMATS)):
                try:
                    generate(key, text, path, fmt)
                    print(f"  생성 {path.relative_to(REPO)}  ({fmt})")
                    made += 1
                    break
                except urllib.error.HTTPError as e:
                    detail = e.read().decode("utf-8", "replace")[:300]
                    # 구독 등급이 낮아 포맷이 막힌 경우만 강등하고 재시도한다
                    if "output_format" in detail:
                        nxt = OUTPUT_FORMATS.index(fmt) + 1
                        if nxt < len(OUTPUT_FORMATS):
                            fmt = OUTPUT_FORMATS[nxt]
                            print(f"  포맷 강등 → {fmt}")
                            continue
                    print(f"  ★ 실패 {path.name}: HTTP {e.code} {detail}")
                    # 인증·권한·잔액 문제면 나머지도 전부 실패한다. 바로 멈춘다.
                    if e.code in (401, 403, 402, 429):
                        print("  ★ 키·권한·잔액 문제로 보인다. 중단한다.")
                        return 1
                    break
                except Exception as e:  # noqa: BLE001
                    print(f"  ★ 실패 {path.name}: {e}")
                    break
            time.sleep(0.4)

    print(f"\n{made}개 생성" + (f" (이미 있어 건너뜀 {skipped}개)" if skipped else "")
          + f" → {group_dir}")
    print(f"다음: python extract_material.py {args.group}"
          f"  →  python organize_takes.py {args.group}")
    print("      추출하면 역할 폴더에 재생용 후보가 놓이고,"
          " 정리하면 반려본이 지워진다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
