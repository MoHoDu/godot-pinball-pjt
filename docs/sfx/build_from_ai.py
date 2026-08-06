#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
③ 마감 단계 — 채택한 AI 소재를 게임 규격으로 마감해 반입한다

  python build_from_ai.py [--dry-run] [--only 역할 ...]

★ AI 추출본을 그대로 게임에 넣으면 안 된다. 두 가지가 어긋난다.

  ① 길이 — 추출본은 그룹마다 한 길이로 잘려 있다.
     그러면 "패링이 일반 타격보다 길어야 구분된다"(sfx_asset_spec_test)가
     깨진다. 둘 다 같은 길이가 되기 때문이다.

  ② 음량 위계 — 추출본은 전부 -10dBFS 로 정규화돼 있다.
     기획서가 요구하는 우선순위별 음량 관계가 통째로 사라진다.

그래서 **재질만 AI 에서 가져오고, 엔벨로프와 dB 는 절차적으로 확정한다.**
계획서의 "절차적 <-> AI 왕복" 이 실제로 만나는 지점이다.

음량 설계는 가이드가 세 곳(p.42 · p.90 · p.154)에서 반복한 우선순위를 따른다.

    패링 > 보스 > 플리퍼 타격 > 공·범퍼 > 벽 > 앰비언트

