// res://vfx/shaders/crt_cyberpunk.gdshader
// Лёгкий CRT-пост-эффект: сканлайны, виньетка, хроматическая аберрация (усиливается при тревоге).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float scan_strength = 0.05;
uniform float vignette = 0.38;
uniform float aberration = 0.0004;
uniform float alarm = 0.0;
uniform float glitch = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = step(0.93 - glitch * 0.45, fract(sin(floor(uv.y * 38.0 + floor(TIME * 18.0) * 7.0) * 43758.5453)));
	uv.x += band * glitch * 0.045 * sin(TIME * 60.0);
	float ab = aberration + alarm * 0.0022 + glitch * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
	float scan = sin(uv.y * 1100.0) * 0.5 + 0.5;
	col *= 1.0 - scan_strength * scan;
	vec2 d = uv - vec2(0.5);
	col *= 1.0 - vignette * dot(d, d) * 2.2;
	col += vec3(alarm * 0.05, 0.0, 0.0) * (0.5 + 0.5 * sin(TIME * 6.0));
	COLOR = vec4(col, 1.0);
}
