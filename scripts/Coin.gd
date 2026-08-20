extends Area2D

## Collectible wallet coin shared by platform spawns and enemy drops.

signal coin_collected

const COIN_SPARKLE_SCENE := preload("res://scenes/effects/CoinSparkle.tscn")

var _player: CharacterBody2D
var _active := true
var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func initialize(player: CharacterBody2D) -> void:
	_player = player


func set_active(is_active: bool) -> void:
	_active = is_active
	set_deferred("monitoring", _active and not _collected)


func _on_body_entered(body: Node2D) -> void:
	if not _active or _collected or body != _player:
		return

	_collected = true
	_active = false
	set_deferred("monitoring", false)
	_spawn_sparkle()
	coin_collected.emit()
	queue_free()


func _spawn_sparkle() -> void:
	var effect_parent := get_parent()
	if effect_parent == null:
		return
	var sparkle := COIN_SPARKLE_SCENE.instantiate() as CPUParticles2D
	effect_parent.add_child(sparkle)
	sparkle.global_position = global_position
	sparkle.finished.connect(sparkle.queue_free)
	sparkle.emitting = true
