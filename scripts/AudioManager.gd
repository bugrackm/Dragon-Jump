class_name AudioManager
extends Node

## Owns persistent sound-effect and music playback across menus and per-run worlds.

const AUDIO_MANAGER_GROUP := &"audio_manager"
const GLIDE_SFX := &"sfx_glide"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const MUSIC_STREAM_PATH := "res://assets/audio/music/music_happy_adventure.ogg"
const MUSIC_DUCK_LEVEL := 0.3
const MUSIC_DUCK_TIME := 0.3
## Per-SFX volume offsets in dB, independent of the SFX bus slider.
const SFX_VOLUME_DB := {
	&"sfx_coin": -6.0,
}
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
var _music_player: AudioStreamPlayer
var _music_enabled := true
var _music_ducked := false
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(AUDIO_MANAGER_GROUP)
	_load_sfx_players()
	_load_music_player()


func _exit_tree() -> void:
	# Release the live music playback so the stream is not held at shutdown.
	stop_all_audio()
	if _music_player != null:
		_music_player.stream = null


func stop_all_audio() -> void:
	_kill_duck_tween()
	if _music_player != null:
		_music_player.stop()
	stop_all_sfx()


func initialize(profile_store: Node) -> void:
	_profile_store = profile_store
	if is_instance_valid(_profile_store):
		set_sound_enabled(bool(_profile_store.call("get_sound_enabled")))
		set_sfx_volume(float(_profile_store.call("get_sfx_volume")))
		set_music_volume(float(_profile_store.call("get_music_volume")))
		set_music_enabled(bool(_profile_store.call("get_music_enabled")))
	else:
		set_music_enabled(_music_enabled)


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


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if _music_player == null:
		return
	_music_player.stream_paused = not _music_enabled
	if _music_enabled and not _music_player.playing:
		_music_player.play()


func restart_music() -> void:
	if _music_player == null:
		return
	_music_ducked = false
	_kill_duck_tween()
	_music_player.volume_db = 0.0
	if _music_player.playing:
		_music_player.seek(0.0)
	elif _music_enabled:
		_music_player.play()


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing and not _music_player.stream_paused


func get_music_player() -> AudioStreamPlayer:
	return _music_player


func set_sfx_volume(linear: float) -> void:
	_set_bus_linear_volume(SFX_BUS, linear)


func set_music_volume(linear: float) -> void:
	_set_bus_linear_volume(MUSIC_BUS, linear)


func duck_music() -> void:
	_music_ducked = true
	_tween_music_level(MUSIC_DUCK_LEVEL)


func unduck_music() -> void:
	_music_ducked = false
	_tween_music_level(1.0)


func is_music_ducked() -> bool:
	return _music_ducked


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
		player.bus = SFX_BUS
		player.volume_db = float(SFX_VOLUME_DB.get(sound_name, 0.0))
		add_child(player)
		_sfx_players[sound_name] = player


func _load_music_player() -> void:
	var stream := load(MUSIC_STREAM_PATH) as AudioStream
	if stream == null:
		push_warning("AudioManager could not load music at '%s'." % MUSIC_STREAM_PATH)
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.stream = stream
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)


func _tween_music_level(linear: float) -> void:
	if _music_player == null:
		return
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_property(
		_music_player,
		"volume_db",
		linear_to_db(linear),
		MUSIC_DUCK_TIME
	)


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


func _set_bus_linear_volume(bus_name: StringName, linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("AudioManager could not find audio bus '%s'." % bus_name)
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped <= 0.0)
	if clamped > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))


func _is_sound_enabled() -> bool:
	if is_instance_valid(_profile_store):
		return _sound_enabled and bool(_profile_store.call("get_sound_enabled"))
	return _sound_enabled
