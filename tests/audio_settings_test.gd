extends SceneTree

const PROFILE_PATH := "user://profile.cfg"

var _checks := 0
var _failures := 0
var _profile_backup := PackedByteArray()
var _profile_existed := false


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	_backup_profile()
	_check_profile_store()
	await _check_audio_manager()
	_restore_profile()
	print("checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(1 if _failures > 0 else 0)


func _backup_profile() -> void:
	_profile_existed = FileAccess.file_exists(PROFILE_PATH)
	if _profile_existed:
		_profile_backup = FileAccess.get_file_as_bytes(PROFILE_PATH)


func _restore_profile() -> void:
	if _profile_existed:
		var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
		file.store_buffer(_profile_backup)
		file.close()
	elif FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))


func _write_settings(sfx: Variant, music: Variant, include_volumes: bool) -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "schema_version", 4)
	config.set_value("profile", "high_score", 0)
	config.set_value("economy", "total_coins", 0)
	config.set_value("settings", "sound_enabled", true)
	config.set_value("settings", "music_enabled", true)
	if include_volumes:
		config.set_value("settings", "sfx_volume", sfx)
		config.set_value("settings", "music_volume", music)
	config.set_value("abilities", "double_jump_unlocked", false)
	config.set_value("abilities", "glide_unlocked", false)
	config.set_value("abilities", "fire_breath_level", 1)
	config.save(PROFILE_PATH)


func _check_profile_store() -> void:
	var store: ProfileStore = ProfileStore.new()

	# Defaults when the file is missing.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	store.load_profile()
	_expect(is_equal_approx(store.get_sfx_volume(), 1.0), "default sfx volume is 1.0")
	_expect(is_equal_approx(store.get_music_volume(), 0.6), "default music volume is 0.6")

	# Round-trip and clamping.
	store.set_sfx_volume(0.35)
	store.set_music_volume(0.8)
	var reloaded: ProfileStore = ProfileStore.new()
	reloaded.load_profile()
	_expect(is_equal_approx(reloaded.get_sfx_volume(), 0.35), "sfx volume round-trips")
	_expect(is_equal_approx(reloaded.get_music_volume(), 0.8), "music volume round-trips")
	store.set_sfx_volume(7.0)
	store.set_music_volume(-3.0)
	_expect(is_equal_approx(store.get_sfx_volume(), 1.0), "sfx volume clamps high")
	_expect(is_equal_approx(store.get_music_volume(), 0.0), "music volume clamps low")

	# Missing keys default and resave.
	_write_settings(0.0, 0.0, false)
	reloaded.load_profile()
	_expect(is_equal_approx(reloaded.get_sfx_volume(), 1.0), "missing sfx volume defaults")
	_expect(is_equal_approx(reloaded.get_music_volume(), 0.6), "missing music volume defaults")
	var resaved := ConfigFile.new()
	resaved.load(PROFILE_PATH)
	_expect(resaved.has_section_key("settings", "sfx_volume"), "missing sfx volume is resaved")
	_expect(resaved.has_section_key("settings", "music_volume"), "missing music volume is resaved")

	# Invalid types default and resave.
	_write_settings("loud", [1], true)
	reloaded.load_profile()
	_expect(is_equal_approx(reloaded.get_sfx_volume(), 1.0), "invalid sfx volume defaults")
	_expect(is_equal_approx(reloaded.get_music_volume(), 0.6), "invalid music volume defaults")
	resaved.load(PROFILE_PATH)
	_expect(
		typeof(resaved.get_value("settings", "sfx_volume")) == TYPE_FLOAT,
		"invalid sfx volume is resaved as float"
	)

	# Out-of-range stored values clamp.
	_write_settings(2.5, -1.0, true)
	reloaded.load_profile()
	_expect(is_equal_approx(reloaded.get_sfx_volume(), 1.0), "stored high sfx volume clamps")
	_expect(is_equal_approx(reloaded.get_music_volume(), 0.0), "stored low music volume clamps")

	# Reset to defaults covers volumes.
	store.set_sfx_volume(0.1)
	store._reset_to_defaults()
	_expect(is_equal_approx(store.get_sfx_volume(), 1.0), "reset restores sfx volume")
	_expect(is_equal_approx(store.get_music_volume(), 0.6), "reset restores music volume")

	store.free()
	reloaded.free()


