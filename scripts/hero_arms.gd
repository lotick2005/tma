extends Node3D
## Руки героя — кости того же тела (hero_body.gd), ставятся двухзвенным IK от плеча до кисти.
## Правая держит светильник там, где он виден в кадре; F — достать / убрать с анимацией,
## пока анимация идёт, повторное нажатие игнорируется. Левая свободна и покачивается в такт шагу.
## Если перед камерой стена — правая подтягивает светильник к груди, левая прижимается к телу.

## Светильник достали (true) или убрали (false). Срабатывает в начале анимации.
signal lamp_changed(out: bool)

## Длительность анимации «достать / убрать», с.
@export var lamp_anim_time := 0.45
## Как далеко перед камерой искать стену, м.
@export var wall_check_distance := 0.7
## Стена ближе этого — руки начинают подтягиваться; ближе wall_pull_full — подтянуты полностью.
@export var wall_pull_start := 0.6
@export var wall_pull_full := 0.25
## Покачивание свободной руки при ходьбе, м.
@export var arm_swing := 0.07
@export var body_path: NodePath = ^"../../../Body"
@export var lamp_path: NodePath = ^"../../../Body/OilLamp"

## Светильник в кадре (в пространстве камеры): обычно и подтянутый к груди у стены.
const LAMP_HELD := Transform3D(Basis(Vector3(0.5, 0.3244, -0.803), Vector3(0.0, 0.9272, 0.3746), Vector3(0.866, -0.1873, 0.4636)), Vector3(0.14, -0.13, -0.36))
const LAMP_PULLED := Transform3D(Basis(Vector3(0.5, 0.3244, -0.803), Vector3(0.0, 0.9272, 0.3746), Vector3(0.866, -0.1873, 0.4636)), Vector3(0.21, -0.07, -0.19))
## Сгиб пальцев, градусов: пустая рука и рука со светильником.
const FINGERS_RELAXED := 25.0
const FINGERS_HOLD := 60.0

## В руке ли светильник. Сохранять — через GameState.lamp_out (это делает Player).
var lamp_out := true
## Насколько поднят светильник: 0 — убран, 1 — в руке.
var raise := 1.0

var _tween: Tween
var _pull := 0.0
## Кисть (кость hand.R, начало — запястье) относительно светильника.
var _hand_from_lamp: Transform3D
var _probe := SphereShape3D.new()

@onready var _camera: Camera3D = get_parent()
@onready var _body: HeroBody = get_node(body_path)
@onready var _lamp: Node3D = get_node(lamp_path)


func _ready() -> void:
	_probe.radius = 0.12
	# Ладонь вверх под светильником, пальцы вперёд и чуть влево. У кости кисти пальцы — по −Y,
	# ладонь правой руки — по −X, большой палец — по −Z.
	var hand_basis := Basis(Vector3.UP, deg_to_rad(20.0)) * Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT)
	var fingers := -hand_basis.y
	var wrist := LAMP_HELD.origin - fingers * 0.045 - Vector3.UP * 0.014
	_hand_from_lamp = LAMP_HELD.affine_inverse() * Transform3D(hand_basis, wrist)


func is_busy() -> bool:
	return _tween != null and _tween.is_running()


## Достать / убрать. Возвращает false, если анимация ещё идёт.
func toggle_lamp() -> bool:
	if is_busy():
		return false
	set_lamp_out(not lamp_out)
	return true


func set_lamp_out(out: bool, instant: bool = false) -> void:
	lamp_out = out
	var target := 1.0 if out else 0.0
	if instant:
		raise = target
	else:
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "raise", target, lamp_anim_time)
	lamp_changed.emit(out)


