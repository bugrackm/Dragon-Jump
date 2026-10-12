extends SceneTree

const SkinCatalog := preload("res://scripts/cosmetics/SkinCatalog.gd")
const SkinDef := preload("res://scripts/cosmetics/SkinDef.gd")
const PROFILE_PATH := "user://profile.cfg"

var _checks := 0
var _failures := 0
var _profile_backup := PackedByteArray()
var _profile_existed := false


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	_backup_profile()
	_check_catalog()
	_check_fresh_profile()
	_check_migrations()
	_check_future_profile()
	_check_cosmetics_loading()
	_check_purchase_and_equip()
	_restore_profile()
	print("cosmetics_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


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


func _fixture(version: int) -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("profile", "schema_version", version)
	config.set_value("profile", "high_score", 1234)
	config.set_value("economy", "total_coins", 3000)
	config.set_value("settings", "sound_enabled", false)
	config.set_value("settings", "music_enabled", false)
	config.set_value("settings", "sfx_volume", 0.25)
	config.set_value("settings", "music_volume", 0.75)
	config.set_value("abilities", "double_jump_unlocked", false)
	config.set_value("abilities", "glide_unlocked", false)
	config.set_value("abilities", "fire_breath_level", 1)
	if version >= 5:
		config.set_value("cosmetics", "owned_skins", PackedStringArray(["classic"]))
		config.set_value("cosmetics", "equipped_skin", "classic")
	return config


func _save_fixture(config: ConfigFile) -> void:
	_expect(config.save(PROFILE_PATH) == OK, "fixture saved")


func _read_profile() -> ConfigFile:
	var config := ConfigFile.new()
	_expect(config.load(PROFILE_PATH) == OK, "saved profile readable")
	return config


func _expect_defaults(store: ProfileStore, description: String) -> void:
	_expect(store.get_owned_skins() == PackedStringArray(["classic"]), description + " ownership")
	_expect(store.get_equipped_skin_id() == "classic", description + " equipped")


func _check_catalog() -> void:
	var expected_ids := PackedStringArray(["classic", "ember", "frost", "amethyst", "sunburst", "obsidian"])
	var prices := [0, 500, 500, 750, 1500, 2000]
	var hues := [0.0, 8.0, 195.0, 275.0, 45.0, 230.0]
	var types := {
		"id": TYPE_STRING, "display_name": TYPE_STRING, "price": TYPE_INT,
		"unlock": TYPE_STRING, "sort_order": TYPE_INT, "icon_path": TYPE_STRING,
		"visual_scene_path": TYPE_STRING, "menu_scene_path": TYPE_STRING,
		"use_tint": TYPE_BOOL, "hue_center": TYPE_FLOAT, "hue_half_width": TYPE_FLOAT,
		"softness": TYPE_FLOAT, "sat_gate": TYPE_FLOAT, "hue_target": TYPE_FLOAT,
		"sat_mul": TYPE_FLOAT, "val_mul": TYPE_FLOAT,
	}
	var skins := SkinCatalog.get_all()
	_expect(skins.size() == 6, "six skins")
	_expect(SkinCatalog.DEFAULT_ID == "classic", "classic is default")
	_expect(SkinCatalog.get_ids() == expected_ids, "ids in shop order")
	var seen := PackedStringArray()
	var last_order := -1
	for index in skins.size():
		var skin: Resource = skins[index]
		_expect(skin.get_script() == SkinDef, "skin uses SkinDef")
		_expect(not seen.has(skin.id), "unique id " + skin.id)
		seen.append(skin.id)
		_expect(skin.sort_order >= last_order, "sorted skin " + skin.id)
		last_order = skin.sort_order
		_expect(SkinCatalog.has_skin(skin.id), "catalog recognizes " + skin.id)
		_expect(SkinCatalog.get_skin(skin.id) == skin, "lookup returns matching definition")
		for field in types:
			_expect(typeof(skin.get(field)) == types[field], skin.id + " type of " + field)
		_expect(skin.id == expected_ids[index], "expected skin id")
		_expect(skin.display_name == String(expected_ids[index]).capitalize(), "display name")
		_expect(skin.price == prices[index], "exact price")
		_expect(skin.unlock == ("default" if index == 0 else "coins"), "unlock method")
		_expect(skin.use_tint == (index != 0), "tint enabled only on shop skins")
		_expect(index == 0 or skin.price > 0, "shop price is positive")
		_expect(is_equal_approx(skin.hue_target, hues[index]), "target hue")
		_expect(is_equal_approx(skin.hue_center, 112.0), "default hue center")
		_expect(is_equal_approx(skin.hue_half_width, 40.0), "default hue half width")
		_expect(is_equal_approx(skin.softness, 12.0), "default softness")
		_expect(is_equal_approx(skin.sat_gate, 0.35), "default saturation gate")
		var expected_sat := 0.35 if skin.id == "obsidian" else (1.1 if skin.id == "sunburst" else 1.0)
		var expected_val := 0.45 if skin.id == "obsidian" else (1.1 if skin.id == "sunburst" else 1.0)
		_expect(is_equal_approx(skin.sat_mul, expected_sat), "saturation multiplier")
		_expect(is_equal_approx(skin.val_mul, expected_val), "value multiplier")
		_expect(skin.icon_path == "" and skin.visual_scene_path == "" and skin.menu_scene_path == "", "optional paths empty")
	_expect(not SkinCatalog.has_skin("nope"), "unknown id not in catalog")
	_expect(SkinCatalog.get_skin("nope") == skins[0], "unknown lookup returns classic")
	skins.clear()
	_expect(SkinCatalog.get_all().size() == 6, "returned array cannot remove catalog entries")


func _check_fresh_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var store: ProfileStore = ProfileStore.new()
	store.load_profile()
	_expect_defaults(store, "fresh profile")
	_expect(store.schema_version == 5, "fresh schema 5")
	_expect(not store.double_jump_unlocked and not store.glide_unlocked, "fresh abilities locked")
	var config := _read_profile()
	_expect(config.get_value("profile", "schema_version") == 5, "fresh schema saved")
	_expect(config.has_section("cosmetics"), "fresh cosmetics section saved")
	_expect(config.get_value("cosmetics", "owned_skins") == PackedStringArray(["classic"]), "fresh ownership saved")
	_expect(config.get_value("cosmetics", "equipped_skin") == "classic", "fresh equipment saved")
	var copy := store.get_owned_skins()
	copy.append("ember")
	copy[0] = "frost"
	_expect_defaults(store, "ownership getter returns a copy")
	store.total_coins = 500
	_expect(store.purchase_skin("ember") and store.equip_skin("ember"), "prepare reset")
	store._reset_to_defaults()
	_expect_defaults(store, "reset cosmetics")
	store.free()


func _check_migrations() -> void:
	for version in [1, 2, 3, 4]:
		var config := _fixture(version)
		config.set_value("cosmetics", "owned_skins", PackedStringArray(["classic", "ember"]))
		config.set_value("cosmetics", "equipped_skin", "ember")
		_save_fixture(config)
		var store: ProfileStore = ProfileStore.new()
		store.load_profile()
		var label := "v%d migration" % version
		_expect(store.double_jump_unlocked == (version < 4), label + " double jump")
		_expect(store.glide_unlocked == (version < 4), label + " glide")
		_expect(store.fire_breath_level == 1, label + " fire level")
		_expect(store.high_score == 1234, label + " score preserved")
		_expect(store.total_coins == (0 if version == 1 else 3000), label + " coin rules preserved")
		_expect(store.sound_enabled == (version < 3), label + " sound rules preserved")
		_expect(store.music_enabled == (version < 3), label + " music rules preserved")
		_expect(is_equal_approx(store.sfx_volume, 0.25), label + " sfx volume preserved")
		_expect(is_equal_approx(store.music_volume, 0.75), label + " music volume preserved")
		_expect_defaults(store, label)
		var saved := _read_profile()
		_expect(saved.get_value("profile", "schema_version") == 5, label + " resaved as 5")
		_expect(saved.get_value("abilities", "double_jump_unlocked") == (version < 4), label + " ability persisted")
		_expect(saved.get_value("cosmetics", "owned_skins") == PackedStringArray(["classic"]), label + " cosmetics persisted")
		store.free()
	var unlocked := _fixture(4)
	unlocked.set_value("abilities", "double_jump_unlocked", true)
	unlocked.set_value("abilities", "glide_unlocked", true)
	unlocked.set_value("abilities", "fire_breath_level", 3)
	_save_fixture(unlocked)
	var store: ProfileStore = ProfileStore.new()
	store.load_profile()
	_expect(store.double_jump_unlocked and store.glide_unlocked, "v4 unlocked abilities retained")
	_expect(store.fire_breath_level == 3, "v4 upgraded fire retained")
	_expect_defaults(store, "unlocked v4")
	store.free()


func _check_future_profile() -> void:
	var config := _fixture(6)
	config.set_value("cosmetics", "owned_skins", ["ember", "future_skin", 12, "ember"])
	config.set_value("cosmetics", "equipped_skin", "future_skin")
	config.set_value("future_section", "future_key", "untouched")
	_save_fixture(config)
	var before := FileAccess.get_file_as_bytes(PROFILE_PATH)
	var store: ProfileStore = ProfileStore.new()
	store.load_profile()
	_expect(store.schema_version == 6, "future schema retained")
	_expect(store.high_score == 1234 and store.total_coins == 3000, "future score and wallet loaded")
	_expect(not store.double_jump_unlocked and not store.glide_unlocked and store.fire_breath_level == 1, "future abilities not granted")
	_expect(store.is_skin_owned("future_skin"), "future ownership retained in memory")
	_expect(store.get_equipped_skin_id() == "classic", "future invalid equipment safe in memory")
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "future file unchanged after load despite corrections")
	_expect(not store.save_profile(), "future save refused")
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "future file unchanged after save refusal")
	store.free()


