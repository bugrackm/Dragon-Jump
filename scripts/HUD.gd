extends CanvasLayer

const UiFx := preload("res://scripts/ui/UiFx.gd")

## Keeps screen-space labels independent from the scrolling world camera.

signal fire_requested
signal pause_requested

const SAFE_AREA := preload("res://scripts/ui/SafeAreaMargin.gd")

@onready var score_label: Label = $MarginContainer/Rows/ScoreLabel
@onready var high_score_label: Label = $MarginContainer/Rows/HighScoreLabel
@onready var coin_label: Label = $MarginContainer/Rows/CoinRow/CoinLabel
@onready var fire_button: Button = $FireButton
@onready var pause_button: Button = $PauseButton

var _fire_on_cooldown := false


func _ready() -> void:
	UiFx.wire_press_fx(self)
	ScreenLayout.layout_changed.connect(_apply_layout)
	_apply_layout()
	fire_button.connect("fire_requested", _on_fire_button_fire_requested)
	pause_button.pressed.connect(_on_pause_button_pressed)
	_update_fire_button()


func _apply_layout() -> void:
	SAFE_AREA.apply_safe_offsets(pause_button, Vector4(-160, 40, -40, 160), Vector4(0, 40, 40, 0))
	SAFE_AREA.apply_safe_offsets(fire_button, Vector4(-180, -180, -40, -40), Vector4(0, 0, 40, 40))


func set_score(value: int) -> void:
	score_label.text = "Altitude: %d" % value


func set_high_score(value: int) -> void:
	high_score_label.text = "High score: %d" % value


func set_coins(value: int) -> void:
	coin_label.text = "Coins: %d" % value


func set_fire_cooldown(on_cooldown: bool) -> void:
	_fire_on_cooldown = on_cooldown
	_update_fire_button()


func show_playing() -> void:
	set_stats_visible(true)
	fire_button.visible = true
	pause_button.visible = true
	if is_instance_valid(fire_button):
		_update_fire_button()


func set_stats_visible(shown: bool) -> void:
	$MarginContainer/Rows.visible = shown


func bump_coins() -> void:
	UiFx.bounce($MarginContainer/Rows/CoinRow/CoinIcon)


func hide_gameplay_ui() -> void:
	fire_button.visible = false
	pause_button.visible = false


func _update_fire_button() -> void:
	if fire_button != null and is_instance_valid(fire_button):
		if fire_button.has_method("set_state"):
			fire_button.set_state(not _fire_on_cooldown)


func _on_fire_button_fire_requested() -> void:
	fire_requested.emit()


func _on_pause_button_pressed() -> void:
	pause_requested.emit()
