extends Node3D
## Руки героя (CLAUDE.md §8) — кости модели hero (скелет Mixamo), поверх мокап-анимации тела (hero_body.gd).
## Двухзвенный IK от плеча до кисти: RightUpperArm → RightLowerArm → RightHand (у левой так же).
## Правая держит светильник снизу: ладонь горизонтально под дном, запястье прямое (пальцы — по направлению
## предплечья), кончики пальцев чуть подогнуты к глине. Локоть согнут ~90–100°.
## Место светильника задаётся от груди (кость Chest, в осях тела): lamp_offset — обычно (перед грудью, чуть
## вправо, на высоте нижних рёбер; глядя прямо огонёк и носик — в правом нижнем углу кадра), lamp_offset_run —
## на бегу, lamp_offset_wall — стена перед лицом. Светильник догоняет это место пружиной (lamp_spring,
## lamp_damping) — качается вместе с телом, с инерцией, без рывков руки; держится ровно (масло не льётся).
## F — достать / убрать: рука плавно уходит из позы анимации к светильнику и обратно, пока анимация идёт,
## повторное нажатие игнорируется. Левая свободна — машет так, как в анимации (на бегу локоть согнут сильнее —
## кисть заходит в кадр снизу слева); у стены прижимается к телу.
## Сам IK — модификатор скелета (_ArmIK): он работает после анимации и после позвоночника (hero_body.gd).
## Старые руки — hero_arms_proc.gd.

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

@export_group("Светильник")
## Где светильник (середина дна) относительно груди, м: x — вправо, y — вверх, z — назад (вперёд — минус).
@export var lamp_offset := Vector3(0.15, 0.23, -0.43)
## На бегу (корпус наклонён вперёд — светильник выше по груди).
@export var lamp_offset_run := Vector3(0.22, 0.4, -0.36)
## В приседе.
@export var lamp_offset_crouch := Vector3(0.24, 0.02, -0.5)
## Стена перед лицом — к груди.
@export var lamp_offset_wall := Vector3(0.1, 0.1, -0.19)
## Носик повёрнут влево от «вперёд», град.
@export var lamp_yaw := 8.0
## Пружина: собственная частота, рад/с (больше — жёстче), и затухание (1 — без перелёта).
@export var lamp_spring := 14.0
@export var lamp_damping := 0.55

@export_group("Кисть")
## Ладонь под светильником: середина дна — на столько вперёд по пальцам от запястья и над осью кисти, м.
@export var palm_forward := 0.065
@export var palm_up := 0.027
## Пальцы — по предплечью (запястье прямое) плюс столько влево, град.
@export var fingers_yaw := 0.0
## Сгиб пальцев («варежка» — указательный палец модели), град: кончики подогнуты к глине снизу.
@export var finger_curl := 12.0
## На бегу левый локоть сгибается сильнее, град, а кисть выше и впереди, чем в анимации, м (в осях тела):
## рука работает, как у бегущего, и на махе вперёд заходит в кадр снизу слева.
@export var left_run_flex := 30.0
@export var left_run_lift := Vector3(0.0, 0.1, -0.08)

## Левая кисть у стены: от груди (кость UpperChest) в осях тела, м.
const LEFT_PRESSED := Vector3(-0.13, -0.33, -0.16)

## В руке ли светильник. Сохранять — через GameState.lamp_out (это делает Player).
var lamp_out := true
## Насколько поднят светильник: 0 — убран, 1 — в руке.
var raise := 1.0

var _tween: Tween
var _pull := 0.0
var _run := 0.0
var _hand_geo: Basis
var _probe := SphereShape3D.new()
var _ik: _ArmIK
var _bones := {}
var _chest_rest: Basis
## Светильник в осях Player: положение, скорость пружины.
var _lamp_pos := Vector3.ZERO
var _lamp_vel := Vector3.ZERO
var _lamp_ready := false
## Направление предплечья правой руки (в осях Player, по горизонтали) — пальцы по нему.
var _forearm := Vector3.FORWARD

@onready var _camera: Camera3D = get_parent()
@onready var _body: HeroBody = get_node(body_path)
@onready var _lamp: Node3D = get_node(lamp_path)
@onready var _player: Player = owner as Player


## Модификатор скелета: вызывает руки после того, как анимация и позвоночник поставили позу.
class _ArmIK:
	extends SkeletonModifier3D
	var arms: Node

	func _process_modification_with_delta(delta: float) -> void:
		arms._apply(delta)


