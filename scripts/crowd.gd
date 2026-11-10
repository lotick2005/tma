class_name Crowd
extends Node3D
## Толпа вступления (уровень 1, площадь A): 20–30 горожан на моделях Meshy со скелетом Mixamo (CharacterModel),
## живые мокап-анимации. Поведение:
##  • stand — стоит (idle, иногда idle_old), иногда поворачивается;
##  • wander — бродит вокруг своего места (радиус wander_radius), останавливается (walk_calm / walk);
##  • sing — поёт: молится стоя (pray_stand), лицом к Храму.
## set_wailing(true) — «песни в плач» (Ам 8:10): все в ужасе (terrified), часть опускается на колени.
## play_person(i, анимация) — любая анимация человеку (для катсцен: shoved, fall_flat, run…).
## flee(i, путь, скорость, задержка, конец) — паника (вступление, этап 4в): человек замирает в ужасе на «задержку»,
## потом бежит по точкам; в конце — "hide" (убежал, пропал из виду), "fall" (упал ничком и остался лежать —
## затоптан), "bang" (добежал до двери и бьётся в неё).
## Коллизия — цилиндр на каждого (герой не проходит сквозь людей), двигается вместе с ним.
## Дальние обновляют анимацию реже (LOD_*): каждый человек — 1 вызов отрисовки, скиннинг — главная цена.

@export var wander_radius := 1.8
@export var wander_speed := 0.7

## Дальше этих расстояний от камеры (м) анимация обновляется раз в LOD_INTERVALS секунд.
const LOD_DISTANCES := [14.0, 28.0]
const LOD_INTERVALS := [1.0 / 15.0, 0.2]

## Плач: 0 — нет, 1 — в полную силу (плавно).
var wailing := 0.0

var _people: Array[Dictionary] = []
var _body: StaticBody3D
var _wail_target := 0.0
var _rng := RandomNumberGenerator.new()
var _lod_timer := 0.0


func _ready() -> void:
	_rng.seed = 33


## Добавить человека: точка у ног, поворот (рад, лицом в −Z при 0), поведение "stand" / "wander" / "sing",
## вариант (чётные — горожанин, нечётные — горожанка).
func add_person(pos: Vector3, yaw: float, behavior: String, variant: int) -> void:
	_people.append({
		"home": pos, "pos": pos, "yaw": yaw, "do": behavior, "variant": variant,
		"target": pos, "wait": _rng.randf_range(0.5, 4.0),
		"kneels": _rng.randf() < 0.4, "turn": yaw, "forced": "",
	})


## Создать модели и коллизию. Вызвать один раз после всех add_person.
func commit() -> void:
	_body = StaticBody3D.new()
	_body.name = "CrowdCollision"
	add_child(_body)
	for i in _people.size():
		var p := _people[i]
		var m := CharacterModel.new()
		m.name = "Person%d" % i
		m.model = CutsceneActor.model_for_variant(p.variant)
		add_child(m)
		m.build()
		m.position = p.pos
		m.rotation.y = p.yaw
		p.model = m
		p.anim = ""
		_set_anim(p, _idle_anim(p), 0.0)
		m.randomize_phase(_rng)
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


func count() -> int:
	return _people.size()


func set_wailing(on: bool) -> void:
	_wail_target = 1.0 if on else 0.0


## Человеку i — анимация (поверх поведения, пока не вызвать с пустым именем).
func play_person(i: int, anim_name: String, blend := 0.25) -> void:
	var p := _people[i]
	p.forced = anim_name
	if anim_name != "":
		_set_anim(p, anim_name, blend)


## Паника: человек i ждёт delay секунд (в ужасе), потом бежит по route со скоростью speed; end — что в конце пути:
## "hide" — пропал из виду, "fall" — падает ничком (fall_flat, ещё ~2,9 м вперёд) и остаётся лежать, "bang" — бьётся в дверь.
## Коллизия с бегущих снимается (герой в это время не управляется).
func flee(i: int, route: PackedVector3Array, speed: float, delay: float, end := "hide") -> void:
	var p := _people[i]
	p.flee = {"route": route, "at": 0, "speed": speed, "delay": delay, "end": end, "done": false}
	p.forced = ""
	if p.has("shape"):
		(p.shape as CollisionShape3D).disabled = true
	_set_anim(p, "terrified", 0.3, _rng.randf_range(1.0, 1.4))
	(p.model as CharacterModel).randomize_phase(_rng)


