extends Node3D
## «Иродианский» глиняный масляный светильник Иудеи I века: круглое тело размером с ладонь,
## отверстие для масла сверху, широкий плоский носик, срезанный ножом, без ручки.
## Модель — models/oil_lamp.glb (Meshy, см. models/CREDITS.md): в файле носик смотрит на −X, огонь на кончике
## носика ≈ (−0,048; 0,033; 0). Здесь она повёрнута носиком в −Z, и середина дна тела — в начале узла
## (на ней лежит ладонь, hero_arms.gd). Огонёк на кончике носика мерцает вместе со светом.

const MODEL := "res://models/oil_lamp.glb"
## Середина круглого тела в файле модели (по X; носик дальше −0,025) — встаёт в начало узла.
const BODY_CENTER_X := 0.012
## Кончик носика, где горит фитиль (в осях файла модели).
const TIP_IN_FILE := Vector3(-0.048, 0.033, 0.0)
## Модель в узле: носик −X → −Z, тело — в начале узла.
const MODEL_XF := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.0, 0.0, -BODY_CENTER_X))
## Кончик носика в осях узла.
var nozzle_tip: Vector3 = MODEL_XF * TIP_IN_FILE

@export var light_color := Color(1.0, 0.62, 0.3)
@export var light_energy := 0.6
## Радиус света, м: маленькое тёплое пятно. Мягкость затухания — omni_attenuation у узла Light.
@export var light_range := 3.5
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
## Свет — чуть над огоньком.
@onready var _light_origin: Vector3 = nozzle_tip + Vector3(0.0, 0.015, 0.0)


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
	_light.omni_range = light_range
	glow = glow_strength * k * intensity
	_clay.set_shader_parameter("self_illum", glow)
	_light.position = _light_origin + Vector3(
		_noise.get_noise_2d(_time, 17.0), _noise.get_noise_2d(_time, 43.0), _noise.get_noise_2d(_time, 71.0)
	) * flicker_wobble
	_flame.scale = Vector3(0.8 + 0.3 * k, 0.6 + 0.6 * k, 1.0)


func _build_model() -> void:
	_clay = CharacterModel.material("oil_lamp").duplicate()
	_clay.set_shader_parameter("self_illum_color", light_color)
	var inst: Node3D = (load(MODEL) as PackedScene).instantiate()
	inst.transform = MODEL_XF
	add_child(inst)
	for m: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _clay
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = 1 << (Player.VIEW_LAYER - 1)

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
	_flame.position = nozzle_tip
	add_child(_flame)
