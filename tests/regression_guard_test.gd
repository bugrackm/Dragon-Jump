extends SceneTree

## Pins gameplay and scene invariants independently of the visual implementation.
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")

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
	_expect(PLAYER_SCRIPT.GRAVITY == 2400.0, "gravity")
	_expect(PLAYER_SCRIPT.JUMP_VELOCITY == -1150.0, "jump velocity")
	_expect(PLAYER_SCRIPT.MOVE_SPEED == 520.0, "move speed")
	_expect(PLAYER_SCRIPT.DOUBLE_JUMP_COOLDOWN == 1.0, "double jump cooldown")
	var player := load("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	var capsule := player.get_node("CollisionShape2D").shape as CapsuleShape2D
	_expect(capsule != null, "capsule shape")
	_expect(capsule.radius == 34.0, "capsule radius")
	_expect(capsule.height == 88.0, "capsule height")
	_expect(player.collision_layer == 1, "collision layer")
	_expect(player.collision_mask == 2, "collision mask")
	_expect(player.floor_snap_length == 8.0, "floor snap length")
	_expect(player.get_node("MouthFlame").position == Vector2(0.0, -46.0), "mouth flame position")
	_expect(player.get_node("GlideTrail").position == Vector2(0.0, 36.0), "glide trail position")
	var sprite := player.get_node_or_null("VisualRoot/Sprite") as AnimatedSprite2D
	_expect(sprite != null, "sprite path and type")
	_expect(sprite.sprite_frames == load("res://assets/sprites/player/dragon_frames.tres"), "dragon frames")
	player.free()
	print("regression_guard_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)
