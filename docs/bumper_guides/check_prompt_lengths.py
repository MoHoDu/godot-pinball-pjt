#!/usr/bin/env python3
"""`leonardo_prompts.md` 의 프롬프트 블록 길이를 센다.

Phoenix 1.0 / Lucid Origin 은 프롬프트 상한이 2,000자다.
넘는 블록을 미리 찾아 두지 않으면 Leonardo 입력창에서 잘린 채로 생성된다.

Leonardo 입력창은 개행을 그대로 받으므로 개행도 1자로 센다.
줄바꿈을 공백으로 합쳐 넣는 경우가 많아 그 길이도 같이 보여준다.

실행:
  python3 docs/bumper_guides/check_prompt_lengths.py
"""

from __future__ import annotations

import os
import re

LIMIT = 2000

HERE = os.path.dirname(__file__)
DOC = os.path.join(HERE, "leonardo_prompts.md")


def main() -> None:
    with open(DOC, encoding="utf-8") as handle:
        text = handle.read()

    # "### 2-n. 이름" 아래에 오는 ```text 블록만 본다.
    sections = re.split(r"^### ", text, flags=re.MULTILINE)[1:]

    print(f"{'블록':<34}{'원문':>8}{'1줄':>8}   상한 {LIMIT}자")
    print("-" * 66)

    over = 0
    for section in sections:
        title = section.splitlines()[0].strip()
        # 프롬프트 본문은 "2-n." 절에만 있다. 모델 설명 절이 딸려 들어오지 않게 거른다.
        if not re.match(r"^\d+-\d+\.", title):
            continue
        # 제목에서 파일명·강조 표기를 걷어내 표를 읽기 쉽게 만든다.
        title = re.sub(r"\s*\(.*?\)|\*\*|`", "", title).strip()
        blocks = re.findall(r"```text\n(.*?)```", section, flags=re.DOTALL)
        if not blocks:
            continue
        body = blocks[0].rstrip("\n")
        raw = len(body)
        joined = len(re.sub(r"\s+", " ", body).strip())
        mark = "  ★ 초과" if raw > LIMIT else ""
        if raw > LIMIT:
            over += 1
        print(f"{title:<34}{raw:>8}{joined:>8}{mark}")

    print("-" * 66)
    if over:
        print(f"{over}개 블록이 상한을 넘는다. Nano Banana 2 는 괜찮지만")
        print("Phoenix / Lucid 로 옮길 때는 문서 4절 순서대로 줄인다.")
    else:
        print("모든 블록이 상한 이내다.")


if __name__ == "__main__":
    main()
