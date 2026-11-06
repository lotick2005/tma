class_name HeroBody
extends Node3D
## Тело героя от первого лица (CLAUDE.md §8): модель models/hero.glb на скелете Mixamo, мокап-анимации (Anims).
## Ходьба, бег, присед, шаги вбок и назад — анимации, смешанные по скорости и направлению (AnimationTree),
## скорость каждой подогнана под скорость движения, чтобы ноги не скользили.
## Меш делится по весам костей на три части:
##  • тело — обычный слой героя (BODY_LAYER): видно грудь, ноги, отбрасывает тень;
##  • руки — слой VIEW_LAYER: свой светильник их напрямую не освещает, только ровная тёплая подсветка (lamp_glow);
##  • голова с шеей — только тень (камера внутри головы); катсцена с камерой вне глаз показывает её.
## Подол туники перевешен на таз и бёдра с плавным переходом — ноги его не пробивают.
## Руки (IK, светильник, стена) — hero_arms.gd, поверх анимации. Старое процедурное тело — hero_body_proc.gd (выключено).

## Насколько тело позади камеры, м: когда смотришь прямо и когда смотришь в пол.
## Глаза — на передней части головы, а глядя вниз, тело чуть отъезжает, чтобы были видны ноги.
@export var body_back := 0.07
@export var body_back_looking_down := 0.42
## Глядя в пол, корпус отклоняется назад на столько градусов (иначе грудь закрывает ноги).
@export var look_down_lean := 20.0
## Глаза над костью Head, м (по модели): по ним тело ставится под камеру.
@export var eye_above_head_bone := 0.09
## На сколько тело может опуститься ниже земли, чтобы голова анимации была у камеры (присед на ходу), м.
@export var max_sink := 0.12
## Насколько огонь светильника подсвечивает руки (0..1). Свой светильник светит на руки
## не напрямую (вплотную кисть пересвечена), а этой ровной тёплой подсветкой.
@export_range(0.0, 1.0) var lamp_glow := 0.9
## Смешивание анимаций: за сколько секунд веса доходят до нужных.
@export var blend_time := 0.15

## Анимации, из которых смешивается движение.
const CLIPS := ["idle", "walk", "walk_back", "strafe_left", "strafe_right", "run", "run_back", "crouch_walk", "crouch_pose"]
## Подол: от таза (вершины выше — только таз) до края туники, м над землёй (по модели hero).
const SKIRT_TOP := 0.86
const SKIRT_HEM := 0.47
## Доля ног у края подола (остальное — таз).
const SKIRT_LEGS := 0.6

var model: CharacterModel
var skeleton: Skeleton3D
## Фаза шага (π на шаг) и сглаженная «сила» шага 0..1.8 — для звука и покачивания.
var step_phase := 0.0
var step_amount := 0.0
## Наклон головы (рад) — его ставит hero_arms.gd на кость Head (видно по тени).
var pitch := 0.0

var _eye_height := 1.62
var _local_vel := Vector3.ZERO
var _crouched := false
var _walk_speed := 2.2
var _run_speed := 4.6
var _tree: AnimationTree
var _weights := {}
var _head_mesh: MeshInstance3D
var _arms_mat: ShaderMaterial
var _offset := Vector3.ZERO

@onready var _lamp: Node3D = $OilLamp


func _ready() -> void:
	model = CharacterModel.new()
	model.name = "Model"
	model.model = "hero"
	model.cast_shadows = true
	add_child(model)
	model.build()
	skeleton = model.skeleton
	_build_meshes()
	_build_tree()


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
	src.mesh = parts[0]
	src.layers = 1 << (Player.BODY_LAYER - 1)
	src.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var arms := MeshInstance3D.new()
	arms.name = "Arms"
	arms.mesh = parts[1]
	arms.skin = src.skin
	arms.skeleton = ^".."
	arms.layers = 1 << (Player.VIEW_LAYER - 1)
	arms.extra_cull_margin = 1.5
	_arms_mat = CharacterModel.material("hero").duplicate()
	_arms_mat.set_shader_parameter("self_illum_shade", 0.0)
	_arms_mat.set_shader_parameter("self_illum_color", _lamp.light_color)
	arms.material_override = _arms_mat
	sk.add_child(arms)

	_head_mesh = MeshInstance3D.new()
	_head_mesh.name = "Head"
	_head_mesh.mesh = parts[2]
	_head_mesh.skin = src.skin
	_head_mesh.skeleton = ^".."
	_head_mesh.layers = 1 << (Player.BODY_LAYER - 1)
	_head_mesh.extra_cull_margin = 1.5
	_head_mesh.material_override = CharacterModel.material("hero")
	_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sk.add_child(_head_mesh)


