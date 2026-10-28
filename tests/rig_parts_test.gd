extends SceneTree

const DATA_PATH := "res://assets/dragon_rig/classic/parts.json"
const EXPECTED_PARENTS := {
	"body": "",
	"head": "body",
	"jaw": "head",
	"wing_big": "body",
	"wing_small": "body",
	"arm_front": "body",
	"arm_back": "body",
	"leg_front": "body",
	"leg_back": "body",
	"tail": "body",
}
const EXPECTED_Z := {
	"wing_small": 0,
	"wing_big": 1,
	"tail": 2,
	"leg_back": 3,
	"arm_back": 4,
	"body": 5,
	"jaw": 6,
	"head": 7,
	"leg_front": 8,
	"arm_front": 9,
}

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + description)


func _load_data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	_expect(file != null, "parts.json opens")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "parts.json parses as a dictionary")
	return parsed as Dictionary if parsed is Dictionary else {}


func _build_part(name: String, data: Dictionary, atlas: Texture2D, nodes: Dictionary) -> Node2D:
	if nodes.has(name):
		return nodes[name]
	var part: Dictionary = data.parts[name]
	var node := Node2D.new()
	node.name = name
	nodes[name] = node
	var parent_name: String = part.parent
	if not parent_name.is_empty():
		var parent := _build_part(parent_name, data, atlas, nodes)
		parent.add_child(node)
		node.position = Vector2(float(part.offset[0]), float(part.offset[1]))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = atlas
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		float(part.region[0]), float(part.region[1]),
		float(part.region[2]), float(part.region[3])
	)
	sprite.centered = false
	sprite.offset = -Vector2(float(part.pivot[0]), float(part.pivot[1]))
	sprite.z_index = int(part.z)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.add_child(sprite)
	return node


func _global_pivots(data: Dictionary) -> Dictionary:
	var result: Dictionary = {data.root: Vector2i.ZERO}
	while result.size() < data.parts.size():
		for name: String in data.parts:
			if result.has(name):
				continue
			var part: Dictionary = data.parts[name]
			if result.has(part.parent):
				result[name] = result[part.parent] + Vector2i(int(part.offset[0]), int(part.offset[1]))
	return result


func _jaw_coverage(data: Dictionary, atlas: Texture2D) -> float:
	var image := atlas.get_image()
	var pivots := _global_pivots(data)
	var jaw: Dictionary = data.parts.jaw
	var head: Dictionary = data.parts.head
	var jaw_place: Vector2i = pivots.jaw - Vector2i(int(jaw.pivot[0]), int(jaw.pivot[1]))
	var head_place: Vector2i = pivots.head - Vector2i(int(head.pivot[0]), int(head.pivot[1]))
	var opaque := 0
	var covered := 0
	for y in range(int(jaw.region[3])):
		for x in range(int(jaw.region[2])):
			if image.get_pixel(int(jaw.region[0]) + x, int(jaw.region[1]) + y).a < 0.25:
				continue
			opaque += 1
			var head_local := Vector2i(x, y) + jaw_place - head_place
			if head_local.x < 0 or head_local.y < 0 or head_local.x >= int(head.region[2]) or head_local.y >= int(head.region[3]):
				continue
			if image.get_pixel(int(head.region[0]) + head_local.x, int(head.region[1]) + head_local.y).a >= 0.25:
				covered += 1
	return float(covered) / float(opaque) if opaque > 0 else 0.0


func _run() -> void:
	var data := _load_data()
	if data.is_empty():
		print("rig_parts_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
		quit(1)
		return
	for key in ["version", "skin", "atlas", "texture_scale", "root", "parts", "anchors"]:
		_expect(data.has(key), "schema key " + key)
	_expect(data.version == 1, "schema version")
	_expect(data.skin == "classic", "classic skin")
	_expect(data.root == "body", "body root")
	_expect(float(data.texture_scale) > 0.0, "positive texture scale")
	_expect(data.parts.size() == 10, "ten parts")
	_expect(data.anchors.has("mouth") and data.anchors.has("feet"), "anchor keys")
	var atlas := load("res://assets/dragon_rig/classic/" + String(data.atlas)) as Texture2D
	_expect(atlas != null, "atlas loads")
	if atlas == null:
		print("rig_parts_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
		quit(1)
		return
	var z_values: Array[int] = []
	for name: String in EXPECTED_PARENTS:
		_expect(data.parts.has(name), "part " + name)
		if not data.parts.has(name):
			continue
		var part: Dictionary = data.parts[name]
		_expect(part.parent == EXPECTED_PARENTS[name], "parent " + name)
		_expect(part.has("region") and part.has("pivot") and part.has("offset") and part.has("z"), "part schema " + name)
		var region: Array = part.region
		_expect(region.size() == 4, "region shape " + name)
		if region.size() == 4:
			_expect(float(region[0]) >= 0.0 and float(region[1]) >= 0.0, "region origin " + name)
			_expect(float(region[0]) + float(region[2]) <= atlas.get_width(), "region width " + name)
			_expect(float(region[1]) + float(region[3]) <= atlas.get_height(), "region height " + name)
			var pivot: Array = part.pivot
			_expect(
				pivot.size() == 2
				and float(pivot[0]) >= -4.0 and float(pivot[0]) <= float(region[2]) + 4.0
				and float(pivot[1]) >= -4.0 and float(pivot[1]) <= float(region[3]) + 4.0,
				"pivot near alpha bounds " + name
			)
		_expect(int(part.z) == int(EXPECTED_Z[name]), "ORA z order " + name)
		z_values.append(int(part.z))
	z_values.sort()
	_expect(z_values == range(10), "unique z values 0 through 9")
	_expect(int(data.parts.jaw.z) < int(data.parts.head.z), "jaw renders behind head")
	_expect(_jaw_coverage(data, atlas) >= 0.98, "jaw is at least 98% covered by head at rest")
	var nodes: Dictionary = {}
	for name: String in data.parts:
		_build_part(name, data, atlas, nodes)
	var rig: Node2D = nodes[data.root]
	root.add_child(rig)
	var sprites := rig.find_children("*", "Sprite2D", true, false)
	_expect(sprites.size() == 10, "built rig has ten Sprite2Ds")
	for name: String in EXPECTED_PARENTS:
		var parent_name: String = EXPECTED_PARENTS[name]
		if parent_name.is_empty():
			_expect(nodes[name] == rig, "root node is body")
		else:
			_expect(nodes[name].get_parent() == nodes[parent_name], "built parent " + name)
	rig.free()
	print("rig_parts_checks=%d passed=%d failed=%d" % [_checks, _checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)
