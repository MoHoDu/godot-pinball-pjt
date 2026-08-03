"""
BallTrail 의 궤적 링버퍼 로직을 그대로 옮겨 시뮬레이션한다.

형락님 영상 지적: "공이 튀기고 나서 속도가 줄어들 때 끝쪽 레이저 잔상이 계속 남아있어".
Godot 을 못 돌리므로 로직만 떼어내 재현하고, 수명 기반 소멸이 실제로 고치는지 확인한다.

★ 이 파일은 ball_trail.gd 의 _sample_history / _drop_expired / _trim_to_length 를
  1:1 로 옮긴 것이다. 원본을 고치면 여기도 같이 고쳐야 한다.
"""
import re
import math

TRES = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt/settings/balls/BallTrailRules.tres"
SAMPLE_STEP_RATIO = 0.18
BR = 22.0
DT = 1.0 / 60.0


def read_rules():
	r = {}
	for ln in open(TRES, encoding="utf-8"):
		m = re.match(r"^(\w+)\s*=\s*([-\d.]+)$", ln.strip())
		if m:
			r[m.group(1)] = float(m.group(2))
	return r


R = read_rules()


def trail_length(speed):
	base = BR * R["length_ratio"]
	s = min(max(speed / max(R["reference_speed"], 1.0),
	            R["min_length_scale"]), R["max_length_scale"])
	return base * s


class Trail:
	def __init__(self, use_lifetime=True):
		self.hist = []
		self.ages = []
		self.use_lifetime = use_lifetime

	def step(self, pos, speed, dt=DT):
		moving = speed >= R["hide_below_speed"]
		for i in range(len(self.ages)):
			self.ages[i] += dt

		if len(self.hist) < 2:
			if moving:
				self.hist = [pos, pos]
				self.ages = [0.0, 0.0]
			return

		self.hist[0] = pos
		self.ages[0] = 0.0

		step = BR * SAMPLE_STEP_RATIO
		if math.dist(pos, self.hist[1]) >= step:
			self.hist.insert(1, pos)
			self.ages.insert(1, 0.0)

		if self.use_lifetime:
			while self.hist and self.ages[-1] > R["point_lifetime"]:
				self.hist.pop()
				self.ages.pop()

		self._trim(speed)

		limit = int(R["point_count"])
		while len(self.hist) > limit:
			self.hist.pop()
			self.ages.pop()

	def _trim(self, speed):
		target = trail_length(speed)
		total = 0.0
		for i in range(1, len(self.hist)):
			seg = math.dist(self.hist[i - 1], self.hist[i])
			if total + seg >= target:
				remain = max(target - total, 0.0)
				ratio = remain / max(seg, 1e-4)
				a, b = self.hist[i - 1], self.hist[i]
				cut = (a[0] + (b[0] - a[0]) * ratio, a[1] + (b[1] - a[1]) * ratio)
				del self.hist[i + 1:]
				del self.ages[i + 1:]
				self.hist[i] = cut
				return
			total += seg

	def drawn_length(self):
		return sum(math.dist(self.hist[i - 1], self.hist[i])
		           for i in range(1, len(self.hist)))

	def tail_distance_from_head(self):
		if len(self.hist) < 2:
			return 0.0
		return math.dist(self.hist[0], self.hist[-1])


def run(use_lifetime):
	"""빠르게 달리다가 튕긴 뒤 급감속해 거의 멈추는 시나리오."""
	t = Trail(use_lifetime)
	x, speed = 0.0, 1100.0
	log = []
	for frame in range(180):
		# 60프레임째부터 급감속 (튕긴 뒤 속도가 죽는 구간)
		if frame >= 60:
			speed = max(speed * 0.90, 70.0)
		x += speed * DT
		t.step((x, 0.0), speed)
		if frame in (59, 70, 85, 100, 140, 179):
			log.append((frame, speed, t.drawn_length(), t.tail_distance_from_head(),
			            len(t.hist)))
	return log


print("=" * 78)
print("꼬리 잔상 재현 — 급감속 시 꼬리 끝이 제자리에 남는가")
print("=" * 78)
for label, use in (("수명 없음 (수정 전)", False), ("수명 0.22s (수정 후)", True)):
	print("\n[%s]" % label)
	print("  프레임   속도    그려진길이   머리~끝거리   점수")
	for f, sp, dl, td, n in run(use):
		print("  %5d  %6.0f   %8.1f    %8.1f    %3d" % (f, sp, dl, td, n))

print("\n" + "=" * 78)
before = run(False)[-1]
after = run(True)[-1]
print("최종 프레임(179) 머리~끝 거리:  수정 전 %.1fpx  ->  수정 후 %.1fpx" % (before[3], after[3]))
ok = after[3] < before[3] * 0.5
print("PASS: 급감속 후 꼬리가 공 쪽으로 걷힌다" if ok else "FAIL: 잔상이 그대로다")
print()
if not ok:
	raise SystemExit(1)
