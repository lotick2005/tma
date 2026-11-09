class_name HeroBody
extends Node3D
## Тело героя от первого лица (CLAUDE.md §8, «как в Dark Messiah»): модель models/hero.glb на скелете Mixamo,
## мокап-анимации (Anims), камера — в голове.
##
## • Тело отдельно от взгляда. Узел Player повёрнут туда, куда смотрит мышь; узел Body (этот) — туда, куда стоит тело.
##   Разница («скрутка») раскладывается по позвоночнику: Spine → Chest → UpperChest, остаток добирают шея и голова,
##   и голова всегда смотрит туда же, куда камера. Стоя тело не крутится за мышью; дальше turn_threshold тело
##   переступает (шаги вбок) и доворачивается. На ходу тело за turn_time_moving доворачивается к взгляду,
##   ноги — walk / walk_back / strafe / run относительно тела. Взгляд вниз-вверх — наклон позвоночника и шеи.
## • Камера — на кости Head (eye_forward / eye_up в осях головы), со сглаживанием camera_smooth: качается сама,
##   от анимации. По горизонтали не дальше camera_max_offset от оси капсулы — иначе тело чуть отходит назад
##   (бег и присед наклоняют корпус вперёд, а камера не должна уйти в стену).
## • Своё тело не рисуется ближе hide_radius к камере (near_discard в psx_lit), тень — от отдельного целого меша.
## • Стойка: конец walk_stop (ноги на ширине плеч, руки вдоль тела) + дыхание грудью (в библиотеке нет idle_breathing,
##   а idle — боевая стойка). Присед стоя — кадр crouch_walk, где обе ступни на земле (crouch_idle нет).
## • Шаги — по касанию ступней (кость стопы опустилась к земле): сигнал foot_down.
## Меш делится по весам костей: тело (BODY_LAYER), руки (VIEW_LAYER, подсветка огнём), голова с шеей (видна только
## катсцене с камерой вне глаз), плюс целый меш только для тени. Подол туники перевешен на таз и бёдра.
## Руки и светильник (IK) — hero_arms.gd, поверх. Старое процедурное тело — hero_body_proc.gd (выключено).

## Ступня встала на землю.
signal foot_down

@export_group("Камера")
## Глаза относительно кости Head в позе покоя, м: вперёд (лицо — ≈0,12) и вверх.
@export var eye_forward := 0.12
@export var eye_up := 0.095
## Сглаживание камеры, 1/с (больше — жёстче за головой).
@export var camera_smooth := 20.0
## Камера не дальше этого от оси капсулы по горизонтали, м: обычно и глядя в пол (голова уходит вперёд
## над ступнями — иначе ноги закрывает живот).
@export var camera_max_offset := 0.2
@export var camera_max_offset_down := 0.32
## Своё тело не рисуется ближе этого к камере, м.
@export var hide_radius := 0.2

@export_group("Поворот тела")
## Стоя: тело доворачивается, когда взгляд ушёл дальше этого угла, град.
@export var turn_threshold := 90.0
## …и останавливается, когда до взгляда осталось столько, град.
@export var turn_stop := 6.0
## Скорость поворота на месте, град/с.
@export var turn_rate := 300.0
## На ходу тело доворачивается к взгляду примерно за столько секунд.
@export var turn_time_moving := 0.25
## Больше этого тело от взгляда не отстаёт никогда (рывок мышью), град.
@export var max_twist := 120.0

@export_group("Прочее")
## Дыхание стоя: наклон груди, град, и период, с.
@export var breath_deg := 1.3
@export var breath_period := 4.2
## Насколько огонь светильника подсвечивает руки (0..1). Свой светильник светит на руки
## не напрямую (вплотную кисть пересвечена), а этой ровной тёплой подсветкой.
@export_range(0.0, 1.0) var lamp_glow := 0.9
## Смешивание анимаций: за сколько секунд веса доходят до нужных.
@export var blend_time := 0.18