## Дерево: каждая анимация → своя скорость (TimeScale) → цепочка Blend2 с весами, которые считает _process.
func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var prev := ""
	for i in CLIPS.size():
		var c: String = CLIPS[i]
		var a := AnimationNodeAnimation.new()
		a.animation = c
		bt.add_node("a_" + c, a, Vector2(0, i * 120))
		bt.add_node("s_" + c, AnimationNodeTimeScale.new(), Vector2(200, i * 120))
		bt.connect_node("s_" + c, 0, "a_" + c)
		if i == 0:
			prev = "s_" + c
		else:
			var b := AnimationNodeBlend2.new()
			bt.add_node("b_" + c, b, Vector2(400 + i * 100, i * 120))
			bt.connect_node("b_" + c, 0, prev)
			bt.connect_node("b_" + c, 1, "s_" + c)
			prev = "b_" + c
		_weights[c] = 1.0 if c == "idle" else 0.0
	bt.connect_node("output", 0, prev)
	_tree = AnimationTree.new()
	_tree.name = "AnimTree"
	model.anim.get_parent().add_child(_tree)
	_tree.root_node = ^".."
	_tree.add_animation_library("", Anims.library())
	_tree.tree_root = bt
	_tree.root_motion_track = Anims.ROOT_TRACK
	# Плеер модели больше не нужен: двигает дерево
	model.anim.active = false
	_tree.active = true


## Голову обычно не видно (только тень). Катсцена, у которой камера ушла из глаз, показывает её.
func set_head_visible(on: bool) -> void:
	if _head_mesh:
		_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## eye_height — высота глаз над ступнями; head_pitch — наклон головы (рад, вниз — минус);
## phase — фаза шага (π на шаг); speed_ratio — скорость / скорость ходьбы.
func update_pose(eye_height: float, head_pitch: float, phase: float, speed_ratio: float) -> void:
	_eye_height = eye_height
	pitch = head_pitch
	step_phase = phase
	step_amount = clampf(speed_ratio, 0.0, 1.8)


## Скорость в осях героя (x — вправо, z — назад, как у Player) и присед — для выбора и смешивания анимаций.
func set_motion(local_velocity: Vector3, crouched: bool, walk_speed: float, run_speed: float) -> void:
	_local_vel = local_velocity
	_crouched = crouched
	_walk_speed = walk_speed
	_run_speed = run_speed


func _process(delta: float) -> void:
	_arms_mat.set_shader_parameter("self_illum", _lamp.glow * lamp_glow)
	_update_blend(delta)
	_place_under_camera(delta)


func _update_blend(delta: float) -> void:
	var v := Vector2(_local_vel.x, -_local_vel.z)  # x — вправо, y — вперёд
	var speed := v.length()
	var move := smoothstep(0.05, 0.6, speed)
	var target := {}
	for c in CLIPS:
		target[c] = 0.0
	var scale := {}
	if _crouched:
		target["crouch_pose"] = 1.0 - move
		target["crouch_walk"] = move
		# Назад в приседе — та же ходьба задом наперёд
		scale["crouch_walk"] = Anims.scale_for("crouch_walk", speed) * (-1.0 if v.y < -0.1 else 1.0)
	else:
		target["idle"] = 1.0 - move
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
		for c in ["walk", "walk_back", "strafe_left", "strafe_right", "run", "run_back"]:
			scale[c] = clampf(Anims.scale_for(c, speed), 0.3, 2.5)
	var k := 1.0 - exp(-delta / maxf(blend_time, 0.01) * 3.0)
	var acc := 0.0
	for c: String in CLIPS:
		_weights[c] = lerpf(_weights[c], target[c], k)
		_tree.set("parameters/s_%s/scale" % c, scale.get(c, 1.0))
		acc += _weights[c]
		if c != "idle":
			_tree.set("parameters/b_%s/blend_amount" % c, _weights[c] / acc if acc > 1e-4 else 0.0)


## Голова анимации — под камерой: тело сдвигается так, чтобы кость Head была у глаз
## (бег и присед наклоняют корпус вперёд), по высоте — только вниз и не глубже max_sink.
## Глядя в пол, под камеру плавно встаёт таз, а корпус отклоняется назад (look_down_lean) —
## иначе грудь закрывает ноги.
func _place_under_camera(delta: float) -> void:
	var down := smoothstep(deg_to_rad(25.0), deg_to_rad(80.0), -pitch)
	var head := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
	var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	var anchor := head.lerp(hips, down)
	# Кость в осях модели (повёрнута на 180°): вперёд героя — −Z
	var back := lerpf(body_back, body_back_looking_down, down)
	var target := Vector3(anchor.x, clampf(_eye_height - (head.y + eye_above_head_bone), -max_sink, 0.0), anchor.z + back)
	_offset = _offset.lerp(target, 1.0 - exp(-12.0 * delta))
	model.position = _offset


## Насколько отклонить корпус назад сейчас (рад) — читает hero_arms.gd (кость Spine).
func lean_back() -> float:
	return deg_to_rad(look_down_lean) * smoothstep(deg_to_rad(25.0), deg_to_rad(80.0), -pitch)
