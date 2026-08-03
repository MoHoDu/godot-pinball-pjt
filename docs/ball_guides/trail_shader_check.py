"""
실제 ball_trail.gdshader 를 llvmpipe 로 컴파일·실행해 확정 스펙과 대조한다.

Godot 런타임이 막혀 있으므로(github.com 403), 최소한 셰이더 본문만큼은
사본이 아니라 리포의 진짜 파일을 돌린다. 유니폼도 BallTrailRules.tres 에서 읽는다.

Line2D 를 흉내 내는 방법: 이 셰이더는 UV 만 쓴다.
  UV.x = 길이 방향 t (0 = 공)
  UV.y = 폭 방향 (0.5 = 중심선)
따라서 UV 격자를 그대로 그리면 "꼬리를 곧게 편" 그림이 나오고,
Line2D 의 width_curve 를 알고 있으니 px 폭으로 되돌릴 수 있다.
"""
import re
import numpy as np
import moderngl

REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
SHADER = f"{REPO}/Resources/shaders/ball_trail.gdshader"
TRES = f"{REPO}/settings/balls/BallTrailRules.tres"
BALL_D = 44.0
BR = BALL_D / 2.0


def read_rules():
	out = {}
	for line in open(TRES, encoding="utf-8"):
		m = re.match(r"^(\w+)\s*=\s*(.+)$", line.strip())
		if not m:
			continue
		k, raw = m.group(1), m.group(2).strip()
		if raw.startswith("Color("):
			out[k] = tuple(float(x) for x in raw[6:-1].split(","))
		elif raw.startswith(("ExtResource", "SubResource")):
			continue
		else:
			try:
				out[k] = float(raw)
			except ValueError:
				pass
	return out


def to_glsl330(src):
	s = src
	s = re.sub(r"^\s*shader_type[^;]*;", "", s, flags=re.M)
	s = re.sub(r"^\s*render_mode[^;]*;", "", s, flags=re.M)
	s = re.sub(r"\s*:\s*source_color", "", s)
	s = re.sub(r"\s*:\s*hint_\w+(\([^)]*\))?", "", s)
	s = re.sub(r"^(uniform[^;=]*?)\s*=\s*[^;]+;", r"\1;", s, flags=re.M)
	s = s.replace("void fragment()", "void main()")
	s = re.sub(r"\bCOLOR\b", "out_color", s)
	s = re.sub(r"\bUV\b", "uv", s)
	return "#version 330\nin vec2 uv;\nout vec4 out_color;\n" + s


def render(rules, nx=560, ny=280, fade=1.0):
	ctx = moderngl.create_context(standalone=True)
	prog = ctx.program(
		vertex_shader="#version 330\nin vec2 p; out vec2 uv;"
		              "void main(){uv=p*0.5+0.5; gl_Position=vec4(p,0,1);}",
		fragment_shader=to_glsl330(open(SHADER, encoding="utf-8").read()))
	u = {
		"ball_radius_px": BR,
		"bloom_root": rules["bloom_root"], "bloom_tip": rules["bloom_tip"],
		"bloom_power": rules["bloom_power"],
		"core_root": rules["core_root"], "core_tip": rules["core_tip"],
		"core_power": rules["core_power"],
		"steps": rules["band_steps"], "step_gamma": rules["step_gamma"],
		"core_step_drop": rules["core_step_drop"],
		"bloom_alpha": rules["bloom_alpha"], "core_alpha": rules["core_alpha"],
		"fade": fade,
		"laser_hot": rules["laser_hot"], "laser_tip": rules["laser_tip"],
		"bloom_in": rules["bloom_in"], "bloom_mid": rules["bloom_mid"],
		"bloom_out": rules["bloom_out"],
	}
	for k, v in u.items():
		if k in prog:
			prog[k].value = v
	vbo = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
	vao = ctx.simple_vertex_array(prog, vbo, "p")
	fbo = ctx.simple_framebuffer((nx, ny), components=4)
	fbo.use(); fbo.clear(0, 0, 0, 0); vao.render()
	a = np.frombuffer(fbo.read(components=4), dtype=np.uint8)
	a = np.flipud(a.reshape(ny, nx, 4).astype(np.float32) / 255.0)
	ctx.release()
	return a


BOARD = np.array([46 / 255, 58 / 255, 71 / 255], np.float32)


def lum(x):
	return 0.2126 * x[..., 0] + 0.7152 * x[..., 1] + 0.0722 * x[..., 2]


FAILS = []


