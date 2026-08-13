class_name AudioManager
extends Node

## Owns persistent sound-effect playback across menus and per-run worlds.

const AUDIO_MANAGER_GROUP := &"audio_manager"
const GLIDE_SFX := &"sfx_glide"
const SFX_STREAM_PATHS := {
	&"sfx_jump": "res://assets/audio/sfx/sfx_jump.ogg",
	&"sfx_double_jump": "res://assets/audio/sfx/sfx_double_jump.ogg",
	&"sfx_fire": "res://assets/audio/sfx/sfx_fire.ogg",
	&"sfx_coin": "res://assets/audio/sfx/sfx_coin.ogg",
	&"sfx_death": "res://assets/audio/sfx/sfx_death.ogg",
	&"sfx_enemy_destroyed": "res://assets/audio/sfx/sfx_enemy_destroyed.ogg",
	&"sfx_glide": "res://assets/audio/sfx/sfx_glide.ogg",
	&"sfx_spring": "res://assets/audio/sfx/sfx_spring.ogg",
	&"sfx_break": "res://assets/audio/sfx/sfx_break.ogg",
	&"sfx_disappear": "res://assets/audio/sfx/sfx_disappear.ogg",
	&"sfx_ui_click": "res://assets/audio/sfx/sfx_ui_click.ogg",
	&"sfx_ui_back": "res://assets/audio/sfx/sfx_ui_back.ogg",
	&"sfx_purchase": "res://assets/audio/sfx/sfx_purchase.ogg",
}

var _profile_store: Node
var _sound_enabled := true
var _sfx_players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(AUDIO_MANAGER_GROUP)
	_load_sfx_players()


func initialize(profile_store: Node) -> void:
	_profile_store = profile_store
	if is_instance_valid(_profile_store):
		set_sound_enabled(bool(_profile_store.call("get_sound_enabled")))


func play_sfx(sound_name: StringName) -> void:
	var player := _sfx_players.get(sound_name) as AudioStreamPlayer
	if player == null:
		push_warning("AudioManager could not find SFX '%s'." % sound_name)
		return
	if not _is_sound_enabled():
		return
	player.play()


func stop_sfx(sound_name: StringName) -> void:
	var player := _sfx_players.get(sound_name) as AudioStreamPlayer
	if player == null:
		push_warning("AudioManager could not find SFX '%s'." % sound_name)
		return
	player.stop()


func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled
	if not _sound_enabled:
		stop_all_sfx()


func stop_all_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_players.values():
		player.stop()


func _load_sfx_players() -> void:
	for sound_name in SFX_STREAM_PATHS:
		var stream_path: String = SFX_STREAM_PATHS[sound_name]
		var stream := load(stream_path) as AudioStream
		if stream == null:
			push_warning("AudioManager could not load SFX at '%s'." % stream_path)
			continue
		if sound_name == GLIDE_SFX and stream is AudioStreamOggVorbis:
			stream.loop = true

		var player := AudioStreamPlayer.new()
		player.name = String(sound_name)
		player.stream = stream
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players[sound_name] = player


func _is_sound_enabled() -> bool:
	if is_instance_valid(_profile_store):
		return _sound_enabled and bool(_profile_store.call("get_sound_enabled"))
	return _sound_enabled
