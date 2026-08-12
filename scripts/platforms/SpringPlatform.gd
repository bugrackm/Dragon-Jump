extends StaticBody2D

## Replaces the normal landing bounce with a stronger upward launch.

const SPRING_MULTIPLIER := 1.65


func on_player_landed(player: CharacterBody2D) -> void:
	player.velocity.y = player.JUMP_VELOCITY * SPRING_MULTIPLIER
