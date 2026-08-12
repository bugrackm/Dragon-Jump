extends CanvasLayer

## Keeps screen-space labels independent from the scrolling world camera.

signal fire_requested

@onready var score_label: Label = $MarginContainer/Rows/ScoreLabel
@onready var high_score_label: Label = $MarginContainer/Rows/HighScoreLabel
@onready var coin_label: Label = $MarginContainer/Rows/CoinLabel
@onready var fire_button: Button = $FireButton

var _fire_on_cooldown := false


func _ready() -> void:
	fire_button.connect("fire_requested", _on_fire_button_fire_requested)
	_update_fire_button()


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
	fire_button.visible = true
	if is_instance_valid(fire_button):
		_update_fire_button()


func show_game_over(final_score: int) -> void:
	score_label.text = "Game over — altitude: %d" % final_score
	fire_button.visible = false


func _update_fire_button() -> void:
	if fire_button != null and is_instance_valid(fire_button):
		if fire_button.has_method("set_state"):
			fire_button.set_state(not _fire_on_cooldown)


func _on_fire_button_fire_requested() -> void:
	fire_requested.emit()
