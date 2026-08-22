extends Node

## Selects dragon sprite animations without affecting Player physics.

@onready var _player := get_parent() as CharacterBody2D
@onready var _sprite := get_node("../VisualRoot/Sprite") as AnimatedSprite2D

var _one_shot_override: StringName = &""
var _current_locomotion: StringName = &""
var _fire_just_triggered := false
var _double_jump_just_triggered := false
var _last_is_gliding := false


func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)


func trigger_fire() -> void:
	_fire_just_triggered = true


func trigger_double_jump() -> void:
	_double_jump_just_triggered = true


func update_animation(is_gliding: bool) -> void:
	_last_is_gliding = is_gliding
	if _player.velocity.x < 0.0:
		_sprite.flip_h = true
	elif _player.velocity.x > 0.0:
		_sprite.flip_h = false

	# Fire has the highest priority and may replace an active double-jump shot.
	if _fire_just_triggered:
		_fire_just_triggered = false
		_double_jump_just_triggered = false
		_play_one_shot(&"fire")
		return

	# Locomotion and lower-priority one-shots cannot interrupt an active override.
	if _one_shot_override != &"":
		_double_jump_just_triggered = false
		return

	if _double_jump_just_triggered:
		_double_jump_just_triggered = false
		_play_one_shot(&"double_jump")
		return

	_select_locomotion()


func stop() -> void:
	_sprite.stop()
	_one_shot_override = &""
	_current_locomotion = &""
	_fire_just_triggered = false
	_double_jump_just_triggered = false
	_last_is_gliding = false


func _play_one_shot(animation_name: StringName) -> void:
	_one_shot_override = animation_name
	_sprite.play(animation_name)


func _select_locomotion() -> void:
	var target_locomotion: StringName
	if _last_is_gliding:
		target_locomotion = &"glide"
	elif not _player.is_on_floor() and _player.velocity.y < 0.0:
		target_locomotion = &"jump"
	elif not _player.is_on_floor() and _player.velocity.y >= 0.0:
		target_locomotion = &"fall"
	else:
		target_locomotion = &"idle"

	if target_locomotion == _current_locomotion:
		return
	_current_locomotion = target_locomotion
	_sprite.play(target_locomotion)


func _on_animation_finished() -> void:
	if _sprite.animation != _one_shot_override:
		return
	_one_shot_override = &""
	_select_locomotion()