## Анимации движения. stand и crouch_still — позы (библиотека "hero", собираются из кадров при старте).
const CLIPS := ["stand", "walk", "walk_back", "strafe_left", "strafe_right", "run", "run_back", "crouch_walk",
	"crouch_still"]
## Стойка — последний кадр walk_stop; присед стоя — кадр crouch_walk, где обе ступни на земле.
const STAND_FROM := ["walk_stop", 3.0]
const CROUCH_FROM := ["crouch_walk", 0.8]
## Доли скрутки и наклона по позвоночнику (Spine, Chest, UpperChest); остальное — шея и голова.
const TWIST_SPINE := [0.15, 0.15, 0.2]
const PITCH_DOWN_SPINE := [0.2, 0.2, 0.2]
const PITCH_UP_SPINE := [0.03, 0.04, 0.08]
## Доля оставшегося поворота головы, которую берёт шея.
const NECK_SHARE := 0.4
## Больше этого шея с головой не поворачиваются относительно груди, град.
const HEAD_LIMIT := 95.0
## Подол: от таза (вершины выше — только таз) до края туники, м над землёй (по модели hero).
const SKIRT_TOP := 0.86
const SKIRT_HEM := 0.47
## Доля ног у края подола (остальное — таз).
const SKIRT_LEGS := 0.6
## Ступня на земле: кость стопы ниже FOOT_DOWN над подошвой; снова в воздухе — выше FOOT_UP, м.
const FOOT_DOWN := 0.128
const FOOT_UP := 0.145

var model: CharacterModel
var skeleton: Skeleton3D
## Скрутка: насколько взгляд левее тела, рад (плюс — влево).
var twist := 0.0
## Тело переступает на месте.
var turning := false
## Доля стойки на месте (0 — идёт) — для дыхания и рук.
var still := 1.0

var _player: Player
var _body_yaw := 0.0
var _yaw_ready := false
var _turn_dir := 0.0
var _world_vel := Vector3.ZERO
var _crouched := false
var _walk_speed := 2.2
var _run_speed := 4.6
var _tree: AnimationTree
var _weights := {}
var _head_mesh: MeshInstance3D
var _body_mats: Array[ShaderMaterial] = []
var _arms_mat: ShaderMaterial
var _head_visible := false
var _bones := {}
var _head_fwd_l := Vector3.FORWARD
var _head_up_l := Vector3.UP
var _head_rest: Transform3D
var _shift := Vector2.ZERO
var _step_offset := 0.0
var _cam_pos := Vector3.ZERO
var _cam_ready := false
var _time := 0.0
var _foot_up := [true, true]
var _delta := 0.016

@onready var _lamp: Node3D = $OilLamp


## Модификатор скелета: позвоночник, голова и камера — после анимации, каждый кадр (руки — после него).
class _BodyMod:
	extends SkeletonModifier3D
	var body: Node

	func _process_modification_with_delta(delta: float) -> void:
		body._apply(delta)


func _ready() -> void:
	_player = get_parent() as Player
	model = CharacterModel.new()
	model.name = "Model"
	model.model = "hero"
	add_child(model)
	model.build()
	skeleton = model.skeleton
	for b in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftFoot", "RightFoot"]:
		_bones[b] = skeleton.find_bone(b)
	# Лицо модели — +Z скелета (модель повёрнута на 180°)
	_head_rest = skeleton.get_bone_global_rest(_bones["Head"])
	_head_fwd_l = (_head_rest.basis.inverse() * Vector3.BACK).normalized()
	_head_up_l = (_head_rest.basis.inverse() * Vector3.UP).normalized()
	_build_meshes()
	_build_tree()
	var mod := _BodyMod.new()
	mod.name = "BodyMod"
	mod.body = self
	skeleton.add_child(mod)