func _ready() -> void:
	_probe.radius = 0.12
	var skel := _body.skeleton
	for side in ["Left", "Right"]:
		for b in ["UpperArm", "LowerArm", "Hand", "IndexProximal", "IndexIntermediate", "IndexDistal"]:
			_bones[side + b] = skel.find_bone(side + b)
	for b in ["Chest", "UpperChest"]:
		_bones[b] = skel.find_bone(b)
	_chest_rest = skel.get_bone_global_rest(_bones["Chest"]).basis.orthonormalized()
	# Оси кисти по геометрии модели (оси костей после ретаргета — от Т-позы, а модель в A-позе):
	# пальцы — к указательному пальцу, ладонь в позе покоя смотрит к бедру (+X у правой руки).
	var hand := _bones["RightHand"] as int
	var fingers_l := skel.get_bone_rest(_bones["RightIndexProximal"]).origin.normalized()
	var palm_l := skel.get_bone_global_rest(hand).basis.inverse() * Vector3.RIGHT
	_hand_geo = _frame(fingers_l, palm_l)
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
	var running := _player != null and _player.move_mode == Player.MoveMode.RUN
	_run = lerpf(_run, 1.0 if running else 0.0, 1.0 - exp(-5.0 * delta))
	_lamp.visible = raise > 0.02
	_lamp.intensity = raise


## Кисть относительно светильника: ладонь горизонтально под дном, пальцы — на fingers_rel (рад) левее носика.
func _hand_from_lamp(fingers_rel := 0.0) -> Transform3D:
	var fingers := Basis(Vector3.UP, fingers_rel) * Vector3.FORWARD
	var palm := Vector3.UP
	var hand_basis := _frame(fingers, palm) * _hand_geo.inverse()
	var wrist := -fingers * palm_forward - palm * palm_up
	return Transform3D(hand_basis, wrist)


