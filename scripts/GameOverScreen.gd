extends CanvasLayer

signal retry_requested
signal menu_requested

@onready var score_label: Label = $CenterContainer/VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var coins_label: Label = $CenterContainer/VBoxContainer/CoinsLabel

var _audio_manager: Node


func _ready() -> void:
	$CenterContainer/VBoxContainer/RetryButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			retry_requested.emit()
	)
	$CenterContainer/VBoxContainer/MenuButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_back")
			menu_requested.emit()
	)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func show_screen(final_score: int, high_score: int, run_coins: int) -> void:
	score_label.text = "Altitude: %d" % final_score
	high_score_label.text = "High score: %d" % high_score
	coins_label.text = "Coins this run: %d" % run_coins
	visible = true


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