func _build_meshes() -> void:
	var src := model.mesh_instance
	var sk := skeleton
	var hips := sk.find_bone("Hips")
	var leg_l := sk.find_bone("LeftUpperLeg")
	var leg_r := sk.find_bone("RightUpperLeg")
	# Подол: вершины туники между тазом и краем — на таз и обе ноги, ближняя нога весит больше
	var skirt := func(p: Vector3, w: Dictionary) -> Variant:
		if p.y > SKIRT_TOP + 0.02 or p.y < SKIRT_HEM - 0.03:
			return null
		var lower := 0.0
		for b in [hips, leg_l, leg_r]:
			lower += float(w.get(b, 0.0))
		if lower < 0.6:
			return null  # кисти у бёдер не трогаем
		var d := clampf((SKIRT_TOP - p.y) / (SKIRT_TOP - SKIRT_HEM), 0.0, 1.0)
		var legs := SKIRT_LEGS * smoothstep(0.0, 1.0, d)
		var left := smoothstep(-0.09, 0.09, p.x)  # левая нога — +X модели
		return {hips: 1.0 - legs, leg_l: legs * (0.15 + 0.7 * left), leg_r: legs * (0.15 + 0.7 * (1.0 - left))}
	var mesh := CharacterModel.reweight(src.mesh, skirt)
	var head_bones := [sk.find_bone("Neck"), sk.find_bone("Head"), sk.find_bone("mixamorig_HeadTop_End")]
	var arm_bones := []
	for side in ["Left", "Right"]:
		for b in ["UpperArm", "LowerArm", "Hand", "IndexProximal", "IndexIntermediate", "IndexDistal"]:
			arm_bones.append(sk.find_bone(side + b))
		arm_bones.append(sk.find_bone("mixamorig_%sHandIndex4" % side))
	# 0 — тело, 1 — руки, 2 — голова
	var classify := func(w: Dictionary) -> int:
		var head := 0.0
		var arm := 0.0
		for b in w:
			if b in head_bones:
				head += w[b]
			elif b in arm_bones:
				arm += w[b]
		if head > 0.5:
			return 2
		return 1 if arm > 0.5 else 0
	var parts := CharacterModel.split_mesh(mesh, 3, classify)
	var body_layer := 1 << (Player.BODY_LAYER - 1)

	# Тень — целый меш (с головой), сам не рисуется
	var shadow := _skinned("Shadow", mesh, CharacterModel.material("hero"), body_layer)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	# Видимое тело: без тени, ближе hide_radius к камере не рисуется
	var body_mat: ShaderMaterial = CharacterModel.material("hero").duplicate()
	_body_mats.append(body_mat)
	src.mesh = parts[0]
	src.layers = body_layer
	src.material_override = body_mat
	src.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_arms_mat = CharacterModel.material("hero").duplicate()
	_arms_mat.set_shader_parameter("self_illum_shade", 0.0)
	_arms_mat.set_shader_parameter("self_illum_color", _lamp.light_color)
	_body_mats.append(_arms_mat)
	_skinned("Arms", parts[1], _arms_mat, 1 << (Player.VIEW_LAYER - 1))

	# Голова с шеей — только для камеры вне глаз (катсцена, клавиша 6)
	var head_mat: ShaderMaterial = CharacterModel.material("hero").duplicate()
	_body_mats.append(head_mat)
	_head_mesh = _skinned("Head", parts[2], head_mat, body_layer)
	_head_mesh.visible = false
	_update_discard()


func _skinned(node_name: String, mesh: Mesh, mat: Material, layers: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.skin = model.mesh_instance.skin
	mi.skeleton = ^".."
	mi.layers = layers
	mi.extra_cull_margin = 1.5
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mi)
	return mi


