extends StaticBody2D

## Remains solid briefly after a top-side landing, then fades away.

const DISAPPEAR_DELAY := 1.2
const FADE_DURATION := 0.15

var _triggered := false
var _pulse_tween: Tween

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual
@onready var _disappear_timer: Timer = $DisappearTimer


func _ready() -> void:
	_disappear_timer.wait_time = DISAPPEAR_DELAY
	_disappear_timer.timeout.connect(_disappear)


func on_player_landed(_player: CharacterBody2D) -> void:
	if _triggered:
		return
	_triggered = true
	_disappear_timer.start()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_visual, "modulate:a", 0.55, 0.25)
	_pulse_tween.tween_property(_visual, "modulate:a", 1.0, 0.25)


func _disappear() -> void:
	_collision_shape.set_deferred("disabled", true)
	if _pulse_tween:
		_pulse_tween.kill()
	var tween := create_tween()
	tween.tween_property(_visual, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	queue_free()
