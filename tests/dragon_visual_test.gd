extends SceneTree

## Exercises host forwarding and controller rebinding with a non-sprite visual.
const SPRITE_VISUAL := preload("res://scenes/dragon_visuals/SpriteDragonVisual.tscn")


class SkinRequest extends Resource:
	var visual_scene: PackedScene


class RecordingVisual extends Node2D:
	signal one_shot_finished(name: StringName)
	var locomotion: StringName = &""
	var one_shot: StringName = &""
	var facing := 0
	var motion := Vector2.ZERO
	var on_floor := false
	var frozen := false
	var skin: Resource
	var skin_calls := 0


	func set_locomotion(state: StringName) -> void:
		locomotion = state


	func play_one_shot(animation_name: StringName) -> void:
		one_shot = animation_name


	func set_facing(dir: int) -> void:
		facing = dir


	func set_motion(velocity: Vector2, grounded: bool) -> void:
		motion = velocity
		on_floor = grounded


	func freeze() -> void:
		frozen = true


	func apply_skin(value: Resource) -> void:
		skin = value
		skin_calls += 1


var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	var player := load("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	var host := player.get_node("VisualRoot")
	var controller := player.get_node("AnimationController")
	var sprite := host.get_visual() as AnimatedSprite2D
	_expect(sprite == player.get_node("VisualRoot/Sprite"), "host returns original sprite")
	_expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "original filtering")
	_expect(sprite.centered and sprite.offset == Vector2.ZERO and sprite.scale == Vector2.ONE,
		"original centered offset and scale")
	sprite.set_facing(-1)
	sprite.set_facing(0)
	_expect(sprite.flip_h, "zero keeps left facing")
	sprite.set_facing(1)
	sprite.set_facing(0)
	_expect(not sprite.flip_h, "zero keeps right facing")
	sprite.set_locomotion(&"jump")
	sprite.pause()
	sprite.set_locomotion(&"jump")
	_expect(sprite.is_playing(), "visual does not dedupe locomotion")
	var snapshot := [sprite.animation, sprite.frame, sprite.flip_h, sprite.is_playing()]
	player.apply_skin(null)
	player.apply_skin(Resource.new())
	sprite.set_motion(Vector2(3.0, 4.0), true)
	_expect(snapshot == [sprite.animation, sprite.frame, sprite.flip_h, sprite.is_playing()],
		"sprite skin and motion are no-ops")
	var changes: Array[Node] = []
	host.visual_changed.connect(func(visual: Node) -> void: changes.append(visual))
	var same_scene := SkinRequest.new()
	same_scene.visual_scene = SPRITE_VISUAL
	player.apply_skin(same_scene)
	_expect(host.get_visual() == sprite and changes.is_empty(), "same scene does not replace sprite")
	var fixture := RecordingVisual.new()
	var packed := PackedScene.new()
	_expect(packed.pack(fixture) == OK, "pack non-sprite fixture")
	fixture.free()
	var request := SkinRequest.new()
	request.visual_scene = packed
	player.apply_skin(request)
	var visual := host.get_visual() as RecordingVisual
	_expect(visual != null and visual.name == &"Visual", "host installs named non-sprite visual")
	_expect(changes == [visual], "host emits replacement")
	_expect(sprite.is_queued_for_deletion() and sprite.get_parent() == null, "old visual removed and queued free")
	_expect(sprite.one_shot_finished.get_connections().is_empty(), "old completion disconnected")
	_expect(visual.one_shot_finished.get_connections().size() == 1, "new completion connected once")
	_expect(visual.skin == request and visual.skin_calls == 1, "skin forwarded after swap")
	player.apply_skin(request)
	player.apply_skin(null)
	var no_scene := Resource.new()
	player.apply_skin(no_scene)
	_expect(host.get_visual() == visual and changes.size() == 1, "same in-memory scene and absent scene retain visual")
	_expect(visual.skin == no_scene and visual.skin_calls == 4, "same scene null and no scene all forward")
	player.velocity = Vector2(-10.0, -20.0)
	controller.update_animation(false)
	_expect(visual.locomotion == &"jump" and visual.facing == -1, "adapter drives non-sprite locomotion and facing")
	_expect(visual.motion == player.velocity and not visual.on_floor, "adapter forwards motion")
	controller.trigger_fire()
	controller.update_animation(false)
	_expect(visual.one_shot == &"fire", "adapter drives non-sprite one-shot")
	player.velocity = Vector2(10.0, 20.0)
	controller.update_animation(false)
	visual.one_shot_finished.emit(&"double_jump")
	_expect(visual.locomotion == &"jump", "mismatched completion ignored")
	visual.one_shot_finished.emit(&"fire")
	_expect(visual.locomotion == &"fall" and visual.facing == 1, "matching completion resumes changed target")
	controller.stop()
	_expect(visual.frozen, "adapter freezes non-sprite visual")
	player.free()
	await process_frame
	_expect(not is_instance_valid(sprite), "old visual freed")
	print("dragon_visual_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)
