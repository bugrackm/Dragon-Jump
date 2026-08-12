extends Node

## Owns state that lasts for one run. Persistent values belong in ProfileStore.

signal state_changed(new_state: int)
signal score_changed(new_score: int)
signal game_over(final_score: int)

enum RunState {
	READY,
	PLAYING,
	GAME_OVER,
}

const DEFAULT_SEED := 13_371_337

var state: RunState = RunState.READY
var score := 0
var rng := RandomNumberGenerator.new()
var rng_seed := DEFAULT_SEED
var _start_y := 0.0


func start_new_run(seed_value: int, start_y: float) -> void:
	rng_seed = seed_value
	rng.seed = rng_seed
	_start_y = start_y
	score = 0
	_set_state(RunState.PLAYING)
	score_changed.emit(score)


func update_player_altitude(player_y: float) -> void:
	if state != RunState.PLAYING:
		return

	# Godot's positive Y axis points down, so upward travel is start_y - player_y.
	var altitude := maxi(0, int(floor(_start_y - player_y)))
	if altitude > score:
		score = altitude
		score_changed.emit(score)


func get_difficulty_factor() -> float:
	return clampf(float(score) / 5000.0, 0.0, 1.0)


func end_run() -> void:
	if state != RunState.PLAYING:
		return

	_set_state(RunState.GAME_OVER)
	game_over.emit(score)


func _set_state(new_state: RunState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
