#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
② 텍스처 단계 — AI 후보를 **역할별 기획 의도**로 거른다

  python filter_candidates.py <그룹>

review_raw.py 는 "AI 결과물로서 쓸 만한가"(연타·룸톤·무음)를 본다.
이쪽은 한 걸음 더 가서 **"이 역할에 맞는 소리인가"** 를 본다.
같은 파일이 벽 충돌음으로는 탈락이고 플리퍼 작동음으로는 채택일 수 있다.

거르는 기준 두 가지 (2026-08-06 형락님 지시)
  ① 소리가 아예 안 나오는 것 — 신호가 잡음 위로 안 올라온 것 (SNR)
     ★ 추출본은 -10dBFS 로 정규화돼 있어 여기서는 판별이 안 된다.
       반드시 **생성 원본**을 봐야 한다.
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

# "소리가 아예 안 나오는 것" 의 판정 기준.
#
# ★ 처음에는 원본 피크가 -30dBFS 미만이면 무음으로 봤다. 틀린 대리 지표였다.
#   저역 위주 소리는 **정상이어도 피크가 낮게 나온다.** 장난감 북 6개와
#   콤보 실패음 6개가 전부 -32~-44dBFS 로 걸렸는데, 실제로 재보니
#   노이즈 플로어가 -85dB 대라 SNR 이 41~56dB 였다. 깨끗한 저음이었다.
#
#   재는 것은 "얼마나 큰가"가 아니라 **"신호가 잡음 위로 올라와 있는가"** 다.
#   음량은 어차피 마감 단계에서 정규화한다.
MIN_SNR_DB = 24.0

## SNR 이 좋아도 이보다 조용하면 실제로 빈 파일이다
ABSOLUTE_FLOOR_DBFS = -60.0

# ★ 들리는 대역에 에너지가 있는가.
#
#   SNR 만으로는 부족했다. bumper_cannon_fire_02 는 SNR 이 멀쩡한데
#   **에너지의 99.9%가 50Hz 아래**였다. DC 오프셋 -0.0196 이 붙은
#   압력 계단이지 소리가 아니다. 그런데 계단의 높이가 피크로 잡혀서
#   "신호가 있다"고 통과했다.
#
#   120Hz 아래는 노트북·휴대폰 스피커가 거의 못 낸다. 그 위에 최소한의
#   에너지가 없으면 게임에서는 무음이다.
AUDIBLE_FLOOR_HZ = 120.0
MIN_AUDIBLE_SHARE = 15.0


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

    # Tier 3 — 흐름음. 충돌음보다 길어도 되고, 음정이 읽혀야 하는 것이 많다.
    "flow_launch": {
        "why": "태엽이 풀리며 튕겨나감. 스프링 질감",
        "len": (40, 400), "low": 40,
    },
    "flow_drain": {
        "why": "공을 잃음. 둔탁하고 가라앉는 느낌",
        "len": (40, 500),
    },
    "combo_rise": {
        "why": "한 음. 피치 사다리를 태우려면 음정이 뚜렷해야 한다",
        "len": (40, 500), "low": 30, "harm": 20,
    },
    "combo_tier": {
        "why": "상승보다 크고 밝게. 유리·수정 질감",
        "len": (40, 600), "low": 30, "harm": 20,
    },
    "combo_timeout": {
        # 아래쪽 경계 120Hz 는 취향이 아니라 재생 한계다. 노트북·휴대폰
        # 스피커는 그 아래를 거의 못 낸다. 너무 어두우면 안 들린다.
        "why": "실패. 처지는 느낌이되 120Hz 아래로 가면 스피커가 못 낸다",
        "len": (40, 600), "cent": (120, 4000),
    },
    "combo_target": {
        "why": "목표 도달. 밝은 성취",
        "len": (40, 600), "low": 30, "glass": 20,
    },
    "wave_win": {
        "why": "저주가 풀림. 따뜻하고 음정이 분명한 한 음",
        "len": (80, 900), "low": 40, "harm": 20,
    },
    "wave_lose": {
        "why": "태엽이 멈춤. 아래로 미끄러지는 느낌",
        "len": (80, 900), "cent": (150, 5000),
    },

    # Tier 4 — 범퍼. 5종이 서로 확실히 갈려야 한다(가이드 3층 구조의 재질음).
    #   음색이 겹치면 무엇을 맞혔는지 소리로 알 수 없다.
    "bumper_button": {
        "why": "딱. 단단한 플라스틱 단추",
        "len": (5, 160), "low": 40,
    },
    "bumper_cotton": {
        "why": "푹. 소리를 먹는다 — 밝으면 솜이 아니다",
        "len": (20, 350), "cent": (100, 3500),
    },
    "bumper_spring": {
        "why": "끽+팡. 흔들리는 음정이 읽혀야 한다",
        "len": (40, 500), "harm": 15,
    },
    "bumper_drum": {
        "why": "통. 속 빈 울림 — 저역이 있어야 한다",
        "len": (20, 350), "cent": (100, 4000),
    },
    "bumper_cannon_click": {
        "why": "철컥. 짧은 걸림쇠",
        "len": (5, 160),
    },
    "bumper_cannon_fire": {
        "why": "팡. 둥글고 바람기 있는 발사",
        "len": (20, 350),
    },
    "bumper_destroy": {
        "why": "장난감이 부서짐. 파편이 흩어지는 잔향",
        "len": (40, 500),
    },
    "bumper_respawn": {
        "why": "태엽이 다시 감김. 예고음이라 길어도 된다",
        "len": (50, 700),
    },
}


