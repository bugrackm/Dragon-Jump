extends CanvasLayer

const UiFx := preload("res://scripts/ui/UiFx.gd")

signal resume_requested
signal settings_requested
signal quit_to_menu_requested

var _audio_manager: Node


func _ready() -> void:
	UiFx.wire_press_fx(self)
	$CenterContainer/Card/Content/ResumeButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			resume_requested.emit()
	)
	$CenterContainer/Card/Content/SettingsButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			settings_requested.emit()
	)
	$CenterContainer/Card/Content/QuitButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_back")
			quit_to_menu_requested.emit()
	)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
