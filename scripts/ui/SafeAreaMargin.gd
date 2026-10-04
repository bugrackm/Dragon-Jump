extends Control

## Insets an anchored control while preserving its original design offsets.
## Works on existing containers so their children and node paths stay intact.
##
## A control's design gap to the screen edge (a MarginContainer's own margins,
## or the edge_gap passed in) already keeps it off the edge. Under a cutout the
## control sits SAFE_PADDING below the cutout, or at its design gap when that
## is larger, never at cutout + design gap.
const SAFE_PADDING := 12.0

var _base_offsets: Vector4
var _edge_gap := Vector4.ZERO


func _ready() -> void:
	_base_offsets = Vector4(offset_left, offset_top, offset_right, offset_bottom)
	if is_class("MarginContainer"):
		_edge_gap = Vector4(get_theme_constant("margin_left"), get_theme_constant("margin_top"),
			get_theme_constant("margin_right"), get_theme_constant("margin_bottom"))
	ScreenLayout.layout_changed.connect(_apply_layout)
	_apply_layout()


func _apply_layout() -> void:
	apply_safe_offsets(self, _base_offsets, _edge_gap)


static func apply_safe_offsets(control: Control, base: Vector4, edge_gap := Vector4.ZERO) -> void:
	var inset := effective_insets(ScreenLayout.safe_insets, edge_gap)
	control.offset_left = base.x + lerpf(inset.x, -inset.z, control.anchor_left)
	control.offset_top = base.y + lerpf(inset.y, -inset.w, control.anchor_top)
	control.offset_right = base.z + lerpf(inset.x, -inset.z, control.anchor_right)
	control.offset_bottom = base.w + lerpf(inset.y, -inset.w, control.anchor_bottom)


## Extra offset per side (left, top, right, bottom) on top of the design gap.
static func effective_insets(inset: Vector4, edge_gap: Vector4) -> Vector4:
	return Vector4(_side(inset.x, edge_gap.x), _side(inset.y, edge_gap.y),
		_side(inset.z, edge_gap.z), _side(inset.w, edge_gap.w))


static func _side(inset: float, gap: float) -> float:
	if inset <= 0.0 or gap <= 0.0:
		return inset
	return maxf(0.0, inset + SAFE_PADDING - gap)
