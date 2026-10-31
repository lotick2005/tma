class_name Crowd
extends Node3D
## Толпа вступления (уровень 1, площадь A): 20–30 лоуполи-фигур PropLibrary.person_mesh.
## Каждый вариант одежды — один MultiMesh, вся толпа — 4 вызова отрисовки. Анимации — наклонами фигуры:
##  • stand — стоит, переминается, иногда поворачивается;
##  • wander — бродит вокруг своего места (радиус wander_radius), останавливается;
##  • sing — поёт: медленно покачивается вперёд-назад.
## set_wailing(true) — «песни в плач» (Ам 8:10): все раскачиваются сильнее и чаще, часть оседает на колени.
## Коллизия — цилиндр на каждого (герой не проходит сквозь людей), двигается вместе с ним.

@export var wander_radius := 1.8
@export var wander_speed := 0.7

## Плач: 0 — нет, 1 — в полную силу (плавно).
var wailing := 0.0

var _people: Array[Dictionary] = []
var _mms: Array[MultiMesh] = []
var _body: StaticBody3D
var _wail_target := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 33


## Добавить человека: точка у ног, поворот (рад, лицом в −Z при 0), поведение "stand" / "wander" / "sing".
func add_person(pos: Vector3, yaw: float, behavior: String, variant: int) -> void:
	_people.append({
		"home": pos, "pos": pos, "yaw": yaw, "do": behavior, "variant": posmod(variant, PropLibrary.PERSON_VARIANTS),
		"target": pos, "wait": _rng.randf_range(0.5, 4.0), "phase": _rng.randf() * TAU,
		"kneels": _rng.randf() < 0.4, "kneel": 0.0, "turn": yaw,
	})


## Создать меши и коллизию. Вызвать один раз после всех add_person.
func commit() -> void:
	_body = StaticBody3D.new()
	_body.name = "CrowdCollision"
	add_child(_body)
	for v in PropLibrary.PERSON_VARIANTS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = PropLibrary.person_mesh(v)
		var count := 0
		for p in _people:
			if p.variant == v:
				count += 1
		mm.instance_count = count
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "People%d" % v
		mmi.multimesh = mm
		mmi.material_override = PropLibrary.material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mms.append(mm)
	for p in _people:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25
		shape.height = 1.7
		cs.shape = shape
		_body.add_child(cs)
		p.shape = cs
	_update(0.0)


## Где сейчас люди (точки у ног).
func positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in _people:
		out.append(p.pos)
	return out


## Середина толпы (для звука).
func center() -> Vector3:
	var c := Vector3.ZERO
	for p in _people:
		c += p.pos
	return c / maxf(_people.size(), 1)


func set_wailing(on: bool) -> void:
	_wail_target = 1.0 if on else 0.0


## Убрать толпу (и её коллизию) — люди исчезли.
func vanish() -> void:
	visible = false
	set_process(false)
	if _body:
		_body.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	wailing = move_toward(wailing, _wail_target, delta * 0.5)
	var t := Time.get_ticks_msec() * 0.001
	var idx := [0, 0, 0, 0]
	for p in _people:
		var rock := 0.0
		var lift := 0.0
		var moving := false
		match p.do:
			"wander":
				if wailing > 0.1:
					pass
				elif p.wait > 0.0:
					p.wait -= delta
					if p.wait <= 0.0:
						var a := _rng.randf() * TAU
						var r := _rng.randf_range(0.6, wander_radius)
						p.target = p.home + Vector3(cos(a) * r, 0.0, sin(a) * r)
				else:
					var to: Vector3 = p.target - p.pos
					to.y = 0.0
					if to.length() < 0.1:
						p.wait = _rng.randf_range(2.0, 6.0)
					else:
						p.pos += to.normalized() * minf(wander_speed * delta, to.length())
						p.turn = atan2(-to.x, -to.z)
						moving = true
			"sing":
				rock = 0.09 * sin(t * 1.4 + p.phase)
			_:
				p.wait -= delta
				if p.wait <= 0.0:
					p.wait = _rng.randf_range(4.0, 10.0)
					p.turn = p.yaw + _rng.randf_range(-0.8, 0.8)
				rock = 0.015 * sin(t * 1.1 + p.phase)
		p.yaw = lerp_angle(p.yaw, p.turn, 1.0 - exp(-3.0 * delta))
		if moving:
			lift = absf(sin(t * 6.0 + p.phase)) * 0.03
			rock -= 0.05
		# Плач: сильное раскачивание, руки к лицу не поднять — зато корпус ходит; часть оседает
		if wailing > 0.0:
			rock += wailing * (0.18 * sin(t * 3.1 + p.phase) - 0.12)
			if p.kneels:
				p.kneel = move_toward(p.kneel, wailing, delta * 0.8)
		var pos: Vector3 = p.pos + Vector3.UP * (lift - 0.45 * p.kneel)
		var basis := Basis(Vector3.UP, p.yaw) * Basis(Vector3.RIGHT, rock - 0.4 * p.kneel)
		var v: int = p.variant
		if not _mms.is_empty():
			_mms[v].set_instance_transform(idx[v], Transform3D(basis, pos))
		idx[v] += 1
		if p.has("shape"):
			(p.shape as CollisionShape3D).position = (p.pos as Vector3) + Vector3.UP * 0.85