자주 나는 소리일수록 작아야 한다. 콤보 상승음은 한 콤보에 수십 번 나므로
가장 작은 축에 둔다. 크면 몇 초 만에 귀가 지친다.
"""

import argparse

import numpy as np
from scipy.io import wavfile

from scipy import signal

from build_sfx import (SR, ROOT, band_noise, gate, modal, norm_peak, secs,
                       trim_floor, write_wav, measure)
from sfx_layout import RAW, ROLES

RESOURCES = ROOT.parent.parent / "Resources" / "sfx"

# 역할 -> (그룹, 폴더, 파일, 반출 경로, 피크dB, 게이트 hold, fall, 고른 근거)
#
# 피크dB 는 파일에 구워지는 값이다. 속도->음량과 피치 +-5% 는 런타임이 건다.
TARGETS = {
    # ── 플리퍼. 값은 build_flipper_sfx.py SPECS 와 같아야 한다 ──
    "flipper_select": ("flipper", "flippers/SFX_Flipper_Select",
                       -14.0, 0.030, 0.055, "flipper_select_05.wav",
                       "21ms 중심 3268Hz — 가장 짧고 깔끔한 딸깍"),
    # ★ AI 소재 + 절차적 기계층. flipper_activate() 참고
    "flipper_activate": ("flipper", "flippers/SFX_Flipper_Activate",
                         -9.0, 0.150, 0.235, None,
                         "★ AI 공기감 + 태엽 걸림쇠 합성 — '쩅' 을 줄이고 '끼리릭' 을 넣음"),
    "flipper_hit": ("flipper", "flippers/SFX_Flipper_Hit",
                    -4.0, 0.095, 0.150, "flipper_hit_04.wav",
                    "유리 60% 배음 59% — 18번 만에 나온 유일한 유리"),
    "flipper_strong": ("flipper", "flippers/SFX_Flipper_StrongHit",
                       -2.5, 0.120, 0.185, "flipper_strong_02.wav",
                       "중심 6017Hz 유리 58% — 타격보다 밝아 세기가 읽힌다"),
    "flipper_return": ("flipper", "flippers/SFX_Flipper_Return",
                       -16.0, 0.080, 0.130, "flipper_return_02.wav",
                       "유리 78% 배음 77% — 초고역 히스가 아닌 태엽 틱"),
    "flipper_parry": ("flipper", "flippers/SFX_Flipper_Parry",
                      -1.0, 0.130, 0.240, "flipper_parry_06.wav",
                      "57ms 중심 1618Hz 배음 54% — 음정이 읽히는 짧은 폭"),

    # ── Tier 3 흐름 ──
    "flow_launch": ("flow", "balls/SFX_Ball_Launch",
                    -5.0, 0.090, 0.200, "flow_launch_03.wav",
                    "태엽이 풀리는 스프링 질감. 세기는 speed 로 런타임 조절"),
    "flow_drain": ("flow", "balls/SFX_Ball_Drain",
                   -7.0, 0.120, 0.280, "flow_drain_01.wav",
                   "저역 100% — 공을 잃는 가라앉는 느낌"),
    "combo_rise": ("combo", "combo/SFX_Combo_Rise",
                   # ★ 한 콤보에 수십 번 난다. 전체에서 가장 작아야 한다
                   -15.0, 0.050, 0.120, "combo_rise_01.wav",
                   "한 음. 피치 사다리는 런타임이 태운다"),
    "combo_tier": ("combo", "combo/SFX_Combo_Tier",
                   -6.0, 0.100, 0.260, "combo_tier_01.wav",
                   "상승음보다 크고 밝다 — 단계가 올랐다는 신호"),
    "combo_timeout": ("combo", "combo/SFX_Combo_Timeout",
                      -10.0, 0.120, 0.300, "combo_timeout_02.wav",
                      "중심 160Hz SNR 54dB — 가청대역 기준을 넘은 유일한 통과본"),
    "combo_target": ("combo", "combo/SFX_Combo_Target",
                     -4.0, 0.140, 0.340, "combo_target_03.wav",
                     "유리 90% — 목표 도달의 밝은 성취"),
    "wave_win": ("wave", "wave/SFX_Wave_Win",
                 -3.0, 0.220, 0.560, "wave_win_01.wav",
                 "오르골 한 음. 저주가 풀리는 순간"),
    "wave_lose": ("wave", "wave/SFX_Wave_Lose",
                  -5.0, 0.240, 0.600, "wave_lose_03.wav",
                  "중심 1415Hz 배음 95% — 아래로 미끄러지는 태엽"),

    # ── Tier 4 범퍼. 5종이 서로 확실히 갈려야 무엇을 맞혔는지 안다 ──
    "bumper_button": ("bumper", "bumpers/SFX_Bumper_Button",
                      -6.0, 0.040, 0.090, "bumper_button_02.wav",
                      "딱. 단단한 플라스틱"),
    "bumper_cotton": ("bumper", "bumpers/SFX_Bumper_Cotton",
                      -9.0, 0.070, 0.150, "bumper_cotton_06.wav",
                      "푹. 소리를 먹는다 — 유일한 통과본"),
    "bumper_spring": ("bumper", "bumpers/SFX_Bumper_Spring",
                      -6.0, 0.110, 0.260, "bumper_spring_01.wav",
                      "끽+팡. 흔들리는 음정"),
    "bumper_drum": ("bumper", "bumpers/SFX_Bumper_Drum",
                    -6.0, 0.090, 0.200, "bumper_drum_05.wav",
                    "통. SNR 56dB 로 다섯 중 가장 깨끗하다"),
    "bumper_cannon_click": ("bumper", "bumpers/SFX_Bumper_CannonClick",
                            -12.0, 0.030, 0.070, "bumper_cannon_click_03.wav",
                            "철컥. 조작음이라 작게"),
    # ★ 소재가 AI 가 아니라 절차적 합성이다. 아래 PROCEDURAL 참고.
    "bumper_cannon_fire": ("bumper", "bumpers/SFX_Bumper_CannonFire",
                           -5.0, 0.100, 0.230, None,
                           "★ 절차적 대체본 — AI 6개가 전부 탈락했고 크레딧이 없다"),
    "bumper_destroy": ("bumper", "bumpers/SFX_Bumper_Destroy",
                       -4.0, 0.130, 0.320, "bumper_destroy_01.wav",
                       "장난감이 부서짐. 파편이 흩어진다"),
    "bumper_respawn": ("bumper", "bumpers/SFX_Bumper_Respawn",
                       -13.0, 0.160, 0.380, "bumper_respawn_01.wav",
                       "태엽이 다시 감김. 예고음이라 작게"),
}

# AI 소재가 없어 절차적으로 합성하는 역할
PROCEDURAL = {
    "bumper_cannon_fire": lambda: cannon_fire(),
    "flipper_activate": lambda: flipper_activate(),
}

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/{rel}.wav"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def tilt_highs(x, cutoff=4200.0, amount=0.80):
    """고역을 깎는다. 완전히 자르지 않고 남길 비율을 정한다.

    완전히 자르면 재질이 죽어 뭉툭해진다. 날은 남기고 찌르는 것만 없앤다.
    """
    b, a = signal.butter(2, cutoff / (SR / 2.0), btype="low")
    low = signal.lfilter(b, a, x)
    return low + (x - low) * (1.0 - amount)


def escapement(n, teeth=8, seed=5, slow=1.35):
    """태엽 걸림쇠가 톱니를 하나씩 넘기는 소리 — '드르륵'.

    ★ 1차 시도의 실패: 톱니 16개를 180ms 안에 **가속하며** 넣었다.
      간격이 평균 11ms(약 90Hz)라 개별 톱니가 안 들리고 하나의 버즈로
      뭉쳤다. 형락님 판정 "굉장히 별로".

      톱니가 **돌아가는** 것으로 들리려면 하나하나가 분리돼 들려야 한다.
      그래서 개수를 절반으로 줄이고 간격을 20~28ms(35~50Hz)로 벌린다.
      그리고 가속이 아니라 **감속**이다 — 태엽은 풀릴수록 느려진다.

    ★ 두 번째 실패 요인: 톱니를 대역 노이즈로만 만들었다.
      그건 금속이 아니라 부스럭거림이다. 톱니 하나는 놋쇠가 튕기는
      **짧은 음정**이다. 그래서 모달 링을 쓰고 노이즈는 어택에만 얹는다.
    """
    y = np.zeros(n)

    # 간격이 점점 벌어진다. 태엽이 풀리며 느려진다
    gaps = np.linspace(1.0, slow, teeth)
    at = np.concatenate([[0.0], np.cumsum(gaps)[:-1]])
    at = at / (at[-1] or 1.0)

    for i, p in enumerate(at):
        start = int(p * n * 0.88)
        if start >= n - 16:
            break

        rest = n - start
        # 톱니마다 음정이 조금씩 내려간다. 기계는 완전히 같은 소리를 두 번 내지 않는다
        drift = 1.0 - 0.045 * i
        tooth = modal(rest, [
            (2680.0 * drift, 1.00, 0.0045),
            (4130.0 * drift, 0.46, 0.0032),
            (6240.0 * drift, 0.18, 0.0022),
        ], seed=seed + i * 7)

        # 놋쇠가 걸리는 순간의 긁힘. 어택에만 짧게
        scrape = band_noise(rest, 1900.0, 5200.0, 0.0011, seed=seed + 40 + i) * 0.34

        # 뒤로 갈수록 약해진다. 스프링 장력이 빠진다
        y[start:] += (tooth + scrape) * (1.0 - 0.42 * i / max(teeth - 1, 1))

    return y / (np.max(np.abs(y)) or 1.0)


def flipper_activate():
    """플리퍼 작동음 — ★ AI 소재 + 절차적 기계층.

    형락님 지적(2026-08-06): "쩅 하는 소리가 너무 크다. 끼리릭 소리가 나야 한다."

    측정해보니 그럴 만했다. AI 소재(flipper_activate_06)는 에너지의 **83%가
    6~10kHz**에 몰려 있고 피크가 9705Hz 였다. 그게 '쩅' 이다. 그리고
    **300~1200Hz 가 0.0%** — 기계 몸통이 아예 없었다.

    AI 후보 3개가 전부 중심 8227~9016Hz 라 다른 것으로 바꿔도 같다.
    크레딧도 없다. 그래서 두 가지를 한다.

      ① 고역을 깎는다 — '쩅' 을 줄인다
      ② 태엽 걸림쇠와 몸통을 합성해 얹는다 — '끼리릭' 을 만든다

    AI 소재를 버리지 않는 이유는 스프링이 풀리는 공기감이 거기 있어서다.
    합성만으로는 그 불규칙함이 안 나온다.
    """
    src = find_source("flipper", "flipper_activate_06.wav")
    n = secs(0.26)

    air = np.zeros(n)
    if src is not None:
        raw = tilt_highs(load_mono(src), amount=0.62)
        m = min(len(raw), n)
        air[:m] = raw[:m] * 0.26      # 공기감만 남기고 물러선다

    # 기계 몸통. 여기가 통째로 비어 있었다
    # ★ 몸통은 받쳐주기만 한다. 세우면 '끼리릭' 이 아니라 '툭' 이 된다.
    #   1차 시도에서 몸통을 크게 잡았더니 피크가 351Hz 로 내려앉아 둔탁했다.
    body = modal(n, [
        (352.0, 1.00, 0.058),
        (615.0, 0.62, 0.044),
        (1140.0, 0.38, 0.030),
    ], seed=3) * 0.55

    # 축이 도는 마찰. 톱니 사이를 메워 '기계 안에서 나는 소리' 로 만든다.
    # 이게 없으면 톱니만 공중에 떠 있어 플라스틱처럼 들린다.
    friction = band_noise(n, 240.0, 950.0, 0.075, seed=17) * 0.045

    # ★ 균형은 계산이 아니라 측정으로 잡았다. 저역 목표는 30% 안팎이다.
    #   몸통 0.52(tau 0.030) -> 저역 4.7%   : 톱니만 떠 있어 플라스틱
    #   몸통 1.35 + 마찰 0.42 -> 저역 83.6% : 톱니가 묻혀 웅웅거림
    #   몸통 0.55 + 마찰 0.045 -> 저역 33%  : 여기
    x = air + body + friction + escapement(n) * 1.00
    return np.tanh(x * 1.2) / np.tanh(1.2)


def cannon_fire():
    """태엽대포 발사 '팡' — ★ 절차적 대체본이다.

    AI 6개가 전부 탈락했다. 마지막 하나(bumper_cannon_fire_02)는 SNR 62dB 로
    멀쩡해 보였지만 **에너지의 99.9%가 50Hz 아래**인 압력 계단이었다.
    DC 오프셋 -0.0196 이 피크로 잡혀 "신호가 있다"고 통과했던 것이다.

    다시 뽑으려 했으나 API 키 한도(2000크레딧)가 소진됐다. 한도를 올리면
    generate_elevenlabs.py bumper --only bumper_cannon_fire 로 교체하면 된다.

    구성은 코르크 대포다 — 짧은 공기 파열 + 통이 울리는 낮은 몸통.
    """
    n = secs(0.24)

    # 통의 울림. 대포지만 장난감이라 나무통에 가깝다 (가이드 p.61)
    body = modal(n, [
        (392.0, 1.00, 0.052),
        (734.0, 0.44, 0.038),
        (1180.0, 0.21, 0.024),
    ], seed=7)

    # 코르크가 빠지는 공기 파열. 이것이 '팡' 을 만든다
    puff = band_noise(n, 900.0, 4200.0, 0.018, seed=11) * 0.85

    # 파열 직전의 아주 짧은 압축 틱
    tick = band_noise(n, 2600.0, 7000.0, 0.0035, seed=13) * 0.42

    x = body + puff + tick
    return np.tanh(x * 1.35) / np.tanh(1.35)   # 부드러운 새추레이션


def find_source(group, filename):
    """역할 폴더 어디에 있든 파일명으로 찾는다."""
    hits = list((RAW / group).glob(f"*/{filename}"))
    return hits[0] if hits else None


def load_mono(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64) / 32768.0
    x = x if x.ndim == 1 else x.mean(axis=1)

    if rate != SR:
        idx = np.linspace(0, len(x) - 1, int(len(x) * SR / rate))
        x = np.interp(idx, np.arange(len(x)), x)

    return x


def centroid(x):
    """마감 뒤에도 재질이 살아 있는지 보는 값."""
    S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return float((S * f).sum() / (S.sum() or 1e-12))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", nargs="+", metavar="역할")
    args = ap.parse_args()

    targets = TARGETS
    if args.only:
        targets = {k: v for k, v in TARGETS.items() if k in args.only}

    print(f"{'역할':22s}{'길이':>9s}{'피크':>9s}{'중심':>8s}  반출")
    print("-" * 80)

    lengths, peaks = {}, {}
    for role, (group, rel, peak_db, hold, fall, filename, why) in targets.items():
        if filename is None:
            raw = PROCEDURAL[role]()          # AI 소재가 없어 합성한 것
        else:
            src = find_source(group, filename)
            if src is None:
                print(f"★ 소재가 없다: {group}/**/{filename}")
                return 1
            raw = load_mono(src)

        # 재질은 AI, 엔벨로프와 음량은 절차적. 왕복이 만나는 지점이다.
        x = norm_peak(trim_floor(gate(raw, hold, fall)), peak_db)
        lengths[role], peaks[role] = len(x) / SR, peak_db

        print(f"{role:22s}{lengths[role] * 1000:8.1f}ms{measure(x)['peak_dbfs']:8.1f}dB"
              f"{centroid(x):7.0f}Hz  {rel}.wav")
        print(f"{'':22s}{ROLES.get(role, '')}")
        print(f"{'':22s}└ {why}")

        if args.dry_run:
            continue

        out = RESOURCES / f"{rel}.wav"
        out.parent.mkdir(parents=True, exist_ok=True)
        write_wav(out, x)

        # ★ .import 이 없으면 Godot 이 기본값(QOA 손실 압축)으로 임포트한다.
        #   어택 트랜지언트와 구워둔 dB 관계가 흔들린다.
        #   uid 와 path 는 Godot 이 첫 임포트 때 채운다.
        imp = out.with_suffix(".wav.import")
        if not imp.exists():
            imp.write_text(IMPORT_TEMPLATE.format(rel=rel), encoding="utf-8")

    # ★ 여기서 걸리면 게임에 넣지 않는다.
    if len(targets) == len(TARGETS):
        order = ["flipper_return", "flipper_select", "flipper_activate",
                 "flipper_hit"]
        got = [peaks[r] for r in order]
        assert got == sorted(got), f"복귀<선택<작동<타격 이어야 한다: {got}"
        assert lengths["flipper_parry"] > lengths["flipper_hit"], \
            "패링이 일반 타격보다 길어야 구분된다"
        assert peaks["combo_rise"] < peaks["combo_tier"], \
            "콤보 상승음은 단계음보다 작아야 한다 (수십 번 난다)"
        assert peaks["flipper_parry"] == max(peaks.values()), \
            "패링이 전체에서 가장 커야 한다 (우선순위 1위)"
        print("\n자가 검증 통과 — 음량 위계 · 패링 길이 · 콤보 빈도 · 우선순위")

    if args.dry_run:
        print("--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"\n{len(targets)}종 반입 → {RESOURCES}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
