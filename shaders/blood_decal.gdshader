// Кровь на полу и стенах: плоские неровные пятна с мягким краем (альфа-смешивание), текстура 32×32.
// Тот же PS1-вид, что у psx_lit: дрожание вершин, аффинные текстуры, nearest, туман по вершинам, общие глобальные параметры.
// Не пишет в глубину (лежит на плитах, не перекрывает то, что стоит на них), цвет — тёмно-красный.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

global uniform float psx_snap_pixels;
global uniform float psx_affine;
global uniform float psx_affine_near;
global uniform vec4 psx_fog_color;
global uniform float psx_fog_start;
global uniform float psx_fog_end;
global uniform float psx_light_max;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);

varying vec3 affine_uv;
varying float affine_k;
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
	affine_uv = vec3(UV * clip.w, clip.w);
	affine_k = psx_affine * clamp(clip.w / max(psx_affine_near, 0.001) - 1.0, 0.0, 1.0);
	fog_k = clamp((length(view_pos) - psx_fog_start) / max(psx_fog_end - psx_fog_start, 0.001), 0.0, 1.0);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine_k);
	vec4 tex = texture(albedo_texture, uv);
	vec3 albedo = tex.rgb * albedo_color.rgb;
	ALBEDO = albedo * (1.0 - fog_k);
	EMISSION = psx_fog_color.rgb * fog_k;
	// Альфа края — из текстуры (плавный градиент, без дизера); COLOR.a — общая прозрачность куска (следы бледнеют)
	ALPHA = tex.a * albedo_color.a * COLOR.a;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 c = LIGHT_COLOR / PI * ATTENUATION * ndl;
	float m = max(c.r, max(c.g, c.b));
	DIFFUSE_LIGHT += c * min(1.0, psx_light_max / max(m, 0.0001));
}
