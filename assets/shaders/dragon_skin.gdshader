shader_type canvas_item;

uniform float hue_center = 115.0;
uniform float hue_half_width = 35.0;
uniform float softness = 15.0;
uniform float sat_gate = 0.35;
uniform float hue_target = 0.0;
uniform float hue_spread = 1.0;
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;

varying vec4 vertex_color;

vec3 rgb_to_hsv(vec3 rgb) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(rgb.bg, k.wz), vec4(rgb.gb, k.xy), step(rgb.b, rgb.g));
	vec4 q = mix(vec4(p.xyw, rgb.r), vec4(rgb.r, p.yzx), step(p.x, rgb.r));
	float delta = q.x - min(q.w, q.y);
	float epsilon = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * delta + epsilon)) * 360.0,
		delta / (q.x + epsilon), q.x);
}

vec3 hsv_to_rgb(vec3 hsv) {
	vec3 p = abs(fract(vec3(hsv.x / 360.0) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return hsv.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), hsv.y);
}

void vertex() {
	// Fragment COLOR already contains TEXTURE; preserve modulation before sampling.
	vertex_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(tex.rgb);
	float d = 180.0 - mod(hue_center - hsv.x + 180.0, 360.0);
	float hue_band = 1.0 - smoothstep(hue_half_width, hue_half_width + softness, abs(d));
	float sat_g = smoothstep(sat_gate - 0.08, sat_gate + 0.08, hsv.y);
	float val_g = smoothstep(0.12, 0.25, hsv.z);
	float mask = hue_band * sat_g * val_g;
	hsv.x = mod(hsv.x + mask * ((hue_target - hue_center) + (hue_spread - 1.0) * d), 360.0);
	hsv.y = clamp(hsv.y * mix(1.0, sat_mul, mask), 0.0, 1.0);
	hsv.z = clamp(hsv.z * mix(1.0, val_mul, mask), 0.0, 1.0);
	COLOR = vec4(hsv_to_rgb(hsv), tex.a) * vertex_color;
}
