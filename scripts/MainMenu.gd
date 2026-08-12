extends CanvasLayer

signal play_requested
signal settings_requested

@onready var high_score_label: Label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var coin_label: Label = $CenterContainer/VBoxContainer/CoinLabel


func _ready() -> void:
	$CenterContainer/VBoxContainer/PlayButton.pressed.connect(
		func() -> void: play_requested.emit()
	)
	$CenterContainer/VBoxContainer/SettingsButton.pressed.connect(
		func() -> void: settings_requested.emit()
	)


func refresh(profile_store: Node) -> void:
	high_score_label.text = "High score: %d" % int(profile_store.get("high_score"))
	coin_label.text = "Coins: %d" % int(profile_store.get("total_coins"))
