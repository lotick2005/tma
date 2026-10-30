// Дым (печь гончара): клубы поднимаются, расползаются и тают. Как огоньки (glow.gdshader) — меш из Glows,
// VERTEX — точка, откуда идёт дым, UV2 — угол квадрата в метрах, COLOR — цвет и плотность.
// Туманом не закрывается: тёмно-рыжий столб, подсвеченный огнём снизу, виден над крышами издалека.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D glow_texture : source_color, filter_nearest, hint_default_white;
// На сколько метров поднимается клуб, пока не растает, и сколько циклов в секунду.
uniform float rise = 9.0;
uniform float speed = 0.05;

varying vec4 tint;

void vertex() {
	float h = fract(sin(dot(VERTEX, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float ph = fract(TIME * speed * (0.8 + 0.4 * h) + h);
	// Клуб сносит ветром и раздувает по мере подъёма
	vec3 base = VERTEX + vec3(sin(ph * 5.0 + h * 9.0) * 0.5 + ph * 1.5, ph * rise, cos(ph * 4.0 + h * 7.0) * 0.5);
	vec3 center = (MODELVIEW_MATRIX * vec4(base, 1.0)).xyz;
	center.xy += UV2 * (0.5 + ph * 2.2);
	POSITION = PROJECTION_MATRIX * vec4(center, 1.0);
	// Внизу клуб рыжий от огня, выше — серый; появляется и тает плавно
	vec3 col = mix(COLOR.rgb * vec3(1.6, 1.1, 0.9), COLOR.rgb * 0.6, ph);
	tint = vec4(col, COLOR.a * sin(ph * 3.14159));
}

void fragment() {
	vec4 t = texture(glow_texture, UV);
	ALBEDO = tint.rgb;
	ALPHA = t.a * tint.a;
}
