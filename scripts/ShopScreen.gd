extends CanvasLayer

signal back_requested
signal purchase_made

@onready var coin_label: Label = $CenterContainer/VBoxContainer/CoinLabel
@onready var double_jump_price_label: Label = $CenterContainer/VBoxContainer/DoubleJumpRow/PriceLabel
@onready var double_jump_button: Button = $CenterContainer/VBoxContainer/DoubleJumpRow/BuyButton
@onready var glide_price_label: Label = $CenterContainer/VBoxContainer/GlideRow/PriceLabel
@onready var glide_button: Button = $CenterContainer/VBoxContainer/GlideRow/BuyButton
@onready var fire_name_label: Label = $CenterContainer/VBoxContainer/FireUpgradeRow/Label
@onready var fire_price_label: Label = $CenterContainer/VBoxContainer/FireUpgradeRow/PriceLabel
@onready var fire_button: Button = $CenterContainer/VBoxContainer/FireUpgradeRow/BuyButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

var _profile_store: Node
var _audio_manager: Node


func _ready() -> void:
	double_jump_button.pressed.connect(_on_double_jump_pressed)
	glide_button.pressed.connect(_on_glide_pressed)
	fire_button.pressed.connect(_on_fire_upgrade_pressed)
	back_button.pressed.connect(_on_back_pressed)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func open(profile_store: Node) -> void:
	_profile_store = profile_store
	refresh()
	visible = true


func refresh() -> void:
	if not is_instance_valid(_profile_store):
		return

	var coins := int(_profile_store.get("total_coins"))
	coin_label.text = "Coins: %d" % coins

	var double_jump_cost := int(_profile_store.call("get_double_jump_cost"))
	double_jump_price_label.text = str(double_jump_cost)
	var owns_double_jump := bool(_profile_store.call("is_double_jump_unlocked"))
	double_jump_button.text = "OWNED" if owns_double_jump else "BUY"
	double_jump_button.disabled = owns_double_jump or coins < double_jump_cost

	var glide_cost := int(_profile_store.call("get_glide_cost"))
	glide_price_label.text = str(glide_cost)
	var owns_glide := bool(_profile_store.call("is_glide_unlocked"))
	glide_button.text = "OWNED" if owns_glide else "BUY"
	glide_button.disabled = owns_glide or coins < glide_cost

	var fire_level := int(_profile_store.call("get_fire_breath_level"))
	var fire_upgrade_cost := int(_profile_store.call("get_next_fire_upgrade_cost"))
	if fire_upgrade_cost < 0:
		fire_name_label.text = "Fire Cooldown Lv.%d" % fire_level
		fire_price_label.text = "MAX"
		fire_button.text = "MAX"
		fire_button.disabled = true
	else:
		fire_name_label.text = "Fire Cooldown Lv.%d" % (fire_level + 1)
		fire_price_label.text = str(fire_upgrade_cost)
		fire_button.text = "BUY"
		fire_button.disabled = coins < fire_upgrade_cost


func _on_double_jump_pressed() -> void:
	_play_sfx(&"sfx_ui_click")
	if (
		is_instance_valid(_profile_store)
		and bool(_profile_store.call("unlock_double_jump"))
	):
		refresh()
		_play_sfx(&"sfx_purchase")
		purchase_made.emit()


func _on_glide_pressed() -> void:
	_play_sfx(&"sfx_ui_click")
	if (
		is_instance_valid(_profile_store)
		and bool(_profile_store.call("unlock_glide"))
	):
		refresh()
		_play_sfx(&"sfx_purchase")
		purchase_made.emit()


func _on_fire_upgrade_pressed() -> void:
	_play_sfx(&"sfx_ui_click")
	if (
		is_instance_valid(_profile_store)
		and bool(_profile_store.call("upgrade_fire_breath"))
	):
		refresh()
		_play_sfx(&"sfx_purchase")
		purchase_made.emit()


func _on_back_pressed() -> void:
	_play_sfx(&"sfx_ui_back")
	back_requested.emit()


func grab_focus_on_first_button() -> void:
	for button in [double_jump_button, glide_button, fire_button]:
		if not button.disabled:
			button.grab_focus()
			return
	back_button.grab_focus()


func _play_sfx(sound_name: StringName) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.call("play_sfx", sound_name)
