shader_type canvas_item;

uniform float sweep = -1.0;

void fragment() {
	vec4 ink = COLOR;
	float band = 1.0 - smoothstep(0.025, 0.095, abs(UV.x + UV.y * 0.24 - sweep));
	COLOR = vec4(mix(ink.rgb, vec3(1.0, 0.96, 0.78), band * 0.65), ink.a);
}
