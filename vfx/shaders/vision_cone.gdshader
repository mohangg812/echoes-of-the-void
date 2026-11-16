// res://vfx/shaders/vision_cone.gdshader
// Сетчатая заливка с градиентным затуханием для зон зрения (по желанию подключается к Polygon2D/ColorRect).
shader_type canvas_item;

uniform vec4 zone_color : source_color = vec4(1.0, 0.0, 0.24, 0.35);
uniform float fade = 0.6;
uniform float grid_lines = 6.0;

void fragment() {
	float g = step(0.92, fract(UV.x * grid_lines)) + step(0.92, fract(UV.y * grid_lines));
	float falloff = 1.0 - fade * UV.x;
	COLOR = vec4(zone_color.rgb * (1.0 + 0.6 * clamp(g, 0.0, 1.0)), zone_color.a * falloff);
}
