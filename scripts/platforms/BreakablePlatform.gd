extends StaticBody2D

## Allows one normal bounce, then breaks shortly after a top-side landing.

const BREAK_DELAY := 0.4
const BREAK_ANIMATION_DURATION := 0.1

var _triggered := false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual
@onready var _break_timer: Timer = $BreakTimer


func _ready() -> void:
	_break_timer.wait_time = BREAK_DELAY
	_break_timer.timeout.connect(_break)


func on_player_landed(_player: CharacterBody2D) -> void:
	if _triggered:
		return
	_triggered = true
	_break_timer.start()


func _break() -> void:
	_collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2.ZERO, BREAK_ANIMATION_DURATION)
	await tween.finished
	queue_free()
