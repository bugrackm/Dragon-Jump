shader_type canvas_item;
render_mode unshaded;

uniform float u_time = 0.0;
uniform vec4 outer_color : source_color = vec4(1.0, 0.235, 0.012, 1.0);
uniform vec4 orange_color : source_color = vec4(1.0, 0.435, 0.016, 1.0);
uniform vec4 gold_color : source_color = vec4(1.0, 0.79, 0.075, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.965, 0.46, 1.0);

varying vec2 wall_position;

void vertex() {
	wall_position = VERTEX;
}

// Continuous curved sides join a rounded belly to a sideways tapered tip.
vec3 tongue(vec2 p, float cell, float spacing, float base, float height, float width, float phase) {
	float seed = fract(cell * 0.618034 + phase);
	float clock = u_time * 1.2 + cell * 2.4 + phase;
	float swell = sin(clock);
	float sway = sin(clock * 0.8 + 1.7);
	float peak = height * (0.83 + 0.17 * seed) + 4.0 * swell;
	float direction = mix(-1.0, 1.0, step(0.48, seed));
	float t = clamp((base - p.y) / peak, 0.0, 1.0);
	float curve = sqrt(1.0 - t);
	float tip = 0.50 + sway * 0.05;
	float bend = 1.6 * t * (1.0 - t) * (1.0 - 2.0 * t);
	float left = width * (tip + bend - 1.45 * sqrt(1.0 - t * t));
	float right = width * (tip + bend - 1.60 * curve + 1.70 * curve * curve);
	float x = (p.x - cell * spacing - 4.0 * sway) * direction;
	float distance_to_edge = max(max(left - x, x - right), base - peak - p.y);
	float edge = clamp(fwidth(distance_to_edge), 0.65, 6.0);
	float center = (left + right) * 0.5;
	float core_radius = (right - left) * 0.32 * sqrt(max(1.0 - (t * t) / 0.4356, 0.0));
	float core_distance = max(abs(x - center) - core_radius, base - peak * 0.66 - p.y);
	float core_edge = clamp(fwidth(core_distance), 0.65, 6.0);
	// Coverage widens toward the base; curled colour masks cannot punch holes.
	float fill_left = width * (tip - 1.70 * sqrt(1.0 - t * t));
	float fill_right = width * (tip + 0.65 * curve);
	float fill_distance = max(max(fill_left - x, x - fill_right), base - peak - p.y);
	float fill_edge = clamp(fwidth(fill_distance), 0.65, 6.0);
	return vec3(1.0 - smoothstep(-edge, edge, distance_to_edge),
		1.0 - smoothstep(-core_edge, core_edge, core_distance),
		1.0 - smoothstep(-fill_edge, fill_edge, fill_distance));
}

vec3 row(vec2 p, float spacing, float base, float height, float width, float phase) {
	float cell = floor(p.x / spacing);
	return max(tongue(p, cell, spacing, base, height, width, phase),
		tongue(p, cell + 1.0, spacing, base, height, width, phase));
}

void fragment() {
	vec2 p = wall_position;
	float edge = max(fwidth(p.y), 0.65);
	float base = -6.0 + 7.0 * sin(p.x * 0.035 + u_time * 1.2);
	float solid = smoothstep(base - edge, base + edge, p.y);
	vec3 back = row(p + vec2(u_time * 5.0, 0.0), 174.0, 56.0, 162.0, 86.0, 0.11);
	vec3 middle = row(p + vec2(u_time * 3.0 + 36.0, 0.0), 158.0, 67.0, 143.0, 82.0, 0.37);
	vec3 front = row(p + vec2(-u_time * 4.0 + 54.0, 0.0), 148.0, 84.0, 125.0, 72.0, 0.64);
	float orange = max(smoothstep(base + 110.0 - edge, base + 110.0 + edge, p.y), max(middle.x, front.z));
	float gold = max(smoothstep(base + 160.0 - edge, base + 160.0 + edge, p.y), front.x);
	vec3 color = mix(outer_color.rgb, orange_color.rgb, orange);
	color = mix(color, gold_color.rgb, gold);
	color = mix(color, core_color.rgb, front.y * gold);
	// Curl recesses inherit the darker backing, never subtract from its alpha.
	COLOR = vec4(color, max(solid, max(back.z, max(middle.z, front.z))));
}