def check(c, msg):
	print(("  PASS  " if c else "  FAIL  ") + msg)
	if not c:
		FAILS.append(msg)


def main():
	rules = read_rules()
	NX, NY = 560, 280
	a = render(rules)
	print("=" * 74)
	print("ball_trail.gdshader — llvmpipe 실행 검증 (공 44px, 확정 안 D1)")
	print("=" * 74)


	def half_px(t, root, tip, power):
		return (tip + (root - tip) * max(1.0 - t, 0.0) ** power) * BR


	print("\n[1] 뿌리 폭 — 레이저 9px / 블룸 60px")
	# UV.y 는 Line2D 폭 전체에 걸쳐 0..1. 실제 px 은 그 지점의 블룸 전체폭.
	row = a[:, 1, :]                       # t ~ 0 (공 쪽)
	bloom_full = half_px(0.0, rules["bloom_root"], rules["bloom_tip"], rules["bloom_power"]) * 2
	core_full = half_px(0.0, rules["core_root"], rules["core_tip"], rules["core_power"]) * 2
	lit = row[..., 3] > 0.02
	bloom_meas = lit.sum() / NY * bloom_full
	# 레이저는 알파가 높고 색이 흰 구간
	white = (row[..., 3] > 0.5) & (row[..., 0] > 0.85) & (row[..., 2] > 0.75)
	core_meas = white.sum() / NY * bloom_full
	check(abs(core_meas - 8.8) <= 1.6, "레이저 뿌리 폭 %.1fpx (확정 8.8px)" % core_meas)
	check(abs(bloom_meas - 59.4) <= 3.0, "블룸 뿌리 폭 %.1fpx (확정 59.4px)" % bloom_meas)

	print("\n[2] 2겹으로 읽히는가 — 블룸/레이저 >= 2.5배")
	check(bloom_meas >= core_meas * 2.5, "%.1f / %.1f = %.1f배" % (bloom_meas, core_meas, bloom_meas / max(core_meas, 1e-3)))

	print("\n[3] 밝기가 길이 방향 4단 계단인가")
	mid = a[NY // 2, :, 3]                 # 중심선을 따라
	steps = np.unique((mid * 255).round())
	steps = steps[steps > 0]
	check(2 <= len(steps) <= int(rules["band_steps"]) + 1,
	      "중심선 알파 계단 %d 종 (밴드 %d)" % (len(steps), int(rules["band_steps"])))
	check(mid[2] > mid[NX - 3], "공 쪽이 끝보다 밝아야 한다 (%.2f > %.2f)" % (mid[2], mid[NX - 3]))

	print("\n[4] 끝은 투명 블룸만 남는가")
	tail = a[:, NX - 3, :]
	check(float(tail[..., 3].max()) < float(a[:, 1, 3].max()) * 0.45,
	      "끝 최대 알파 %.2f < 뿌리 %.2f 의 45%%" % (tail[..., 3].max(), a[:, 1, 3].max()))

	print("\n[5] 색 — 중심은 흰색, 바깥은 청록 (안개 ①과 통일)")
	cen = a[NY // 2, 3, :3]
	edge_y = int(NY * 0.5 + NY * 0.34)
	edg = a[edge_y, 3, :3]
	check(cen[0] > 0.85 and cen[1] > 0.85, "중심 RGB (%.2f, %.2f, %.2f) = 흰색" % tuple(cen))
	check(edg[1] > edg[0] * 1.3, "바깥 RGB (%.2f, %.2f, %.2f) = 청록" % tuple(edg))

	print("\n[6] 정지 시 fade=0 이면 완전히 사라지는가")
	z = render(rules, fade=0.0)
	check(float(z[..., 3].max()) < 0.005, "fade 0 에서 최대 알파 %.4f" % z[..., 3].max())

	print("\n[7] 레이저가 공(0.990)보다 밝은가 — 의도적 이탈이므로 '밝다'가 정상")
	comp = a[..., :3] * a[..., 3:4] + BOARD * (1 - a[..., 3:4])
	vmax = float(np.percentile(lum(comp)[a[..., 3] > 0.2], 99.9))
	print("        레이저 최대 휘도 %.3f  (형락님 확정: 그대로 둔다)" % vmax)

	print("\n" + "=" * 74)
	if FAILS:
		print("FAIL: trail_shader_check (%d)" % len(FAILS))
		raise SystemExit(1)
	print("PASS: trail_shader_check — 실제 .gdshader 로 확정 스펙 대조 완료")


if __name__ == "__main__":
	main()