## Поза рук поверх анимации (из модификатора скелета).
func _apply(delta: float) -> void:
	var skel := _body.skeleton
	var to_skel := skel.global_transform.affine_inverse()
	var body_basis := to_skel.basis * _body.global_basis

	# Место светильника: от груди, в осях тела, повёрнутых так же, как грудь (анимация + скрутка + наклон):
	# рука растёт из груди — наклонился, и светильник ушёл вперёд и вниз.
	var chest := skel.get_bone_global_pose(_bones["Chest"])
	var chest_rot := chest.basis.orthonormalized() * _chest_rest.inverse()
	var frame := chest_rot * body_basis
	var crouch_w := clampf(_body.weight("crouch_walk") + _body.weight("crouch_idle"), 0.0, 1.0)
	if crouch_w > 0.0:
		# В приседе грудь в анимациях сильно наклонена и повёрнута (crouch_walk — почти на 50° вправо),
		# а светильник держат перед собой ровно: оси тела + доля скрутки взгляда, что ушла в позвоночник
		var up := (body_basis * Vector3.UP).normalized()
		var spine_twist := 0.0
		for t: float in HeroBody.TWIST_SPINE:
			spine_twist += t
		var level := Basis(up, _body.twist * spine_twist) * body_basis
		frame = Basis(frame.get_rotation_quaternion().slerp(level.get_rotation_quaternion(), crouch_w))
	var offset := lamp_offset.lerp(lamp_offset_run, _run).lerp(lamp_offset_crouch, crouch_w).lerp(lamp_offset_wall, _pull)
	var target_world := skel.global_transform * (chest.origin + frame * offset)
	var target := _player.to_local(target_world)
	if not _lamp_ready:
		_lamp_pos = target
		_lamp_vel = Vector3.ZERO
		_lamp_ready = true
	# Пружина (полунеявный Эйлер, шагами не длиннее 1/120 с)
	var steps := ceili(delta * 120.0)
	var dt := delta / maxf(steps, 1)
	for i in steps:
		var acc := (target - _lamp_pos) * lamp_spring * lamp_spring - _lamp_vel * 2.0 * lamp_damping * lamp_spring
		_lamp_vel += acc * dt
		_lamp_pos += _lamp_vel * dt
	# Держится ровно: только поворот вокруг вертикали — куда смотрит грудь, носик чуть влево
	var fwd := skel.global_transform.basis * (frame * Vector3.FORWARD)
	var yaw := atan2(-fwd.x, -fwd.z) + deg_to_rad(lamp_yaw)
	var lamp_xf := Transform3D(Basis(Vector3.UP, yaw), _player.to_global(_lamp_pos))
	# Запястье прямое: пальцы по предплечью (с прошлого кадра), относительно носика
	var fa_world := _player.global_basis * _forearm
	var fingers_rel := wrapf(atan2(-fa_world.x, -fa_world.z) - yaw + deg_to_rad(fingers_yaw), -PI, PI)
	fingers_rel = clampf(fingers_rel, deg_to_rad(-60.0), deg_to_rad(60.0))
	var hand_from_lamp := _hand_from_lamp(fingers_rel)

	# Правая: от позы анимации к светильнику
	if raise > 0.001:
		var held := to_skel * lamp_xf * hand_from_lamp
		var pole := body_basis * Vector3(0.8, -1.0, 0.35)
		_solve_arm("Right", held, pole, false, raise)
		_curl("Right", finger_curl * raise)
		var fa := skel.get_bone_global_pose(_bones["RightHand"]).origin - skel.get_bone_global_pose(_bones["RightLowerArm"]).origin
		var fa_p := _player.global_basis.inverse() * (skel.global_basis * fa)
		fa_p.y = 0.0
		if fa_p.length() > 0.02:
			_forearm = _forearm.slerp(fa_p.normalized(), 1.0 - exp(-12.0 * delta))

	# Левая на бегу: локоть согнут сильнее
	var run_w := _body.weight("run") + _body.weight("run_back") * 0.5
	if run_w > 0.01 and _pull < 0.99:
		var w := run_w * (1.0 - _pull)
		_flex("Left", left_run_flex * w)
		var lh := skel.get_bone_global_pose(_bones["LeftHand"])
		# Вперёд-вверх сильнее на махе вперёд: насколько кисть уже впереди плеча
		var sh := skel.get_bone_global_pose(_bones["LeftUpperArm"]).origin
		var ahead := clampf(-(body_basis.inverse() * (lh.origin - sh)).z / 0.25 + 0.5, 0.0, 1.0)
		var lift := body_basis * (left_run_lift * (0.4 + 0.6 * ahead))
		_solve_arm("Left", Transform3D(lh.basis, lh.origin + lift), body_basis * Vector3(-0.6, -1.0, 0.4), true, w)

	# Левая: у стены прижимается к телу
	if _pull > 0.001:
		var uc := skel.get_bone_global_pose(_bones["UpperChest"]).origin
		var left := Transform3D(Basis(), uc + body_basis * LEFT_PRESSED)
		_solve_arm("Left", left, body_basis * Vector3(-0.6, -1.0, 0.4), true, _pull)

	# Светильник лежит в настоящей кисти, даже если рука не дотянулась
	var hand := skel.get_bone_global_pose(_bones["RightHand"])
	_lamp.global_transform = skel.global_transform * hand * hand_from_lamp.affine_inverse()


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


## Согнуть локоть сильнее на deg (в плоскости плечо — локоть — кисть).
func _flex(side: String, deg: float) -> void:
	var skel := _body.skeleton
	var ua := skel.get_bone_global_pose(_bones[side + "UpperArm"])
	var fa := skel.get_bone_global_pose(_bones[side + "LowerArm"])
	var hand := skel.get_bone_global_pose(_bones[side + "Hand"]).origin
	var upper := fa.origin - ua.origin
	var lower := hand - fa.origin
	var axis := upper.cross(lower)
	if axis.length() < 1e-4:
		return
	# Сгиб — поворот предплечья к плечу: от lower к -upper
	var rot := Basis(axis.normalized(), deg_to_rad(deg))
	var fa_new := rot * fa.basis.orthonormalized()
	skel.set_bone_pose_rotation(_bones[side + "LowerArm"], (ua.basis.orthonormalized().inverse() * fa_new).get_rotation_quaternion())


## Указательный палец («варежка» — вся кисть одним блоком) сгибается к ладони вокруг своей +X.
func _curl(side: String, deg: float) -> void:
	var skel := _body.skeleton
	for b in ["IndexProximal", "IndexIntermediate", "IndexDistal"]:
		var i: int = _bones[side + b]
		skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, deg_to_rad(deg / 3.0)))
