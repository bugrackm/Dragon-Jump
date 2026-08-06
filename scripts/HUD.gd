extends CanvasLayer

## Keeps screen-space labels independent from the scrolling world camera.

@onready var score_label: Label = $MarginContainer/Rows/ScoreLabel
@onready var high_score_label: Label = $MarginContainer/Rows/HighScoreLabel


func set_score(value: int) -> void:
	score_label.text = "Altitude: %d" % value


func set_high_score(value: int) -> void:
	high_score_label.text = "High score: %d" % value


func show_game_over(final_score: int) -> void:
	score_label.text = "Game over — altitude: %d" % final_score

