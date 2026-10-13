extends RefCounted

## Creates independent body tint materials; Classic uses the original material-free path.

const SHADER := preload("res://assets/shaders/dragon_skin.gdshader")
const UNIFORMS := [
	"hue_center", "hue_half_width", "softness", "sat_gate",
	"hue_target", "hue_spread", "sat_mul", "val_mul",
]


static func make_material(skin: Resource) -> ShaderMaterial:
	if skin == null or not skin.get("use_tint"):
		return null
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for uniform in UNIFORMS:
		material.set_shader_parameter(uniform, skin.get(uniform))
	return material


static func apply_to(item: CanvasItem, skin: Resource) -> void:
	item.material = make_material(skin)
