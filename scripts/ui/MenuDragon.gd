extends Node2D

## Absolute poses keep the additive hop independent of float, tilt and breathing.
const HOP_PERIOD := 4.0
var _elapsed := 0.0

@onready var hop: Node2D = $DragonHop


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_active(false)


func set_active(active: bool) -> void:
	set_process(active)


func _process(delta: float) -> void:
	_elapsed += delta
	apply_pose(_elapsed)


func apply_pose(time: float) -> void:
	position = Vector2(sin(time * TAU / 6.4) * 20.0, sin(time * TAU / 2.6) * 14.0)
	rotation = deg_to_rad(4.0) * sin(time * TAU / 3.2)
	var breath := sin(time * TAU / 1.3) * 0.025
	scale = Vector2(1.0 + breath, 1.0 - breath)
	apply_hop(fposmod(time, HOP_PERIOD))


func apply_hop(time: float) -> void:
	hop.position = Vector2.ZERO
	hop.scale = Vector2.ONE
	if time < 0.16:
		hop.scale = Vector2.ONE.lerp(Vector2(1.07, 0.92), time / 0.16)
	elif time < 0.48:
		var phase := (time - 0.16) / 0.32
		hop.position.y = -60.0 * (1.0 - pow(1.0 - phase, 2.0))
		hop.scale = Vector2(1.07, 0.92).lerp(Vector2(0.97, 1.04), sin(phase * PI * 0.5))
	elif time < 0.80:
		var phase := (time - 0.48) / 0.32
		hop.position.y = -60.0 * (1.0 - phase * phase)
		hop.scale = Vector2(0.97, 1.04).lerp(Vector2(1.045, 0.95), phase * phase)
	elif time < 0.98:
		hop.scale = Vector2(1.045, 0.95).lerp(Vector2.ONE, smoothstep(0.80, 0.98, time))
