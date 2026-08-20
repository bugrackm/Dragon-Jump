extends Camera2D

## Applies short-lived visual shake without changing the camera altimeter position.

const DEFAULT_DURATION := 0.35
const DEFAULT_AMPLITUDE := 14.0

var _rng := RandomNumberGenerator.new()
var _duration := 0.0
var _remaining := 0.0
var _amplitude := 0.0


func _ready() -> void:
	_rng.randomize()
	offset = Vector2.ZERO
	set_process(false)


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if is_zero_approx(_remaining):
		stop_shake()
		return

	var remaining_ratio := _remaining / _duration
	var strength := _amplitude * remaining_ratio * remaining_ratio
	offset = Vector2(
		_rng.randf_range(-strength, strength),
		_rng.randf_range(-strength, strength)
	)


func start_shake(
	duration: float = DEFAULT_DURATION,
	amplitude: float = DEFAULT_AMPLITUDE
	) -> void:
	if duration <= 0.0 or amplitude <= 0.0:
		stop_shake()
		return

	_duration = duration
	_remaining = duration
	_amplitude = amplitude
	set_process(true)


func stop_shake() -> void:
	_remaining = 0.0
	offset = Vector2.ZERO
	set_process(false)