func _process(delta: float) -> void:
	var skel := _body.skeleton
	var to_skel := skel.global_transform.affine_inverse()
	_pull = lerpf(_pull, _wall_pull(), 1.0 - exp(-10.0 * delta))
	var chest := skel.get_bone_global_pose(_body.bone("chest"))
	var swing := sin(_body.step_phase) * arm_swing * minf(_body.step_amount, 1.5)

	# Правая: от опущенной вдоль тела (светильник убран) до светильника в кадре
	var lamp_cam := LAMP_HELD.interpolate_with(LAMP_PULLED, _pull)
	var held := to_skel * _camera.global_transform * lamp_cam * _hand_from_lamp
	var lowered := chest * Transform3D(Basis(), Vector3(0.22, -0.4, -swing))
	var pole_r := Vector3(0.4, -0.2, 1.0).lerp(Vector3(0.7, -1.0, 0.2), raise)
	_solve_arm("R", lowered.interpolate_with(held, raise), pole_r, false)
	_curl("R", lerpf(FINGERS_RELAXED, FINGERS_HOLD, raise))

	# Левая: свободна, чуть согнута, у стены прижимается к телу
	var left := chest * Transform3D(Basis(), Vector3(-0.21 + 0.03 * _pull, -0.37, -0.1 + swing + 0.08 * _pull))
	_solve_arm("L", left, Vector3(-0.4, -0.2, 1.0), true)
	_curl("L", FINGERS_RELAXED)

	# Светильник лежит в настоящей кисти, даже если рука не дотянулась
	var hand := skel.get_bone_global_pose(_body.bone("hand.R"))
	_lamp.global_transform = skel.global_transform * hand * _hand_from_lamp.affine_inverse()
	_lamp.visible = raise > 0.02
	_lamp.intensity = raise


## 1 — стена вплотную перед камерой, 0 — далеко.
func _wall_pull() -> float:
	var player := owner as CollisionObject3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis(), _camera.global_position)
	q.motion = -_camera.global_basis.z * wall_check_distance
	q.collision_mask = player.collision_mask
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.cast_motion(q)
	var dist := hit[0] * wall_check_distance
	return 1.0 - smoothstep(wall_pull_full, wall_pull_start, dist)


## Двухзвенный IK: плечо → локоть → запястье. pole — куда смотрит локоть.
## hand_follows — кисть продолжает предплечье, иначе берёт поворот из target.
func _solve_arm(side: String, target: Transform3D, pole: Vector3, hand_follows: bool) -> void:
	var skel: Skeleton3D = _body.skeleton
	var ua := _body.bone("upper_arm." + side)
	var fa := _body.bone("forearm." + side)
	var hb := _body.bone("hand." + side)
	var a := HeroModel.UPPER_ARM
	var b := HeroModel.FOREARM
	var shoulder := skel.get_bone_global_pose(ua).origin
	var to_target := target.origin - shoulder
	var d := clampf(to_target.length(), 0.05, (a + b) * 0.999)
	var dir := to_target.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var out := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * a * cos_a + out * a * sqrt(1.0 - cos_a * cos_a)
	var wrist := shoulder + dir * d
	# Ось локтя: в покое это +X кости, сгиб вперёд
	var hinge := (elbow - shoulder).cross(wrist - elbow)
	if hinge.length_squared() < 1e-8:
		hinge = dir.cross(out)
	var fore_basis := _limb_basis(wrist - elbow, hinge)
	_set_global_basis(ua, _limb_basis(elbow - shoulder, hinge))
	_set_global_basis(fa, fore_basis)
	_set_global_basis(hb, fore_basis if hand_follows else target.basis.orthonormalized())


## Базис кости конечности: −Y вдоль конечности, X — ось сгиба.
func _limb_basis(along: Vector3, hinge: Vector3) -> Basis:
	var y := -along.normalized()
	var x := (hinge - y * hinge.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


func _set_global_basis(bone_idx: int, global_basis: Basis) -> void:
	var skel: Skeleton3D = _body.skeleton
	var parent_basis := skel.get_bone_global_pose(skel.get_bone_parent(bone_idx)).basis
	skel.set_bone_pose_rotation(bone_idx, (parent_basis.inverse() * global_basis).get_rotation_quaternion())


## Пальцы сгибаются к ладони: у правой ладонь по −X, у левой по +X.
func _curl(side: String, deg: float) -> void:
	var sign_z := -1.0 if side == "R" else 1.0
	_body.skeleton.set_bone_pose_rotation(_body.bone("fingers." + side), Quaternion(Vector3.BACK, deg_to_rad(deg) * sign_z))
