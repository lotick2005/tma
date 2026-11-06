extends Node3D
## Руки героя (CLAUDE.md §8) — кости модели hero (скелет Mixamo), поверх мокап-анимации тела (hero_body.gd).
## Двухзвенный IK от плеча до кисти: RightUpperArm → RightLowerArm → RightHand (у левой так же).
## Правая держит светильник там, где он виден в кадре; F — достать / убрать: рука плавно уходит
## из позы анимации к светильнику и обратно, пока анимация идёт, повторное нажатие игнорируется.
## Левая свободна — машет так, как в анимации ходьбы и бега. Если перед камерой стена — правая
## подтягивает светильник к груди, левая прижимается к телу.
## Сам IK — модификатор скелета (_ArmIK): он работает после анимации, каждый кадр.
## Голова кивает вместе с камерой (кость Head) — это видно по тени. Старые руки — hero_arms_proc.gd.

## Светильник достали (true) или убрали (false). Срабатывает в начале анимации.
signal lamp_changed(out: bool)

## Длительность анимации «достать / убрать», с.
@export var lamp_anim_time := 0.45
## Как далеко перед камерой искать стену, м.
@export var wall_check_distance := 0.7
## Стена ближе этого — руки начинают подтягиваться; ближе wall_pull_full — подтянуты полностью.
@export var wall_pull_start := 0.6
@export var wall_pull_full := 0.25
@export var body_path: NodePath = ^"../../../Body"
@export var lamp_path: NodePath = ^"../../../Body/OilLamp"

## Светильник в кадре (в пространстве камеры): обычно и подтянутый к груди у стены.
const LAMP_HELD := Transform3D(Basis(Vector3(0.5, 0.3244, -0.803), Vector3(0.0, 0.9272, 0.3746), Vector3(0.866, -0.1873, 0.4636)), Vector3(0.14, -0.13, -0.36))
const LAMP_PULLED := Transform3D(Basis(Vector3(0.5, 0.3244, -0.803), Vector3(0.0, 0.9272, 0.3746), Vector3(0.866, -0.1873, 0.4636)), Vector3(0.21, -0.07, -0.19))
## Ладонь под светильником: от запястья вперёд по пальцам и вниз от дна светильника, м.
const PALM_FORWARD := 0.075
const PALM_BELOW := 0.025
## Сгиб пальцев (указательный — «варежка»), градусов: пустая рука и рука со светильником.
const FINGERS_HOLD := 50.0
## Левая кисть у стены: от груди (кость UpperChest) в осях тела, м.
const LEFT_PRESSED := Vector3(-0.13, -0.33, -0.16)
## Наклон головы вслед за камерой: доля на кость Head (остальное — анимация шеи).
const HEAD_FOLLOW := 0.8

## В руке ли светильник. Сохранять — через GameState.lamp_out (это делает Player).
var lamp_out := true
## Насколько поднят светильник: 0 — убран, 1 — в руке.
var raise := 1.0

var _tween: Tween
var _pull := 0.0
## Кисть (кость RightHand, начало — запястье) относительно светильника.
var _hand_from_lamp: Transform3D
var _probe := SphereShape3D.new()
var _ik: _ArmIK
var _bones := {}

@onready var _camera: Camera3D = get_parent()
@onready var _body: HeroBody = get_node(body_path)
@onready var _lamp: Node3D = get_node(lamp_path)


## Модификатор скелета: вызывает руки после того, как анимация поставила позу.
class _ArmIK:
	extends SkeletonModifier3D
	var arms: Node

	func _process_modification_with_delta(_delta: float) -> void:
		arms._apply()


func _ready() -> void:
	_probe.radius = 0.12
	var skel := _body.skeleton
	for side in ["Left", "Right"]:
		for b in ["UpperArm", "LowerArm", "Hand", "IndexProximal", "IndexIntermediate", "IndexDistal"]:
			_bones[side + b] = skel.find_bone(side + b)
	for b in ["Head", "UpperChest", "Spine"]:
		_bones[b] = skel.find_bone(b)
	# Оси кисти по геометрии модели (оси костей после ретаргета — от Т-позы, а модель в A-позе):
	# пальцы — к указательному пальцу, ладонь в позе покоя смотрит к бедру (+X у правой руки).
	var hand := _bones["RightHand"] as int
	var fingers_l := skel.get_bone_rest(_bones["RightIndexProximal"]).origin.normalized()
	var palm_l := skel.get_bone_global_rest(hand).basis.inverse() * Vector3.RIGHT
	var hand_geo := _frame(fingers_l, palm_l)
	# В кадре: ладонь вверх под светильником, пальцы вперёд и чуть влево.
	var fingers := Basis(Vector3.UP, deg_to_rad(20.0)) * Vector3.FORWARD
	var palm := Vector3.UP
	var hand_basis := _frame(fingers, palm) * hand_geo.inverse()
	var wrist := LAMP_HELD.origin - fingers * PALM_FORWARD - palm * PALM_BELOW
	_hand_from_lamp = LAMP_HELD.affine_inverse() * Transform3D(hand_basis, wrist)
	_ik = _ArmIK.new()
	_ik.name = "ArmIK"
	_ik.arms = self
	skel.add_child(_ik)


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
	_pull = lerpf(_pull, _wall_pull(), 1.0 - exp(-10.0 * delta))
	_lamp.visible = raise > 0.02
	_lamp.intensity = raise


