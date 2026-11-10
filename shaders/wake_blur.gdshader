shader_type canvas_item;
// «Очнулся» (scripts/awaken.gd): мутная картинка — размытие экрана и чуть темнее; amount 0…1.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * (0.5 + amount * 3.5);
	vec3 c = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			c += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb;
		}
	}
	c /= 25.0;
	// Двоится: вторая копия чуть в стороне
	vec3 ghost = texture(screen_tex, SCREEN_UV + vec2(amount * 0.02, 0.0)).rgb;
	c = mix(c, ghost, 0.3 * amount);
	COLOR = vec4(c * (1.0 - 0.3 * amount), amount > 0.001 ? 1.0 : 0.0);
}
