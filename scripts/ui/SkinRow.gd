extends PanelContainer

## A catalog row selects a preview independently of its purchase/equip action.
signal selected(id: String)
signal action_requested(id: String)

const SkinMaterial := preload("res://scripts/cosmetics/SkinMaterial.gd")

var skin: Resource
@onready var action_button: Button = $HBox/ActionButton


func _ready() -> void:
	action_button.pressed.connect(func() -> void: action_requested.emit(skin.id))


func configure(definition: Resource) -> void:
	skin = definition
	name = skin.id.capitalize() + "Row"
	$HBox/Label.text = skin.display_name
	$HBox/Icon.material = SkinMaterial.make_material(skin)


func refresh(profile: Node, selected_id: String) -> void:
	var owned: bool = profile.is_skin_owned(skin.id)
	var equipped: bool = profile.get_equipped_skin_id() == skin.id
	$HBox/PriceLabel.text = "" if owned else str(skin.price)
	action_button.text = "EQUIPPED" if equipped else ("EQUIP" if owned else "BUY")
	action_button.disabled = equipped or (not owned and profile.total_coins < skin.price)
	action_button.theme_type_variation = &"Button" if owned else &"AccentButton"
	theme_type_variation = &"ShopRowSelected" if selected_id == skin.id else &"ShopRow"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		selected.emit(skin.id)
