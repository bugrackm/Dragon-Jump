extends RefCounted

## Lists skin definitions in shop order, with Classic as the fallback.

const DEFAULT_ID := "classic"
const SKINS := [
	preload("res://data/skins/classic.tres"),
	preload("res://data/skins/ember.tres"),
	preload("res://data/skins/frost.tres"),
	preload("res://data/skins/amethyst.tres"),
	preload("res://data/skins/sunburst.tres"),
	preload("res://data/skins/obsidian.tres"),
]


static func get_all() -> Array:
	return SKINS.duplicate()


static func has_skin(id: String) -> bool:
	for skin in SKINS:
		if skin.id == id:
			return true
	return false


static func get_skin(id: String) -> Resource:
	for skin in SKINS:
		if skin.id == id:
			return skin
	return SKINS[0]


static func get_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for skin in SKINS:
		ids.append(skin.id)
	return ids
