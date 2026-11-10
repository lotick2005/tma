class_name PhysProps
extends Node3D
## Предметы с физикой уровня (этап 5): создаёт их по списку из данных уровня (PHYS_PROPS), следит, чтобы
## тел было не больше S.MAX_BODIES, замораживает дальние (дальше S.FREEZE_DISTANCE от героя) и
## размораживает ближние — спящими: пока предмет не тронули, физика его не считает.
## Черепки разбитой глины — тоже отсюда (spawn_shards).

const S := preload("res://data/stealth.gd")

var bodies: Array[PhysProp] = []
var _timer := 0.0


## Поставить предмет вида kind в точку pos (низ предмета), поворот yaw. Вернёт его или null (лимит тел).
func spawn(kind: String, pos: Vector3, yaw := 0.0, sleep := true) -> PhysProp:
	if bodies.size() >= S.MAX_BODIES or not S.KINDS.has(kind):
		return null
	var p := PhysProp.new()
	p.setup(kind)
	p.manager = self
	add_child(p)
	var info: Dictionary = S.KINDS[kind]
	var lift: float = (info.size as Array)[1] * 0.5 + 0.01 if info.shape == "lump" else 0.005
	p.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * lift)
	p.sleeping = sleep
	bodies.append(p)
	return p


## Черепки разбитой глины: count штук в точке, разлетаются со скоростью около vel.
func spawn_shards(pos: Vector3, count: int, vel: Vector3) -> void:
	for i in count:
		var a := TAU * i / count + randf() * 0.8
		var off := Vector3(cos(a), 0.0, sin(a)) * 0.08
		var p := spawn("shard_piece", pos + off, randf() * TAU, false)
		if p == null:
			return
		p.launch(vel + off.normalized() * randf_range(0.6, 1.4) + Vector3.UP * randf_range(0.5, 1.5),
			Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)))


## Предмет ушёл (разбился, взят в руку).
func forget(p: PhysProp) -> void:
	bodies.erase(p)


## Ближайший предмет, который можно взять: в луче взгляда (угол ≤ PICK_ANGLE) не дальше PICK_DISTANCE.
func pickable(from: Vector3, dir: Vector3) -> PhysProp:
	var best: PhysProp = null
	var best_score := INF
	var cos_max := cos(deg_to_rad(S.PICK_ANGLE))
	for p in bodies:
		if p.pick_limit() <= 0:
			continue
		var to := p.global_position + Vector3.UP * minf(p.height() * 0.5, 0.15) - from
		var d := to.length()
		if d > S.PICK_DISTANCE or d < 0.01:
			continue
		var c := to.dot(dir) / d
		if c < cos_max:
			continue
		var score := d * (2.0 - c)
		if score < best_score:
			best_score = score
			best = p
	return best


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.FREEZE_CHECK
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hero: Vector3 = (players[0] as Node3D).global_position
	var far2 := S.FREEZE_DISTANCE * S.FREEZE_DISTANCE
	for p in bodies:
		var far := p.global_position.distance_squared_to(hero) > far2
		if far and not p.freeze and p.sleeping:
			p.freeze = true
		elif not far and p.freeze:
			p.freeze = false
			p.sleeping = true


## Сколько тел сейчас не спит (для замеров).
func awake_count() -> int:
	var n := 0
	for p in bodies:
		if not p.freeze and not p.sleeping:
			n += 1
	return n
