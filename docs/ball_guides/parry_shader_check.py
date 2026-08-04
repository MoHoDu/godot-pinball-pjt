"""ball_parry_wave.gd 안에 박힌 셰이더를 llvmpipe 로 컴파일·실행해 검수한다.

컨테이너에 Godot 을 못 받으므로(=> godot-install-blocked) 셰이더만 GLSL 330 으로
기계 치환해 돌린다. 사본이 아니라 **리포의 진짜 .gd 파일**에서 읽는다.

파동은 파일 하나로 합쳐졌으므로 셰이더 코드도 기본값도 전부 이 .gd 한 곳에서 읽는다.
따로 .gdshader / .tres 를 보지 않으므로 원본과 어긋날 일이 없다.

★ .gd 의 _apply_uniforms() 를 고치면 이 파일의 uniforms_at() 도 같이 고쳐야 한다.
"""

from __future__ import annotations

import math
import re
from pathlib import Path

import moderngl
import numpy as np
from PIL import Image

# 이 파일은 docs/ball_guides/ 에 있다. 리포 루트는 두 단계 위.
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SOURCE = REPO / "scripts" / "ball_base_system" / "vfx" / "ball_parry_wave.gd"

BALL_RADIUS = 22.0  # 기획서 기준 실제 게임 크기 (지름 44px)

_CTX = None  # ★ 전역 재사용. 렌더마다 create/release 하면 Xvfb 에서 조용히 죽는다


def ctx() -> moderngl.Context:
    global _CTX
    if _CTX is None:
        _CTX = moderngl.create_standalone_context(backend="egl", require=330)
    return _CTX


def read_source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def extract_shader(src: str) -> str:
    """const SHADER_CODE := \"\"\" ... \"\"\" 안쪽만 꺼낸다."""
    m = re.search(r'const SHADER_CODE\s*:=\s*"""(.*?)"""', src, re.S)
    if m is None:
        raise RuntimeError("SHADER_CODE 를 찾지 못했다. .gd 구조가 바뀌었는지 확인할 것")
    return m.group(1)


def extract_values(src: str) -> dict:
    """const 숫자값과 @export 색/불리언 기본값을 전부 이름 그대로 읽는다.

    이름 매핑 표를 두지 않는다. 표를 두면 .gd 가 바뀔 때 조용히 어긋난다.
    """
    out: dict = {}

    for m in re.finditer(r"^const\s+(\w+)\s*(?::\s*\w+\s*)?:?=\s*(-?[\d.]+)\s*(?:#.*)?$",
                         src, re.M):
        out[m.group(1)] = float(m.group(2))

    for m in re.finditer(r"^@export var (\w+)\s*:=\s*Color\(([^)]+)\)", src, re.M):
        out[m.group(1)] = tuple(float(x) for x in m.group(2).split(","))

    for m in re.finditer(r"^@export var (\w+)\s*:\s*bool\s*=\s*(true|false)", src, re.M):
        out[m.group(1)] = m.group(2) == "true"

    return out


def to_glsl(godot_src: str) -> str:
    """Godot 셰이더를 GLSL 330 으로 기계 치환한다. 로직은 건드리지 않는다."""
    s = re.sub(r"^\s*shader_type.*$", "", godot_src, flags=re.M)
    s = re.sub(r"^\s*render_mode.*$", "", s, flags=re.M)
    s = s.replace(" : source_color", "")
    s = s.replace("void fragment()", "void main()")
    s = s.replace("COLOR", "FRAG_OUT")
    return "#version 330\nin vec2 UV;\nout vec4 FRAG_OUT;\n" + s


# ── ball_parry_wave.gd 의 곡선 계산 1:1 이식 ─────────────────

def expand_curve(v: dict, t: float) -> float:
    return 1.0 - (1.0 - min(max(t, 0.0), 1.0)) ** v["DEFAULT_EXPAND_EXP"]


def main_radius_ratio(v: dict, t: float) -> float:
    a, b = v["DEFAULT_START_RADIUS_RATIO"], v["DEFAULT_END_RADIUS_RATIO"]
    return a + (b - a) * expand_curve(v, t)


def sub_radius_ratio(v: dict, t: float) -> float:
    span = max(1.0 - v["DEFAULT_SUB_DELAY"], 0.001)
    ts = min(max((t - v["DEFAULT_SUB_DELAY"]) / span, 0.0), 1.0)
    a, b = v["DEFAULT_START_RADIUS_RATIO"], v["DEFAULT_END_RADIUS_RATIO"]
    return a + (b - a) * expand_curve(v, ts)


def ring_width_ratio(v: dict, t: float) -> float:
    return v["DEFAULT_RING_WIDTH_RATIO"] * (
        1.0 - v["DEFAULT_RING_WIDTH_SHRINK"] * expand_curve(v, t)
    )


def fade(v: dict, t: float) -> float:
    span = max(1.0 - v["DEFAULT_FADE_START"], 0.001)
    x = min(max((t - v["DEFAULT_FADE_START"]) / span, 0.0), 1.0)
    return min(max(1.0 - x ** v["DEFAULT_FADE_EXP"], 0.0), 1.0)


def flash_amount(v: dict, elapsed: float) -> float:
    ft = v["DEFAULT_FLASH_TIME"]
    if ft <= 0.0 or elapsed >= ft:
        return 0.0
    return min(max((1.0 - elapsed / ft) ** 0.8, 0.0), 1.0)


