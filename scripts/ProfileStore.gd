extends Node

## Stores the small amount of persistent M1 profile data in an INI-style file.

signal high_score_changed(new_high_score: int)

const SAVE_PATH := "user://profile.cfg"
const CURRENT_SCHEMA_VERSION := 1
const SECTION_PROFILE := "profile"

var high_score := 0
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

	schema_version = maxi(1, int(config.get_value(
		SECTION_PROFILE,
		"schema_version",
		CURRENT_SCHEMA_VERSION
	)))
	high_score = maxi(0, int(config.get_value(SECTION_PROFILE, "high_score", 0)))

	# M1 has one schema. A newer/older valid file is normalized on the next save.
	schema_version = CURRENT_SCHEMA_VERSION


func update_high_score(candidate_score: int) -> bool:
	if candidate_score <= high_score:
		return false

	high_score = maxi(0, candidate_score)
	high_score_changed.emit(high_score)
	return save_profile()


func save_profile() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION_PROFILE, "schema_version", CURRENT_SCHEMA_VERSION)
	config.set_value(SECTION_PROFILE, "high_score", high_score)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save profile.cfg (error %s)." % error)
		return false
	return true


func _reset_to_defaults() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	high_score = 0

