// Тень-пятно (blob shadow, CLAUDE.md §7): тёмное размытое пятно на полу под святыми, героем, телами и предметами
// вместо настоящих теней. Квадрат с UV 0..1: в середине темнее, к краю плавно в ноль.
// Тот же PS1-вид, что у psx_lit: дрожание вершин, туман по вершинам (в тумане пятно гаснет).
// Не пишет в глубину и не освещается; общая сила — глобальный psx_blob_strength (0 — выкл).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, specular_disabled;

global uniform float psx_snap_pixels;
global uniform float psx_fog_start;
global uniform float psx_fog_end;
global uniform float psx_blob_strength;

// Прозрачность в середине пятна (0,4–0,6).
uniform float opacity : hint_range(0.0, 1.0) = 0.5;

varying float fog_k;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	if (psx_snap_pixels > 0.0 && clip.w > 0.0) {
		vec2 grid = VIEWPORT_SIZE * 0.5 / psx_snap_pixels;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = round(ndc * grid) / grid * clip.w;
	}
	POSITION = clip;
	fog_k = clamp((length(view_pos) - psx_fog_start) / max(psx_fog_end - psx_fog_start, 0.001), 0.0, 1.0);
}

void fragment() {
	// COLOR.a — прозрачность этого пятна (у тел и предметов разная)
	float d = length(UV * 2.0 - 1.0);
	float a = 1.0 - smoothstep(0.45, 1.0, d);
	ALBEDO = vec3(0.0);
	ALPHA = a * opacity * COLOR.a * psx_blob_strength * (1.0 - fog_k);
}
