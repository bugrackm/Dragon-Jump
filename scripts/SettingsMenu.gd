extends CanvasLayer

signal back_requested

@onready var sound_toggle: CheckButton = $CenterContainer/VBoxContainer/SoundRow/SoundToggle
@onready var music_toggle: CheckButton = $CenterContainer/VBoxContainer/MusicRow/MusicToggle
@onready var sfx_slider: HSlider = $CenterContainer/VBoxContainer/SfxVolumeRow/SfxVolumeSlider
@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicVolumeRow/MusicVolumeSlider

var _profile_store: Node
var _audio_manager: Node


func _ready() -> void:
	sound_toggle.toggled.connect(_on_sound_toggled)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	music_slider.value_changed.connect(_on_music_volume_changed)
	$CenterContainer/VBoxContainer/BackButton.pressed.connect(
		func() -> void:
			_play_sfx(&"sfx_ui_back")
			back_requested.emit()
	)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func open(profile_store: Node) -> void:
	_profile_store = profile_store
	sound_toggle.set_pressed_no_signal(bool(profile_store.call("get_sound_enabled")))
	music_toggle.set_pressed_no_signal(bool(profile_store.call("get_music_enabled")))
	sfx_slider.set_value_no_signal(float(profile_store.call("get_sfx_volume")))
	music_slider.set_value_no_signal(float(profile_store.call("get_music_volume")))
	visible = true


func _on_sound_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_profile_store):
		_profile_store.call("set_sound_enabled", toggled_on)
	if is_instance_valid(_audio_manager):
		_audio_manager.call("set_sound_enabled", toggled_on)
	_play_sfx(&"sfx_ui_click")


func _on_music_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_profile_store):
		_profile_store.call("set_music_enabled", toggled_on)
	if is_instance_valid(_audio_manager):
		_audio_manager.call("set_music_enabled", toggled_on)
	_play_sfx(&"sfx_ui_click")


func _on_sfx_volume_changed(value: float) -> void:
	if is_instance_valid(_profile_store):
		_profile_store.call("set_sfx_volume", value)
	if is_instance_valid(_audio_manager):
		_audio_manager.call("set_sfx_volume", value)


func _on_sfx_drag_ended(_value_changed: bool) -> void:
	_play_sfx(&"sfx_ui_click")


func _on_music_volume_changed(value: float) -> void:
	if is_instance_valid(_profile_store):
		_profile_store.call("set_music_volume", value)
	if is_instance_valid(_audio_manager):
		_audio_manager.call("set_music_volume", value)


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
