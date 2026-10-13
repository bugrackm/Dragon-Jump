extends SceneTree

const SkinCatalog := preload("res://scripts/cosmetics/SkinCatalog.gd")
const UiFx := preload("res://scripts/ui/UiFx.gd")
const PROFILE_PATH := "user://profile.cfg"

var _checks := 0
var _failures := 0
var _profile_backup := PackedByteArray()
var _profile_existed := false


class FailingProfile extends ProfileStore:
	var saves_remaining := 0

	func save_profile() -> bool:
		if saves_remaining == 0:
			return false
		saves_remaining -= 1
		return true


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _backup_profile() -> void:
	_profile_existed = FileAccess.file_exists(PROFILE_PATH)
	if _profile_existed:
		_profile_backup = FileAccess.get_file_as_bytes(PROFILE_PATH)


func _restore_profile() -> void:
	if _profile_existed:
		var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
		file.store_buffer(_profile_backup)
		file.close()
	elif FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))


func _settle() -> void:
	for frame in 6:
		await process_frame


func _run() -> void:
	_backup_profile()
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	root.size = Vector2i(1080, 1920)
	await _settle()
	var profile := ProfileStore.new()
	profile.total_coins = 1200
	var shop = load("res://scenes/ShopScreen.tscn").instantiate()
	root.add_child(shop)
	shop.open(profile)
	await create_timer(0.35).timeout
	await _settle()
	var purchases := [0]
	shop.purchase_made.connect(func() -> void: purchases[0] += 1)
	var rows: Array = shop.skin_list.get_children()
	var classic: Control = rows[0]
	var ember: Control = rows[1]
	var frost: Control = rows[2]
	_expect(rows.size() == 6, "six reusable rows")
	_expect(shop.get_node("%PreviewCard").size.x == 920 and shop.get_node("%Card").size.x == 920, "both cards 920 wide")
	_expect(shop.get_node("%PreviewCard").get_global_rect().end.y < shop.get_node("%Card").get_global_rect().position.y, "preview above shop")
	_expect(shop.get_node("%AbilitiesTab").button_group == shop.get_node("%SkinsTab").button_group, "shared tab group")
	_expect(shop.abilities_page.get_child_count() == 3, "three original ability rows")
	for row_name in ["DoubleJumpRow", "GlideRow", "FireUpgradeRow"]:
		_expect(shop.abilities_page.has_node(row_name + "/HBox/BuyButton"), "original row " + row_name)
	for index in rows.size():
		var skin: Resource = SkinCatalog.get_all()[index]
		var row: Control = rows[index]
		_expect(row.skin == skin, "catalog order " + skin.id)
		_expect(row.get_node("HBox/Label").text == skin.display_name, "skin name " + skin.id)
		_expect(row.get_node("HBox/PriceLabel").text == ("" if index == 0 else str(skin.price)), "skin price " + skin.id)
		_check_material(row.get_node("HBox/Icon"), skin.id)
		_expect(row.action_button.has_meta(&"ui_fx_wired"), "runtime press fx " + skin.id)
	_expect(shop.get_node("%AbilitiesTab").has_meta(&"ui_fx_wired"), "tab press fx")
	_expect(shop.abilities_page.visible and not shop.skins_page.visible, "open on abilities")
	_expect(shop.get_node("%AbilitiesTab").button_pressed, "abilities selected")
	_check_material(shop.preview_dragon, "classic")
	_expect(shop.preview_dragon.animation == &"idle" and shop.preview_dragon.is_playing(), "idle preview playing")
	_expect(not shop.preview_dragon.flip_h, "preview faces right")
	_expect(classic.action_button.text == "EQUIPPED" and classic.action_button.disabled, "classic equipped")
	profile.total_coins = 499
	shop.refresh()
	_expect(ember.action_button.text == "BUY" and ember.action_button.disabled, "unaffordable BUY")
	shop._on_skin_action("ember")
	_expect(profile.total_coins == 499 and not profile.is_skin_owned("ember") and purchases[0] == 0, "insufficient purchase does nothing")
	profile.total_coins = 1200
	shop.refresh()
	_expect(not ember.action_button.disabled, "affordable BUY")
	shop.grab_focus_on_first_button()
	_expect(shop.double_jump_button.has_focus(), "first ability focus preserved")
	var rects: Array[Rect2] = []
	for node in [shop.get_node("%PreviewCard"), shop.get_node("%TabRow"), shop.back_button]:
		rects.append(node.get_global_rect())
	shop.get_node("%SkinsTab").pressed.emit()
	await _settle()
	_expect(shop._selected_skin_id == "classic", "skins starts at equipped")
	var index := 0
	for node in [shop.get_node("%PreviewCard"), shop.get_node("%TabRow"), shop.back_button]:
		_expect(node.get_global_rect().is_equal_approx(rects[index]), "stable tab geometry %d" % index)
		index += 1
	await _click(ember.get_node("HBox/Label").get_global_rect().get_center())
	_expect(shop._selected_skin_id == "ember", "row body selects")
	_expect(ember.theme_type_variation == &"ShopRowSelected" and classic.theme_type_variation == &"ShopRow", "selection highlight")
	_check_material(shop.preview_dragon, "ember")
	_expect(profile.total_coins == 1200 and profile.get_owned_skins() == PackedStringArray(["classic"])
		and profile.get_equipped_skin_id() == "classic", "selection never changes profile")
	_expect(shop.get_node("%PreviewStatusLabel").text == "500 coins", "unowned preview price")
	await _click(ember.action_button.get_global_rect().get_center())
	_expect(profile.total_coins == 700 and profile.is_skin_owned("ember") and profile.get_equipped_skin_id() == "ember", "BUY owns and equips")
	_expect(purchases[0] == 1, "BUY emits once")
	_expect(shop.coin_label.text == "Coins: 700", "coin label refreshed")
	_expect(ember.action_button.text == "EQUIPPED" and ember.action_button.disabled, "purchased row refreshed")
	_expect(classic.action_button.text == "EQUIP" and not classic.action_button.disabled, "owned unequipped row")
	await _settle()
	await _click(classic.action_button.get_global_rect().get_center())
	_expect(profile.get_equipped_skin_id() == "classic" and purchases[0] == 2, "EQUIP emits once")
	shop._select_skin("frost")
	shop.get_node("%AbilitiesTab").pressed.emit()
	_check_material(shop.preview_dragon, "classic")
	_expect(shop.get_node("%PreviewNameLabel").text == "Classic", "abilities reverts to equipped")
	shop.double_jump_button.pressed.emit()
	_expect(profile.is_double_jump_unlocked() and profile.total_coins == 500, "ability purchase unchanged")
	_expect(shop.double_jump_button.text == "OWNED" and shop.double_jump_button.disabled and purchases[0] == 3, "ability refresh and signal")
	shop.grab_focus_on_first_button()
	_expect(shop.glide_button.has_focus(), "focus skips owned ability")
	profile.glide_unlocked = true
	profile.fire_breath_level = 3
	shop.refresh()
	shop.grab_focus_on_first_button()
	_expect(shop.back_button.has_focus(), "focus falls back to Back")
	_expect(shop.glide_button.text == "OWNED" and shop.fire_button.text == "MAX", "ability owned and MAX labels")
	_expect(shop.fire_button.disabled and shop.fire_price_label.text == "MAX", "MAX rules preserved")

	root.content_scale_size = Vector2i(1080, 1440)
	root.size = Vector2i(1080, 1440)
	shop._show_tab(true)
	await _settle()
	_expect(shop.skin_scroll.size.y >= 2.5 * frost.size.y, "short screen shows at least 2.5 rows")
	await _drag(shop, frost, false)
	await _drag(shop, frost, true)
	_expect(profile.total_coins == 500 and not profile.is_skin_owned("frost") and purchases[0] == 3, "drags never buy")
	shop.skin_scroll.scroll_vertical = 0
	await _settle()
	await _click(frost.action_button.get_global_rect().get_center())
	_expect(profile.is_skin_owned("frost") and profile.get_equipped_skin_id() == "frost", "tap after drag still buys")
	profile._owned_skins.append("obsidian")
	profile._equipped_skin = "obsidian"
	shop._show_tab(false)
	shop._show_tab(true)
	await _settle()
	_expect(shop.skin_scroll.get_global_rect().encloses(rows[5].get_global_rect()), "tab reveals equipped row")
	shop.open(profile)
	await create_timer(0.35).timeout
	_expect(not shop.skins_page.visible and shop.skin_scroll.scroll_vertical == 0, "reopen resets tab and scroll")
	_check_material(shop.preview_dragon, "obsidian")
	_expect(shop.skin_list.get_children() == rows, "rows reused after refresh and reopen")
	UiFx.hide_now(shop)
	var phase: float = shop._preview_time
	await _settle()
	_expect(not shop.is_processing() and shop._preview_time == phase and not shop.preview_dragon.is_playing(), "hidden preview stops")
	shop.open(profile)
	paused = true
	await _settle()
	_expect(shop._preview_time > phase and shop.preview_dragon.is_playing(), "preview runs while tree paused")
	paused = false
	_check_failed_saves(shop)
	shop.free()
	profile.free()
	await _integration()
	_restore_profile()
	print("shop_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _check_material(item: CanvasItem, id: String) -> void:
	if id == "classic":
		_expect(item.material == null, "classic material null")
	else:
		_expect(item.material is ShaderMaterial, id + " shader material")
		if item.material is ShaderMaterial:
			_expect(is_equal_approx(item.material.get_shader_parameter("hue_target"), SkinCatalog.get_skin(id).hue_target), id + " hue target")


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)


