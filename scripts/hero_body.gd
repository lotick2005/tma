class_name HeroBody
extends Node3D
## Тело героя от первого лица: одна лоуполи-фигура со скелетом (HeroModel: Skeleton3D + скиннинг).
## Здесь — таз, ноги и голова: ходьба, бег, присед процедурно через кости.
## Руки (IK, светильник, стены) — hero_arms.gd. Голова только отбрасывает тень, камера внутри неё.
## Позу задаёт Player через update_pose(); кости обновляются в _process.

## Размах бедра при ходьбе, градусов.
@export var leg_swing_deg := 24.0
## Сгиб колена у ноги, которая идёт вперёд, градусов.
@export var knee_bend_deg := 35.0
## От глаз до таза, м: по высоте камеры считается, насколько тело присело.
@export var eye_to_pelvis := 0.67
## Насколько тело позади камеры, м: когда смотришь прямо и когда смотришь в пол.
## Глаза — на передней части головы, а глядя вниз, тело чуть отъезжает, чтобы были видны ноги.
@export var body_back := 0.07
@export var body_back_looking_down := 0.25
## Насколько огонь светильника подсвечивает тело (0..1): иначе рука под огнём — чёрная палка.
@export_range(0.0, 1.0) var lamp_glow := 0.5

var skeleton: Skeleton3D
## Фаза шага (π на шаг) и сглаженная «сила» шага 0..1.8 — их читает hero_arms.gd для покачивания рук.
var step_phase := 0.0
var step_amount := 0.0

var _eye_height := 1.62
var _pitch := 0.0
var _speed_ratio := 0.0
var _idx := {}
var _materials: Array[ShaderMaterial] = []

@onready var _lamp: Node3D = $OilLamp


func _ready() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	HeroModel.build_skeleton(skeleton)
	for b in HeroModel.BONES:
		_idx[b[0]] = skeleton.find_bone(b[0])
	var skin := skeleton.create_skin_from_rest_transforms()
	var layer := 1 << (Player.BODY_LAYER - 1)

	var body := MeshInstance3D.new()
	body.mesh = HeroModel.build_body(skeleton)
	body.skin = skin
	body.skeleton = NodePath("..")
	body.layers = layer
	# Меш анимируется костями — запас, чтобы его не отсекало по исходной рамке
	body.extra_cull_margin = 1.0
	skeleton.add_child(body)
	for i in body.mesh.get_surface_count():
		_materials.append(body.mesh.surface_get_material(i))

	var head := MeshInstance3D.new()
	head.mesh = HeroModel.build_head(skeleton)
	head.skin = skin
	head.skeleton = NodePath("..")
	head.layers = layer
	head.extra_cull_margin = 1.0
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	skeleton.add_child(head)


func bone(bone_name: String) -> int:
	return _idx[bone_name]


## eye_height — высота глаз над ступнями; pitch — наклон головы (рад, вниз — минус);
## phase — фаза шага (π на шаг); speed_ratio — скорость / скорость ходьбы.
func update_pose(eye_height: float, pitch: float, phase: float, speed_ratio: float) -> void:
	_eye_height = eye_height
	_pitch = pitch
	step_phase = phase
	_speed_ratio = speed_ratio


func _process(delta: float) -> void:
	# Глядя в пол, тело отъезжает назад: верх плеч уходит из кадра, видны грудь, ноги и ступни
	position.z = lerpf(body_back, body_back_looking_down, smoothstep(deg_to_rad(25.0), deg_to_rad(80.0), -_pitch))
	var glow: float = _lamp.glow * lamp_glow
	for m in _materials:
		m.set_shader_parameter("self_illum", glow)
	var pelvis_h := _eye_height - eye_to_pelvis
	skeleton.set_bone_pose_position(_idx["pelvis"], Vector3(0.0, pelvis_h, 0.0))
	# Присед: бедро вперёд на угол, голень назад на тот же угол — таз опускается
	var hip_h := pelvis_h - (HeroModel.PELVIS_Y - HeroModel.HIP_Y)
	var leg := HeroModel.THIGH + HeroModel.SHIN
	var crouch := acos(clampf((hip_h - HeroModel.ANKLE_H) / leg, 0.0, 1.0))
	step_amount = lerpf(step_amount, clampf(_speed_ratio, 0.0, 1.8), 1.0 - exp(-10.0 * delta))
	var swing := deg_to_rad(leg_swing_deg) * step_amount
	var bend := deg_to_rad(knee_bend_deg) * step_amount
	var hips_sum := 0.0
	for side in ["L", "R"]:
		var ph := step_phase + (0.0 if side == "L" else PI)
		var hip := crouch + swing * sin(ph)
		hips_sum += hip
		var knee := -2.0 * crouch - bend * maxf(0.0, cos(ph))
		_rot("thigh." + side, hip)
		_rot("shin." + side, knee)
		_rot("foot." + side, -(hip + knee))  # стопа остаётся ровной
	# Подол спереди ложится на бёдра: шаг ног взаимно гасится, присед поднимает подол
	_rot("skirt", maxf(0.0, hips_sum * 0.5))
	# Голова кивает вместе с камерой — это видно по тени
	_rot("head", _pitch)


func _rot(bone_name: String, angle_x: float) -> void:
	skeleton.set_bone_pose_rotation(_idx[bone_name], Quaternion(Vector3.RIGHT, angle_x))
