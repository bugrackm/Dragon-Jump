extends Resource

## Describes a skin without loading its optional visual assets.

@export var id: String = ""
@export var display_name: String = ""
@export var price: int = 0
@export var unlock: String = ""
@export var sort_order: int = 0
@export var icon_path: String = ""
@export var visual_scene_path: String = ""
@export var menu_scene_path: String = ""
@export var use_tint: bool = false
@export var hue_center: float = 115.0
@export var hue_half_width: float = 35.0
@export var softness: float = 15.0
@export var sat_gate: float = 0.35
@export var hue_target: float = 0.0
@export var hue_spread: float = 1.0
@export var sat_mul: float = 1.0
@export var val_mul: float = 1.0
