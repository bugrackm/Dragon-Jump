extends SceneTree

## Visual contract and real SceneTree pause coverage for the fire scene.
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	var scene := load("res://scenes/hazards/RisingFire.tscn") as PackedScene
	_expect(scene != null, "scene loads")
	var fire := scene.instantiate() as Node2D
	root.add_child(fire)
	_expect(fire.get_node("Flames") is CPUParticles2D, "Flames remains CPU particles")
	_expect(fire.z_index == 10, "root z index")
	_expect(not fire.visible, "root starts hidden")
	_expect(fire.process_mode == Node.PROCESS_MODE_PAUSABLE, "root is pausable")
	for entry in [["speed_model", 2], ["visible_band", 70.0], ["kill_inset", 12.0],
			["rise_speed_min", 90.0], ["rise_speed_max", 170.0],
			["leash_below_screen", 40.0]]:
		_expect(fire.get(entry[0]) == entry[1], "unchanged " + entry[0])
	var material := fire.get_node("Body").material as ShaderMaterial
	_expect(material != null and material.shader != null, "wall shader material")
	var uniforms: Array[String] = []
	for uniform in material.shader.get_shader_uniform_list():
		uniforms.append(uniform.name)
	for uniform in ["u_time", "outer_color", "orange_color", "gold_color", "core_color"]:
		_expect(uniforms.has(uniform), "shader uniform " + uniform)
	_expect(not material.shader.code.contains("TIME"), "no built-in clock")
	_expect(ResourceLoader.exists("res://assets/sprites/particles/ember_flake.png"), "ember texture exists")
	var embers := fire.get_node("Flames") as CPUParticles2D
	_expect(embers.texture.resource_path.ends_with("ember_flake.png"), "ember texture assigned")
	_expect(embers.amount >= 14 and embers.amount <= 22, "deliberate ember count")
	var polygon: PackedVector2Array = fire.get_node("Body").polygon
	_expect(polygon[0].x == -200.0 and polygon[1].x == 1280.0, "wall wrap coverage")
	var haze := fire.get_node("Haze") as Sprite2D
	_expect(haze.position.y == -250.0, "haze extent")
	var haze_gradient := (haze.texture as GradientTexture2D).gradient
	var peak_alpha := 0.0
	for color in haze_gradient.colors:
		peak_alpha = maxf(peak_alpha, color.a)
	_expect(peak_alpha >= 0.35 and peak_alpha <= 0.45, "visible translucent haze")
	_expect(haze_gradient.sample(0.0).a == 0.0, "haze fades out above the wall")
	var camera := Camera2D.new()
	var player := Node2D.new()
	root.add_child(camera)
	root.add_child(player)
	camera.position = Vector2(540.0, 960.0)
	player.position.y = 1000.0
	fire.setup(camera, player, 1722.0)
	fire.notify_platform_landing()
	fire._physics_process(0.0)
	fire.set_physics_process(false)
	var before := float(material.get_shader_parameter("u_time"))
	await create_timer(0.06).timeout
	var running := float(material.get_shader_parameter("u_time"))
	_expect(running > before, "process advances time")
	paused = true
	await create_timer(0.06, true).timeout
	_expect(float(material.get_shader_parameter("u_time")) == running, "paused time stays frozen")
	paused = false
	await create_timer(0.06).timeout
	_expect(float(material.get_shader_parameter("u_time")) > running, "resume advances time")
	fire.stop()
	var stopped := float(material.get_shader_parameter("u_time"))
	await create_timer(0.06).timeout
	_expect(float(material.get_shader_parameter("u_time")) == stopped, "stopped time stays frozen")
	var second := scene.instantiate() as Node2D
	root.add_child(second)
	_expect(second.get_node("Body").material != material, "per-instance visual clock")
	fire.free()
	second.free()
	camera.free()
	player.free()
	print("fire_visual_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)
