// PS1-материал: дрожание вершин в экранных координатах, аффинные текстуры, nearest, туман по вершинам.
// Все настройки — глобальные параметры шейдеров (Настройки проекта → Shader Globals), общие для всех материалов:
//   psx_snap_pixels — шаг сетки привязки вершин в пикселях внутреннего разрешения (0 — выкл, 1 — как на PS1);
//   psx_affine      — 0 — правильная перспектива, 1 — текстуры полностью аффинные (плывут);
//   psx_affine_near — ближе этого расстояния (м) аффинность плавно гаснет, чтобы вплотную у стены не было каши;
//   psx_fog_color, psx_fog_start, psx_fog_end — цвет тумана и где он начинается и где закрывает всё (м);
//   psx_light_max   — сколько максимум даёт один источник света: вплотную к огню нет белого пятна.
shader_type spatial;
render_mode specular_disabled;

global uniform float psx_snap_pixels;
global uniform float psx_affine;
global uniform float psx_affine_near;
global uniform vec4 psx_fog_color;
global uniform float psx_fog_start;
global uniform float psx_fog_end;
global uniform float psx_light_max;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Собственная подсветка 0..1 (руки и светильник в кадре подсвечивает огонь).
uniform float self_illum : hint_range(0.0, 1.0) = 0.0;
// 1 — подсветка сверху ярче, снизу темнее (светильник); 0 — ровная по всей поверхности (тело, руки).
uniform float self_illum_shade : hint_range(0.0, 1.0) = 1.0;
// Цвет подсветки: для рук — цвет огня.
uniform vec3 self_illum_color : source_color = vec3(1.0);

// xy — UV, умноженные на w; z — сам w. Деление во fragment() убирает перспективную коррекцию.
varying vec3 affine_uv;
varying float affine_k;
varying float fog_k;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	if (psx_snap_pixels > 0.0 && clip.w > 0.0) {
		// NDC -1..1 → сетка с шагом psx_snap_pixels пикселей
		vec2 grid = VIEWPORT_SIZE * 0.5 / psx_snap_pixels;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = round(ndc * grid) / grid * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
	// Вплотную (до psx_affine_near) — без аффинности, к 2×psx_affine_near — в полную силу
	affine_k = psx_affine * clamp(clip.w / max(psx_affine_near, 0.001) - 1.0, 0.0, 1.0);
	// Туман по расстоянию до камеры, как на PS1 — считается в вершинах
	fog_k = clamp((length(view_pos) - psx_fog_start) / max(psx_fog_end - psx_fog_start, 0.001), 0.0, 1.0);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine_k);
	vec4 tex = texture(albedo_texture, uv);
	// Итог = свет × albedo + emission, поэтому так получается mix(освещённый цвет, туман, fog_k)
	vec3 albedo = tex.rgb * albedo_color.rgb;
	ALBEDO = albedo * (1.0 - fog_k);
	float shade = mix(1.0, 0.3 + 0.7 * clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0), self_illum_shade);
	EMISSION = mix(albedo * self_illum * shade * self_illum_color, psx_fog_color.rgb, fog_k);
}

// Ламберт, но вклад одного источника ограничен psx_light_max. Ограничиваем всю тройку RGB
// одним множителем, чтобы тёплый свет вблизи не выгорал в белый.
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 c = LIGHT_COLOR / PI * ATTENUATION * ndl;
	float m = max(c.r, max(c.g, c.b));
	DIFFUSE_LIGHT += c * min(1.0, psx_light_max / max(m, 0.0001));
}
