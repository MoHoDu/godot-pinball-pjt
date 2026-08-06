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

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
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

# 각 음원이 게임에서 무엇을 표현하는지. 생성·검수 때 같이 출력한다.
# 소리만 들으면 무엇을 위한 건지 알 수 없어서 판단이 안 된다.
ROLES = {
    "wall_wood_tok": "벽 충돌 — 저속. 공이 벽에 약하게 닿을 때 (목재 톡)",
    "wall_hollow_duk": "벽 충돌 — 중속. 속 빈 프레임의 둑 하는 몸통",
    "wall_glass_ting": "벽 충돌 — 고속에만 얹는 작은 유리 팅",
    "flipper_tak": "플리퍼 일반 타격 — 플리퍼가 공을 침 (MUST)",
    "flipper_pang": "플리퍼 강한 타격 — 세게 쳤을 때. 금속 쾅이 아닌 탄력 있는 쫙",
    "flipper_spring": "플리퍼 작동 — Space 를 눌러 플리퍼가 올라가는 순간",
    "flipper_button": "플리퍼 선택 — 방향키로 조작할 플리퍼 그룹을 바꿀 때",
    "flipper_tremble": "플리퍼 복귀 — 플리퍼가 제자리로 내려올 때의 태엽 떨림",
    "parry_glass_ting": "정확한 패링 2번째 레이어 — 성공을 알리는 밝은 유리 팅",
    "parry_bell": "정확한 패링 악센트 — 짧은 종 1음",
    "ball_clockwork_escapement": "정속 태엽눈 재질음 — 태엽 걸림쇠 클릭",
    "ball_clockwork_glass_pin": "정속 태엽눈 재질음 — 유리 위 금속 톡",
    "ball_clockwork_detent": "정속 태엽눈 재질음 — 태엽 감기 멈춤",
}

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
    "flipper": {
        # ★ 3차 (2026-08-06). 2차에서 button 만 단발로 성공하고 나머지는 연타였다.
        #
        #   성공한 button 과 실패한 셋의 차이가 명확했다.
        #     성공: "A single crisp click of a small plastic toy button"
        #           → 물체 **하나**, 소리는 **명사**(click), 동작 없음, "Exactly one"
        #     실패: "impact of a paddle **against** a marble" (물체 둘 + 충돌 서술)
        #           "a spring **compressing and releasing**" (동작 서술)
        #
        #   물체가 둘이면 모델이 "부딪히는 장면"을 만들고, 장면에는 반복이 따라온다.
        #   → 물체 하나, 소리 명사, "Exactly one X at the very start" 로 통일한다.
        # ★ 4차 (2026-08-06 형락님 방향 제시)
        #   "플리퍼가 공을 치는 소리는 **유리로 된 탁구공을 치는 듯한 느낌**"
        #
        #   → 가볍고 · 속이 비었고 · 밝은 유리. 무겁거나 둔탁하면 안 된다.
        #     3차 후보(tak_02)는 중심이 236Hz 였다. 정반대 방향이었다.
        #
        #   'ping-pong' 이라는 단어는 쓰지 않는다. 탁구는 **랠리**를 연상시켜
        #   모델이 통통 튀는 연속음을 만들 위험이 크다. 물성만 서술한다.
        "flipper_tak": (
            "One-shot foley sample. A single bright glassy knock of a hollow "
            "thin-walled glass ball, very light and small. Toy scale, "
            "close-miked, anechoic, completely dry. Exactly one knock at the "
            "very start, then silence."
        ),
        "flipper_pang": (
            "One-shot foley sample. A single sharp glassy crack of a hollow "
            "thin-walled glass ball struck hard. Bright and springy, never "
            "dull or deep. Toy scale, close-miked, anechoic, completely dry. "
            "Exactly one crack at the very start, then silence."
        ),
        "flipper_spring": (
            "One-shot foley sample. A single short creak of a small coiled toy "
            "spring. Toy scale, close-miked, anechoic, completely dry. Exactly "
            "one creak at the very start, then silence."
        ),
        "flipper_button": (
            "One-shot foley sample. A single crisp click of a small plastic "
            "toy button. Toy scale, close-miked, anechoic, completely dry. "
            "Exactly one click at the very start, then silence."
        ),
        "flipper_tremble": (
            "One-shot foley sample. A tiny brass clockwork part settling to "
            "rest, three faint ticks fading out within a quarter second. Very "
            "quiet, close-miked, anechoic, completely dry. Then silence."
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
    args = ap.parse_args()

    prompts = GROUPS[args.group]
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
    out_dir = RAW / args.group
    out_dir.mkdir(parents=True, exist_ok=True)

    fmt = OUTPUT_FORMATS[0]
    made = 0
    skipped = 0
    for name, text in prompts.items():
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
                    print(f"        용도: {ROLES.get(name, '(미기재)')}")
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
          + f" → {out_dir}")
    print("다음: 채택 기준 4개로 고른다 — 앞 30ms 안에 재질이 다 들어있는가 / "
          "잔향·룸톤이 안 붙었는가 / 재질 모드가 뚜렷한가 / 클릭이 하나인가")
    return 0


if __name__ == "__main__":
    sys.exit(main())
