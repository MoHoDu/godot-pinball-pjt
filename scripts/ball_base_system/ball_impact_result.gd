# ball_impact_result.gd
class_name BallImpactResult
extends RefCounted

enum DirectionMode {
    PHYSICAL_REFLECTION,
    FIXED_WORLD,
    FIXED_LOCAL,
    KEEP_CURRENT,
}

var direction_mode: DirectionMode = DirectionMode.PHYSICAL_REFLECTION
var direction: Vector2 = Vector2.UP

var speed_multiplier: float = 1.0
var speed_addition: float = 0.0
var minimum_speed: float = 0.0
var maximum_speed: float = 3000.0

# 한 프레임에 여러 특수 충돌이 생겼을 때 사용
var priority: int = 0