## Убрать толпу (и её коллизию) — людей на площади больше нет.
func vanish() -> void:
	visible = false
	set_process(false)
	for p in _people:
		(p.model as CharacterModel).process_mode = Node.PROCESS_MODE_DISABLED
	if _body:
		_body.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_update(delta)


func _idle_anim(p: Dictionary) -> String:
	match p.do:
		"sing":
			return "pray_stand"
		_:
			return "idle_old" if int(p.variant) == 3 else "idle"


func _set_anim(p: Dictionary, anim_name: String, blend: float, speed := 1.0) -> void:
	(p.model as CharacterModel).play(anim_name, blend, speed)
	p.anim = anim_name


func _update(delta: float) -> void:
	wailing = move_toward(wailing, _wail_target, delta * 0.5)
	for p in _people:
		var moving := false
		if p.has("flee"):
			_update_flee(p, delta)
			continue
		if p.forced != "":
			pass
		elif wailing > 0.1:
			# Плач: ужас; часть опускается на колени
			var a := "kneel_down" if p.kneels else "terrified"
			if p.anim != a:
				_set_anim(p, a, 0.6, _rng.randf_range(0.85, 1.1))
		else:
			match p.do:
				"wander":
					if p.wait > 0.0:
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
					pass
				_:
					p.wait -= delta
					if p.wait <= 0.0:
						p.wait = _rng.randf_range(4.0, 10.0)
						p.turn = p.yaw + _rng.randf_range(-0.8, 0.8)
			var want := "walk_calm" if moving else _idle_anim(p)
			if p.anim != want:
				_set_anim(p, want, 0.35, Anims.scale_for(want, wander_speed) if moving else 1.0)
		p.yaw = lerp_angle(p.yaw, p.turn, 1.0 - exp(-3.0 * delta))
		var m: CharacterModel = p.model
		m.position = p.pos
		m.rotation.y = p.yaw
		if p.has("shape"):
			(p.shape as CollisionShape3D).position = (p.pos as Vector3) + Vector3.UP * 0.85
	_update_lod(delta)


## Паника: ждёт, бежит по точкам, в конце — пропадает, падает или бьётся в дверь.
func _update_flee(p: Dictionary, delta: float) -> void:
	var f: Dictionary = p.flee
	var m: CharacterModel = p.model
	if f.done:
		return
	if f.delay > 0.0:
		f.delay -= delta
		return
	var route: PackedVector3Array = f.route
	var left: float = f.speed * delta
	while left > 0.0 and f.at < route.size():
		var to: Vector3 = route[f.at] - p.pos
		to.y = 0.0
		var d := to.length()
		if d <= left:
			p.pos = Vector3(route[f.at].x, p.pos.y, route[f.at].z)
			left -= d
			f.at += 1
		else:
			p.pos += to / d * left
			p.turn = atan2(-to.x, -to.z)
			left = 0.0
	p.yaw = lerp_angle(p.yaw, p.turn, 1.0 - exp(-10.0 * delta))
	m.position = p.pos
	m.rotation.y = p.yaw
	if f.at < route.size():
		var a := "run_fast" if f.speed > 5.0 else "run"
		if p.anim != a:
			_set_anim(p, a, 0.2, clampf(Anims.scale_for(a, f.speed), 0.6, 1.6))
			m.randomize_phase(_rng)
		return
	f.done = true
	match f.end:
		"fall":
			m.rotation.y = p.turn
			m.set_update_interval(0.0)
			m.play("fall_flat", 0.15, 1.0, true)
		"bang":
			_set_anim(p, "terrified", 0.2, 1.5)
			m.randomize_phase(_rng)
		_:
			m.visible = false


## Дальние — реже обновлять анимацию (раз в 0,5 с проверять расстояния).
func _update_lod(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer > 0.0:
		return
	_lod_timer = 0.5
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var eye := cam.global_position
	for p in _people:
		if p.has("flee") and p.flee.done:
			continue
		var d := eye.distance_to(global_transform * (p.pos as Vector3))
		var interval := 0.0
		for k in LOD_DISTANCES.size():
			if d > LOD_DISTANCES[k]:
				interval = LOD_INTERVALS[k]
		(p.model as CharacterModel).set_update_interval(interval)
