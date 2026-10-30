// PS1-материал: дрожание вершин в экранных координатах, аффинные текстуры, nearest.
// Сила эффектов — глобальные параметры шейдеров (Настройки проекта → Shader Globals):
//   psx_snap_pixels — шаг сетки привязки вершин в пикселях внутреннего разрешения (0 — выкл, 1 — как на PS1);
//   psx_affine      — 0 — правильная перспектива, 1 — текстуры полностью аффинные (плывут).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

global uniform float psx_snap_pixels;
global uniform float psx_affine;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);

// xy — UV, умноженные на w; z — сам w. Деление во fragment() убирает перспективную коррекцию.
varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (psx_snap_pixels > 0.0 && clip.w > 0.0) {
		// NDC -1..1 → сетка с шагом psx_snap_pixels пикселей
		vec2 grid = VIEWPORT_SIZE * 0.5 / psx_snap_pixels;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = round(ndc * grid) / grid * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, psx_affine);
	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = tex.rgb * albedo_color.rgb;
}
