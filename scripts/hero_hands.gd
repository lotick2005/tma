class_name HeroHands
extends Node
## Левая рука героя и шум от героя (этап 5, CLAUDE.md §8): узел Player/Hands.
##  • Шаги шумят: каждый шаг (сигнал Player.footstep) — шумовое событие по режиму (присед / шаг / бег, data/stealth.gd).
##  • Задеть: CharacterBody3D сам тела не толкает — герой проходит сквозь предметы с физикой, а предмету даётся
##    толчок по скорости героя (шагом — качнулся, бегом — опрокинулся).
##  • E — взять предмет в левую руку (правая со светильником): черепков до 3, камень или малый кувшин — по одному.
##  • ЛКМ — бросить по дуге левой рукой (анимация throw_left на костях левой руки). Чем дольше держишь — тем дальше.
##    Пока зажата — пунктир дуги и метка места падения: та же формула, что у броска (_throw_start + _trace),
##    до первой стены или пола.
## Предмет в руке — только картинка в кисти (тело с физикой появляется в момент броска, не в стене): кувшин держат
## за горло, камень и черепки лежат в ладони (hero_arms.gd, left_grip). Освещается как всё вокруг.

const S := preload("res://data/stealth.gd")

## Анимация броска: на каком кадре рука замахнулась (держит, пока зажата ЛКМ), где отпускает, где кончается.
const THROW_ANIM := "throw_left"
const THROW_START := 0.2
const THROW_COCK := 0.62
const THROW_RELEASE := 0.8
const THROW_END := 1.55
## Скорость анимации броска (1 — как в записи).
const THROW_ANIM_SPEED := 1.5

enum Throw { NONE, CHARGE, RELEASE }

## Что в руке (вид data/stealth.gd KINDS) и сколько.
var held_kind := ""
var held_count := 0
## Предметы уровня (ставит уровень).
var props: PhysProps

var _player: Player
var _arms: Node3D
var _throw := Throw.NONE
var _t := 0.0
var _w := 0.0
var _charge := 0.0
var _released := false
var _bumped := {}
var _touching := {}
var _held_meshes: Array[MeshInstance3D] = []
var _query := PhysicsShapeQueryParameters3D.new()
var _shape := CapsuleShape3D.new()
## Дуга броска: точки пунктира (один MultiMesh) и метка места падения.
var _arc: MultiMeshInstance3D
var _mark: MeshInstance3D


func _ready() -> void:
	_player = get_parent() as Player
	_arms = _player.get_node("Head/Camera3D/Arms")
	_player.footstep.connect(_on_footstep)
	_shape.radius = _player.collision_radius + S.BUMP_REACH
	_shape.height = 1.2
	_query.shape = _shape
	_query.collision_mask = 1 << (PhysProp.LAYER - 1)
	_build_arc()


func _unhandled_input(event: InputEvent) -> void:
	if _player.locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("interact"):
		try_pick()
	elif event.is_action_pressed("throw"):
		start_throw()
	elif event.is_action_released("throw"):
		release_throw()


# ─── Шум шагов ───────────────────────────────────────────────────────────────

func _on_footstep(mode: Player.MoveMode) -> void:
	var r: float = S.STEP_RADIUS.walk
	match mode:
		Player.MoveMode.CROUCH:
			r = S.STEP_RADIUS.crouch
		Player.MoveMode.RUN:
			r = S.STEP_RADIUS.run
	NoiseSystem.make_noise(_player.global_position, r, "step", _player)


# ─── Задеть ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	for k in _bumped.keys():
		_bumped[k] -= delta
		if _bumped[k] <= 0.0 and not _touching.has(k):
			_bumped.erase(k)
	var v := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if props == null:
		return
	_query.transform = Transform3D(Basis(), _player.global_position + Vector3.UP * 0.6)
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(_query, 8)
	var now := {}
	for h: Dictionary in hits:
		var p := h.collider as PhysProp
		if p == null:
			continue
		var id := p.get_instance_id()
		now[id] = true
		# Толкаем только при входе в предмет (пока герой внутри — второй раз не толкаем)
		if _bumped.has(id) or v.length() < 0.4:
			continue
		var to := p.global_position - _player.global_position
		to.y = 0.0
		# Только то, во что идём (не то, что сзади)
		if to.length() > 0.05 and to.normalized().dot(v.normalized()) < 0.1:
			continue
		_bumped[id] = S.BUMP_COOLDOWN
		var k := S.BUMP_IMPULSE * (S.BUMP_CROUCH if _player.move_mode == Player.MoveMode.CROUCH else 1.0)
		var dir := (v.normalized() * 0.8 + to.normalized() * 0.2).normalized()
		# Шагом толкает низко (сдвинулся, качнулся), бегом — высоко (опрокинулся)
		var run_k := clampf((v.length() - _player.walk_speed) / maxf(_player.run_speed - _player.walk_speed, 0.1), 0.0, 1.0)
		var at := lerpf(S.BUMP_HEIGHT_WALK, S.BUMP_HEIGHT_RUN, run_k)
		k *= float(p.info.get("bump", 1.0))
		p.bump(dir * k * pow(v.length(), S.BUMP_SPEED_POWER) * pow(p.mass, S.BUMP_MASS_POWER), at)
	_touching = now


