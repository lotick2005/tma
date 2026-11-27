class_name LampPickup
extends Node3D
## Светильник героя на земле (CLAUDE.md §2, §8): лежит рядом с местом пробуждения, горит на камне впереди; герой берёт его сам (ПКМ).
## До этого в руке пусто (GameState.has_lamp = false), F не работает. Взял — светильник в руке (Player.set_lamp),
## F — убрать / достать. Берёт HeroHands.try_lamp(), подсказку «ПКМ — взять» показывает Hints.

## Дальше этого герой не берёт, м; и угол от взгляда до светильника, градусы.
const PICK_DISTANCE := 2.4
const PICK_ANGLE := 55.0

const MODEL := "res://models/oil_lamp.glb"
## Модель в узле (носик −X → −Z, середина тела — в начале узла), как в scripts/oil_lamp.gd.
const MODEL_XF := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.0, 0.0, -0.012))
const TIP := Vector3(0.0, 0.033, -0.048)

var _flame: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	name = "LampPickup"
	var clay := CharacterModel.material("oil_lamp").duplicate() as ShaderMaterial
	clay.set_shader_parameter("self_illum", 0.5)
	clay.set_shader_parameter("self_illum_color", Color(1.0, 0.62, 0.3))
	var inst: Node3D = (load(MODEL) as PackedScene).instantiate()
	inst.transform = MODEL_XF
	add_child(inst)
	for m: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		m.material_override = clay
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Огонёк на кончике носика (как у светильника в руке) и тёплый свет: по нему светильник видно в тьме издалека
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
	_flame.position = TIP
	add_child(_flame)
	var light := OmniLight3D.new()
	light.set_script(preload("res://scripts/flicker_light.gd"))
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 0.7
	light.omni_range = 3.5
	light.position = TIP + Vector3(0.0, 0.05, 0.0)
	add_child(light)


func _process(delta: float) -> void:
	_time += delta * 9.0
	_flame.scale = Vector3(0.9 + 0.2 * sin(_time), 0.8 + 0.4 * sin(_time * 1.7 + 1.0), 1.0)


## Можно ли взять: светильник в пределах PICK_DISTANCE и в конусе PICK_ANGLE от взгляда, между ними нет стены.
func pickable(from: Vector3, dir: Vector3, exclude := []) -> bool:
	var at := global_position + Vector3.UP * 0.12
	var to := at - from
	var d := to.length()
	if d > PICK_DISTANCE or d < 0.01:
		return false
	if to.dot(dir) / d < cos(deg_to_rad(PICK_ANGLE)):
		return false
	var q := PhysicsRayQueryParameters3D.create(from, from + to * 0.95, 1, exclude)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
