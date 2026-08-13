extends CanvasLayer

signal resume_requested
signal settings_requested
signal quit_to_menu_requested

var _audio_manager: Node


func _ready() -> void:
	$CenterContainer/VBoxContainer/ResumeButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			resume_requested.emit()
	)
	$CenterContainer/VBoxContainer/SettingsButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_click")
			settings_requested.emit()
	)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_back")
			quit_to_menu_requested.emit()
	)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
