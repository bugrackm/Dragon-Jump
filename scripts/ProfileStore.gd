class_name ProfileStore
extends Node

## Stores persistent score, wallet, settings, and ability unlock data.

signal high_score_changed(new_high_score: int)
signal coins_changed(new_total: int)
signal settings_changed(key: String, value: Variant)
signal ability_unlocked(ability_key: String)
signal ability_upgraded(ability_key: String, new_level: int)

const SAVE_PATH := "user://profile.cfg"
const CURRENT_SCHEMA_VERSION := 4
const SECTION_PROFILE := "profile"
const SECTION_ECONOMY := "economy"
const SECTION_SETTINGS := "settings"
const SECTION_ABILITIES := "abilities"

const MAX_FIRE_BREATH_LEVEL := 3
const COST_DOUBLE_JUMP := 200
const COST_GLIDE := 400
const COST_FIRE_LEVEL_2 := 300
const COST_FIRE_LEVEL_3 := 800
const FIRE_COOLDOWN_BY_LEVEL := [0.5, 0.35, 0.2]

var high_score := 0
var total_coins := 0
var sound_enabled := true
var music_enabled := true
var double_jump_unlocked := false
var glide_unlocked := false
var fire_breath_level := 1
var schema_version := CURRENT_SCHEMA_VERSION


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error == ERR_FILE_NOT_FOUND:
		_reset_to_defaults()
		save_profile()
		return
	if error != OK:
		push_warning("Profile could not be read; restoring safe defaults.")
		_reset_to_defaults()
		save_profile()
		return

	var loaded_schema_value: Variant = config.get_value(
		SECTION_PROFILE,
		"schema_version",
		1
	)
	var schema_is_valid := typeof(loaded_schema_value) == TYPE_INT
	var loaded_schema_version := maxi(
		1,
		int(loaded_schema_value) if schema_is_valid else 1
	)
	var is_future_schema := loaded_schema_version > CURRENT_SCHEMA_VERSION

	var loaded_high_score: Variant = config.get_value(
		SECTION_PROFILE,
		"high_score",
		0
	)
	var high_score_is_valid := typeof(loaded_high_score) == TYPE_INT
	high_score = maxi(0, int(loaded_high_score)) if high_score_is_valid else 0

	var loaded_total_coins: Variant = config.get_value(
		SECTION_ECONOMY,
		"total_coins",
		0
	)
	var coins_are_valid := typeof(loaded_total_coins) == TYPE_INT
	if loaded_schema_version >= 2:
		total_coins = maxi(0, int(loaded_total_coins)) if coins_are_valid else 0
	else:
		total_coins = 0

	var loaded_sound_enabled: Variant = config.get_value(
		SECTION_SETTINGS,
		"sound_enabled",
		true
	)
	var loaded_music_enabled: Variant = config.get_value(
		SECTION_SETTINGS,
		"music_enabled",
		true
	)
	var sound_is_valid := typeof(loaded_sound_enabled) == TYPE_BOOL
	var music_is_valid := typeof(loaded_music_enabled) == TYPE_BOOL
	if loaded_schema_version >= 3:
		sound_enabled = loaded_sound_enabled if sound_is_valid else true
		music_enabled = loaded_music_enabled if music_is_valid else true
	else:
		sound_enabled = true
		music_enabled = true

	var loaded_double_jump: Variant = config.get_value(
		SECTION_ABILITIES,
		"double_jump_unlocked",
		false
	)
	var loaded_glide: Variant = config.get_value(
		SECTION_ABILITIES,
		"glide_unlocked",
		false
	)
	var loaded_fire_level: Variant = config.get_value(
		SECTION_ABILITIES,
		"fire_breath_level",
		1
	)
	var double_jump_is_valid := typeof(loaded_double_jump) == TYPE_BOOL
	var glide_is_valid := typeof(loaded_glide) == TYPE_BOOL
	var fire_level_is_valid := typeof(loaded_fire_level) == TYPE_INT
	var fire_level_was_in_range := (
		fire_level_is_valid
		and int(loaded_fire_level) >= 1
		and int(loaded_fire_level) <= MAX_FIRE_BREATH_LEVEL
	)

	if loaded_schema_version < CURRENT_SCHEMA_VERSION:
		# Before M3b these abilities were always available, so existing players
		# retain them when their legacy profile is upgraded to schema v4.
		double_jump_unlocked = true
		glide_unlocked = true
		fire_breath_level = 1
	else:
		double_jump_unlocked = loaded_double_jump if double_jump_is_valid else false
		glide_unlocked = loaded_glide if glide_is_valid else false
		fire_breath_level = clampi(int(loaded_fire_level), 1, MAX_FIRE_BREATH_LEVEL) \
			if fire_level_is_valid else 1

	schema_version = loaded_schema_version if is_future_schema else CURRENT_SCHEMA_VERSION
	if is_future_schema:
		push_warning(
			"Profile schema %d is newer than supported schema %d; leaving the file unchanged."
			% [loaded_schema_version, CURRENT_SCHEMA_VERSION]
		)
		return

	var economy_missing := not config.has_section_key(SECTION_ECONOMY, "total_coins")
	var sound_missing := not config.has_section_key(SECTION_SETTINGS, "sound_enabled")
	var music_missing := not config.has_section_key(SECTION_SETTINGS, "music_enabled")
	var double_jump_missing := not config.has_section_key(
		SECTION_ABILITIES,
		"double_jump_unlocked"
	)
	var glide_missing := not config.has_section_key(
		SECTION_ABILITIES,
		"glide_unlocked"
	)
	var fire_level_missing := not config.has_section_key(
		SECTION_ABILITIES,
		"fire_breath_level"
	)
	if (
		loaded_schema_version != CURRENT_SCHEMA_VERSION
		or not schema_is_valid
		or economy_missing
		or sound_missing
		or music_missing
		or double_jump_missing
		or glide_missing
		or fire_level_missing
		or not high_score_is_valid
		or not coins_are_valid
		or not sound_is_valid
		or not music_is_valid
		or not double_jump_is_valid
		or not glide_is_valid
		or not fire_level_was_in_range
	):
		save_profile()


