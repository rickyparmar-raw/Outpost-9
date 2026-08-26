shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.08;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.035;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float d = distance(SCREEN_UV, vec2(0.5, 0.5));
	float vig = smoothstep(0.3, 0.78, d);
	col *= mix(1.0, 1.0 - vignette_strength, vig);
	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * 900.0);
	col *= mix(1.0, scan, scanline_strength);
	col += (rand(SCREEN_UV + vec2(TIME * 0.37, TIME * 0.71)) - 0.5) * noise_strength;
	COLOR = vec4(col, 1.0);
}