def analyse(cut_path, raw_path):
    rate, data = wavfile.read(str(cut_path))
    x = data.astype(np.float64) / 32768.0

    # ★ 무음 판정은 정규화 전 **원본**으로 한다.
    #   추출본은 전부 -10dBFS 로 맞춰져 있어 여기서는 아무것도 알 수 없다.
    raw_peak_db, snr_db = -999.0, -999.0
    if raw_path.exists():
        rate_r, raw = wavfile.read(str(raw_path))
        r = raw.astype(np.float64) / 32768.0
        r = r if r.ndim == 1 else r.mean(axis=1)
        peak = np.max(np.abs(r)) or 1e-9
        raw_peak_db = 20.0 * np.log10(peak)

        # 10ms 창 중 가장 조용한 곳을 잡음 바닥으로 본다
        w = max(int(0.010 * rate_r), 1)
        windows = np.array([np.sqrt(np.mean(r[i:i + w] ** 2))
                            for i in range(0, max(len(r) - w, 1), w)])
        quiet = windows[windows > 0]
        floor = float(np.min(quiet)) if quiet.size else 1e-9
        snr_db = 20.0 * np.log10(peak / max(floor, 1e-9))

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
        "snr_db": snr_db,
        "eff_ms": eff_ms,
        "centroid": float((S * f).sum() / tot),
        "low": float(S[f < 800].sum() / tot * 100.0),
        "audible": float(S[f >= AUDIBLE_FLOOR_HZ].sum() / tot * 100.0),
        "glass": float(S[(f >= 4000) & (f <= 10000)].sum() / tot * 100.0),
        "harm": float(harm),
    }


def verdict(role, m):
    spec = ROLE_SPECS.get(role)
    fails = []

    # ① 소리가 아예 안 나오는 것 — 잡음 위로 올라와 있는가로 본다
    if m["snr_db"] < MIN_SNR_DB:
        return ["①무음(SNR %.0fdB)" % m["snr_db"]]

    if m["raw_peak_db"] < ABSOLUTE_FLOOR_DBFS:
        return ["①무음(%.0fdB)" % m["raw_peak_db"]]

    # 들리는 대역이 비었으면 게임에서는 무음이다
    if m["audible"] < MIN_AUDIBLE_SHARE:
        return ["①가청대역 %.1f%%(≥%d)" % (m["audible"], MIN_AUDIBLE_SHARE)]

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
                  f"{m['eff_ms']:5.0f}ms SNR{m['snr_db']:5.0f}dB "
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