func update_high_score(candidate_score: int) -> bool:
	if candidate_score <= high_score:
		return false

	high_score = maxi(0, candidate_score)
	high_score_changed.emit(high_score)
	return save_profile()


func add_coins(amount: int) -> void:
	total_coins += amount
	coins_changed.emit(total_coins)
	save_profile()


func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	settings_changed.emit("sound_enabled", sound_enabled)
	save_profile()


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	settings_changed.emit("music_enabled", music_enabled)
	save_profile()


func get_sound_enabled() -> bool:
	return sound_enabled


func get_music_enabled() -> bool:
	return music_enabled


func is_double_jump_unlocked() -> bool:
	return double_jump_unlocked


func is_glide_unlocked() -> bool:
	return glide_unlocked


func get_fire_breath_level() -> int:
	return fire_breath_level


func get_double_jump_cost() -> int:
	return COST_DOUBLE_JUMP


func get_glide_cost() -> int:
	return COST_GLIDE


func get_next_fire_upgrade_cost() -> int:
	if fire_breath_level >= MAX_FIRE_BREATH_LEVEL:
		return -1
	return COST_FIRE_LEVEL_2 if fire_breath_level == 1 else COST_FIRE_LEVEL_3


func get_fire_cooldown() -> float:
	return get_fire_cooldown_for_level(fire_breath_level)


static func get_fire_cooldown_for_level(level: int) -> float:
	return float(FIRE_COOLDOWN_BY_LEVEL[clampi(level - 1, 0, 2)])


func unlock_double_jump() -> bool:
	if double_jump_unlocked or total_coins < COST_DOUBLE_JUMP:
		return false

	var old_total_coins := total_coins
	var old_unlocked := double_jump_unlocked
	total_coins -= COST_DOUBLE_JUMP
	double_jump_unlocked = true
	if not save_profile():
		total_coins = old_total_coins
		double_jump_unlocked = old_unlocked
		return false

	coins_changed.emit(total_coins)
	ability_unlocked.emit("double_jump")
	return true


func unlock_glide() -> bool:
	if glide_unlocked or total_coins < COST_GLIDE:
		return false

	var old_total_coins := total_coins
	var old_unlocked := glide_unlocked
	total_coins -= COST_GLIDE
	glide_unlocked = true
	if not save_profile():
		total_coins = old_total_coins
		glide_unlocked = old_unlocked
		return false

	coins_changed.emit(total_coins)
	ability_unlocked.emit("glide")
	return true


func upgrade_fire_breath() -> bool:
	var upgrade_cost := get_next_fire_upgrade_cost()
	if upgrade_cost < 0 or total_coins < upgrade_cost:
		return false

	var old_total_coins := total_coins
	var old_fire_level := fire_breath_level
	total_coins -= upgrade_cost
	fire_breath_level = mini(fire_breath_level + 1, MAX_FIRE_BREATH_LEVEL)
	if not save_profile():
		total_coins = old_total_coins
		fire_breath_level = old_fire_level
		return false

	coins_changed.emit(total_coins)
	ability_upgraded.emit("fire_breath", fire_breath_level)
	return true


func save_profile() -> bool:
	if schema_version > CURRENT_SCHEMA_VERSION:
		push_warning("Refusing to overwrite a profile created by a newer schema.")
		return false

	var config := ConfigFile.new()
	config.set_value(SECTION_PROFILE, "schema_version", CURRENT_SCHEMA_VERSION)
	config.set_value(SECTION_PROFILE, "high_score", high_score)
	config.set_value(SECTION_ECONOMY, "total_coins", total_coins)
	config.set_value(SECTION_SETTINGS, "sound_enabled", sound_enabled)
	config.set_value(SECTION_SETTINGS, "music_enabled", music_enabled)
	config.set_value(SECTION_ABILITIES, "double_jump_unlocked", double_jump_unlocked)
	config.set_value(SECTION_ABILITIES, "glide_unlocked", glide_unlocked)
	config.set_value(SECTION_ABILITIES, "fire_breath_level", fire_breath_level)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save profile.cfg (error %s)." % error)
		return false
	return true


func _reset_to_defaults() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	high_score = 0
	total_coins = 0
	sound_enabled = true
	music_enabled = true
	double_jump_unlocked = false
	glide_unlocked = false
	fire_breath_level = 1
