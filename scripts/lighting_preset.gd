class_name LightingPreset
extends Resource
## Пресет освещения уровня: солнце или небесное тело, небо, фоновый свет, туман psx-шейдера, дальность камеры.
## Лежат в res://data/lighting/: day.tres — «день» (вступление, этап 4), darkness.tres — «тьма» (вся игра).
## Туман — глобальные параметры шейдеров psx_fog_* (CLAUDE.md §7). Днём небо — цвет тумана;
## во тьме небо почти чёрное, а дальние стены — силуэты цвета тумана на его фоне.

## Что висит в небе во тьме (CLAUDE.md §7).
enum SkyBody {
	NONE,
	## Чёрный диск с бледной короной высоко в небе, как вечное полное затмение (Ам 8:9).
	BLACK_SUN,
}

@export_group("Солнце")
## Включено ли солнце (во тьме вместо него светит небесное тело, см. sky_body).
@export var sun_enabled := true
@export var sun_color := Color(1.0, 0.93, 0.8)
@export var sun_energy := 1.0
## Направление солнца: наклон (градусы, отрицательный — светит сверху вниз) и азимут.
## Азимут 0 — солнце на юге, 90 — на востоке (светит на запад), −90 — на западе.
@export_range(-90.0, 0.0) var sun_pitch := -45.0
@export_range(-180.0, 180.0) var sun_azimuth := 45.0
## Тени от солнца. По CLAUDE.md §7 тени только там, где важны для механики, поэтому выключены.
@export var sun_shadows := false

@export_group("Небо")
## true — небо цвета тумана (день, дымка); false — своё, sky_color.
@export var sky_is_fog := true
@export var sky_color := Color(0.01, 0.01, 0.015)
@export var sky_body: SkyBody = SkyBody.NONE

@export_subgroup("Чёрное солнце")
## Высота над горизонтом и азимут (как у солнца), угловой размер диска, градусы.
@export_range(0.0, 90.0) var black_sun_elevation := 62.0
@export_range(-180.0, 180.0) var black_sun_azimuth := 20.0
@export var black_sun_size := 9.0
@export var black_sun_corona := Color(0.78, 0.8, 0.82)
## Едва заметный холодный свет сверху.
@export var black_sun_light_color := Color(0.55, 0.62, 0.8)
@export var black_sun_light_energy := 0.06

@export_group("Фоновый свет")
@export var ambient_color := Color(0.75, 0.8, 0.9)
@export var ambient_energy := 0.4

@export_group("Туман")
@export var fog_color := Color(0.85, 0.82, 0.75)
## Где туман начинается и где закрывает всё, м.
@export var fog_start := 10.0
@export var fog_end := 120.0

@export_group("Прочее")
## psx_light_max: сколько максимум даёт один источник света.
@export var light_max := 0.9
## Дальность камеры, м. Должна быть больше fog_end, иначе край мира виден до тумана.
## Во тьме — 240 м: силуэт Антонии и маяк на ней видны с площади (до них ~200 м).
@export var camera_far := 130.0


## sun — направленный свет уровня (солнце или свет небесного тела), sky — узел DarkSky (может быть null).
## interior_mask — слои, которых направленный свет не касается (внутри домов).
func apply(env: Environment, sun: DirectionalLight3D, camera: Camera3D = null, sky: Node = null,
		interior_mask: int = 0) -> void:
	PsxMaterial.set_global("psx_fog_color", fog_color)
	PsxMaterial.set_global("psx_fog_start", fog_start)
	PsxMaterial.set_global("psx_fog_end", fog_end)
	PsxMaterial.set_global("psx_light_max", light_max)
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog_color if sky_is_fog else sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	if sun:
		sun.shadow_enabled = sun_shadows
		sun.light_cull_mask = 0xFFFFF & ~interior_mask
		match sky_body:
			SkyBody.BLACK_SUN:
				_set_light(sun, true, black_sun_light_color, black_sun_light_energy, black_sun_elevation, black_sun_azimuth)
			_:
				_set_light(sun, sun_enabled, sun_color, sun_energy, -sun_pitch, sun_azimuth)
	if sky and sky.has_method("show_body"):
		sky.show_body(self)
		if sky.has_method("set_fade"):
			sky.set_fade(1.0)
	if camera:
		camera.far = camera_far
