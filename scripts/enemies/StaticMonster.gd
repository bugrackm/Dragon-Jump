extends Area2D

## Stationary platform-owned contact hazard.


func set_active(is_active: bool) -> void:
	set_deferred("monitoring", is_active)