func _click(point: Vector2) -> void:
	_mouse(point, true)
	await process_frame
	_mouse(point, false)
	await _settle()


func _drag(shop: Node, row: Control, touch: bool) -> void:
	shop.skin_scroll.scroll_vertical = 0
	await _settle()
	var start: Vector2 = row.action_button.get_global_rect().get_center()
	var finish := start - Vector2(0, 150)
	if touch:
		var down := InputEventScreenTouch.new()
		down.position = start
		down.pressed = true
		root.push_input(down, true)
		# The viewport's push_input does not synthesize OS mouse emulation.
		_mouse(start, true)
		await process_frame
		var motion := InputEventScreenDrag.new()
		motion.position = finish
		motion.relative = finish - start
		root.push_input(motion, true)
		var up := InputEventScreenTouch.new()
		up.position = finish
		root.push_input(up, true)
		_mouse(finish, false)
	else:
		_mouse(start, true)
		await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position = finish
		motion.relative = finish - start
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		_mouse(finish, false)
	await _settle()
	_expect(shop.skin_scroll.scroll_vertical > 0, "list scrolled by " + ("touch" if touch else "mouse"))
	_expect(not row.action_button.disabled and row.action_button.text == "BUY", "drag cancels press and restores button")


func _check_failed_saves(shop: Node) -> void:
	var profile := FailingProfile.new()
	profile.total_coins = 1200
	shop.open(profile)
	shop._show_tab(true)
	var signals := [0]
	var count := func() -> void: signals[0] += 1
	shop.purchase_made.connect(count)
	shop._on_skin_action("ember")
	_expect(profile.total_coins == 1200 and not profile.is_skin_owned("ember") and signals[0] == 0, "failed purchase rolls back")
	profile.saves_remaining = 1
	shop._on_skin_action("ember")
	_expect(profile.total_coins == 700 and profile.is_skin_owned("ember") and profile.get_equipped_skin_id() == "classic", "purchase succeeds but equip failure preserves equipped")
	_expect(shop.skin_list.get_child(1).action_button.text == "EQUIP" and signals[0] == 1, "partial success re-reads row state")
	_expect(shop.get_node("%PreviewStatusLabel").text == "OWNED", "partial success preview owned")
	shop._on_skin_action("ember")
	_expect(profile.get_equipped_skin_id() == "classic" and signals[0] == 1, "failed EQUIP emits nothing")
	shop.purchase_made.disconnect(count)
	profile.free()


func _integration() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.audio_manager.stop_all_audio()
	main.profile_store._reset_to_defaults()
	main.profile_store.total_coins = 1200
	main.profile_store.sound_enabled = false
	main.profile_store.music_enabled = false
	main._skin_override = "obsidian"
	main._show_shop()
	var shop: Node = main._shop_screen
	shop._show_tab(true)
	shop._on_skin_action("ember")
	_expect(main._skin_override.is_empty(), "equip clears debug override")
	_expect(main.hud.get_node("MarginContainer/Rows/CoinRow/CoinLabel").text.contains("700"), "HUD coins updated")
	_expect(main._main_menu.find_child("MenuDragon", true, false).material == null, "menu dragon stays classic")
	main._hide_shop()
	main._start_game()
	_check_material(main._player.get_node("VisualRoot/Sprite"), "ember")
	main.audio_manager.stop_all_audio()
	main.free()
	paused = false
	await _settle()
