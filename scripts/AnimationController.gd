extends Node

## Selects dragon visual animations without affecting Player physics.

@onready var _player := get_parent() as CharacterBody2D
@onready var _visual_host := get_node("../VisualRoot")

var _visual: Node

var _one_shot_override: StringName = &""
var _current_locomotion: StringName = &""
var _fire_just_triggered := false
var _double_jump_just_triggered := false
var _last_is_gliding := false


func _ready() -> void:
	_visual_host.visual_changed.connect(_bind_visual)
	_bind_visual(_visual_host.get_visual())


func _bind_visual(visual: Node) -> void:
	if is_instance_valid(_visual):
		_visual.one_shot_finished.disconnect(_on_one_shot_finished)
	_visual = visual
	_visual.one_shot_finished.connect(_on_one_shot_finished)
	_current_locomotion = &""
	_one_shot_override = &""


func trigger_fire() -> void:
	_fire_just_triggered = true


func trigger_double_jump() -> void:
	_double_jump_just_triggered = true


func update_animation(is_gliding: bool) -> void:
	_last_is_gliding = is_gliding
	_visual.set_motion(_player.velocity, _player.is_on_floor())
	if _player.velocity.x < 0.0:
		_visual.set_facing(-1)
	elif _player.velocity.x > 0.0:
		_visual.set_facing(1)

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
	_visual.freeze()
	_one_shot_override = &""
	_current_locomotion = &""
	_fire_just_triggered = false
	_double_jump_just_triggered = false
	_last_is_gliding = false


func _play_one_shot(animation_name: StringName) -> void:
	_one_shot_override = animation_name
	_visual.play_one_shot(animation_name)


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
	_visual.set_locomotion(target_locomotion)


func _on_one_shot_finished(name: StringName) -> void:
	if name != _one_shot_override:
		return
	_one_shot_override = &""
	_select_locomotion()
