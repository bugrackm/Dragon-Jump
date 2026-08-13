extends StaticBody2D

## Replaces the normal landing bounce with a stronger upward launch.

const SPRING_MULTIPLIER := 1.65


func on_player_landed(player: CharacterBody2D) -> void:
	_play_sfx(&"sfx_spring")
	player.velocity.y = player.JUMP_VELOCITY * SPRING_MULTIPLIER


func _play_sfx(sound_name: StringName) -> void:
	var audio_manager := get_tree().get_first_node_in_group(&"audio_manager")
	if audio_manager != null:
		audio_manager.call("play_sfx", sound_name)
