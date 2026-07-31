# ball_impact_context.gd
class_name BallImpactContext
extends RefCounted

var ball: RigidBody2D
var velocity: Vector2
var collider_velocity: Vector2
var normal: Vector2
var point: Vector2

func _init(
    p_ball: RigidBody2D,
    p_velocity: Vector2,
    p_collider_velocity: Vector2,
    p_normal: Vector2,
    p_point: Vector2
) -> void:
    ball = p_ball
    velocity = p_velocity
    collider_velocity = p_collider_velocity
    normal = p_normal
    point = p_point