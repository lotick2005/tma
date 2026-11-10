class_name HeroHands
extends Node
## Левая рука героя и шум от героя (этап 5, CLAUDE.md §8): узел Player/Hands.
##  • Шаги шумят: каждый шаг (сигнал Player.footstep) — шумовое событие по режиму (присед / шаг / бег, data/stealth.gd).
##  • Задеть: CharacterBody3D сам тела не толкает — герой проходит сквозь предметы с физикой, а предмету даётся
##    толчок по скорости героя (шагом — качнулся, бегом — опрокинулся).
##  • E — взять предмет в левую руку (правая со светильником): черепков до 3, камень или малый кувшин — по одному.
##  • ЛКМ — бросить по дуге левой рукой (анимация throw_left на костях левой руки). Чем дольше держишь — тем дальше.
## Предмет в руке — только картинка у кисти (тело с физикой появляется в момент броска, не в стене).

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


func _ready() -> void:
	_player = get_parent() as Player
	_arms = _player.get_node("Head/Camera3D/Arms")
	_player.footstep.connect(_on_footstep)
	_shape.radius = _player.collision_radius + S.BUMP_REACH
	_shape.height = 1.2
	_query.shape = _shape
	_query.collision_mask = 1 << (PhysProp.LAYER - 1)


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
	if held_count <= 0:
		held_kind = ""
		_arms.set_left_holding(false)
		return
	var info: Dictionary = S.KINDS[held_kind]
	for i in held_count:
		var mi := MeshInstance3D.new()
		mi.mesh = PropLibrary.mesh(info.mesh)
		mi.material_override = PropLibrary.material()
		mi.layers = 1 << (Player.VIEW_LAYER - 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_player.add_child(mi)
		mi.top_level = true
		_held_meshes.append(mi)
	_arms.set_left_holding(true)


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
	_place_held()


## Предмет в руке — у кисти (картинка; черепки — стопкой).
func _place_held() -> void:
	if _held_meshes.is_empty():
		return
	var grip: Transform3D = _arms.left_grip()
	for i in _held_meshes.size():
		_held_meshes[i].global_transform = grip * Transform3D(Basis(Vector3.UP, i * 0.9), Vector3(0.0, i * 0.02, 0.0))


## Отпустил: тело с физикой появляется у кисти (если кисть за стеной — перед стеной) и летит по дуге.
func _launch() -> void:
	if held_count <= 0 or props == null:
		return
	var cam := _player.eye_camera()
	var fwd := -cam.global_basis.z
	var from := cam.global_position
	var at: Vector3 = _arms.left_grip().origin
	var q := PhysicsRayQueryParameters3D.create(from, at + fwd * 0.15, 1)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = from + (hit.position - from) * 0.6
	var k := clampf(_charge / S.THROW_HOLD_FULL, 0.0, 1.0)
	var speed := lerpf(S.THROW_SPEED_MIN, S.THROW_SPEED_MAX, k)
	var vel := (fwd + Vector3.UP * S.THROW_LIFT).normalized() * speed + _player.velocity * 0.5
	held_count -= 1
	var kind := held_kind
	var p := props.spawn(kind, at, randf() * TAU, false)
	if p:
		var info: Dictionary = S.KINDS[kind]
		if info.shape != "lump":
			# Кувшин в руке держат за середину: тело ставится низом в точку — опустить на полвысоты
			p.global_position -= Vector3.UP * (info.size as Array)[1] * 0.5
		p.launch(vel, Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)))
	_update_held()


## Отдать всё из руки (поймали — уронил).
func drop_all() -> void:
	held_count = 0
	_throw = Throw.NONE
	_update_held()