def quad_radius_ratio(v: dict) -> float:
    return v["DEFAULT_END_RADIUS_RATIO"] * v["SPOKE_OUTER_MUL"] * v["QUAD_PADDING"]


def visible_frames(v: dict, threshold: float = 0.8, fps: float = 60.0) -> float:
    span = max(1.0 - v["DEFAULT_FADE_START"], 0.001)
    x = (1.0 - threshold) ** (1.0 / v["DEFAULT_FADE_EXP"])
    return min(v["DEFAULT_FADE_START"] + span * x, 1.0) * v["DEFAULT_DURATION"] * fps


def uniforms_at(v: dict, t: float, ball_radius: float = BALL_RADIUS) -> dict:
    quad = max(ball_radius * quad_radius_ratio(v), 0.001)
    to_quad = ball_radius / quad
    elapsed = t * v["DEFAULT_DURATION"]

    main_r = main_radius_ratio(v, t) * to_quad
    main_w = ring_width_ratio(v, t) * to_quad
    spoke_out = main_r * v["SPOKE_OUTER_MUL"]

    return dict(
        quad_radius_px=quad,
        ball_r=to_quad,
        main_r=main_r,
        main_w=main_w,
        sub_r=sub_radius_ratio(v, t) * to_quad,
        sub_w=main_w * v["DEFAULT_SUB_WIDTH_SCALE"],
        sub_on=1.0 if t >= v["SUB_APPEAR"] else 0.0,
        spoke_count=v["DEFAULT_SPOKE_COUNT"],
        spoke_in=main_r * v["SPOKE_INNER_MUL"],
        spoke_out=spoke_out,
        spoke_w=math.radians(v["DEFAULT_SPOKE_WIDTH_DEG"]) * 0.5 * spoke_out,
        spoke_on=1.0 if (t >= v["SPOKE_APPEAR"] and v["DEFAULT_SPOKE_COUNT"] > 0) else 0.0,
        spark_count=v["DEFAULT_SPARK_COUNT"],
        spark_r=main_r,
        spark_len=v["DEFAULT_SPARK_LENGTH_RATIO"] * to_quad,
        spark_w=v["SPARK_WIDTH_RATIO"] * to_quad,
        spark_on=1.0 if (
            v["DEFAULT_SPARK_COUNT"] > 0
            and t >= v["SPARK_APPEAR"]
            and t <= v["SPARK_VANISH"]
        ) else 0.0,
        flash_r=v["DEFAULT_START_RADIUS_RATIO"] * 0.92 * to_quad,
        flash_a=flash_amount(v, elapsed),
        flash_hollow=1.0 if v.get("flash_hollow") else 0.0,
        bands=v["DEFAULT_BAND_COUNT"],
        wobble=v["DEFAULT_WOBBLE"],
        wobble_lobes=v["WOBBLE_LOBES"],
        gaps=v["DEFAULT_GAP_COUNT"],
        gap_width=v["DEFAULT_GAP_WIDTH"],
        fade=fade(v, t),
        col_ring=v["ring_color"],
        col_sub=v["sub_color"],
        col_flash=v["flash_color"],
        col_spark=v["spark_color"],
    )


def render(uniforms: dict, size: int, shader_src: str) -> Image.Image:
    c = ctx()
    prog = c.program(
        vertex_shader="""
            #version 330
            in vec2 in_pos;
            out vec2 UV;
            void main() {
                UV = in_pos * 0.5 + 0.5;
                gl_Position = vec4(in_pos, 0.0, 1.0);
            }
        """,
        fragment_shader=to_glsl(shader_src),
    )

    missing = []
    for name, value in uniforms.items():
        if name not in prog:
            missing.append(name)
            continue
        prog[name].value = tuple(value) if isinstance(value, tuple) else float(value)

    declared = {n for n in prog if hasattr(prog[n], "value")}
    render.missing = missing
    render.unset = declared - set(uniforms) - {"in_pos"}

    quad = np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype="f4")
    vbo = c.buffer(quad.tobytes())
    vao = c.simple_vertex_array(prog, vbo, "in_pos")
    fbo = c.simple_framebuffer((size, size), components=4)
    fbo.use()
    fbo.clear(0.0, 0.0, 0.0, 0.0)
    vao.render(moderngl.TRIANGLE_STRIP)

    data = fbo.read(components=4, dtype="f1")
    img = Image.frombytes("RGBA", (size, size), data).transpose(Image.FLIP_TOP_BOTTOM)

    fbo.release()
    vao.release()
    vbo.release()
    prog.release()
    return img


if __name__ == "__main__":
    source = read_source()
    shader = extract_shader(source)
    values = extract_values(source)

    print("셰이더 줄 수:", len(shader.splitlines()))
    print("읽어온 상수:", len(values), "개")

    u = uniforms_at(values, 0.45)
    size = int(round(u["quad_radius_px"] * 2))
    img = render(u, size, shader)

    print("렌더 성공", img.size)
    print("셰이더에 없는 유니폼:", render.missing)
    print("값이 안 들어간 유니폼:", sorted(render.unset))
    print("잘 보이는 구간: %.1f프레임 (60fps)" % visible_frames(values))