# ─── Взять ───────────────────────────────────────────────────────────────────

## E: взять предмет перед собой. Вернёт true, если взял.
func try_pick() -> bool:
	if props == null or _throw != Throw.NONE:
		return false
	var cam := _player.eye_camera()
	var p := props.pickable(cam.global_position, -cam.global_basis.z)
	if p == null:
		return false
	var limit := p.pick_limit()
	if held_count > 0 and (held_kind != p.kind or held_count >= limit):
		return false
	held_kind = p.kind
	held_count += 1
	props.forget(p)
	AudioManager.play_3d("wood_clack" if p.info.material == "wood" else "stone_drop", p.global_position,
		{"db": -14.0, "pitch": 1.2})
	p.queue_free()
	_update_held()
	return true


func _update_held() -> void:
	for m in _held_meshes:
		m.queue_free()
	_held_meshes.clear()
	_arms.set_left_items([])
	if held_count <= 0:
		held_kind = ""
		_arms.set_left_holding(false)
		return
	var info: Dictionary = S.KINDS[held_kind]
	for i in held_count:
		var mi := MeshInstance3D.new()
		mi.mesh = PropLibrary.mesh(info.mesh)
		# Обычный слой: свой светильник и свет вокруг освещают предмет так же, как всё остальное
		mi.material_override = PropLibrary.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_player.add_child(mi)
		mi.top_level = true
		_held_meshes.append(mi)
	_arms.set_left_items(_held_meshes)
	if info.has("neck"):
		var n: Array = info.neck
		_arms.set_left_holding(true, "neck", 0.0, Vector2(n[0], n[1]))
	else:
		_arms.set_left_holding(true, "palm", (info.size as Array)[1])


# ─── Бросить ─────────────────────────────────────────────────────────────────

func start_throw() -> void:
	if held_count <= 0 or _throw != Throw.NONE:
		return
	_throw = Throw.CHARGE
	_t = THROW_START
	_charge = 0.0
	_released = false


func release_throw() -> void:
	if _throw == Throw.CHARGE:
		_throw = Throw.RELEASE


func is_throwing() -> bool:
	return _throw != Throw.NONE


func _process(delta: float) -> void:
	match _throw:
		Throw.CHARGE:
			_charge += delta
			_t = minf(_t + delta * THROW_ANIM_SPEED, THROW_COCK)
			_w = move_toward(_w, 1.0, delta / 0.15)
		Throw.RELEASE:
			_t += delta * THROW_ANIM_SPEED * 1.4
			_w = move_toward(_w, 1.0, delta / 0.1)
			if not _released and _t >= THROW_RELEASE:
				_released = true
				_launch()
			if _t >= THROW_END:
				_throw = Throw.NONE
		Throw.NONE:
			_w = move_toward(_w, 0.0, delta / 0.25)
	_arms.set_arm_anim(THROW_ANIM, _t, _w, "Left")
	_update_arc()


## Откуда и с какой скоростью предмет полетит, если отпустить сейчас: [точка, скорость].
## Точка — слева внизу от глаз, где рука (если там стена — перед стеной); скорость — по взгляду, чуть вверх.
func _throw_start() -> Array:
	var eye := _player.eye_camera().global_position
	var look := _player.eye_basis()
	var fwd := -look.z
	var at := eye + look * S.THROW_ORIGIN
	var q := PhysicsRayQueryParameters3D.create(eye, at + (at - eye).normalized() * 0.15, 1)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = eye + (hit.position - eye) * 0.6
	var k := clampf(_charge / S.THROW_HOLD_FULL, 0.0, 1.0)
	var speed := lerpf(S.THROW_SPEED_MIN, S.THROW_SPEED_MAX, k)
	var vel := (fwd + Vector3.UP * S.THROW_LIFT).normalized() * speed + _player.velocity * 0.5
	return [at, vel]


