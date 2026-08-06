#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
② 텍스처 단계 — AI 후보를 **역할별 기획 의도**로 거른다

  python filter_candidates.py <그룹>

review_raw.py 는 "AI 결과물로서 쓸 만한가"(연타·룸톤·무음)를 본다.
이쪽은 한 걸음 더 가서 **"이 역할에 맞는 소리인가"** 를 본다.
같은 파일이 벽 충돌음으로는 탈락이고 플리퍼 작동음으로는 채택일 수 있다.

거르는 기준 두 가지 (2026-08-06 형락님 지시)
  ① 소리가 아예 안 나오는 것 — 원본 피크가 -30dBFS 미만
     ★ cut/ 파일은 -10dBFS 로 정규화돼 있어 여기서는 판별이 안 된다.
       반드시 **원본**을 봐야 한다.
  ② 기획 의도와 안 맞을 것 같은 것 — 역할별 규격 (아래 ROLE_SPECS)

수치가 기준을 벗어났다고 무조건 결함은 아니다. 다만 **들어볼 후보를 좁히는** 데는
쓸 수 있다. 탈락 사유를 전부 적어두므로 판단이 다르면 되돌릴 수 있다.
"""

import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile

from sfx_layout import RAW, ROLES, role_of, source_dir  # noqa: E402

ROOT = Path(__file__).resolve().parent

## 원본 피크가 이보다 작으면 "소리가 안 나오는 것"으로 본다
SILENT_PEAK_DBFS = -30.0


# 역할별 기획 의도를 수치로 옮긴 것.
#   len:   유효 길이(ms) 허용 구간
#   low:   800Hz 미만 비중 상한(%)  — 넘으면 둔탁한 쿵
#   glass: 4~10kHz 비중 하한(%)     — 구슬 유리 성분
#   cent:  중심 주파수 허용 구간(Hz)
#   harm:  배음성 하한(%)           — 음정이 읽히는가
ROLE_SPECS = {
    "flipper_select": {
        "why": "조작 확인음. 짧은 딸깍·단추 (p.20)",
        "len": (5, 80), "low": 25, "cent": (1500, 9000),
    },
    "flipper_activate": {
        "why": "스프링 압축 + 짧은 휙. 기계가 실제로 움직이는 소리 (p.20)",
        "len": (50, 260), "low": 30, "cent": (1500, 9200),
    },
    "flipper_return": {
        "why": "작은 태엽 떨림. 있는 줄 모를 만큼 작게 (p.20)",
        "len": (20, 260), "low": 20, "glass": 20,
    },
    "flipper_hit": {
        "why": "구슬이 플리퍼에 맞는 소리. 유리 성분이 있어야 한다",
        "len": (40, 260), "low": 25, "glass": 25,
    },
    "flipper_strong": {
        "why": "세게 친 것. 금속 쾅이 아니라 탄력 있는 쫙 (p.20)",
        "len": (40, 260), "low": 25, "glass": 25,
    },
    "flipper_parry": {
        "why": "리듬천국 탁구 — 음정이 있는 짧고 깨끗한 폭",
        "len": (20, 130), "low": 25, "harm": 25,
    },
    "wall_wood_tok": {
        "why": "벽 저속. 짧은 목재·플라스틱 톡 (p.61)",
        "len": (20, 200), "low": 30,
    },
    "wall_hollow_duk": {
        "why": "벽 중속. 속 빈 프레임의 약한 둑 (p.61)",
        "len": (20, 220), "low": 60,
    },
    "wall_glass_ting": {
        "why": "벽 고속. 작은 유리 팅 (p.61)",
        "len": (20, 200), "glass": 25,
    },
}


def analyse(cut_path, raw_path):
    rate, data = wavfile.read(str(cut_path))
    x = data.astype(np.float64) / 32768.0

    # ★ 무음 판정은 정규화 전 **원본**으로 한다
    raw_peak_db = -999.0
    if raw_path.exists():
        _, raw = wavfile.read(str(raw_path))
        peak = np.max(np.abs(raw.astype(np.float64))) or 1e-9
        raw_peak_db = 20.0 * np.log10(peak / 32768.0)

    env = np.abs(x)
    thr = np.max(env) * 0.02
    idx = np.where(env > thr)[0]
    eff_ms = (idx[-1] - idx[0]) / rate * 1000.0 if len(idx) else 0.0

    S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / rate)
    tot = S.sum() or 1e-12

    f0 = f[int(np.argmax(S))]
    harm = sum(S[(f > f0 * k * 0.97) & (f < f0 * k * 1.03)].sum()
               for k in (1, 2, 3, 4)) / tot * 100.0

    return {
        "raw_peak_db": raw_peak_db,
        "eff_ms": eff_ms,
        "centroid": float((S * f).sum() / tot),
        "low": float(S[f < 800].sum() / tot * 100.0),
        "glass": float(S[(f >= 4000) & (f <= 10000)].sum() / tot * 100.0),
        "harm": float(harm),
    }


def verdict(role, m):
    spec = ROLE_SPECS.get(role)
    fails = []

    # ① 소리가 아예 안 나오는 것
    if m["raw_peak_db"] < SILENT_PEAK_DBFS:
        return ["①무음(%.0fdB)" % m["raw_peak_db"]]

    if spec is None:
        return fails

    # ② 기획 의도와 안 맞는 것
    lo, hi = spec["len"]
    if not (lo <= m["eff_ms"] <= hi):
        fails.append("②길이 %.0fms(%d~%d)" % (m["eff_ms"], lo, hi))

    if "low" in spec and m["low"] > spec["low"]:
        fails.append("②저역 %.0f%%(≤%d)" % (m["low"], spec["low"]))

    if "glass" in spec and m["glass"] < spec["glass"]:
        fails.append("②유리 %.0f%%(≥%d)" % (m["glass"], spec["glass"]))

    if "cent" in spec and not (spec["cent"][0] <= m["centroid"] <= spec["cent"][1]):
        fails.append("②중심 %.0fHz(%d~%d)" % (m["centroid"], *spec["cent"]))

    if "harm" in spec and m["harm"] < spec["harm"]:
        fails.append("②배음성 %.0f%%(≥%d)" % (m["harm"], spec["harm"]))

    return fails


def main():
    if len(sys.argv) < 2:
        print("사용법: python filter_candidates.py <그룹>")
        return 1

    group = sys.argv[1]
    base = RAW / group

    # 역할 폴더에 놓인 추출본. 정리 전 평평한 cut/ 배치도 받아준다.
    files = sorted(p for p in base.glob("*/*.wav")
                   if p.parent.name != "_source")
    files = files or sorted((base / "cut").glob("*.wav"))
    if not files:
        print(f"추출본이 없다: {base}  (먼저 extract_material.py 를 돌린다)")
        return 1

    by_role = {}
    for p in files:
        role = role_of(p.stem)
        # ★ 무음 판정은 정규화 전 원본으로 해야 한다. 위치는 두 배치를 다 본다.
        src = source_dir(group, role) / p.name
        m = analyse(p, src if src.exists() else base / p.name)
        by_role.setdefault(role, []).append((p.name, m, verdict(role, m)))

    kept_total = 0
    for role, items in by_role.items():
        spec = ROLE_SPECS.get(role, {})
        print(f"\n[{source_dir(group, role).parent.name}] {ROLES.get(role, role)}")
        print(f"  기준: {spec.get('why', '(없음)')}")
        for name, m, fails in items:
            mark = "채택" if not fails else "탈락"
            if not fails:
                kept_total += 1
            print(f"  {mark}  {name:28s}"
                  f"{m['eff_ms']:5.0f}ms 원본{m['raw_peak_db']:6.1f}dB "
                  f"중심{m['centroid']:6.0f} 저역{m['low']:4.0f}% "
                  f"유리{m['glass']:4.0f}% 배음{m['harm']:4.0f}%"
                  + ("  " + " ".join(fails) if fails else ""))

    print(f"\n채택 {kept_total}/{len(files)}")
    print("\n역할별 채택:")
    for role, items in by_role.items():
        kept = [n for n, _, f in items if not f]
        print(f"  {role:20s} {', '.join(kept) if kept else '★ 없음 — 재생성 필요'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