## Дерево: каждая анимация → (перемотка) → своя скорость (TimeScale) → цепочка Blend2 с весами из _update_blend.
func _build_tree() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("stand", Anims.pose_from(STAND_FROM[0], STAND_FROM[1]))
	lib.add_animation("crouch_still", Anims.pose_from(CROUCH_FROM[0], CROUCH_FROM[1]))
	var bt := AnimationNodeBlendTree.new()
	var prev := ""
	for i in CLIPS.size():
		var c: String = CLIPS[i]
		var a := AnimationNodeAnimation.new()
		a.animation = ("hero/" + c) if c in ["stand", "crouch_still"] else c
		bt.add_node("a_" + c, a, Vector2(0, i * 120))
		var src := "a_" + c
		if c == "crouch_walk":
			# Трогается с места из присяда — с того же кадра, что и поза crouch_still
			bt.add_node("seek_" + c, AnimationNodeTimeSeek.new(), Vector2(100, i * 120))
			bt.connect_node("seek_" + c, 0, src)
			src = "seek_" + c
		bt.add_node("s_" + c, AnimationNodeTimeScale.new(), Vector2(200, i * 120))
		bt.connect_node("s_" + c, 0, src)
		if i == 0:
			prev = "s_" + c
		else:
			var b := AnimationNodeBlend2.new()
			bt.add_node("b_" + c, b, Vector2(400 + i * 100, i * 120))
			bt.connect_node("b_" + c, 0, prev)
			bt.connect_node("b_" + c, 1, "s_" + c)
			prev = "b_" + c
		_weights[c] = 1.0 if c == "stand" else 0.0
	bt.connect_node("output", 0, prev)
	_tree = AnimationTree.new()
	_tree.name = "AnimTree"
	model.anim.get_parent().add_child(_tree)
	_tree.root_node = ^".."
	_tree.add_animation_library("", Anims.library())
	_tree.add_animation_library("hero", lib)
	_tree.tree_root = bt
	_tree.root_motion_track = Anims.ROOT_TRACK
	# Плеер модели больше не нужен: двигает дерево
	model.anim.active = false
	_tree.active = true


## Голову обычно не видно (камера в ней). Катсцена с камерой вне глаз и клавиша 6 показывают её.
func set_head_visible(on: bool) -> void:
	_head_visible = on
	if _head_mesh:
		_head_mesh.visible = on
	_update_discard()


func _update_discard() -> void:
	for m in _body_mats:
		m.set_shader_parameter("near_discard", 0.0 if _head_visible else hide_radius)


## Скорость (мировая) и присед — для выбора анимаций и поворота тела.
func set_motion(world_velocity: Vector3, crouched: bool, walk_speed: float, run_speed: float) -> void:
	_world_vel = Vector3(world_velocity.x, 0.0, world_velocity.z)
	_crouched = crouched
	_walk_speed = walk_speed
	_run_speed = run_speed


## Герой шагнул вверх на rise (порог, ступень): тело и камера догоняют плавно.
func add_step(rise: float) -> void:
	_step_offset -= rise


## Сразу поставить тело по взгляду и камеру в глаза (после телепорта, set_look катсцены не нужен).
func snap() -> void:
	_yaw_ready = false
	_cam_ready = false


func _process(delta: float) -> void:
	_delta = delta
	_time += delta
	_arms_mat.set_shader_parameter("self_illum", _lamp.glow * lamp_glow)
	_update_discard()
	_update_turn(delta)
	_update_blend(delta)
	_step_offset *= exp(-10.0 * delta)
	var shift := basis.inverse() * Vector3(_shift.x, 0.0, _shift.y)
	model.position = Vector3(shift.x, _step_offset, shift.z)


## Тело и взгляд: стоя — тело стоит, пока взгляд не ушёл дальше turn_threshold; на ходу — догоняет взгляд.
func _update_turn(delta: float) -> void:
	if _player == null:
		return
	var look := _player.global_rotation.y
	if not _yaw_ready:
		_body_yaw = look
		_yaw_ready = true
	var tw := wrapf(look - _body_yaw, -PI, PI)
	var moving := _world_vel.length() > 0.3
	_turn_dir = 0.0
	if moving:
		turning = false
		_body_yaw = lerp_angle(_body_yaw, look, 1.0 - exp(-3.0 * delta / maxf(turn_time_moving, 0.01)))
	else:
		if not turning and absf(tw) > deg_to_rad(turn_threshold):
			turning = true
		if turning:
			var step := minf(absf(tw), deg_to_rad(turn_rate) * delta) * signf(tw)
			_body_yaw += step
			_turn_dir = signf(tw)
			if absf(tw - step) < deg_to_rad(turn_stop):
				turning = false
	tw = wrapf(look - _body_yaw, -PI, PI)
	var lim := deg_to_rad(max_twist)
	if absf(tw) > lim:
		_body_yaw = look - signf(tw) * lim
		tw = signf(tw) * lim
	_body_yaw = wrapf(_body_yaw, -PI, PI)
	twist = tw
	rotation.y = -tw


