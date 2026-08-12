extends Node

## Stores persistent score and wallet data in an INI-style file.

signal high_score_changed(new_high_score: int)
signal coins_changed(new_total: int)

const SAVE_PATH := "user://profile.cfg"
const CURRENT_SCHEMA_VERSION := 2
const SECTION_PROFILE := "profile"
const SECTION_ECONOMY := "economy"

var high_score := 0
var total_coins := 0
var schema_version := CURRENT_SCHEMA_VERSION


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error == ERR_FILE_NOT_FOUND:
		_reset_to_defaults()
		return
	if error != OK:
		push_warning("Profile could not be read; restoring safe defaults.")
		_reset_to_defaults()
		save_profile()
		return

	var loaded_schema_version := maxi(1, int(config.get_value(
		SECTION_PROFILE,
		"schema_version",
		1
	)))
	high_score = maxi(0, int(config.get_value(SECTION_PROFILE, "high_score", 0)))
	if loaded_schema_version >= 2:
		total_coins = maxi(0, int(config.get_value(
			SECTION_ECONOMY,
			"total_coins",
			0
		)))
	else:
		total_coins = 0

	schema_version = CURRENT_SCHEMA_VERSION
	var economy_missing := not config.has_section_key(SECTION_ECONOMY, "total_coins")
	if loaded_schema_version != CURRENT_SCHEMA_VERSION or economy_missing:
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


func save_profile() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION_PROFILE, "schema_version", CURRENT_SCHEMA_VERSION)
	config.set_value(SECTION_PROFILE, "high_score", high_score)
	config.set_value(SECTION_ECONOMY, "total_coins", total_coins)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save profile.cfg (error %s)." % error)
		return false
	return true


func _reset_to_defaults() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	high_score = 0
	total_coins = 0
