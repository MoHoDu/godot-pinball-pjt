#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
그룹 4 — 범퍼 8종을 inbox 소재에서 마감한다.

  python build_bumper_group.py [--dry-run]

★ 재질 5종이 **서로 확실히 갈려야** 한다.
  음색이 겹치면 무엇을 맞혔는지 화면을 봐야 안다. 그래서 중심 주파수를
  일부러 벌려 두고, 마지막에 서로 1.4배 이상 떨어졌는지 검사한다.

    솜 237Hz  <  북 340Hz  <  용수철 994Hz  <  단추 3288Hz  <  대포 6321Hz

★ Firefly 가 대역 밖으로 준 것이 넷이라 피치로 끌어온다.
    솜 22~43Hz · 북 217Hz        -> 너무 낮다. 올린다
    대포 철컥 12339Hz · 리스폰 10084Hz -> 순수 히스다. 내린다

  이것이 다섯 번째 같은 함정이다. Firefly 는 soft/muffled/low 를 주면
  가청대역을 비우고, brass/ratchet/whirr 를 주면 초고역만 준다.
  프롬프트를 더 굴리는 것보다 받은 소재를 옮기는 쪽이 확실하다.
"""

import argparse
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

from build_sfx import SR, ROOT, gate, norm_peak, secs, trim_floor, tt, write_wav
from cut_best_hit import cut_best_hit

INBOX = ROOT / "inbox" / "bumper"
WALL = ROOT / "inbox" / "ball"
FLIPPERS = ROOT.parent.parent / "Resources" / "sfx" / "flippers"
OUT = ROOT.parent.parent / "Resources" / "sfx" / "bumpers"

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://Resources/sfx/bumpers/{name}.wav"

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


def load(path):
    rate, data = wavfile.read(str(path))
    x = data.astype(np.float64) / 32768.0
    x = x if x.ndim == 1 else x.mean(axis=1)

    if rate != SR:
        idx = np.linspace(0, len(x) - 1, int(len(x) * SR / rate))
        x = np.interp(idx, np.arange(len(x)), x)

    return x


def shift(x, ratio):
    """재생 속도를 바꿔 음높이를 옮긴다.

    ratio > 1 이면 올라가고 짧아진다. 길이는 게이트가 어차피 다시 자른다.

    ★ 걸음 폭이 곧 배속이다. 1/ratio 로 쓰면 정반대로 움직인다 —
      처음에 그렇게 써서 여섯 배 올리려던 솜이 그대로 28Hz 에 남았다.
    """
    idx = np.arange(0, len(x), ratio)
    return np.interp(idx, np.arange(len(x)), x)


def tilt(x, cutoff, amount):
    b, a = signal.butter(2, cutoff / (SR / 2.0), btype="low")
    low = signal.lfilter(b, a, x)
    return low + (x - low) * (1.0 - amount)


def src(name):
    return cut_best_hit(load(INBOX / name))


def saturate(x, drive):
    """뾰족한 피크를 눌러 실체를 만든다.

    ★ 종이봉투 파열음은 순간 피크만 크고 몸통이 없다. 피크로 정규화하면
      RMS 가 -35dB 까지 내려가, 북(-17.7dB)보다 17dB 작게 들린다.
      '펑' 이 아니라 '틱' 이다.

      레이어 비율을 올려도 소용없었다 — 피크를 정하는 것이 그 파열 순간이라
      비율만 바뀌고 정규화 뒤 결과가 같았다(0.85배와 7배가 동일). 크레스트
      팩터 자체를 줄여야 한다.

    폭발음을 크게 들리게 하는 표준 처리다. 소재를 만들어내는 것이 아니라
    받은 소재의 파형을 다듬는 것이다.
    """
    peak = float(np.max(np.abs(x))) or 1e-9
    return np.tanh(x / peak * drive) / np.tanh(drive)


def hipass(x, cutoff):
    """가청대역 아래를 잘라낸다.

    ★ Firefly 는 부드러운 재질을 요구하면 에너지를 150Hz 아래에 쏟는다.
      노트북 스피커가 못 내는 대역이라, 피크는 멀쩡한데 실제로는 안 들린다.
      쿠션 소재가 정확히 그랬다 — 채택한 변형조차 49% 가 그 아래였다.
    """
    b, a = signal.butter(3, cutoff / (SR / 2.0), btype="high")
    return signal.lfilter(b, a, x)


def button():
    """단추 — 작은 플라스틱 조각이 틱틱.

    ★ 프롬프트를 `Two quick plastic ticks, dry and crisp` 로 바꿔 다시 받았다.
      직전 소재는 94ms 에 몸통 67% 라 '딱' 이 아니라 둔탁한 툭이었다.

      4변형 중 **변형4** 를 골랐다. 넷 다 밝았지만 셋은 고역 93~100% 인
      순수 히스였고, 변형4 만 몸통이 20% 남아 있어 '조각' 의 실체가 있다.
    """
    return src("C1_button.wav")


def cotton():
    """솜 — 푸슥. 눌리는 몸통 위에 진짜 솜 부스럭이 얹힌다.

    ★ 베개 몸통만으로는 "솜은 저렇게 둔탁한 소리를 내지 않는다"는 지적을
      받았다 (2026-08-07 밤). 맞는 말이다 — 떨어지는 퍽만 있고 섬유가
      비벼지는 결이 없었다.

      그래서 솜뭉치를 쥐어짜는 소리를 따로 받았다.
      `A fluffy cotton ball squeezed softly, airy gentle rustle` 변형4.
      4변형 전부 중심 4~10kHz 의 진짜 공기 결이었다.

      부스럭은 3.5kHz 로 눌러 히스를 걷어내고 0.45 로 섞는다.
      더 올리면 철컥(2595Hz)과 중심이 붙고, 내리면 다시 둔탁해진다.
    """
    body = tilt(hipass(src("C2_cotton.wav"), 45.0), 1200.0, 0.70)

    b, a = signal.butter(2, 3500.0 / (SR / 2.0), btype="low")
    rustle = signal.lfilter(b, a, src("C2_rustle.wav"))

    n = max(len(body), len(rustle))
    rms = lambda v: float(np.sqrt(np.mean(v ** 2))) or 1e-9

    mixed = np.zeros(n)
    for layer, gain in [(body, 1.0), (rustle, 0.45)]:
        mixed[:len(layer)] += (layer / rms(layer)) * gain

    return mixed


def spring():
    """용수철 인형 — 끽 + 팡. 흔들리는 음정이 읽혀야 한다."""
    return src("C3_spring.wav")


def drum():
    """북 — 베이스 드럼. 깊은 둥.

    ★ 톰에서 **킥 드럼**으로 지정이 바뀌었다 (2026-08-07 밤).
      `A bass drum kick, one deep booming thump` 4변형 전부 중심 41~46Hz,
      에너지 100% 가 60Hz 아래 — 진짜 킥은 원래 이렇게 깊다.

      다만 60Hz 아래는 웬만한 스피커가 아예 못 낸다. 그래서 1.5배 올리고
      새추레이션으로 배음을 세워 **중심 71Hz·에너지 94% 를 60~150Hz** 에
      앉혔다. 깊은 킥의 느낌은 그대로, 재생만 되게 옮긴 것이다.
    """
    return saturate(hipass(shift(src("C4_drum.wav"), 1.5), 35.0), 8.0)


def cannon_aim():
    """태엽 대포 조준 — 방향을 한 칸 옮길 때마다 태엽이 맞물린다.

    ★ 새로 만들지 않고 **A1(플리퍼 선택음)에서 파생**시킨다.
      형락님이 "A1 비슷한 소리"를 지정했고, 실제로 둘은 같은 역할이다 —
      아직 확정되지 않은 선택을 한 칸 옮겼다는 신호다. 같은 계열로
      들리는 편이 조작 언어가 하나로 묶인다.

      조금 올려서 태엽 쪽으로 당기고, 짧게 끊는다.
    """
    return shift(load(FLIPPERS / "SFX_Flipper_Select.wav"), 1.25)


def cannon_click():
    """태엽 대포 조작 — 철컥. 원본이 12kHz 순수 히스라 내려서 쓴다.

    ★ 단추와 겹치지 않게 **용수철과 단추 사이**에 세운다.
      단추를 플라스틱 틱으로 새로 받으면서 5559Hz 로 밝아졌고, 그러자 위에
      있던 철컥(6321Hz)과 1.14배로 붙어 버렸다. 둘 다 짧은 딸깍이라
      중심이 겹치면 무엇을 맞혔는지 전혀 구분되지 않는다.

      두 번째로 겪는 같은 충돌이다. 이번엔 아래로 피한다 —
      태엽이 맞물리는 소리는 원래 단추보다 둔탁한 쪽이 맞다.
    """
    return tilt(shift(src("C5_click.wav"), 0.22), 5000.0, 0.25)


def cannon_fire():
    """대포 발사 — 진짜 대포. 펑.

    ★ `cannon` 을 정면으로 쓰되 `sharp cracking bang` 으로 밝기를 지정했다.
      이전 두 번은 `cannon` 이 35Hz 초저역만 줬는데, 이번엔 4변형 중
      **변형3** 이 하이패스 후 중심 305Hz·몸통 54% 로 실체가 남았다.
      종이봉투 우회는 결만 있고 무게가 없어 형락님이 반려했다.

      초저역만 잘라내고 새추레이션으로 몸통을 세운다. 둘 다 파형 손질이지
      소재 합성이 아니다.
    """
    # ★ 컷을 100 → 40Hz 로 내렸다. 100 에서는 대포의 무게가 다 잘려
    #   '펑' 이 아니라 '탁' 이었다. 솜 참조 영상에서 배운 그대로다 —
    #   저역이 재질이다. 40 은 럼블·DC 만 걷어낸다.
    return saturate(hipass(src("C6_fire.wav"), 40.0), 8.0)



def respawn():
    """리스폰 예고 — 태엽이 다시 감긴다. 알림이지 사건이 아니라 작다."""
    return tilt(shift(src("C8_respawn.wav"), 0.45), 6500.0, 0.35)


# 파일 -> (함수, 피크dB, hold, fall, 설명)
#
# 음량은 기획서 우선순위를 따른다. 파괴가 가장 크고 리스폰 예고가 가장 작다.
SPECS = {
    "SFX_Bumper_Button": (button, -3.0, 0.075, 0.115, "단추 — 플라스틱 조각이 틱틱"),
    "SFX_Bumper_Cotton": (cotton, -9.0, 0.130, 0.210, "솜 — 푹신한 것에 튕긴다"),
    "SFX_Bumper_Spring": (spring, -6.0, 0.100, 0.220, "용수철 인형 — 끽 + 팡"),
    "SFX_Bumper_Drum": (drum, -4.0, 0.090, 0.200, "장난감 북 — 둥. 막이 운다"),
    "SFX_Bumper_CannonClick": (cannon_click, -12.0, 0.035, 0.080, "대포 조작 — 철컥"),
    "SFX_Bumper_CannonAim": (cannon_aim, -17.0, 0.030, 0.055, "대포 조준 — 태엽이 한 칸"),
    # 대포는 이 판의 유일한 "발사 사건"이라 제일 크고 제일 길다.
    # -5dB/200ms 는 작다는 지적을 받았다 (2026-08-07 밤).
    "SFX_Bumper_CannonFire": (cannon_fire, -1.5, 0.180, 0.420, "대포 발사 — 펑"),
    "SFX_Bumper_Respawn": (respawn, -13.0, 0.140, 0.320, "리스폰 예고 — 다시 감긴다"),
}

## ★ 이 다섯은 "무엇을 맞혔는가"를 소리로 알려주는 것들이라 서로 갈려야 한다.
MATERIALS = ["SFX_Bumper_Cotton", "SFX_Bumper_Drum", "SFX_Bumper_Spring",
             "SFX_Bumper_Button", "SFX_Bumper_CannonClick"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print(f"{'파일':26s}{'길이':>7s}{'피크':>8s}{'중심':>8s}{'저':>5s}{'몸통':>6s}{'고':>5s}")
    print("-" * 68)

    cent = {}
    rms_db = {}
    for name, (fn, peak_db, hold, fall, why) in SPECS.items():
        x = norm_peak(trim_floor(gate(fn(), hold, fall)), peak_db)
        rms_db[name] = 20.0 * np.log10(float(np.sqrt(np.mean(x ** 2))) + 1e-12)

        S = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / SR)
        total = S.sum() or 1e-12
        cent[name] = float((S * f).sum() / total)

        print(f"{name:26s}{len(x) / SR * 1000:6.0f}ms{peak_db:7.1f}dB{cent[name]:7.0f}Hz"
              f"{S[f < 400].sum() / total * 100:4.0f}%"
              f"{S[(f >= 400) & (f < 2500)].sum() / total * 100:5.0f}%"
              f"{S[f >= 2500].sum() / total * 100:4.0f}%")
        print(f"{'':26s}{why}")

        if args.dry_run:
            continue

        OUT.mkdir(parents=True, exist_ok=True)
        write_wav(OUT / f"{name}.wav", x)
        (OUT / f"{name}.wav.import").write_text(
            IMPORT_TEMPLATE.format(name=name), encoding="utf-8")

    # ★ 재질 5종이 서로 갈리는가. 여기서 걸리면 게임에 넣지 않는다.
    order = sorted(MATERIALS, key=lambda n: cent[n])
    print("\n재질 5종 (낮은 것부터)")
    for i, name in enumerate(order):
        gap = "" if i == 0 else f"  이전 대비 {cent[name] / cent[order[i - 1]]:.2f}배"
        print(f"  {cent[name]:6.0f}Hz  {name}{gap}")
        if i > 0:
            assert cent[name] >= cent[order[i - 1]] * 1.4, \
                (f"{name} 이 {order[i - 1]} 과 너무 가깝다 "
                 f"({cent[order[i - 1]]:.0f}Hz vs {cent[name]:.0f}Hz). "
                 "무엇을 맞혔는지 소리로 구분되지 않는다.")

    # 파괴음은 형락님 지시로 뺐다 (2026-08-07). 부서질 때는 화면 연출만 남는다.
    # 그래서 "파괴음이 재질음을 덮는가" 검사도 함께 내렸다.

    # 가청대역 검사. Firefly 가 계속 초저역·초고역으로 빠져서 넣었다.
    #
    # ★ 바닥을 150 → **60Hz** 로 내렸다 (2026-08-07 밤).
    #   형락님 참조 영상(솜: 중심 136~184Hz, 에너지 대부분 150Hz 아래)과
    #   베이스 드럼 지정이 증명했다 — 원하는 재질감이 저역 그 자체인 소리가
    #   있다. 60Hz 아래만이 스피커가 아예 못 내는 진짜 불능 영역이다.
    for name in MATERIALS:
        assert cent[name] >= 60.0, \
            f"{name} 중심이 {cent[name]:.0f}Hz 다. 스피커가 아예 못 내는 대역이다."

    print("자가 검증 통과 — 재질 5종이 서로 1.4배 이상 떨어져 있다")
    if args.dry_run:
        print("--dry-run 이라 쓰지 않았다.")
        return 0

    print(f"8종 반입 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
