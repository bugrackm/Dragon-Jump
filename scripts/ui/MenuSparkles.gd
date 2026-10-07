extends Node2D

## Chunky outlined rays and four small stars, drawn without texture assets.
var _elapsed := 0.0
var _reveal := 1.0
var _rng := RandomNumberGenerator.new()
var _stars: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	for index in 4:
		_stars.append({"phase": index * 0.55, "position": _star_position()})


func _star_position() -> Vector2:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	if _rng.randf() < 0.5:
		return Vector2(_rng.randf_range(-365.0, 365.0), _rng.randf_range(-256.0, -248.0))
	return Vector2(side * _rng.randf_range(420.0, 442.0), _rng.randf_range(110.0, 200.0))


func reveal() -> void:
	visible = true
	_reveal = 0.0


func advance(delta: float) -> void:
	_elapsed += delta
	_reveal = minf(1.0, _reveal + delta / 0.25)
	for star in _stars:
		star.phase += delta
		if star.phase >= 2.2:
			star.phase = fposmod(star.phase, 2.2)
			star.position = _star_position()
	queue_redraw()


func _draw() -> void:
	var pop := sin(_reveal * PI * 0.5)
	if pop < 0.01:
		return
	for side in [-1.0, 1.0]:
		for index in 2:
			var twinkle := (1.0 + 0.15 * sin(_elapsed * TAU / 1.2 + index * 1.4 + side)) * pop
			var origin := Vector2(side * 382.0, 75.0 + index * 53.0)
			var direction := Vector2(side * 60.0, -40.0 if index == 0 else 22.0)
			var normal := direction.normalized().orthogonal() * 12.0
			var points := PackedVector2Array([origin - normal, origin + direction, origin + normal, origin - direction * 0.08])
			for point in points.size():
				points[point] = origin + (points[point] - origin) * twinkle
			_polygon(points, Color("ffd23f"))
	for star in _stars:
		var alpha := pow(maxf(0.0, sin(star.phase / 2.2 * PI)), 2.0) * pop
		if alpha < 0.01:
			continue
		var radius := 15.0 * alpha
		var points := PackedVector2Array()
		for index in 8:
			var angle := index * TAU / 8.0
			points.append(star.position + Vector2(sin(angle), cos(angle)) * radius * (1.0 if index % 2 == 0 else 0.28))
		_polygon(points, Color(1.0, 0.88, 0.36, alpha))


func _polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.88, 0.48, 0.08, color.a), 3.0, true)
