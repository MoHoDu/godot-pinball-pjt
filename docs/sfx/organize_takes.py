#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
③ 정리 단계 — 거른 결과대로 역할 폴더를 만들고 **반려본을 지운다**

  python organize_takes.py <그룹> [--dry-run]

filter_candidates.py 가 판정만 하고 끝났다면 여기서 실제로 옮기고 지운다.

  채택 → raw/<그룹>/<N>_<역할>/          추출본 (재생할 것)
         raw/<그룹>/<N>_<역할>/_source/  생성 원본 (다시 자를 때만)
  반려 → 삭제

★ 삭제는 되돌릴 수 없다. --dry-run 으로 먼저 확인한다.
  git 에 추적 중인 파일은 `git checkout -- <경로>` 로 되살릴 수 있지만
  추적 전 파일은 영구 삭제다. 실행 시 어느 쪽인지 같이 알려준다.
"""

import argparse
import shutil
import subprocess
from pathlib import Path

from filter_candidates import analyse, verdict, ROLE_SPECS
from sfx_layout import RAW, ROLES, role_dir, source_dir, role_of, iter_role_dirs


## 저장소 루트. raw = <루트>/docs/sfx/raw
REPO = RAW.parent.parent.parent


def tracked_set():
    """git 이 알고 있는 파일 목록.

    ★ 한 건씩 `git ls-files --error-unmatch` 로 묻지 않는다. 윈도우 절대경로를
      그대로 넘기면 git 이 못 알아보고 **전부 '추적 전'으로 나온다** — 삭제
      경고가 실제보다 훨씬 무섭게 뜬다. 한 번에 목록을 받아 비교한다.
    """
    try:
        out = subprocess.run(
            ["git", "ls-files", "docs/sfx/raw"],
            capture_output=True, text=True, cwd=str(REPO),
        )
    except OSError:
        return set()

    return {(REPO / line).resolve() for line in out.stdout.splitlines() if line}


def collect(group):
    """평평하게 쌓인 것과 이미 정리된 것을 모두 모은다.

    (원본, 추출본, 역할) 세 쌍으로 돌려준다. 추출본이 없으면 None.
    """
    base = RAW / group
    found = {}

    # 아직 정리 전 — raw/<그룹>/*.wav + raw/<그룹>/cut/*.wav
    for p in sorted(base.glob("*.wav")):
        found[p.stem] = (p, base / "cut" / p.name)

    # 이미 정리됨 — raw/<그룹>/<N>_<역할>/
    for _, d in iter_role_dirs(group):
        for p in sorted(d.glob("*.wav")):
            found[p.stem] = (d / "_source" / p.name, p)

    return [(stem, src, cut, role_of(stem)) for stem, (src, cut) in found.items()]


def write_readme(group, kept, dropped):
    """무엇을 들어야 하고 무엇이 왜 없는지 폴더에 남긴다."""
    lines = [
        f"# {group} 음원 후보",
        "",
        "폴더 앞 숫자는 **오디션 순서**다. 위에서부터 재생하면 된다.",
        "반려본은 지웠으므로 **여기 있는 것은 전부 들어볼 가치가 있는 것**이다.",
        "`_source/` 는 생성 원본이다. 길이를 바꿔 다시 자를 때만 쓴다.",
        "",
    ]

    for role in sorted(set(list(kept) + list(dropped)),
                       key=lambda r: role_dir(group, r).name):
        names = kept.get(role, [])
        lines.append(f"## {role_dir(group, role).name}")
        lines.append("")
        lines.append(f"{ROLES.get(role, '(용도 미기재)')}")
        lines.append("")
        spec = ROLE_SPECS.get(role)
        if spec:
            lines.append(f"판정 기준: {spec['why']}")
            lines.append("")

        if names:
            for n in sorted(names):
                lines.append(f"- `{n}.wav`")
        else:
            lines.append("★ **남은 후보 없음 — 재생성이 필요하다.**")

        n_dropped = len(dropped.get(role, []))
        if n_dropped:
            lines.append("")
            lines.append(f"반려 {n_dropped}개:")
            for name, reasons in sorted(dropped[role]):
                lines.append(f"- ~~{name}~~ — {' '.join(reasons)}")
        lines.append("")

    path = RAW / group / "README.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("group")
    ap.add_argument("--dry-run", action="store_true", help="옮기지도 지우지도 않는다")
    args = ap.parse_args()

    items = collect(args.group)
    if not items:
        print(f"파일이 없다: {RAW / args.group}")
        return 1

    kept, dropped = {}, {}
    to_delete = []

    for stem, src, cut, role in sorted(items):
        if cut is None or not cut.exists():
            print(f"  건너뜀 {stem} — 추출본이 없다. extract_material.py 를 먼저 돌린다.")
            continue

        reasons = verdict(role, analyse(cut, src))
        if reasons:
            dropped.setdefault(role, []).append((stem, reasons))
            to_delete += [p for p in (src, cut) if p.exists()]
        else:
            kept.setdefault(role, []).append(stem)

    known = tracked_set()
    tracked = sum(1 for p in to_delete if p.resolve() in known)
    verb = "지울 예정" if args.dry_run else "삭제"

    print(f"[{args.group}] 채택 {sum(len(v) for v in kept.values())}"
          f" · 반려 {sum(len(v) for v in dropped.values())}")
    print(f"{verb} {len(to_delete)}개"
          f" (git 추적 {tracked}개 = 복구 가능,"
          f" 추적 전 {len(to_delete) - tracked}개 = 영구 삭제)")
    print()

    # 채택본을 역할 폴더로 옮긴다
    for role, stems in kept.items():
        dst, src_dst = role_dir(args.group, role), source_dir(args.group, role)
        print(f"{dst.relative_to(RAW)}/  ← {len(stems)}개   {ROLES.get(role, '')}")
        if args.dry_run:
            continue

        dst.mkdir(parents=True, exist_ok=True)
        src_dst.mkdir(parents=True, exist_ok=True)
        for stem, s, c, r in items:
            if r != role or stem not in stems:
                continue
            if c.exists() and c.resolve() != (dst / c.name).resolve():
                shutil.move(str(c), str(dst / c.name))
            if s.exists() and s.resolve() != (src_dst / s.name).resolve():
                shutil.move(str(s), str(src_dst / s.name))

    for role in dropped:
        if role not in kept:
            print(f"{role_dir(args.group, role).relative_to(RAW)}/"
                  f"  ← ★ 0개, 재생성 필요   {ROLES.get(role, '')}")

    if args.dry_run:
        print("\n--dry-run 이라 아무것도 건드리지 않았다.")
        return 0

    for p in to_delete:
        p.unlink(missing_ok=True)

    # 비게 된 cut/ 을 치운다
    old_cut = RAW / args.group / "cut"
    if old_cut.is_dir() and not any(old_cut.iterdir()):
        old_cut.rmdir()

    readme = write_readme(args.group, kept, dropped)
    print(f"\n정리 끝 → {RAW / args.group}")
    print(f"안내문: {readme}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
