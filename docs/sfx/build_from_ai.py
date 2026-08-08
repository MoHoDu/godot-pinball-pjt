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
INBOX = ROOT / "inbox"

# 형락님이 직접 뽑아 넣는 슬롯 번호. inbox/ 의 파일 이름에 이 번호가 들어간다.
# 번호표는 docs/sfx/inbox/README.md 와 같아야 한다.
SLOT_CODES = {
    "flipper_select": "A1",
    "flipper_activate": "A2",
    "flipper_return": "A3",
    "flipper_hit": "A4",
    "flipper_strong": "A5",
    "flipper_parry": "A6",
    "wall_low": "B1",
    "wall_mid": "B2",
    "wall_high": "B3",
    "flow_launch": "B4",
    "flow_drain": "B5",
    "ball_select": "B6",
}

# 역할 -> (그룹, 폴더, 파일, 반출 경로, 피크dB, 게이트 hold, fall, 고른 근거)
#
# 피크dB 는 파일에 구워지는 값이다. 속도->음량과 피치 +-5% 는 런타임이 건다.
TARGETS = {
    # ── 플리퍼. 값은 build_flipper_sfx.py SPECS 와 같아야 한다 ──
    "flipper_select": ("flipper", "flippers/SFX_Flipper_Select",
                       -14.0, 0.030, 0.055, "flipper_select_05.wav",
                       "★ 형락님 채택본(Firefly) — 35ms 짧은 딸깍 2연타(24ms 간격), "
                       "SNR 79dB. 중심 9998Hz 로 밝은 편이다"),
    # ★ 형락님 채택본이 inbox 에 있으면 그것을 쓴다.
    #   없을 때만 flipper_activate() 합성본으로 떨어진다.
    "flipper_activate": ("flipper", "flippers/SFX_Flipper_Activate",
                         -9.0, 0.150, 0.235, None,
                         "★ 형락님 채택본 — 철컥+덜컹. 타격 2개가 37ms 간격, "
                         "쇠(1~12kHz 64%) + 몸통(150Hz 아래 24%)"),
    "flipper_hit": ("flipper", "flippers/SFX_Flipper_Hit",
                    -2.0, 0.095, 0.150, "flipper_hit_04.wav",
                    "★ 형락님 채택본(Firefly + 목소리) — 풀스케일, SNR 94dB, "
                    "중심 1527Hz. 1~6kHz 63%로 어택이 살아 있다"),
    "flipper_strong": ("flipper", "flippers/SFX_Flipper_StrongHit",
                       -1.6, 0.120, 0.185, "flipper_strong_02.wav",
                       "중심 6017Hz 유리 58% — 타격보다 밝아 세기가 읽힌다"),
    "flipper_return": ("flipper", "flippers/SFX_Flipper_Return",
                       -15.0, 0.080, 0.130, None,
                       "★ A2 작동음에서 파생 — 덜컹만 남기고 철컥은 흔적만. "
                       "같은 기계에서 나야 플리퍼가 하나로 들린다"),
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
    # ★ A2 에서 파생한다. inbox 에 A3 가 들어오면 그쪽이 우선한다.
    "flipper_return": lambda: flipper_return(),
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


def flipper_return():
    """플리퍼 복귀음 — ★ A2(작동음)에서 파생한다.

    형락님 지시(2026-08-07): "플리퍼가 아래로 내려갔을 때 소리도 A2 참고해서".

    맞는 판단이다. **같은 기계에서 나는 소리**라 따로 뽑으면 재질이 어긋나
    두 장치처럼 들린다. 올라가는 소리와 내려오는 소리가 다른 물건이면
    플리퍼 하나가 아니라 둘이 있는 것처럼 들린다.

    물리적으로도 둘은 다르다.
      올라갈 때 — 솔레노이드가 **때린다**. 철컥(쇠 걸쇠) + 덜컹(통)
      내려올 때 — 그냥 **떨어진다**. 때리는 힘이 없으니 철컥이 거의 없고
                  통이 받는 덜컹만 남는다

    그래서 A2 의 **두 번째 타격(덜컹)부터** 가져오고, 첫 타격(철컥)은
    흔적만 남긴다. 고역도 함께 깎는다 — 힘이 안 실린 접촉은 밝지 않다.
    """
    src = find_inbox("flipper", "flipper_activate")
    if src is None:
        return None

    x = align_to_onset(load_mono(src))

    # 타격 두 개를 찾는다. 파일이 바뀌어도 따라가도록 위치를 고정하지 않는다.
    w = max(int(0.003 * SR), 1)
    env = np.sqrt(np.convolve(x ** 2, np.ones(w) / w, "same"))
    rise = np.diff(env)
    rise[rise < 0] = 0.0
    peaks, _ = signal.find_peaks(
        rise, height=np.max(rise) * 0.25, distance=int(0.02 * SR)
    )

    if len(peaks) >= 2:
        landing = max(int(peaks[1]) - int(0.004 * SR), 0)
        y = np.zeros(len(x) - landing)
        y[:] = x[landing:]

        # 철컥의 흔적. 아주 작게 앞에 둔다 — 걸쇠가 풀리는 소리는 남는다
        head = x[:landing]
        n = min(len(head), len(y))
        # ★ 철컥 흔적을 거의 없앤다. 남기면 A2 와 구분이 안 된다는 지적이 나왔다.
        y[:n] += head[:n] * 0.05
    else:
        y = x.copy()

    # ★ 떨어지는 접촉은 눌러 앉는다. 살짝 낮춰 A2 와 음높이를 벌린다.
    #   같은 기계인 것은 유지하되 "올라감/내려옴"이 귀로 갈려야 한다.
    idx = np.arange(0, len(y), 0.94)
    y = np.interp(idx, np.arange(len(y)), y)

    # 힘이 안 실린 접촉은 밝지 않다
    # ★ 너무 죽이면 A2 옆에서 아예 안 들린다. 어둡되 윤곽은 남긴다.
    return tilt_highs(y, cutoff=2800.0, amount=0.62)


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


def find_inbox(group, role):
    """★ 형락님이 직접 뽑아 넣은 파일이 있으면 그것을 최우선으로 쓴다.

    `docs/sfx/inbox/<그룹>/` 에서 슬롯 번호(A1~A6 · B1~B6)로 찾는다.
    파일 이름은 번호만 맞으면 된다 — `A2.wav` · `A2_01.wav` · `A2 좋은거.wav`.

    여러 개가 있으면 이름 순으로 첫 번째를 쓴다. 고르는 것은 사람의 일이고
    이 스크립트는 마감만 한다.
    """
    code = SLOT_CODES.get(role)
    if code is None:
        return None

    d = INBOX / group
    if not d.is_dir():
        return None

    hits = [p for p in sorted(d.iterdir())
            if p.suffix.lower() in (".wav", ".mp3") and code in p.stem.upper()]
    return hits[0] if hits else None


def align_to_onset(x, rate=SR, pre_ms=2.0):
    """첫 타격 바로 앞에서 자른다.

    ★ 앞에 붙은 무음을 안 자르면 그만큼 소리가 늦게 난다. 받은 A1 은
      15ms 가 비어 있었다. 충돌음에서 15ms 지연은 어긋난 것으로 들린다.

    ★ 순간값이 아니라 3ms 이동 RMS 로 본다. 조용한 파일에서는 앞쪽 잡음이
      순간 문턱을 먼저 넘어 타격이 아니라 무음을 잘라내게 된다
      (extract_material.first_onset 과 같은 이유).
    """
    if np.max(np.abs(x)) <= 0:
        return x

    win = max(int(0.003 * rate), 1)
    usable = x[:len(x) // win * win]
    if len(usable) < win:
        return x

    frames = np.sqrt((usable.reshape(-1, win) ** 2).mean(axis=1))
    above = np.where(frames > frames.max() * 0.35)[0]
    if not len(above):
        return x

    start = max(int(above[0] * win) - int(pre_ms / 1000.0 * rate), 0)
    return x[start:]


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
        # ★ 소재 우선순위: 받은 파일 > 절차적 합성 > AI 원본
        inbox = find_inbox(group, role)
        if inbox is not None:
            raw = align_to_onset(load_mono(inbox))
            origin = f"받음 {inbox.name}"
        elif filename is None:
            raw = PROCEDURAL[role]()
            origin = "절차적 합성"
        else:
            src = find_source(group, filename)
            if src is None:
                print(f"★ 소재가 없다: {group}/**/{filename}")
                return 1
            raw = load_mono(src)
            origin = f"AI {filename}"

        # 재질은 AI, 엔벨로프와 음량은 절차적. 왕복이 만나는 지점이다.
        x = norm_peak(trim_floor(gate(raw, hold, fall)), peak_db)
        lengths[role], peaks[role] = len(x) / SR, peak_db

        print(f"{role:22s}{lengths[role] * 1000:8.1f}ms{measure(x)['peak_dbfs']:8.1f}dB"
              f"{centroid(x):7.0f}Hz  {rel}.wav")
        print(f"{'':22s}{ROLES.get(role, '')}")
        print(f"{'':22s}└ {origin}  ·  {why}")

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