func _check_cosmetics_loading() -> void:
	var cases := [
		[17, "classic", ["classic"], "classic"],
		[["ember", 42, true, "ember", "retired"], "ember", ["ember", "retired", "classic"], "ember"],
		[["classic", "classic", "ember"], "ember", ["classic", "ember"], "ember"],
		[PackedStringArray(["ember"]), "ember", ["ember", "classic"], "ember"],
		[["classic", "retired"], "retired", ["classic", "retired"], "classic"],
		[["classic"], "ember", ["classic"], "classic"],
		[["classic", "ember"], 123, ["classic", "ember"], "classic"],
		[[], "nope", ["classic"], "classic"],
		["ember", "ember", ["classic"], "classic"],
	]
	for index in cases.size():
		var test_case: Array = cases[index]
		var config := _fixture(5)
		config.set_value("cosmetics", "owned_skins", test_case[0])
		config.set_value("cosmetics", "equipped_skin", test_case[1])
		_save_fixture(config)
		var store: ProfileStore = ProfileStore.new()
		store.load_profile()
		var expected := PackedStringArray(test_case[2])
		var label := "corrupt case %d" % index
		_expect(store.get_owned_skins() == expected, label + " ownership corrected")
		_expect(store.get_equipped_skin_id() == test_case[3], label + " equipment corrected")
		var saved := _read_profile()
		_expect(typeof(saved.get_value("cosmetics", "owned_skins")) == TYPE_PACKED_STRING_ARRAY, label + " saved packed array")
		_expect(saved.get_value("cosmetics", "owned_skins") == expected, label + " ownership resaved")
		_expect(saved.get_value("cosmetics", "equipped_skin") == test_case[3], label + " equipment resaved")
		store.load_profile()
		_expect(store.get_owned_skins() == expected, label + " correction stable on reload")
		store.free()
	for missing_key in ["owned_skins", "equipped_skin"]:
		var config := _fixture(5)
		config.erase_section_key("cosmetics", missing_key)
		_save_fixture(config)
		var store: ProfileStore = ProfileStore.new()
		store.load_profile()
		_expect_defaults(store, "missing " + missing_key)
		_expect(_read_profile().has_section_key("cosmetics", missing_key), "missing key resaved")
		store.free()
	for owned in [["classic", "ember", "retired"], PackedStringArray(["classic", "ember", "retired"])]:
		var config := _fixture(5)
		config.set_value("cosmetics", "owned_skins", owned)
		config.set_value("cosmetics", "equipped_skin", "ember")
		_save_fixture(config)
		var before := FileAccess.get_file_as_bytes(PROFILE_PATH)
		var store: ProfileStore = ProfileStore.new()
		store.load_profile()
		_expect(store.get_owned_skins() == PackedStringArray(owned), "valid v5 ownership retained including unknown id")
		_expect(store.get_equipped_skin_id() == "ember", "valid v5 equipment retained")
		_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "valid v5 not rewritten")
		_expect(not store.equip_skin("retired"), "owned unknown id cannot be equipped")
		_expect(not store.purchase_skin("retired"), "owned unknown id cannot be purchased")
		_expect(store.save_profile(), "valid v5 can save")
		store.load_profile()
		_expect(store.is_skin_owned("retired"), "unknown ownership survives explicit save and reload")
		store.free()


