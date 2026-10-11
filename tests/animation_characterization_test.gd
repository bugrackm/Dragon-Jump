extends SceneTree

## Golden captured from the original controller before the DragonVisual refactor.
const GOLDEN := [
	[&"idle", 0, false, false],
	[&"jump", 0, false, true],
	[&"jump", 1, true, true],
	[&"jump", 1, true, true],
	[&"fall", 0, false, true],
	[&"fall", 0, false, true],
	[&"glide", 0, true, true],
	[&"double_jump", 0, true, true],
	[&"double_jump", 2, true, false],
	[&"double_jump", 2, true, false],
	[&"jump", 0, false, true],
	[&"fire", 0, false, true],
	[&"fire", 0, true, true],
	[&"fire", 0, true, false],
	[&"fire", 0, true, false],
	[&"double_jump", 0, false, true],
	[&"fire", 0, true, true],
	[&"fall", 0, true, true],
	[&"double_jump", 0, true, true],
	[&"jump", 0, true, true],
	[&"fire", 0, true, true],
	[&"fire", 0, true, false],
	[&"idle", 0, true, true],
	[&"idle", 0, true, false],
	[&"idle", 0, true, true],
	[&"fire", 0, true, true],
	[&"fire", 0, true, false],
	[&"idle", 0, true, true],
]

var _checks := 0
var _failures := 0
var _snapshots: Array = []
var _player: CharacterBody2D
var _controller: Node
var _sprite: AnimatedSprite2D


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _record(description: String) -> void:
	var snapshot := [_sprite.animation, _sprite.frame, _sprite.flip_h, _sprite.is_playing()]
	var index := _snapshots.size()
	_snapshots.append(snapshot)
	print("snapshot[%d] %s: %s" % [index, description, JSON.stringify(snapshot)])
	_expect(index < GOLDEN.size() and snapshot == GOLDEN[index], description)


func _update(velocity: Vector2, gliding: bool, description: String) -> void:
	_player.velocity = velocity
	_controller.update_animation(gliding)
	_record(description)


func _finish_one_shot(description: String) -> void:
	# Reproduce the engine's terminal state without elapsed-time animation updates.
	_sprite.set_frame_and_progress(_sprite.sprite_frames.get_frame_count(_sprite.animation) - 1, 1.0)
	_sprite.pause()
	_sprite.animation_finished.emit()
	_record(description)


func _run() -> void:
	_player = load("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	_player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_player)
	_controller = _player.get_node("AnimationController")
	_sprite = _player.get_node("VisualRoot/Sprite") as AnimatedSprite2D
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.collision_mask = 1
	floor_body.position = Vector2(0.0, 50.0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 10.0)
	collider.shape = shape
	floor_body.add_child(collider)
	root.add_child(floor_body)
	await physics_frame
	await process_frame
	_expect(not _player.is_on_floor(), "fixture starts airborne")
	_record("initial idle stopped")
	_update(Vector2(10.0, -10.0), false, "jump facing right")
	_sprite.set_frame_and_progress(1, 0.5)
	_update(Vector2(-10.0, -10.0), false, "jump facing left preserves frame")
	_update(Vector2(0.0, -10.0), false, "zero horizontal keeps left")
	_update(Vector2(10.0, 0.0), false, "zero vertical falls facing right")
	_update(Vector2(0.0, 10.0), false, "positive vertical falls keeps right")
	_update(Vector2(-10.0, 10.0), true, "glide takes priority")
	_controller.trigger_double_jump()
	_update(Vector2(0.0, 10.0), true, "double jump overrides glide")
	_finish_one_shot("same glide target freezes double jump last frame")
	_update(Vector2(0.0, 10.0), true, "same target stays frozen")
	_update(Vector2(10.0, -10.0), false, "changed target resumes jump")
	_controller.trigger_fire()
	_update(Vector2(0.0, -10.0), false, "fire overrides jump")
	_controller.trigger_double_jump()
	_update(Vector2(-10.0, -10.0), false, "double jump ignored during fire but facing updates")
	_finish_one_shot("same jump target freezes fire last frame")
	_update(Vector2(0.0, -10.0), false, "ignored double jump is not queued")
	_controller.trigger_double_jump()
	_update(Vector2(10.0, -10.0), false, "double jump starts after fire finishes")
	_controller.trigger_fire()
	_update(Vector2(-10.0, 10.0), false, "fire interrupts double jump")
	_finish_one_shot("changed target resumes fall after fire")
	_controller.trigger_double_jump()
	_update(Vector2(0.0, -10.0), false, "double jump while target changes to jump")
	_finish_one_shot("changed target resumes jump after double jump")
	_controller.trigger_double_jump()
	_controller.trigger_fire()
	_update(Vector2(0.0, -10.0), false, "simultaneous requests choose fire")
	_finish_one_shot("simultaneous fire freezes unchanged jump target")
	_player.velocity = Vector2.ZERO
	_player.apply_floor_snap()
	_expect(_player.is_on_floor(), "real capsule snaps to fixture floor")
	_update(Vector2.ZERO, false, "idle on floor")
	_controller.trigger_double_jump()
	_controller.trigger_fire()
	_sprite.set_frame_and_progress(1, 0.5)
	_controller.stop()
	_record("stop resets frame and playback")
	_update(Vector2.ZERO, false, "stop clears queued shots and locomotion dedupe")
	_controller.trigger_fire()
	_update(Vector2.ZERO, false, "fire before stop")
	_controller.stop()
	_record("stop cancels active override")
	_update(Vector2.ZERO, false, "idle resumes after stopped override")
	_expect(_snapshots.size() == GOLDEN.size(), "all golden steps recorded")
	_player.free()
	floor_body.free()
	print("animation_characterization_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)
