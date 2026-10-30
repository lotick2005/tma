extends Node3D
## «Иродианский» глиняный масляный светильник Иудеи I века: круглое тело размером с ладонь,
## отверстие для масла сверху, широкий плоский носик, срезанный ножом, без ручки.
## Огонёк на кончике носика мерцает вместе со светом. Модель строится кодом.

## Кончик носика, где горит фитиль (в локальных координатах светильника, носик смотрит в −Z).
const NOZZLE_TIP := Vector3(0.0, 0.018, -0.066)
## Профиль тела (радиус, высота), м: дно → плечо → край отверстия → вниз в отверстие.
const BODY_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.022, 0.0), Vector2(0.036, 0.008), Vector2(0.038, 0.014),
	Vector2(0.032, 0.022), Vector2(0.014, 0.026), Vector2(0.009, 0.021), Vector2(0.0, 0.019),
]

@export var light_color := Color(1.0, 0.62, 0.3)
@export var light_energy := 1.6
## Радиус света, м.
@export var light_range := 6.0
## Тени от светильника выключены, как на PS1: свет идёт почти из глаз героя, тени от него
## видны только рваными полосами по полу, а в браузере каждая кубическая тень — 6 лишних проходов.
@export var shadows := false
## Сила мерцания: доля яркости, на которую пламя «проседает».
@export_range(0.0, 1.0) var flicker_amount := 0.25
## Скорость мерцания.
@export var flicker_speed := 9.0
## Насколько свет дрожит в пространстве, м.
@export var flicker_wobble := 0.008
## Насколько огонь подсвечивает сам светильник и руки (0..1): свой свет их не освещает.
@export_range(0.0, 1.0) var glow_strength := 0.7

## Яркость света 0..1. Её меняет рука, когда достаёт или убирает светильник (scripts/hero_arms.gd).
var intensity := 1.0
## Текущая подсветка от огня 0..1 (мерцание × intensity × glow_strength) — для рук в кадре.
var glow := 0.0

var _noise := FastNoiseLite.new()
var _time := 0.0
var _flame: MeshInstance3D
var _clay: ShaderMaterial

@onready var _light: OmniLight3D = $Light
@onready var _light_origin: Vector3 = _light.position


func _ready() -> void:
	_build_model()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	_light.light_color = light_color
	_light.omni_range = light_range
	_light.shadow_enabled = shadows
	# Тело и руки героя не загораживают собственный светильник, а руки и он сам им не освещаются
	var view_bit := 1 << (Player.VIEW_LAYER - 1)
	_light.shadow_caster_mask = 0xFFFFFFFF & ~(1 << (Player.BODY_LAYER - 1)) & ~view_bit
	_light.light_cull_mask = 0xFFFFFFFF & ~view_bit


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	var n := _noise.get_noise_1d(_time) * 0.5 + 0.5  # 0..1
	var k := 1.0 - flicker_amount * n
	_light.visible = intensity > 0.01
	_light.light_energy = light_energy * k * intensity
	glow = glow_strength * k * intensity
	_clay.set_shader_parameter("self_illum", glow)
	_light.position = _light_origin + Vector3(
		_noise.get_noise_2d(_time, 17.0), _noise.get_noise_2d(_time, 43.0), _noise.get_noise_2d(_time, 71.0)
	) * flicker_wobble
	_flame.scale = Vector3(0.8 + 0.3 * k, 0.6 + 0.6 * k, 1.0)


func _build_model() -> void:
	_clay = PsxMaterial.make(ProcTextures.mottled(64, Color(0.6, 0.31, 0.19), 0.05, 0.12, 7))
	var body := MeshInstance3D.new()
	body.mesh = PsxMesh.lathe(PackedVector2Array(BODY_PROFILE), 8, 0.05)
	# Носик: от тела вперёд, к концу шире и площе, торец срезан прямо
	var nozzle := MeshInstance3D.new()
	nozzle.mesh = PsxMesh.hexahedron([
		Vector3(-0.011, 0.006, -0.026), Vector3(0.011, 0.006, -0.026),
		Vector3(0.015, 0.008, -0.07), Vector3(-0.015, 0.008, -0.07),
		Vector3(-0.011, 0.021, -0.026), Vector3(0.011, 0.021, -0.026),
		Vector3(0.015, 0.018, -0.07), Vector3(-0.015, 0.018, -0.07),
	], 0.05)
	for m in [body, nozzle]:
		m.material_override = _clay
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = 1 << (Player.VIEW_LAYER - 1)
		add_child(m)

	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	flame_mat.billboard_keep_scale = true
	flame_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flame_mat.albedo_texture = ProcTextures.flame(8, 16)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.013, 0.026)
	quad.center_offset = Vector3(0.0, 0.013, 0.0)
	_flame = MeshInstance3D.new()
	_flame.mesh = quad
	_flame.material_override = flame_mat
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.layers = 1 << (Player.VIEW_LAYER - 1)
	_flame.position = NOZZLE_TIP
	add_child(_flame)