func _check_audio_manager() -> void:
	var audio: AudioManager = AudioManager.new()
	root.add_child(audio)

	var player := audio.get_music_player()
	_expect(player != null, "music player exists")
	_expect(player.stream is AudioStreamOggVorbis and player.stream.loop, "music stream loops")
	_expect(player.bus == &"Music", "music player uses Music bus")
	_expect(AudioServer.get_bus_index(&"Music") >= 0, "Music bus exists")
	_expect(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus exists")
	var sfx_player := audio.get_node("sfx_ui_click") as AudioStreamPlayer
	_expect(sfx_player.bus == &"SFX", "sfx players use SFX bus")

	audio.set_music_enabled(true)
	_expect(audio.is_music_playing(), "music starts when enabled")
	audio.set_music_enabled(true)
	_expect(audio.is_music_playing(), "re-enabling keeps music playing")
	audio.set_music_enabled(false)
	_expect(not audio.is_music_playing(), "music stops when disabled")
	audio.set_music_enabled(true)
	_expect(audio.is_music_playing(), "music restarts when re-enabled")

	# Finish startup before measuring real-time waits against tween progress.
	await process_frame
	await process_frame

	# Ducking runs while the tree is paused.
	paused = true
	audio.duck_music()
	await create_timer(0.5, true, false, true).timeout
	_expect(
		absf(player.volume_db - linear_to_db(AudioManager.MUSIC_DUCK_LEVEL)) < 0.1,
		"duck reaches ~30%% level while paused (%.2f dB)" % player.volume_db
	)
	audio.unduck_music()
	await create_timer(0.5, true, false, true).timeout
	_expect(absf(player.volume_db) < 0.1, "unduck restores level (%.2f dB)" % player.volume_db)
	paused = false

	# restart_music restarts playback, clears ducking, and respects music_enabled.
	await create_timer(0.6, true, false, true).timeout
	var before := player.get_playback_position()
	_expect(before > 0.3, "music advanced before restart (%.2f s)" % before)
	audio.duck_music()
	audio.restart_music()
	_expect(not audio.is_music_ducked(), "restart_music clears ducked flag")
	_expect(absf(player.volume_db) < 0.1, "restart_music resets level")
	_expect(audio.is_music_playing(), "music playing after restart")
	_expect(player.get_playback_position() < before, "restart_music rewinds playback")
	await create_timer(0.5, true, false, true).timeout
	_expect(absf(player.volume_db) < 0.1, "no stale duck tween after restart")
	audio.set_music_enabled(false)
	audio.restart_music()
	_expect(not audio.is_music_playing(), "restart_music is a no-op when music disabled")
	audio.set_music_enabled(true)

	# Per-SFX offsets are applied independently of the SFX bus slider.
	var coin := audio.get_node("sfx_coin") as AudioStreamPlayer
	_expect(is_equal_approx(coin.volume_db, -6.0), "coin sfx has -6 dB offset")
	_expect(is_zero_approx(sfx_player.volume_db), "other sfx have no offset")
	audio.set_sfx_volume(0.25)
	_expect(is_equal_approx(coin.volume_db, -6.0), "coin offset independent of sfx slider")
	audio.set_sfx_volume(1.0)

	# Sliders drive bus volume independently of ducking.
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	audio.set_music_volume(0.5)
	_expect(
		absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.5)) < 0.01,
		"music slider sets Music bus volume"
	)
	_expect(not AudioServer.is_bus_mute(music_bus), "music bus unmuted above 0")
	audio.set_music_volume(0.0)
	_expect(AudioServer.is_bus_mute(music_bus), "music bus muted at 0")
	audio.set_music_volume(0.6)
	_expect(not AudioServer.is_bus_mute(music_bus), "music bus unmuted again")
	audio.set_sfx_volume(0.25)
	_expect(
		absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.25)) < 0.01,
		"sfx slider sets SFX bus volume"
	)
	audio.set_sfx_volume(0.0)
	_expect(AudioServer.is_bus_mute(sfx_bus), "sfx bus muted at 0")
	audio.set_sfx_volume(1.0)
	audio.set_music_volume(0.6)

	# Music disabled at launch, then enabled later, must actually play.
	var late: AudioManager = AudioManager.new()
	root.add_child(late)
	late.set_music_enabled(false)
	_expect(not late.is_music_playing(), "music not playing when disabled at launch")
	late.set_music_enabled(true)
	_expect(late.is_music_playing(), "music plays when enabled after disabled launch")
	late.free()

	# Let the mixer release the live playback before teardown, or the engine
	# reports the music stream as leaked at exit.
	audio.set_music_enabled(false)
	audio.get_music_player().stop()
	await create_timer(0.3, true, false, true).timeout
	player = null
	audio.free()
