extends Node3D
## Тело героя: туника, кольчуга (lorica hamata), пояс, калиги. Головы нет — в ней камера.
## Посмотрел вниз — видно грудь, ноги и ступни. Ноги шагают в такт ходьбе, при приседе тело садится.
## Тело отбрасывает тень (понадобится для ангела, CLAUDE.md §4); голова и руки — только тенью,
## в кадре руки свои (hero_arms.gd). Позу каждый кадр задаёт Player через update_pose().

## Размах бедра при ходьбе, градусов.
@export var leg_swing_deg := 24.0
## Сгиб колена у ноги, которая идёт вперёд, градусов.
@export var knee_bend_deg := 35.0
## От глаз до тазобедренных суставов, м: по высоте камеры считается, насколько тело присело.
@export var eye_to_hip := 0.7

const THIGH := 0.44
const SHIN := 0.42
const FOOT_H := 0.06
const HIP_X := 0.095
## Насколько тело позади камеры, м: когда смотришь прямо и когда смотришь в пол.
## Глядя вниз, тело отъезжает назад, иначе видно только плечи, а не грудь и ноги.
@export var body_back := 0.12
@export var body_back_looking_down := 0.28

const SKIN := Color(0.72, 0.5, 0.36)

var _hips: Node3D
var _legs: Array[Dictionary] = []
var _right_arm: Node3D
var _amount := 0.0


func _ready() -> void:
	var skin := PsxMaterial.make(ProcTextures.mottled(64, SKIN, 0.03, 0.06, 11))
	var mail := PsxMaterial.make(ProcTextures.chainmail(64, 4, Color(0.5, 0.5, 0.53), Color(0.14, 0.14, 0.16)))
	var tunic := PsxMaterial.make(ProcTextures.mottled(64, Color(0.55, 0.15, 0.12), 0.04, 0.1, 12))
	var leather := PsxMaterial.make(ProcTextures.mottled(64, Color(0.33, 0.2, 0.11), 0.04, 0.08, 13))
	var caliga := PsxMaterial.make(ProcTextures.stripes(64, 12, Color(0.3, 0.18, 0.1), SKIN, 14))

	_hips = Node3D.new()
	_hips.position = Vector3(0.0, FOOT_H + THIGH + SHIN, body_back)
	add_child(_hips)
	# Кольчуга: корпус и скошенные плечи
	_part(_hips, PsxMesh.frustum(Vector2(0.36, 0.24), Vector2(0.4, 0.22), 0.54, 0.2), Vector3(0.0, -0.12, 0.0), mail)
	_part(_hips, PsxMesh.frustum(Vector2(0.4, 0.22), Vector2(0.2, 0.12), 0.16, 0.2), Vector3(0.0, 0.42, 0.0), mail)
	_part(_hips, PsxMesh.frustum(Vector2(0.41, 0.3), Vector2(0.36, 0.26), 0.2, 0.3), Vector3(0.0, -0.3, 0.0), tunic)
	_part(_hips, PsxMesh.box(Vector3(0.39, 0.05, 0.26), 0.3), Vector3(0.0, 0.0, 0.0), leather)
	# Голова в шлеме и руки — только тень
	_part(_hips, PsxMesh.frustum(Vector2(0.2, 0.23), Vector2(0.17, 0.2), 0.32, 1.0), Vector3(0.0, 0.5, -0.04), skin, true)
	var arm_mesh := PsxMesh.frustum(Vector2(0.07, 0.07), Vector2(0.1, 0.1), 0.62, 1.0)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.24 * side, 0.46, 0.0)
		shoulder.rotation.x = 0.05
		_hips.add_child(shoulder)
		_part(shoulder, arm_mesh, Vector3(0.0, -0.62, 0.0), skin, true)
		if side > 0.0:
			_right_arm = shoulder

	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(HIP_X * side, 0.0, 0.0)
		_hips.add_child(hip)
		_part(hip, PsxMesh.frustum(Vector2(0.11, 0.12), Vector2(0.15, 0.16), THIGH, 0.2), Vector3(0.0, -THIGH, 0.0), skin)
		var knee := Node3D.new()
		knee.position.y = -THIGH
		hip.add_child(knee)
		_part(knee, PsxMesh.frustum(Vector2(0.085, 0.09), Vector2(0.11, 0.12), SHIN, 0.2), Vector3(0.0, -SHIN, 0.0), skin)
		var ankle := Node3D.new()
		ankle.position.y = -SHIN
		knee.add_child(ankle)
		_part(ankle, PsxMesh.box(Vector3(0.1, FOOT_H, 0.25), 0.1), Vector3(0.0, -FOOT_H * 0.5, -0.06), caliga)
		_legs.append({"hip": hip, "knee": knee, "ankle": ankle})


## eye_height — высота глаз над ступнями; pitch — наклон головы (рад, вниз — минус);
## phase — фаза шага (π на шаг); speed_ratio — скорость / скорость ходьбы;
## lamp_raise — насколько поднят светильник (0..1).
func update_pose(eye_height: float, pitch: float, phase: float, speed_ratio: float, lamp_raise: float, delta: float) -> void:
	var hip_h := eye_height - eye_to_hip
	_hips.position.y = hip_h
	_hips.position.z = lerpf(body_back, body_back_looking_down, clampf(-pitch / (PI * 0.5), 0.0, 1.0))
	# Присед: бедро вперёд на угол, голень назад на тот же угол — таз опускается
	var crouch := acos(clampf((hip_h - FOOT_H) / (THIGH + SHIN), 0.0, 1.0))
	_amount = lerpf(_amount, clampf(speed_ratio, 0.0, 1.8), 1.0 - exp(-10.0 * delta))
	var swing := deg_to_rad(leg_swing_deg) * _amount
	var bend := deg_to_rad(knee_bend_deg) * _amount
	for i in _legs.size():
		var ph := phase + PI * i
		var hip := crouch + swing * sin(ph)
		var knee := -2.0 * crouch - bend * maxf(0.0, cos(ph))
		_legs[i].hip.rotation.x = hip
		_legs[i].knee.rotation.x = knee
		_legs[i].ankle.rotation.x = -(hip + knee)  # стопа остаётся ровной
	_right_arm.rotation.x = lerpf(0.05, 1.2, lamp_raise)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, shadow_only: bool = false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.layers = 1 << (Player.BODY_LAYER - 1)
	if shadow_only:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(mi)
