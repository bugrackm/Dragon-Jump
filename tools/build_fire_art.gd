extends SceneTree

## Deterministic supersampled orange leaf with an inset golden core.
const OUTPUT := "res://assets/sprites/particles/ember_flake.png"
const SIZE := Vector2i(48, 72)
const SAMPLES := 4


func _initialize() -> void:
	var image := Image.create(SIZE.x * SAMPLES, SIZE.y * SAMPLES, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in image.get_height():
		for x in image.get_width():
			var p := Vector2(x + 0.5, y + 0.5) / float(SAMPLES)
			var h := (p.y - 5.0) / 62.0
			if h <= 0.0 or h >= 1.0:
				continue
			var center := 24.0 + 12.0 * pow(1.0 - h, 3.0) - 8.0 * h * h
			var width := 18.0 * pow(sin(PI * h), 0.70)
			if absf(p.x - center) > width:
				continue
			var color := Color("ff7608")
			var inner_h := (h - 0.30) / 0.54
			if inner_h > 0.0 and inner_h < 1.0:
				var inner_width := 6.5 * pow(sin(PI * inner_h), 0.8)
				if absf(p.x - center + 1.0) < inner_width:
					color = Color("ffe84f")
			image.set_pixel(x, y, color)
	image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(OUTPUT)
	if error != OK:
		push_error("Fire art save failed: %s" % error_string(error))
		quit(1)
		return
	print("fire_art_generated=1 path=%s" % OUTPUT)
	quit()
