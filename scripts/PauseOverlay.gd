extends CanvasLayer

signal resume_requested
signal settings_requested
signal quit_to_menu_requested


func _ready() -> void:
	$CenterContainer/VBoxContainer/ResumeButton.pressed.connect(
		func() -> void: resume_requested.emit()
	)
	$CenterContainer/VBoxContainer/SettingsButton.pressed.connect(
		func() -> void: settings_requested.emit()
	)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(
		func() -> void: quit_to_menu_requested.emit()
	)