func _update_blend(delta: float) -> void:
	# Скорость в осях тела: x — вправо, y — вперёд
	var lv := global_basis.inverse() * _world_vel
	var v := Vector2(lv.x, -lv.z)
	var speed := v.length()
	var move := smoothstep(0.05, 0.6, speed)
	# Переступает на месте — шаги вбок в сторону поворота
	var turn_w := 0.0
	if _turn_dir != 0.0 and move < 0.5:
		turn_w = 0.75
	var target := {}
	for c in CLIPS:
		target[c] = 0.0
	var scale := {}
	if _crouched:
		var cm := maxf(move, turn_w)
		target["crouch_still"] = 1.0 - cm
		target["crouch_walk"] = cm
		var sp := speed if move > turn_w else 0.9
		# Назад в приседе — та же ходьба задом наперёд
		scale["crouch_walk"] = clampf(Anims.scale_for("crouch_walk", sp), 0.3, 2.0) * (-1.0 if v.y < -0.1 else 1.0)
		if _weights["crouch_walk"] < 0.05:
			_tree.set("parameters/seek_crouch_walk/seek_request", CROUCH_FROM[1])
	else:
		target["stand"] = 1.0 - maxf(move, turn_w)
		if move > 0.0:
			var d := v / maxf(speed, 0.001)
			var f := maxf(d.y, 0.0)
			var b := maxf(-d.y, 0.0)
			var l := maxf(-d.x, 0.0)
			var r := maxf(d.x, 0.0)
			var sum := f + b + l + r
			var run := smoothstep(_walk_speed * 1.05, _run_speed * 0.95, speed)
			target["walk"] = move * f / sum * (1.0 - run)
			target["run"] = move * f / sum * run
			target["walk_back"] = move * b / sum * (1.0 - run)
			target["run_back"] = move * b / sum * run
			target["strafe_left"] = move * l / sum
			target["strafe_right"] = move * r / sum
		elif turn_w > 0.0:
			target["strafe_left" if _turn_dir > 0.0 else "strafe_right"] = turn_w
		for c in ["walk", "walk_back", "strafe_left", "strafe_right", "run", "run_back"]:
			scale[c] = clampf(Anims.scale_for(c, speed), 0.3, 2.5) if move > 0.0 else 0.9
	var k := 1.0 - exp(-delta / maxf(blend_time, 0.01) * 3.0)
	var acc := 0.0
	for c: String in CLIPS:
		_weights[c] = lerpf(_weights[c], target[c], k)
		_tree.set("parameters/s_%s/scale" % c, scale.get(c, 1.0))
		acc += _weights[c]
		if c != "stand":
			_tree.set("parameters/b_%s/blend_amount" % c, _weights[c] / acc if acc > 1e-4 else 0.0)
	still = clampf(_weights["stand"] + _weights["crouch_still"], 0.0, 1.0)


# ─── После анимации (модификатор скелета) ────────────────────────────────────

