extends AnimatedSprite2D

## Menu-only flight, independent of the player's simulation and pause state.
var _elapsed := 0.0
var _flap_clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	animation_finished.connect(_on_animation_finished)
	play(&"glide")


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	_flap_clock += delta
	var stage := get_parent() as Control
	var phase := _elapsed * TAU / 8.0
	position = stage.size * 0.5 + Vector2(sin(phase) * stage.size.x * 0.22, sin(phase * 2.0) * 20.0)
	flip_h = cos(phase) < 0.0
	if _flap_clock >= 3.0:
		_flap_clock = fmod(_flap_clock, 3.0)
		play(&"double_jump")


func _on_animation_finished() -> void:
	if animation == &"double_jump":
		play(&"glide")