## Поза рук поверх анимации (из модификатора скелета).
func _apply() -> void:
	var skel := _body.skeleton
	var to_skel := skel.global_transform.affine_inverse()
	var body_basis := to_skel.basis * _body.global_basis

	# Глядя в пол, корпус отклоняется назад (hero_body.gd), голова кивает вслед за камерой (видно по тени)
	var right := (body_basis * Vector3.RIGHT).normalized()
	var spine: int = _bones["Spine"]
	_set_global_basis(spine, Basis(right, _body.lean_back()) * skel.get_bone_global_pose(spine).basis)
	var hb: int = _bones["Head"]
	var head_g := skel.get_bone_global_pose(hb)
	var nod := Basis(right, _body.pitch * HEAD_FOLLOW - _body.lean_back())
	_set_global_basis(hb, nod * head_g.basis)

	# Правая: от позы анимации к светильнику в кадре
	if raise > 0.001:
		var lamp_cam := LAMP_HELD.interpolate_with(LAMP_PULLED, _pull)
		var held := to_skel * _camera.global_transform * lamp_cam * _hand_from_lamp
		var pole := body_basis * Vector3(0.7, -1.0, 0.25)
		_solve_arm("Right", held, pole, false, raise)
		_curl("Right", FINGERS_HOLD * raise)

	# Левая: у стены прижимается к телу
	if _pull > 0.001:
		var chest := skel.get_bone_global_pose(_bones["UpperChest"]).origin
		var target := Transform3D(Basis(), chest + body_basis * LEFT_PRESSED)
		_solve_arm("Left", target, body_basis * Vector3(-0.6, -1.0, 0.4), true, _pull)

	# Светильник лежит в настоящей кисти, даже если рука не дотянулась
	var hand := skel.get_bone_global_pose(_bones["RightHand"])
	_lamp.global_transform = skel.global_transform * hand * _hand_from_lamp.affine_inverse()


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


## Двухзвенный IK в пространстве скелета: плечо → локоть → запястье. pole — куда смотрит локоть.
## Кости поворачиваются по кратчайшей дуге от позы анимации (без лишнего скручивания).
## hand_follows — кисть едет вместе с предплечьем, иначе берёт поворот из target.
## weight — доля IK поверх позы анимации (0 — анимация, 1 — IK).
func _solve_arm(side: String, target: Transform3D, pole: Vector3, hand_follows: bool, weight: float) -> void:
	var skel := _body.skeleton
	var ua: int = _bones[side + "UpperArm"]
	var fa: int = _bones[side + "LowerArm"]
	var hb: int = _bones[side + "Hand"]
	var a := skel.get_bone_rest(fa).origin.length()
	var b := skel.get_bone_rest(hb).origin.length()
	var parent_g := skel.get_bone_global_pose(skel.get_bone_parent(ua))
	var ua_g := skel.get_bone_global_pose(ua)
	var fa_g := skel.get_bone_global_pose(fa)
	var hb_g := skel.get_bone_global_pose(hb)
	var shoulder := ua_g.origin
	var to_target := target.origin - shoulder
	var d := clampf(to_target.length(), 0.05, (a + b) * 0.999)
	var dir := to_target.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var out := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * a * cos_a + out * a * sqrt(1.0 - cos_a * cos_a)
	var wrist := shoulder + dir * d
	var ua_new := _turn(fa_g.origin - ua_g.origin, elbow - shoulder) * ua_g.basis.orthonormalized()
	var fa_cur := ua_new * ua_g.basis.orthonormalized().inverse() * fa_g.basis.orthonormalized()
	var fa_new := _turn(fa_cur * skel.get_bone_rest(hb).origin, wrist - elbow) * fa_cur
	var hb_new: Basis
	if hand_follows:
		hb_new = fa_new * fa_g.basis.orthonormalized().inverse() * hb_g.basis.orthonormalized()
	else:
		hb_new = target.basis.orthonormalized()
	# Смешать с анимацией и записать локальные повороты по цепочке
	ua_new = ua_g.basis.orthonormalized().slerp(ua_new, weight)
	fa_new = fa_g.basis.orthonormalized().slerp(fa_new, weight)
	hb_new = hb_g.basis.orthonormalized().slerp(hb_new, weight)
	skel.set_bone_pose_rotation(ua, (parent_g.basis.orthonormalized().inverse() * ua_new).get_rotation_quaternion())
	skel.set_bone_pose_rotation(fa, (ua_new.inverse() * fa_new).get_rotation_quaternion())
	skel.set_bone_pose_rotation(hb, (fa_new.inverse() * hb_new).get_rotation_quaternion())


## Поворот по кратчайшей дуге от направления from к to.
func _turn(from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	if f.dot(t) > 0.99999:
		return Basis()
	if f.dot(t) < -0.9999:
		return Basis(f.cross(Vector3.UP).normalized(), PI)
	return Basis(Quaternion(f, t))


## Базис по двум направлениям: X — a, Y — h (без составляющей вдоль a).
func _frame(a: Vector3, h: Vector3) -> Basis:
	var x := a.normalized()
	var y := (h - x * h.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _set_global_basis(bone_idx: int, global_basis: Basis) -> void:
	var skel := _body.skeleton
	var parent_basis := skel.get_bone_global_pose(skel.get_bone_parent(bone_idx)).basis.orthonormalized()
	skel.set_bone_pose_rotation(bone_idx, (parent_basis.inverse() * global_basis).get_rotation_quaternion())


## Указательный палец («варежка» — вся кисть одним блоком) сгибается к ладони вокруг своей +X.
func _curl(side: String, deg: float) -> void:
	var skel := _body.skeleton
	for b in ["IndexProximal", "IndexIntermediate", "IndexDistal"]:
		var i: int = _bones[side + b]
		skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, deg_to_rad(deg / 3.0)))
