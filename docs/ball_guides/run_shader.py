"""
실제 .gdshader 파일을 llvmpipe 로 컴파일·실행한다.

Godot 컨테이너 설치가 막혀(github.com 403) 엔진 런타임 테스트를 못 돌리므로,
최소한 셰이더 본문만큼은 사본이 아니라 **리포의 진짜 파일**을 돌려서 검증한다.
유니폼 값도 하드코딩하지 않고 BallGlowOutlineRules.tres 에서 읽는다.
"""
import re
import numpy as np
import moderngl

REPO = "/sessions/dreamy-gracious-cori/mnt/godot-pinball-pjt"
SHADER = f"{REPO}/Resources/shaders/ball_mist_aura.gdshader"
TRES = f"{REPO}/settings/balls/BallGlowOutlineRules.tres"

QUAD_PADDING = 1.16      # BallGlowOutline.QUAD_PADDING
MIN_CORE_WIDTH_PX = 0.85  # BallGlowOutline.MIN_CORE_WIDTH_PX


def read_rules() -> dict:
	"""tres 를 파싱해 규칙 값을 읽는다. 값이 바뀌면 검증도 따라 움직인다."""
	out = {}
	for line in open(TRES, encoding="utf-8"):
		m = re.match(r"^(\w+)\s*=\s*(.+)$", line.strip())
		if not m:
			continue
		key, raw = m.group(1), m.group(2).strip()
		if raw.startswith("Color("):
			out[key] = tuple(float(x) for x in raw[6:-1].split(","))
		elif raw.startswith(("ExtResource", "SubResource")):
			continue
		else:
			try:
				out[key] = float(raw)
			except ValueError:
				pass
	return out


def to_glsl330(src: str) -> str:
	"""Godot canvas_item 셰이더 -> GLSL 330. 기계적 치환만 한다."""
	s = src
	s = re.sub(r"^\s*shader_type[^;]*;", "", s, flags=re.M)
	s = re.sub(r"^\s*render_mode[^;]*;", "", s, flags=re.M)
	s = re.sub(r"\s*:\s*source_color", "", s)
	s = re.sub(r"\s*:\s*hint_\w+(\([^)]*\))?", "", s)
	# uniform 기본값은 파이썬에서 넣는다
	s = re.sub(r"^(uniform[^;=]*?)\s*=\s*[^;]+;", r"\1;", s, flags=re.M)
	s = s.replace("void fragment()", "void main()")
	s = re.sub(r"\bCOLOR\b", "out_color", s)
	s = re.sub(r"\bUV\b", "uv", s)
	return "#version 330\nin vec2 uv;\nout vec4 out_color;\n" + s


def render(size: int, rules: dict, ball_d: float, state: str = "normal",
           flash: float = 0.0, gaze: float | None = None, drift: float = 0.0) -> np.ndarray:
	ball_r = ball_d * 0.5
	outer_r = ball_r * rules["radius_ratio"]
	half_quad = outer_r * QUAD_PADDING
	core_w = max(ball_r * rules["core_width_ratio"], MIN_CORE_WIDTH_PX)

	def lerp(a, b, t):
		return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))

	core = rules[f"{state}_core_color"]
	mist = rules[f"{state}_mist_color"]
	if flash > 0.0:
		core = lerp(core, rules["flash_core_color"], flash)
		mist = lerp(mist, rules["flash_mist_color"], flash)
	dk = rules["outer_darken"]
	outer_c = (mist[0] * dk, mist[1] * dk, mist[2] * dk, mist[3])
	gain = 1.0 + (rules["flash_alpha_scale"] - 1.0) * flash

	ctx = moderngl.create_context(standalone=True)
	prog = ctx.program(
		vertex_shader="#version 330\nin vec2 p; out vec2 uv;"
		              "void main(){uv=p*0.5+0.5; gl_Position=vec4(p,0,1);}",
		fragment_shader=to_glsl330(open(SHADER, encoding="utf-8").read()),
	)
	u = {
		"ball_ratio": ball_r / half_quad,
		"outer_ratio": outer_r / half_quad,
		"peak": rules["peak_alpha"],
		"bands": rules["band_count"],
		"falloff_exp": rules["falloff_exp"],
		"plume": rules["plume_amount"],
		"plume_lobes": rules["plume_lobes"],
		"wisp": rules["wisp_amount"],
		"wisp_lobes": rules["wisp_lobes"],
		"wisp_radial": rules["wisp_radial"],
		"inner_bloom": rules["inner_bloom"],
		"gaze_stretch": rules["gaze_stretch"],
		"gaze_angle": 0.0 if gaze is None else gaze,
		"gaze_enabled": 0.0 if gaze is None else 1.0,
		"core_alpha": rules["core_alpha"],
		"core_w_norm": core_w / half_quad,
		"core_gain": gain,
		"alpha_gain": gain,
		"wobble": rules["wobble_amount"],
		"drift_phase": drift,
		"seed": 7.0,
		"col_core": core,
		"col_mist": mist,
		"col_outer": outer_c,
	}
	for k, v in u.items():
		if k in prog:
			prog[k].value = v

	vbo = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
	vao = ctx.simple_vertex_array(prog, vbo, "p")
	fbo = ctx.simple_framebuffer((size, size), components=4)
	fbo.use()
	fbo.clear(0.0, 0.0, 0.0, 0.0)
	vao.render()
	a = np.frombuffer(fbo.read(components=4), dtype=np.uint8)
	a = a.reshape(size, size, 4).astype(np.float32) / 255.0
	ctx.release()
	return np.flipud(a)      # GL 은 아래가 원점
