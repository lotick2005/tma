class_name LightingPreset
extends Resource
## Пресет освещения уровня: солнце, фоновый свет, туман psx-шейдера, дальность камеры.
## Лежат в res://data/lighting/ (day.tres — «день»). На этапе 4 вступление переключит уровень
## на пресет «тьма» тем же apply().
## Туман — глобальные параметры шейдеров psx_fog_* (CLAUDE.md §7), фон уровня — цвет тумана.

@export_group("Солнце")
## Включено ли солнце (во тьме — нет).
@export var sun_enabled := true
@export var sun_color := Color(1.0, 0.93, 0.8)
@export var sun_energy := 1.0
## Направление солнца: наклон (градусы, отрицательный — светит сверху вниз) и азимут.
## Азимут 0 — солнце на юге, 90 — на востоке (светит на запад), −90 — на западе.
@export_range(-90.0, 0.0) var sun_pitch := -45.0
@export_range(-180.0, 180.0) var sun_azimuth := 45.0
## Тени от солнца. По CLAUDE.md §7 тени только там, где важны для механики, поэтому днём выключены.
@export var sun_shadows := false

@export_group("Фоновый свет")
@export var ambient_color := Color(0.75, 0.8, 0.9)
@export var ambient_energy := 0.4

@export_group("Туман")
## Цвет тумана — он же цвет неба (фон уровня).
@export var fog_color := Color(0.85, 0.82, 0.75)
## Где туман начинается и где закрывает всё, м.
@export var fog_start := 10.0
@export var fog_end := 120.0

@export_group("Прочее")
## psx_light_max: сколько максимум даёт один источник света.
@export var light_max := 0.9
## Дальность камеры, м. Должна быть больше fog_end, иначе край мира виден до тумана.
@export var camera_far := 130.0


func apply(env: Environment, sun: DirectionalLight3D, camera: Camera3D = null) -> void:
	PsxMaterial.set_global("psx_fog_color", fog_color)
	PsxMaterial.set_global("psx_fog_start", fog_start)
	PsxMaterial.set_global("psx_fog_end", fog_end)
	PsxMaterial.set_global("psx_light_max", light_max)
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	if sun:
		sun.visible = sun_enabled
		sun.light_color = sun_color
		sun.light_energy = sun_energy
		sun.shadow_enabled = sun_shadows
		# Свет идёт вдоль −Z узла: поворот по азимуту, потом наклон вниз
		sun.rotation = Vector3(deg_to_rad(sun_pitch), deg_to_rad(sun_azimuth), 0.0)
	if camera:
		camera.far = camera_far