## Смесь двух пресетов: t = 0 — a, t = 1 — b (вступление: день гаснет в тьму за несколько секунд).
## Туман смешивается по логарифму расстояния — видимость падает равномерно, а не в самом конце.
## Свет — от солнца a к свету небесного тела b, небесное тело b проявляется с sky_from до sky_to.
static func apply_blend(a: LightingPreset, b: LightingPreset, t: float, env: Environment, sun: DirectionalLight3D,
		camera: Camera3D = null, sky: Node = null, interior_mask: int = 0, sky_from := 0.1, sky_to := 0.6) -> void:
	t = clampf(t, 0.0, 1.0)
	var log_lerp := func(x: float, y: float) -> float: return exp(lerpf(log(maxf(x, 0.01)), log(maxf(y, 0.01)), t))
	PsxMaterial.set_global("psx_fog_color", a.fog_color.lerp(b.fog_color, t))
	PsxMaterial.set_global("psx_fog_start", log_lerp.call(a.fog_start, b.fog_start))
	PsxMaterial.set_global("psx_fog_end", log_lerp.call(a.fog_end, b.fog_end))
	PsxMaterial.set_global("psx_light_max", lerpf(a.light_max, b.light_max, t))
	env.background_mode = Environment.BG_COLOR
	env.background_color = a.background().lerp(b.background(), t)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = a.ambient_color.lerp(b.ambient_color, t)
	env.ambient_light_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	if sun:
		var la := a.light_params()
		var lb := b.light_params()
		sun.shadow_enabled = a.sun_shadows and b.sun_shadows
		sun.light_cull_mask = 0xFFFFF & ~interior_mask
		var ea: float = la[2] if la[0] else 0.0
		var eb: float = lb[2] if lb[0] else 0.0
		_set_light(sun, ea > 0.0 or eb > 0.0, (la[1] as Color).lerp(lb[1], t), lerpf(ea, eb, t),
			lerpf(la[3], lb[3], t), rad_to_deg(lerp_angle(deg_to_rad(la[4]), deg_to_rad(lb[4]), t)))
	if sky and sky.has_method("show_body"):
		var shown := b if b.sky_body != SkyBody.NONE else a
		sky.show_body(shown)
		if sky.has_method("set_fade"):
			var k := smoothstep(sky_from, sky_to, t) if shown == b else 1.0 - smoothstep(sky_from, sky_to, t)
			sky.set_fade(k)
	if camera:
		camera.far = maxf(a.camera_far, b.camera_far) if t > 0.0 and t < 1.0 else (b.camera_far if t >= 1.0 else a.camera_far)


## Цвет фона: днём — туман, во тьме — своё небо.
func background() -> Color:
	return fog_color if sky_is_fog else sky_color


## Направленный свет пресета: [включён, цвет, яркость, высота над горизонтом, азимут].
func light_params() -> Array:
	if sky_body == SkyBody.BLACK_SUN:
		return [true, black_sun_light_color, black_sun_light_energy, black_sun_elevation, black_sun_azimuth]
	return [sun_enabled, sun_color, sun_energy, -sun_pitch, sun_azimuth]


## Направление на небесное тело (единичный вектор от наблюдателя).
static func direction(elevation: float, azimuth: float) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(-elevation), deg_to_rad(azimuth), 0.0)) * Vector3.BACK


static func _set_light(sun: DirectionalLight3D, on: bool, color: Color, energy: float, elevation: float, azimuth: float) -> void:
	sun.visible = on
	sun.light_color = color
	sun.light_energy = energy
	# Свет идёт вдоль −Z узла: поворот по азимуту, потом наклон вниз
	sun.rotation = Vector3(deg_to_rad(-elevation), deg_to_rad(azimuth), 0.0)