func _check_purchase_and_equip() -> void:
	var config := _fixture(5)
	config.set_value("economy", "total_coins", 499)
	_save_fixture(config)
	var store: ProfileStore = ProfileStore.new()
	store.load_profile()
	var coin_events: Array[int] = []
	var purchase_events: Array[String] = []
	var equip_events: Array[String] = []
	store.coins_changed.connect(func(value: int) -> void: coin_events.append(value))
	store.skin_purchased.connect(func(id: String) -> void: purchase_events.append(id))
	store.skin_equipped.connect(func(id: String) -> void: equip_events.append(id))
	var before := FileAccess.get_file_as_bytes(PROFILE_PATH)
	_expect(not store.purchase_skin("ember"), "insufficient coins rejects purchase")
	_expect(store.total_coins == 499, "insufficient purchase retains coins")
	_expect_defaults(store, "insufficient purchase")
	_expect(not store.purchase_skin("nope"), "unknown purchase rejected")
	_expect(not store.purchase_skin("classic"), "classic purchase rejected")
	_expect(not store.equip_skin("ember"), "unowned equip rejected")
	_expect(not store.equip_skin("nope"), "unknown equip rejected")
	_expect(coin_events.is_empty() and purchase_events.is_empty() and equip_events.is_empty(), "rejected actions emit no signals")
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "rejected actions leave file unchanged")

	store.total_coins = 1000
	var frost: Resource = SkinCatalog.get_skin("frost")
	var old_unlock: String = frost.unlock
	frost.unlock = "event"
	var reserved_result := store.purchase_skin("frost")
	frost.unlock = old_unlock
	_expect(not reserved_result and not store.is_skin_owned("frost") and store.total_coins == 1000, "reserved unlock cannot be purchased")
	_expect(store.purchase_skin("ember"), "purchase succeeds")
	_expect(store.total_coins == 500, "purchase deducts exact price")
	_expect(store.get_owned_skins() == PackedStringArray(["classic", "ember"]), "purchase adds ownership")
	_expect(store.get_equipped_skin_id() == "classic", "purchase does not equip")
	_expect(coin_events == [500], "purchase emits coins once with balance")
	_expect(purchase_events == ["ember"], "purchase emits skin once with id")
	_expect(equip_events.is_empty(), "purchase emits no equip signal")
	var reloaded: ProfileStore = ProfileStore.new()
	reloaded.load_profile()
	_expect(reloaded.total_coins == 500 and reloaded.is_skin_owned("ember"), "purchase persisted after reload")
	_expect(reloaded.get_equipped_skin_id() == "classic", "purchase persisted without equip")
	before = FileAccess.get_file_as_bytes(PROFILE_PATH)
	_expect(not store.purchase_skin("ember"), "duplicate purchase rejected")
	_expect(store.total_coins == 500 and store.get_owned_skins().size() == 2, "duplicate purchase changes nothing")
	_expect(coin_events == [500] and purchase_events == ["ember"], "duplicate emits no signals")
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "duplicate leaves file unchanged")

	store.schema_version = ProfileStore.CURRENT_SCHEMA_VERSION + 1
	_expect(not store.purchase_skin("frost"), "failed save rejects purchase")
	_expect(store.total_coins == 500, "failed purchase rolls back wallet")
	_expect(store.get_owned_skins() == PackedStringArray(["classic", "ember"]), "failed purchase rolls back ownership")
	_expect(coin_events == [500] and purchase_events == ["ember"], "failed purchase emits no signals")
	_expect(not store.equip_skin("ember"), "failed save rejects equip")
	_expect(store.get_equipped_skin_id() == "classic", "failed equip rolls back equipment")
	_expect(equip_events.is_empty(), "failed equip emits no signals")
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "failed saves leave file unchanged")
	_expect(store.equip_skin("classic"), "current equip succeeds even when saving would fail")
	_expect(equip_events.is_empty(), "current equip emits no signals")
	store.schema_version = ProfileStore.CURRENT_SCHEMA_VERSION

	_expect(store.equip_skin("ember"), "owned equip succeeds")
	_expect(store.get_equipped_skin_id() == "ember", "equipment changes")
	_expect(equip_events == ["ember"], "equip emits once with id")
	_expect(coin_events == [500] and purchase_events == ["ember"], "equip does not emit purchase or coin signals")
	reloaded.load_profile()
	_expect(reloaded.get_equipped_skin_id() == "ember", "equipment persisted after reload")
	before = FileAccess.get_file_as_bytes(PROFILE_PATH)
	store.schema_version = ProfileStore.CURRENT_SCHEMA_VERSION + 1
	_expect(store.equip_skin("ember"), "equipping current skin succeeds without saving")
	_expect(equip_events == ["ember"], "repeated equip emits nothing")
	_expect(FileAccess.get_file_as_bytes(PROFILE_PATH) == before, "repeated equip leaves file unchanged")
	store.schema_version = ProfileStore.CURRENT_SCHEMA_VERSION
	_expect(store.equip_skin("classic"), "can equip classic again")
	_expect(store.purchase_skin("frost"), "purchase with exact balance succeeds")
	_expect(store.total_coins == 0, "exact balance purchase leaves zero")
	store.free()
	reloaded.free()
