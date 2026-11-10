class_name PhysProp
extends RigidBody3D
## Предмет с физикой (этап 5, CLAUDE.md §8 «Предметы с физикой»): кувшин, черепок, камень, табурет.
## Отдельный узел RigidBody3D (не в слитых кусках уровня). Физика здесь ради шума: каждый удар — шумовое событие
## (NoiseSystem) и звук, радиус — скорость удара × вес × громкость материала (data/stealth.gd).
## Глина от сильного удара разбивается: звук, большой шум, вместо неё 2–4 черепка (их можно подобрать).
## Пока предмет не тронули, он спит; дальше FREEZE_DISTANCE от героя — заморожен (PhysProps).
## Герой сквозь предметы проходит и толкает их (HeroHands); святые их не толкают и не видят (коллизии нет).

const S := preload("res://data/stealth.gd")
## Слой физики предметов (3-й бит). Сталкиваются со стенами (слой 1) и друг с другом.
const LAYER := 3

## Вид — ключ data/stealth.gd KINDS.
var kind := ""
var info: Dictionary = {}
## Менеджер (черепки после удара, счёт тел).
var manager: Node

var _prev_vel := Vector3.ZERO
var _prev_ang := Vector3.ZERO
var _skip := 0
var _cooldown := 0.0
var _broken := false
var _height := 0.3
var _quiet := S.SPAWN_QUIET
## Скорость в полёте (последний шаг без касаний) и сколько шагов с тех пор прошло.
var _free_vel := Vector3.ZERO
var _since_free := 99


## Собрать предмет вида kind (до add_child).
func setup(kind_name: String) -> void:
	kind = kind_name
	info = S.KINDS[kind]
	name = "Phys_" + kind
	mass = info.mass
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1 | (1 << (LAYER - 1))
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	continuous_cd = kind == "shard_piece" or kind == "stone_throw"
	linear_damp = 0.1
	angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.05 if info.material == "clay" else 0.15
	physics_material_override = pm
	var mi := MeshInstance3D.new()
	mi.mesh = PropLibrary.mesh(info.mesh)
	mi.material_override = PropLibrary.material()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var size: Array = info.size
	match info.shape:
		"cyl":
			# Восьмигранник по силуэту кувшина (донце уже, плечи шире, горло): выпуклая форма лежит спокойно,
			# цилиндр в Godot Physics дрожит и не засыпает
			var r: float = size[0]
			var hh: float = size[1]
			var pts := PackedVector3Array()
			for ring: Vector2 in [Vector2(0.0, 0.8), Vector2(0.45, 1.0), Vector2(0.8, 0.85), Vector2(1.0, 0.45)]:
				for i in 8:
					var a := TAU * i / 8.0
					pts.append(Vector3(cos(a) * r * ring.y, hh * ring.x, sin(a) * r * ring.y))
			var c := ConvexPolygonShape3D.new()
			c.points = pts
			cs.shape = c
			_height = hh
			# Центр масс — пониже середины (донце тяжелее)
			center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			center_of_mass = Vector3(0.0, size[1] * 0.4, 0.0)
		"box":
			var b := BoxShape3D.new()
			b.size = Vector3(size[0], size[1], size[2])
			cs.shape = b
			cs.position.y = size[1] * 0.5
			_height = size[1]
		_:
			var b := BoxShape3D.new()
			b.size = Vector3(size[0], size[1], size[2])
			cs.shape = b
			_height = size[1]
	add_child(cs)


func _ready() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		add_collision_exception_with(p)
	_skip = 3


## Высота предмета, м (куда толкать, чтобы опрокинуть).
func height() -> float:
	return _height


## Можно ли взять в руку и сколько таких в руке.
func pick_limit() -> int:
	return int(info.get("pick", 0))


## Толчок от героя: impulse — Н·с (направление — куда), на доле высоты at_height.
## Слабый толчок — «качнулся»: тихий звук и шум 1–2 м.
func bump(impulse: Vector3, at_height: float) -> void:
	if freeze:
		freeze = false
	sleeping = false
	_skip = 3
	var at := global_basis * Vector3(0.0, _height * at_height, 0.0)
	apply_impulse(impulse, at)
	var dv := impulse.length() / mass
	if info.material == "clay" or info.material == "wood":
		var radius := clampf(dv * 2.0, 1.0, 2.0)
		_sound(S.HIT_SOUND[info.material], radius / info.max_radius)
		NoiseSystem.make_noise(global_position, radius, "impact", self)


## Брошен: скорость и вращение (после add_child).
func launch(velocity: Vector3, spin: Vector3) -> void:
	freeze = false
	sleeping = false
	linear_velocity = velocity
	angular_velocity = spin
	_prev_vel = velocity
	_prev_ang = spin
	_skip = 2
	_quiet = 0.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var v := state.linear_velocity
	var w := state.angular_velocity
	var contacts := state.get_contact_count()
	if _skip > 0:
		_skip -= 1
	elif contacts > 0:
		# Удар: насколько резко сменилась скорость (поступательная и вращение на краю предмета).
		# Только что летел (касания не было шаг-два назад): ещё и скорость в полёте поперёк поверхности
		var speed := maxf((v - _prev_vel).length(), (w - _prev_ang).length() * _height * 0.5)
		if _since_free <= 2:
			var n := state.get_contact_local_normal(0)
			speed = maxf(speed, absf(_free_vel.dot(n)) * S.GLANCE + _free_vel.length() * S.GLANCE_ALONG)
		if speed >= S.MIN_SPEED and _cooldown <= 0.0 and _quiet <= 0.0:
			_cooldown = S.HIT_COOLDOWN
			_impact.call_deferred(speed)
	if contacts == 0:
		_free_vel = v
		_since_free = 0
	else:
		_since_free += 1
	_prev_vel = v
	_prev_ang = w


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_quiet -= delta


func _impact(speed: float) -> void:
	if _broken or not is_inside_tree():
		return
	var brk: float = info.get("break_speed", 0.0)
	if brk > 0.0 and speed >= brk:
		_break()
		return
	var radius := minf(S.LOUDNESS[info.material] * speed * mass, info.max_radius)
	if radius < 0.5:
		return
	_sound(S.HIT_SOUND[info.material], radius / info.max_radius)
	NoiseSystem.make_noise(global_position, radius, "impact", self)


## Глина разбилась: звук, большой шум, вместо предмета — черепки.
func _break() -> void:
	_broken = true
	var snd: String = S.BREAK_SOUND.get(kind, "pot_break")
	AudioManager.play_3d(snd, global_position + Vector3.UP * 0.1)
	NoiseSystem.make_noise(global_position, info.break_radius, "impact", self)
	var n: Array = info.get("shards", [0, 0])
	var count := randi_range(n[0], n[1])
	if manager and count > 0:
		manager.spawn_shards(global_position + Vector3.UP * minf(_height * 0.5, 0.2), count, _prev_vel * 0.4)
	if manager:
		manager.forget(self)
	queue_free()


## Звук удара: громкость по силе (k — доля от самого громкого), высота ±5 %.
func _sound(sound_name: String, k: float) -> void:
	var db := lerpf(S.QUIET_DB, 0.0, clampf(k, 0.0, 1.0))
	AudioManager.play_3d(sound_name, global_position + Vector3.UP * 0.05,
		{"db": db, "pitch": randf_range(0.95, 1.05)})
