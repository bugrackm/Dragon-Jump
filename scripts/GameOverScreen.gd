extends CanvasLayer

const UiFx := preload("res://scripts/ui/UiFx.gd")

signal retry_requested
signal menu_requested

@onready var score_label: Label = $CenterContainer/Card/Content/ScoreLabel
@onready var high_score_label: Label = $CenterContainer/Card/Content/HighScoreLabel
@onready var coins_label: Label = $CenterContainer/Card/Content/CoinsRow/CoinsLabel

var _audio_manager: Node


func _ready() -> void:
	UiFx.wire_press_fx(self)
	$CenterContainer/Card/Content/RetryButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			retry_requested.emit()
	)
	$CenterContainer/Card/Content/MenuButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_back")
			menu_requested.emit()
	)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func show_screen(final_score: int, high_score: int, run_coins: int, is_new_best: bool) -> void:
	var badge := $CenterContainer/Card/Content/BadgeHolder/NewBestBadge as Control
	badge.hide()
	_reserve_number_width(score_label, "Altitude: %d", final_score)
	_reserve_number_width(coins_label, "Coins this run: %d", run_coins)
	high_score_label.text = "High score: %d" % high_score
	UiFx.open_screen(self)
	var sequence := UiFx.tween_for(self, &"numbers")
	sequence.tween_interval(UiFx.OPEN_DURATION)
	sequence.tween_callback(func() -> void:
		var score_tween := UiFx.count_up(score_label, "Altitude: %d", final_score, 0.8)
		score_tween.finished.connect(func() -> void:
			if is_new_best:
				UiFx.pop_badge(badge)
			UiFx.count_up(coins_label, "Coins this run: %d", run_coins, 0.4)
		)
	)


## Reserve the final text width before opening so count-up never resizes the Card.
func _reserve_number_width(label: Label, fmt: String, value: int) -> void:
	label.custom_minimum_size.x = 0
	label.text = fmt % value
	label.custom_minimum_size.x = label.get_minimum_size().x
	label.text = fmt % 0


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
