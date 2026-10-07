extends Node

## Owns menu-only clocks and layout; a fresh menu gets one entrance.
const UiFx := preload("res://scripts/ui/UiFx.gd")
const LOGO_WIDTH := 918.0
const TITLE_HEIGHT := 530.0
const DRAGON_HEIGHT := 630.0

var hero_scale := 1.0
var entrance_played := false
var entrance_running := false
var _elapsed := 0.0
var _active := false

@onready var menu: CanvasLayer = get_parent()
@onready var center: Control = menu.get_node("CenterContainer")
@onready var stack: VBoxContainer = center.get_node("VBoxContainer")
@onready var title_holder: Control = stack.get_node("TitleHolder")
@onready var logo_root: Node2D = title_holder.get_node("LogoRoot")
@onready var logo_motion: Node2D = logo_root.get_node("LogoMotion")
@onready var logo: Sprite2D = logo_motion.get_node("MenuLogo")
@onready var sparkles: Node2D = logo_motion.get_node("Sparkles")
@onready var dragon_stage: Control = stack.get_node("DragonStage")
@onready var dragon_root: Node2D = dragon_stage.get_node("DragonRoot")
@onready var dragon: Node2D = dragon_root.get_node("DragonFloat")
@onready var card: Control = stack.get_node("Card")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	logo.material = logo.material.duplicate()
	center.resized.connect(_apply_layout)
	card.minimum_size_changed.connect(_apply_layout)
	title_holder.resized.connect(_place_roots)
	dragon_stage.resized.connect(_place_roots)
	menu.visibility_changed.connect(_on_visibility_changed)
	_apply_layout()
	set_process(false)


func _apply_layout() -> void:
	var available := center.size
	var width_scale := minf(920.0, available.x * 0.85) / LOGO_WIDTH
	var height_scale := (available.y - card.get_combined_minimum_size().y - 24.0 - 64.0) / (TITLE_HEIGHT + DRAGON_HEIGHT)
	hero_scale = clampf(minf(width_scale, height_scale), 0.6, 1.0)
	stack.custom_minimum_size.x = maxf(800.0, LOGO_WIDTH * hero_scale)
	title_holder.custom_minimum_size.y = TITLE_HEIGHT * hero_scale
	dragon_stage.custom_minimum_size.y = DRAGON_HEIGHT * hero_scale
	logo_root.scale = Vector2.ONE * hero_scale
	dragon_root.scale = Vector2.ONE * hero_scale
	_place_roots()


func _place_roots() -> void:
	logo_root.position = title_holder.size * 0.5
	dragon_root.position = dragon_stage.size * 0.5 + Vector2(0, 25.0 * hero_scale)


func open() -> void:
	_active = true
	set_process(true)
	dragon.set_active(true)
	if entrance_played:
		_settle_logo()
		return
	entrance_played = true
	entrance_running = true
	sparkles.visible = false
	logo_motion.position = Vector2(0, -900)
	var tween := UiFx.tween_for(self, &"entrance")
	tween.tween_property(logo_motion, "position:y", 0.0, 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo_motion, "scale", Vector2(1.035, 0.955), 0.09)
	tween.tween_property(logo_motion, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_finish_entrance)


func _finish_entrance() -> void:
	_settle_logo()
	sparkles.reveal()


func _settle_logo() -> void:
	UiFx.stop(self, &"entrance")
	entrance_running = false
	logo_motion.position = Vector2.ZERO
	logo_motion.scale = Vector2.ONE
	sparkles.visible = true


func _on_visibility_changed() -> void:
	if menu.visible:
		return
	_active = false
	set_process(false)
	dragon.set_active(false)
	_settle_logo()
	(logo.material as ShaderMaterial).set_shader_parameter("sweep", -1.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if entrance_running:
		return
	logo_motion.position = Vector2(0, sin(_elapsed * TAU / 3.4) * 3.0)
	logo_motion.scale = Vector2.ONE * (1.0 + sin(_elapsed * TAU / 4.2) * 0.004)
	var shine_time := fposmod(_elapsed, 4.6)
	var sweep := lerpf(-0.3, 1.5, (shine_time - 4.0) / 0.6) if shine_time >= 4.0 else -1.0
	(logo.material as ShaderMaterial).set_shader_parameter("sweep", sweep)
	sparkles.advance(delta)
