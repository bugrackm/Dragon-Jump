extends CanvasLayer

signal retry_requested
signal menu_requested

@onready var score_label: Label = $CenterContainer/VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var coins_label: Label = $CenterContainer/VBoxContainer/CoinsLabel


func _ready() -> void:
	$CenterContainer/VBoxContainer/RetryButton.pressed.connect(
		func() -> void: retry_requested.emit()
	)
	$CenterContainer/VBoxContainer/MenuButton.pressed.connect(
		func() -> void: menu_requested.emit()
	)


func show_screen(final_score: int, high_score: int, run_coins: int) -> void:
	score_label.text = "Altitude: %d" % final_score
	high_score_label.text = "High score: %d" % high_score
	coins_label.text = "Coins this run: %d" % run_coins
	visible = true
