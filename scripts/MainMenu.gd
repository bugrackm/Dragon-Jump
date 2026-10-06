extends CanvasLayer

const UiFx := preload("res://scripts/ui/UiFx.gd")

signal play_requested
signal settings_requested
signal shop_requested

@onready var high_score_label: Label = $CenterContainer/VBoxContainer/Card/Content/HighScoreLabel
@onready var coin_label: Label = $CenterContainer/VBoxContainer/Card/Content/CoinRow/CoinLabel

var _audio_manager: Node


func _ready() -> void:
	UiFx.wire_press_fx(self)
	UiFx.idle_bob(find_child("TitleLabel", true, false), 7.0, 2.5)
	$CenterContainer/VBoxContainer/Card/Content/PlayButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			play_requested.emit()
	)
	$CenterContainer/VBoxContainer/Card/Content/SettingsButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			settings_requested.emit()
	)
	$CenterContainer/VBoxContainer/Card/Content/ShopButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			shop_requested.emit()
	)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func refresh(profile_store: Node) -> void:
	high_score_label.text = "High score: %d" % int(profile_store.get("high_score"))
	coin_label.text = "Coins: %d" % int(profile_store.get("total_coins"))


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