## Полёт предмета шагами физики (как считает движок: затухание, тяжесть, сдвиг) до первой стены или пола.
## Возвращает {"points": точки пути, "hit": попал ли, "pos": куда, "normal": нормаль там}.
func _trace(at: Vector3, vel: Vector3) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var dt := 1.0 / Engine.physics_ticks_per_second
	var g := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1
	var pts := PackedVector3Array([at])
	var p := at
	var v := vel
	for i in ceili(S.ARC_MAX_TIME / dt):
		v = v * (1.0 - S.THROW_DAMP * dt) + g * dt
		var np := p + v * dt
		q.from = p
		q.to = np
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			pts.append(hit.position)
			return {"points": pts, "hit": true, "pos": hit.position, "normal": hit.normal}
		pts.append(np)
		p = np
	return {"points": pts, "hit": false, "pos": p, "normal": Vector3.UP}


## Отпустил: тело с физикой появляется в точке броска и летит по той же дуге, что была нарисована.
func _launch() -> void:
	if held_count <= 0 or props == null:
		return
	var start := _throw_start()
	var at: Vector3 = start[0]
	held_count -= 1
	var kind := held_kind
	var p := props.spawn(kind, at, randf() * TAU, false)
	if p:
		var info: Dictionary = S.KINDS[kind]
		# Точка тела — в точке броска: у «комка» spawn поднимает середину над точкой, у кувшина точка — дно
		var lift: float = (info.size as Array)[1] * 0.5
		p.global_position -= Vector3.UP * lift
		p.launch(start[1], Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)))
	_update_held()


# ─── Дуга броска ─────────────────────────────────────────────────────────────

func _build_arc() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = S.ARC_COLOR
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Точка одного размера на экране, как бы далеко ни была
	mat.fixed_size = true
	mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * S.ARC_DOT_SIZE
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = ceili(S.THROW_SPEED_MAX * S.ARC_MAX_TIME / S.ARC_DOT_STEP) + 2
	mm.visible_instance_count = 0
	_arc = MultiMeshInstance3D.new()
	_arc.name = "ThrowArc"
	_arc.multimesh = mm
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Точки по всему пути — не отсекать по коробке одного меша
	_arc.custom_aabb = AABB(Vector3.ONE * -60.0, Vector3.ONE * 120.0)
	_arc.visible = false
	add_child(_arc)
	# Метка места падения — кольцо на поверхности
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), 0.0, sin(a0))
		var o1 := Vector3(cos(a1), 0.0, sin(a1))
		for v: Vector3 in [o0, o1, o1 * 0.72, o0, o1 * 0.72, o0 * 0.72]:
			ring.add_vertex(v * S.ARC_MARK_RADIUS)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = S.ARC_COLOR
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.disable_fog = true
	_mark = MeshInstance3D.new()
	_mark.name = "ThrowMark"
	_mark.mesh = ring.commit()
	_mark.material_override = ring_mat
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.top_level = true
	_mark.visible = false
	add_child(_mark)


## Пока зажата ЛКМ (и до самого вылета) — пунктир от руки до места падения и кольцо там.
func _update_arc() -> void:
	var on := held_count > 0 and (_throw == Throw.CHARGE or (_throw == Throw.RELEASE and not _released))
	_arc.visible = on
	_mark.visible = on
	if not on:
		return
	var start := _throw_start()
	var tr := _trace(start[0], start[1])
	var pts: PackedVector3Array = tr.points
	var mm := _arc.multimesh
	var count := 0
	var next := S.ARC_DOT_FROM
	var run := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		var l := seg.length()
		while next <= run + l and count < mm.instance_count:
			mm.set_instance_transform(count, Transform3D(Basis(), pts[i - 1] + seg * ((next - run) / maxf(l, 1e-5))))
			count += 1
			next += S.ARC_DOT_STEP
		run += l
	mm.visible_instance_count = count
	_arc.global_transform = Transform3D()
	_mark.visible = tr.hit
	if tr.hit:
		var nrm: Vector3 = tr.normal
		var side := nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized()
		_mark.global_transform = Transform3D(Basis(side, nrm, side.cross(nrm)), tr.pos + nrm * 0.03)


## Отдать всё из руки (поймали — уронил).
func drop_all() -> void:
	held_count = 0
	_throw = Throw.NONE
	_update_held()
