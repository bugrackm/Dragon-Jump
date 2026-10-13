extends CanvasLayer

const SkinCatalog := preload("res://scripts/cosmetics/SkinCatalog.gd")
const SkinMaterial := preload("res://scripts/cosmetics/SkinMaterial.gd")
const SkinRow := preload("res://scenes/ui/SkinRow.tscn")
const UiFx := preload("res://scripts/ui/UiFx.gd")

signal back_requested
signal purchase_made

@onready var coin_label: Label = $%Card/Content/CoinRow/CoinLabel
@onready var double_jump_price_label: Label = $%Card/Content/Pages/AbilitiesPage/DoubleJumpRow/HBox/PriceLabel
@onready var double_jump_button: Button = $%Card/Content/Pages/AbilitiesPage/DoubleJumpRow/HBox/BuyButton
@onready var glide_price_label: Label = $%Card/Content/Pages/AbilitiesPage/GlideRow/HBox/PriceLabel
@onready var glide_button: Button = $%Card/Content/Pages/AbilitiesPage/GlideRow/HBox/BuyButton
@onready var fire_name_label: Label = $%Card/Content/Pages/AbilitiesPage/FireUpgradeRow/HBox/Label
@onready var fire_price_label: Label = $%Card/Content/Pages/AbilitiesPage/FireUpgradeRow/HBox/PriceLabel
@onready var fire_button: Button = $%Card/Content/Pages/AbilitiesPage/FireUpgradeRow/HBox/BuyButton
@onready var back_button: Button = $%Card/Content/BackButton

@onready var preview_stage: Control = %PreviewStage
@onready var preview_dragon: AnimatedSprite2D = %PreviewDragon
@onready var abilities_page: VBoxContainer = %AbilitiesPage
@onready var skins_page: Control = %SkinsPage
@onready var skin_scroll: ScrollContainer = %SkinScroll
@onready var skin_list: VBoxContainer = %SkinList

var _selected_skin_id := "classic"
var _skins_active := false
var _preview_time := 0.0
var _profile_store: Node
var _audio_manager: Node


func _ready() -> void:
	for skin in SkinCatalog.get_all():
		var row := SkinRow.instantiate()
		skin_list.add_child(row)
		row.configure(skin)
		row.selected.connect(_select_skin)
		row.action_requested.connect(_on_skin_action)
	UiFx.wire_press_fx(self)
	%AbilitiesTab.pressed.connect(_on_tab_pressed.bind(false))
	%SkinsTab.pressed.connect(_on_tab_pressed.bind(true))
	$CenterContainer.resized.connect(_update_layout)
	skin_list.minimum_size_changed.connect(_update_layout)
	visibility_changed.connect(_update_preview_activity)
	_update_layout.call_deferred()
	_update_preview_activity()
	double_jump_button.pressed.connect(_on_double_jump_pressed)
	glide_button.pressed.connect(_on_glide_pressed)
	fire_button.pressed.connect(_on_fire_upgrade_pressed)
	back_button.pressed.connect(_on_back_pressed)


func set_audio_manager(audio_manager: Node) -> void:
	_audio_manager = audio_manager


func open(profile_store: Node) -> void:
	_profile_store = profile_store
	_show_tab(false)
	skin_scroll.scroll_vertical = 0
	UiFx.open_screen(self)


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

	for row in skin_list.get_children():
		row.refresh(_profile_store, _selected_skin_id)
	_refresh_preview()


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


func _on_tab_pressed(skins: bool) -> void:
	_play_sfx(&"sfx_ui_click")
	_show_tab(skins)


func _show_tab(skins: bool) -> void:
	_skins_active = skins
	abilities_page.visible = not skins
	skins_page.visible = skins
	%AbilitiesTab.set_pressed_no_signal(not skins)
	%SkinsTab.set_pressed_no_signal(skins)
	if is_instance_valid(_profile_store):
		_selected_skin_id = _profile_store.get_equipped_skin_id()
	refresh()
	if skins:
		_reveal_selected.call_deferred()


func _reveal_selected() -> void:
	if not _skins_active:
		return
	for row in skin_list.get_children():
		if row.skin.id == _selected_skin_id:
			skin_scroll.ensure_control_visible(row)


func _select_skin(id: String) -> void:
	_selected_skin_id = id
	refresh()


func _on_skin_action(id: String) -> void:
	if not is_instance_valid(_profile_store) or skin_scroll.is_dragging():
		return
	_select_skin(id)
	if _profile_store.is_skin_owned(id):
		if _profile_store.get_equipped_skin_id() != id and _profile_store.equip_skin(id):
			refresh()
			_play_sfx(&"sfx_ui_click")
			purchase_made.emit()
	elif _profile_store.purchase_skin(id):
		_profile_store.equip_skin(id)
		refresh()
		_play_sfx(&"sfx_purchase")
		purchase_made.emit()


func _refresh_preview() -> void:
	var equipped: String = _profile_store.get_equipped_skin_id()
	var skin: Resource = SkinCatalog.get_skin(_selected_skin_id if _skins_active else equipped)
	SkinMaterial.apply_to(preview_dragon, skin)
	%PreviewNameLabel.text = skin.display_name
	%PreviewStatusLabel.text = "EQUIPPED" if skin.id == equipped else (
		"OWNED" if _profile_store.is_skin_owned(skin.id) else "%d coins" % skin.price)


## Both pages share a reserved height; only the scroll contents may exceed it.
func _update_layout() -> void:
	var available: float = $CenterContainer.size.y
	var stage_height := clampf(200.0 + (available - 1440.0) / 3.0, 200.0, 360.0)
	preview_stage.custom_minimum_size.y = stage_height
	var fixed_height: float = $CenterContainer/Stack.get_combined_minimum_size().y - %Pages.custom_minimum_size.y
	var page_height := clampf(available - fixed_height - 24.0,
		abilities_page.get_combined_minimum_size().y, skin_list.get_combined_minimum_size().y)
	%Pages.custom_minimum_size.y = page_height


func _update_preview_activity() -> void:
	set_process(visible)
	if visible:
		preview_dragon.set_facing(1)
		preview_dragon.play(&"idle")
	else:
		preview_dragon.pause()


func _process(delta: float) -> void:
	_preview_time += delta
	preview_dragon.position = preview_stage.size * 0.5 + Vector2(0, sin(_preview_time * 1.8) * 4.0)
	var dragon_scale := minf(1.7, (preview_stage.size.y - 16.0) / 176.0)
	preview_dragon.scale = Vector2.ONE * dragon_scale * (1.0 + sin(_preview_time * 1.8) * 0.012)
