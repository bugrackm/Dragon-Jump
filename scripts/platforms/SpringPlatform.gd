extends StaticBody2D

## Replaces the normal landing bounce with a stronger upward launch.

const SPRING_MULTIPLIER := 1.65

## Coil art is bottom-anchored just below the landing surface, so each frame
## needs its own centre offset: the sprite grows upward instead of sinking in.
const SPRING_IDLE := preload("res://assets/sprites/platforms/spring_idle.png")
const SPRING_COMPRESSED := preload("res://assets/sprites/platforms/spring_compressed.png")
const SPRING_EXTENDED := preload("res://assets/sprites/platforms/spring_extended.png")

const OFFSET_IDLE := -29.25
const OFFSET_COMPRESSED := -24.25
const OFFSET_EXTENDED := -37.5

const COMPRESS_TIME := 0.05
const EXTEND_TIME := 0.12

## True while a compress/extend/idle sequence is in flight. Landings that
## arrive mid-sequence are ignored so two sequences can never write to the
## same sprite out of order (previously only prevented incidentally by
## Player.gd's jump physics, not by an invariant of this platform).
var _animating := false

## Tracks which stage the in-flight timer is counting down for, since the
## same Timer is reused for both the compress and extend delays.
var _extending := false

@onready var _spring_sprite := $SpringSprite as Sprite2D
@onready var _sequence_timer: Timer = $SequenceTimer


func _ready() -> void:
	_sequence_timer.timeout.connect(_on_sequence_timer_timeout)


func on_player_landed(player: CharacterBody2D) -> void:
	_play_sfx(&"sfx_spring")
	player.velocity.y = player.JUMP_VELOCITY * SPRING_MULTIPLIER
	if _animating:
		return
	_animating = true
	_extending = false
	_set_frame(SPRING_COMPRESSED, OFFSET_COMPRESSED)
	_sequence_timer.start(COMPRESS_TIME)


## Node-owned Timer, so it (and any pending timeout) is cleaned up
## automatically if PlatformManager frees this platform mid-sequence.
func _on_sequence_timer_timeout() -> void:
	if not _extending:
		_extending = true
		_set_frame(SPRING_EXTENDED, OFFSET_EXTENDED)
		_sequence_timer.start(EXTEND_TIME)
	else:
		_set_frame(SPRING_IDLE, OFFSET_IDLE)
		_animating = false


func _set_frame(texture: Texture2D, offset_y: float) -> void:
	_spring_sprite.texture = texture
	_spring_sprite.position.y = offset_y


func _play_sfx(sound_name: StringName) -> void:
	var audio_manager := get_tree().get_first_node_in_group(&"audio_manager")
	if audio_manager != null:
		audio_manager.call("play_sfx", sound_name)
