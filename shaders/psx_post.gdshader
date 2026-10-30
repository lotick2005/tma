// Пост-эффект на весь экран: упорядоченный дизеринг 4×4 и урезание цвета, как на PS1 (15 бит = 5 бит на канал).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Бит на канал: 5 — 15-битный цвет PS1, 8 — без урезания.
uniform float color_bits : hint_range(1.0, 8.0, 1.0) = 5.0;
// Сила дизеринга: 0 — выкл (видны полосы), 1 — как на PS1.
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float levels = exp2(color_bits) - 1.0;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
	c += threshold * dither_strength / levels;
	c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	COLOR = vec4(c, 1.0);
}
