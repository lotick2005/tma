// Огоньки: пламя светильников в нишах, жаровни, маяк на Антонии. Тёплые точки, которые видны сквозь
// туман psx-шейдера (свой туман здесь не считается) — по ним игрок находит дорогу во тьме.
// Все огоньки уровня — один меш (Glows, scripts/glows.gd): в VERTEX лежит центр огонька,
// в UV2 — смещение угла квадрата в метрах; квадрат разворачивается к камере здесь, в вершинах.
// COLOR — цвет, COLOR.a — яркость. Мерцание у каждого огонька своё (по хешу центра).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D glow_texture : source_color, filter_nearest, hint_default_white;
// Минимальный угловой радиус огонька, рад: вдали он не становится меньше пары пикселей 320×240.
uniform float min_angle = 0.012;
// С какого расстояния огонёк гаснет и где пропадает совсем, м.
uniform float fade_start = 30.0;
uniform float fade_end = 45.0;
// Сила мерцания 0..1.
uniform float flicker = 0.3;

varying vec3 tint;

void vertex() {
	vec3 center = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(center);
	float size = max(length(UV2) * 0.7071, 0.001);
	// Вдали квадрат растёт, чтобы не исчезнуть между пикселями, и чуть тускнеет
	float k = max(1.0, dist * min_angle / size);
	center.xy += UV2 * k;
	POSITION = PROJECTION_MATRIX * vec4(center, 1.0);
	float h = fract(sin(dot(VERTEX, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float f = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * (6.0 + 5.0 * h) + h * 40.0)) * (0.6 + 0.4 * sin(TIME * 13.0 + h * 9.0));
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	tint = COLOR.rgb * COLOR.a * f * fade / sqrt(k);
}

void fragment() {
	vec4 t = texture(glow_texture, UV);
	ALBEDO = tint * t.rgb;
	ALPHA = t.a;
}