func _apply(delta: float) -> void:
	if _player == null:
		return
	var skel := skeleton
	var to_skel := skel.global_transform.affine_inverse()
	var up := (to_skel.basis * Vector3.UP).normalized()
	var right := (to_skel.basis * global_basis.x).normalized()
	var pitch := _player.get_pitch()

	# Позвоночник: доля скрутки и наклона на каждую кость; грудь дышит
	var breath := sin(_time * TAU / maxf(breath_period, 0.5)) * deg_to_rad(breath_deg) * still
	var yaw_acc := 0.0
	var spine := ["Spine", "Chest", "UpperChest"]
	for i in 3:
		var tw: float = twist * TWIST_SPINE[i]
		var pt: float = pitch * (PITCH_DOWN_SPINE[i] if pitch < 0.0 else PITCH_UP_SPINE[i])
		if i == 1:
			pt -= breath
		elif i == 2:
			pt += breath * 0.6
		yaw_acc += tw
		var r := Basis(up, yaw_acc) * right
		_rotate_global(_bones[spine[i]], Basis(r, pt) * Basis(up, tw))

	# Шея и голова: голова смотрит туда же, куда камера
	var look := to_skel.basis * _player.eye_basis()
	var target := _frame(-look.z, look.y)
	for i in 2:
		var bone: int = _bones["Neck" if i == 0 else "Head"]
		var hb := skel.get_bone_global_pose(_bones["Head"]).basis.orthonormalized()
		var cur := _frame(hb * _head_fwd_l, hb * _head_up_l)
		var q := (target * cur.inverse()).get_rotation_quaternion()
		var ang := q.get_angle()
		var share := NECK_SHARE if i == 0 else 1.0
		var lim := deg_to_rad(HEAD_LIMIT) * (NECK_SHARE if i == 0 else 1.0)
		var w := minf(share, lim / ang) if ang > 0.0001 else 0.0
		_rotate_global(bone, Basis(Quaternion().slerp(q, w)))

	_place_camera(delta)
	_detect_steps()


## Глаза — на кости Head; камера догоняет их сглаженно, по горизонтали — не дальше camera_max_offset.
func _place_camera(delta: float) -> void:
	var skel := skeleton
	var eye_rest := _head_rest.origin + Vector3(0.0, eye_up, eye_forward)
	var eye_skel := skel.get_bone_global_pose(_bones["Head"]) * (_head_rest.affine_inverse() * eye_rest)
	var eye := _player.to_local(skel.global_transform * eye_skel)
	# Без сдвига тела: где была бы голова, и насколько тело отвести назад
	var raw := Vector2(eye.x - _shift.x, eye.z - _shift.y)
	var down := smoothstep(deg_to_rad(20.0), deg_to_rad(75.0), -_player.get_pitch())
	var limit := lerpf(camera_max_offset, camera_max_offset_down, down)
	var excess := raw - raw.limit_length(limit) if raw.length() > limit else Vector2.ZERO
	_shift = _shift.lerp(-excess, 1.0 - exp(-10.0 * delta))
	eye = Vector3(raw.x + _shift.x, eye.y, raw.y + _shift.y)
	var flat := Vector2(eye.x, eye.z).limit_length(limit + 0.02)
	eye = Vector3(flat.x, eye.y, flat.y)
	if not _cam_ready:
		_cam_pos = eye
		_cam_ready = true
	_cam_pos = _cam_pos.lerp(eye, 1.0 - exp(-camera_smooth * delta))
	_player.place_camera(_cam_pos)


## Шаг — кость стопы опустилась к земле (с гистерезисом), пока герой идёт или переступает.
func _detect_steps() -> void:
	var active := _world_vel.length() > 0.2 or turning
	for i in 2:
		var y := skeleton.get_bone_global_pose(_bones["LeftFoot" if i == 0 else "RightFoot"]).origin.y
		if _foot_up[i] and y < FOOT_DOWN:
			_foot_up[i] = false
			if active:
				foot_down.emit()
		elif not _foot_up[i] and y > FOOT_UP:
			_foot_up[i] = true


## Повернуть кость в пространстве скелета (вокруг её начала), дети едут вместе с ней.
func _rotate_global(bone: int, rot: Basis) -> void:
	var g := skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var pb := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(bone, (pb.inverse() * rot.orthonormalized() * g).get_rotation_quaternion())


## Базис по направлению «вперёд» f и «вверх» u.
func _frame(f: Vector3, u: Vector3) -> Basis:
	var z := -f.normalized()
	var x := u.cross(z).normalized()
	return Basis(x, z.cross(x), z)
