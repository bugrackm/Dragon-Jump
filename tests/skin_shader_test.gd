extends SceneTree

const SkinCatalog := preload("res://scripts/cosmetics/SkinCatalog.gd")
const SkinDef := preload("res://scripts/cosmetics/SkinDef.gd")
const SkinMaterial := preload("res://scripts/cosmetics/SkinMaterial.gd")
const PROFILE_PATH := "user://profile.cfg"
const UNIFORMS := [
	"hue_center", "hue_half_width", "softness", "sat_gate",
	"hue_target", "hue_spread", "sat_mul", "val_mul",
]

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
	_check_materials()
	await _check_player()
	await _check_main()
	_restore_profile()
	print("skin_shader_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


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


func _check_materials() -> void:
	var shader := load("res://assets/shaders/dragon_skin.gdshader") as Shader
	_expect(shader != null, "shader loads")
	var names: Array[String] = []
	for uniform in shader.get_shader_uniform_list():
		names.append(uniform.name)
	for uniform in UNIFORMS:
		_expect(names.has(uniform), "shader uniform " + uniform)
	_expect(SkinMaterial.make_material(null) == null, "null skin clears material")
	_expect(SkinMaterial.make_material(Resource.new()) == null, "missing tint clears material")
	_expect(SkinMaterial.make_material(SkinDef.new()) == null, "disabled tint clears material")
	var defaults := SkinDef.new()
	var expected: Dictionary = {"hue_center": 115.0, "hue_half_width": 35.0, "softness": 15.0, "sat_gate": 0.35, "hue_spread": 1.0}
	for field in expected:
		_expect(is_equal_approx(defaults.get(field), expected[field]), "default " + field)
	for skin in SkinCatalog.get_all():
		var material := SkinMaterial.make_material(skin)
		if skin.id == "classic":
			_expect(material == null, "Classic has no material")
			continue
		_expect(material is ShaderMaterial, skin.id + " shader material")
		_expect(material.shader == shader, skin.id + " shared shader")
		_expect(material != SkinMaterial.make_material(skin), skin.id + " independent material")
		for uniform in UNIFORMS:
			_expect(is_equal_approx(material.get_shader_parameter(uniform), skin.get(uniform)), skin.id + " " + uniform)
	var sunburst := SkinCatalog.get_skin("sunburst")
	_expect(sunburst.hue_target == 44.0, "sunburst target")
	_expect(is_equal_approx(sunburst.hue_spread, 0.3), "sunburst spread")
	_expect(is_equal_approx(sunburst.sat_mul, 1.15), "sunburst saturation")
	_expect(is_equal_approx(sunburst.val_mul, 1.1), "sunburst value")


func _is_ember(item: CanvasItem) -> bool:
	return item.material is ShaderMaterial and is_equal_approx(item.material.get_shader_parameter("hue_target"), 8.0)


func _check_player() -> void:
	var player := load("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	var host := player.get_node("VisualRoot")
	var sprite := player.get_node("VisualRoot/Sprite") as AnimatedSprite2D
	var flame := player.get_node("MouthFlame") as CanvasItem
	var trail := player.get_node("GlideTrail") as CanvasItem
	var effect_materials := [flame.material, trail.material]
	player.apply_skin(SkinCatalog.get_skin("ember"))
	_expect(_is_ember(sprite), "real player tinted Ember")
	_expect(flame.material == effect_materials[0] and trail.material == effect_materials[1], "effect materials unchanged")
	_expect(not flame.use_parent_material and not trail.use_parent_material, "effects do not inherit tint")
	for child in sprite.find_children("*", "CanvasItem", true, false):
		_expect(not child.use_parent_material, "visual child does not inherit tint")
	player.apply_skin(SkinCatalog.get_skin("classic"))
	_expect(sprite.material == null, "real player Classic clears material")
	_expect(host.get_visual() == sprite, "empty scene path preserves instance")
	var controller := player.get_node("AnimationController")
	player.velocity.y = -20.0
	controller.update_animation(false)
	_expect(sprite.animation == &"jump", "jump selected before swap")
	controller.trigger_fire()
	controller.update_animation(false)
	_expect(controller._one_shot_override == &"fire", "one shot active before swap")
	var changes: Array[Node] = []
	host.visual_changed.connect(func(visual: Node) -> void: changes.append(visual))
	var skin: Resource = SkinCatalog.get_skin("ember").duplicate()
	skin.visual_scene_path = "res://tests/fixtures/SkinDragonVisual.tscn"
	player.apply_skin(skin)
	var replacement := host.get_visual() as AnimatedSprite2D
	_expect(replacement != sprite and changes == [replacement], "path swaps and emits once")
	_expect(_is_ember(replacement), "replacement receives skin")
	_expect(controller._current_locomotion == &"" and controller._one_shot_override == &"", "rebind clears animation caches")
	controller.update_animation(false)
	_expect(replacement.animation == &"jump", "same locomotion resent after swap")
	player.apply_skin(skin)
	_expect(host.get_visual() == replacement and changes.size() == 1, "same path does not swap again")
	player.apply_skin(SkinCatalog.get_skin("classic"))
	_expect(host.get_visual() == replacement and replacement.material == null, "empty path retains replacement and clears tint")
	player.free()
	await process_frame


func _press_f8(main: Node, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F8
	event.pressed = pressed
	event.echo = echo
	main._unhandled_input(event)


func _menu_dragon(main: Node) -> Sprite2D:
	return main._main_menu.find_child("MenuDragon", true, false) as Sprite2D


func _check_main() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "schema_version", 5)
	config.set_value("settings", "sound_enabled", false)
	config.set_value("settings", "music_enabled", false)
	config.set_value("cosmetics", "owned_skins", PackedStringArray(["classic", "ember"]))
	config.set_value("cosmetics", "equipped_skin", "ember")
	_expect(config.save(PROFILE_PATH) == OK, "Ember profile fixture saved")
	var main := load("res://scenes/Main.tscn").instantiate() as Node
	main.set("run_seed", 17017)
	root.add_child(main)
	main.audio_manager.stop_all_audio()
	_expect(_menu_dragon(main).material == null, "boot menu stays Classic with Ember equipped")
	main._start_game()
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	var first_material: Material = main._player.get_node("VisualRoot/Sprite").material
	_expect(_is_ember(main._player.get_node("VisualRoot/Sprite")), "run uses equipped Ember")
	main._retry()
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	_expect(_is_ember(main._player.get_node("VisualRoot/Sprite")), "retry keeps Ember")
	_expect(main._player.get_node("VisualRoot/Sprite").material != first_material, "retry creates fresh material")
	_expect(main.profile_store.equip_skin("classic"), "equip Classic during run")
	main._quit_to_menu()
	main._start_game()
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	_expect(main._player.get_node("VisualRoot/Sprite").material == null, "run uses material-free Classic")
	main._quit_to_menu()
	_expect(main.profile_store.equip_skin("ember"), "equip Ember in menu")
	_expect(_menu_dragon(main).material == null, "equipping Ember keeps menu Classic")
	var profile_before := FileAccess.get_file_as_bytes(PROFILE_PATH)
	_press_f8(main, false)
	_press_f8(main, true, true)
	_expect(main._skin_override == "", "release and echo do not cycle")
	main._show_shop()
	_press_f8(main)
	_expect(main._skin_override == "", "shop ignores F8")
	main._hide_shop()
	main._show_settings()
	_press_f8(main)
	_expect(main._skin_override == "", "settings ignores F8")
	main._hide_settings()
	_press_f8(main)
	_expect(main._active_skin_id() == "frost", "F8 advances from equipped Ember to Frost")
	_expect(_menu_dragon(main).material == null, "F8 keeps menu Classic")
	_expect(main.profile_store.get_equipped_skin_id() == "ember", "F8 does not equip")
	main._start_game()
	main._current_world.process_mode = Node.PROCESS_MODE_DISABLED
	_expect(is_equal_approx(main._player.get_node("VisualRoot/Sprite").material.get_shader_parameter("hue_target"), 195.0), "next run uses Frost override")
	_press_f8(main)
	_expect(main._active_skin_id() == "frost", "run ignores F8")
	main._quit_to_menu()
	for skin_id in ["amethyst", "sunburst", "obsidian", "classic", "ember", "frost"]:
		_press_f8(main)
		_expect(main._active_skin_id() == skin_id, "F8 catalog order " + skin_id)
		_expect(_menu_dragon(main).material == null, "menu stays Classic for override " + skin_id)
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == profile_before, "override never writes profile")
	_expect(main.profile_store.get_equipped_skin_id() == "ember", "full cycle leaves equipped skin unchanged")
	main.audio_manager.stop_all_audio()
	main.queue_free()
	paused = false
	await create_timer(0.2).timeout
