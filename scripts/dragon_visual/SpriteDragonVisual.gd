extends AnimatedSprite2D

## Duck-typed DragonVisual contract:
## signal one_shot_finished(name: StringName)
## set_locomotion(state: StringName) -> void: play idle/jump/fall/glide; controller dedupes.
## play_one_shot(name: StringName) -> void: play fire/double_jump.
## set_facing(dir: int) -> void: -1 left, 1 right, 0 keeps current facing.
## set_motion(velocity: Vector2, on_floor: bool) -> void: no-op here; reserved for rigs.
## freeze() -> void: stop playback using the original sprite stop semantics.
## apply_skin(skin: Resource) -> void: apply body tint, or clear the material for Classic.

signal one_shot_finished(name: StringName)

const SkinMaterial := preload("res://scripts/cosmetics/SkinMaterial.gd")


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)


func set_locomotion(state: StringName) -> void:
	play(state)


func play_one_shot(name: StringName) -> void:
	play(name)


func set_facing(dir: int) -> void:
	if dir < 0:
		flip_h = true
	elif dir > 0:
		flip_h = false


func set_motion(_velocity: Vector2, _on_floor: bool) -> void:
	pass


func freeze() -> void:
	stop()


func apply_skin(skin: Resource) -> void:
	SkinMaterial.apply_to(self, skin)


func _on_animation_finished() -> void:
	one_shot_finished.emit(animation)
