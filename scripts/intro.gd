class_name Intro
extends Node
## Вступление уровня 1 (CLAUDE.md §2): утро на площади A, толпа, свободной ходьбы нет —
## вестник прибегает через free_time_min…max (3–5) секунд (или раньше, если герой дошёл до точки под аркой) → катсцена
## data/cutscenes/intro.gd: вестник → паника → героя сбивают с ног → без сознания → очнулся во тьме.
## Данные — INTRO в data/level_1_western_street.gd.
## Создаёт уровень (western_street.gd), только если GameState.intro_done ещё false.
## Отладка (tma/debug/keys): клавиша 4 — пропустить вступление (сразу во тьму).

const CUTSCENE := "res://data/cutscenes/intro.gd"
## Сколько метров человек пролетает вперёд в анимации fall_flat (animations/README.md).
const FALL_LENGTH := 2.92

enum State { FREE, CUTSCENE, DONE }

var state := State.FREE

var _level: Node3D
var _d: Dictionary
var _player: Player
var _crowd: Crowd
var _messenger: CutsceneActor
var _double: CharacterModel
var _barrier: StaticBody3D
var _wails: Array[SoundEmitter] = []
var _stampede: SoundEmitter
var _montage: AudioStreamPlayer
var _timer := 0.0
var _limit := 75.0
var _trigger := Vector3.ZERO
var _debug_keys := false
## Дневные предметы, которые опрокидывают в панике: имя → {pivot: Node3D, body: StaticBody3D, kind}.
var _day_props := {}
var _tweens: Array[Tween] = []
## Куда герой смотрит лёжа (по горизонтали) — туда же встаёт дублёр.
var _fall_dir := Vector3.FORWARD


## Затоптанные из INTRO.falls: [{index, from — где начал падать, at — где лежит тело, yaw, kind}].
## Считается и здесь (кто куда бежит), и в уровне (где после тьмы лежат тела) — из одних данных.
static func falls(data: Dictionary, level: Node3D) -> Array:
	var out := []
	for e: Array in data.falls:
		var c: Array = data.crowd[e[0]]
		var home: Vector3 = level.map_point(Vector2(c[0], c[1]))
		var at: Vector3 = level.map_point(Vector2(e[1], e[2]))
		var dir := at - home
		dir.y = 0.0
		var run := maxf(dir.length() - FALL_LENGTH, 0.0)
		dir = dir.normalized()
		out.append({"index": e[0], "from": home + dir * run, "at": home + dir * (run + FALL_LENGTH),
			"yaw": atan2(-dir.x, -dir.z), "kind": e[3]})
	return out


## level — уровень (map_point, cell_point, fade_day_sound, set_day, show_aftermath, blend_lighting, goal_point).
func setup(level: Node3D, data: Dictionary, player: Player) -> void:
	_level = level
	_d = data
	_player = player
	_debug_keys = ProjectSettings.get_setting("tma/debug/keys", false)
	_limit = randf_range(data.free_time_min, data.free_time_max)
	_trigger = level.map_point(data.trigger)

	_crowd = Crowd.new()
	_crowd.name = "Crowd"
	level.add_child(_crowd)
	for e in data.crowd:
		_crowd.add_person(level.map_point(Vector2(e[0], e[1])), deg_to_rad(e[2]), e[3], e[4])
	_crowd.commit()

	var m: Dictionary = data.messenger
	_messenger = CutsceneActor.new()
	_messenger.name = "Messenger"
	_messenger.variant = m.variant
	level.add_child(_messenger)
	_messenger.global_position = level.map_point(m.start)
	_messenger.visible = false

	# Дублёр героя для кадра со стороны «очнулся»: та же модель, встаёт с мостовой
	_double = CharacterModel.new()
	_double.name = "HeroDouble"
	_double.model = "hero"
	level.add_child(_double)
	_double.build()
	_double.visible = false
	_double.process_mode = Node.PROCESS_MODE_DISABLED

	for e: Array in data.day_props:
		_add_day_prop(e)

	# Невидимая стена поперёк главной дороги: пока день, в квартал не пройти
	var a: Vector3 = level.cell_point(data.barrier_cols.x, data.barrier_row)
	var b: Vector3 = level.cell_point(data.barrier_cols.y, data.barrier_row)
	_barrier = StaticBody3D.new()
	_barrier.name = "IntroBarrier"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(absf(b.x - a.x) + 1.0, 6.0, 0.4)
	cs.shape = box
	_barrier.add_child(cs)
	level.add_child(_barrier)
	_barrier.global_position = Vector3((a.x + b.x) * 0.5, a.y + 3.0, a.z - 0.5)

	for p: Vector2 in data.wail_sources:
		var pos: Vector3 = level.map_point(p) + Vector3.UP * float(data.wail_height)
		var em := AudioManager.add_emitter("crowd_panic", level, pos, {"active": false})
		if em:
			_wails.append(em)
	_stampede = AudioManager.add_emitter("crowd_stampede", level,
		level.map_point(data.plaza_center) + Vector3.UP * 0.3, {"active": false})

	# Утро: светильник убран (достанет во тьме, в конце катсцены)
	player.set_lamp(false, true)


## Предмет, который стоит днём и падает в панике: меш на «петле» у края основания + коллизия.
func _add_day_prop(e: Array) -> void:
	var kind: String = e[1]
	var size: Vector3 = PropLibrary.info(kind).get("collide", Vector3.ZERO)
	var half := maxf(size.z, 0.4) * 0.5
	var root := Node3D.new()
	root.name = "Day_" + String(e[0])
	_level.add_child(root)
	root.global_position = _level.map_point(Vector2(e[2], e[3]))
	root.rotation.y = deg_to_rad(e[4])
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, half)
	root.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = PropLibrary.mesh(kind)
	mi.material_override = PropLibrary.material()
	mi.position = Vector3(0.0, 0.0, -half)
	pivot.add_child(mi)
	if size != Vector3.ZERO:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.position = Vector3.UP * size.y * 0.5
		body.add_child(cs)
		root.add_child(body)
	_day_props[e[0]] = {"root": root, "pivot": pivot, "height": maxf(size.y, 0.5)}


func _unhandled_input(event: InputEvent) -> void:
	if _debug_keys and event.is_action_pressed("debug_4"):
		skip()


func _process(delta: float) -> void:
	if state != State.FREE:
		return
	_timer += delta
	var flat := _player.global_position - _trigger
	flat.y = 0.0
	if _timer >= _limit or flat.length() < float(_d.trigger_radius):
		_start()


## Пропустить вступление целиком (клавиша 4): если катсцены ещё нет — запустить и сразу пропустить.
func skip() -> void:
	if state == State.FREE:
		_start()
	if state == State.CUTSCENE:
		Cutscenes.skip()


func _start() -> void:
	state = State.CUTSCENE
	await Cutscenes.play_file(CUTSCENE, {"actors": {"messenger": _messenger, "double": _double}, "points": _points(),
		"target": self, "level": _level})
	state = State.DONE
	GameState.intro_done = true


## Точки катсцены — от того, где сейчас герой.
func _points() -> Dictionary:
	var m: Dictionary = _d.messenger
	var hero := _player.global_position
	var corner_pt: Vector3 = _level.map_point(m.corner)
	var east := hero.x > corner_pt.x + 1.0
	var path: Array = m.path
	var arch: Vector3 = _level.map_point(path[path.size() - 1])
	var corner: Vector3 = corner_pt if east else arch
	var to_hero := hero - corner
	to_hero.y = 0.0
	var stop := hero - to_hero.normalized() * minf(1.8, to_hero.length())
	var dark: LightingPreset = _level.darkness
	var sun_dir := LightingPreset.direction(dark.black_sun_elevation, dark.black_sun_azimuth)
	# Лёжа герой смотрит вдоль мостовой на ближайшего затоптанного (если он рядом), иначе — к арке
	_fall_dir = arch - hero
	var best := 9.0
	for f: Dictionary in falls(_d, _level):
		var d: Vector3 = f.at - hero
		d.y = 0.0
		if d.length() < best and d.length() > 1.5:
			best = d.length()
			_fall_dir = d
	_fall_dir.y = 0.0
	_fall_dir = _fall_dir.normalized()
	var fall_cam := hero + _fall_dir * 0.45 + Vector3.UP * 0.2
	var pts := {
		"m_path": _level.map_point(path[0]),
		"m_corner": corner,
		"m_stop": stop,
		"m_flee": _level.map_point(m.flee),
		"plaza": _level.map_point(_d.plaza_center),
		"sun": func() -> Vector3: return _player.eye_camera().global_position + sun_dir * 100.0,
		"crowd": func() -> Vector3: return _crowd.center() + Vector3.UP * 1.0,
		"goal": func() -> Vector3: return _level.goal_point(),
		"fall_cam": fall_cam,
		"fall_look": fall_cam + _fall_dir * 6.0 + Vector3.UP * 0.25,
		"wake_look": hero + _fall_dir * 4.0,
	}
	for n: String in _day_props:
		var p: Dictionary = _day_props[n]
		pts[n] = (p.root as Node3D).global_position + Vector3.UP * float(p.height) * 0.6
	return pts


# ─── Методы для шагов "call" катсцены ────────────────────────────────────────

## Паника: толпа срывается с места. Почти все — на север, под арку (там давка); часть — на восток к стройке,
## часть — к дверям домов. Двое падают (INTRO.falls). Один сбивает героя через knock_time секунд,
## ещё несколько пробегают мимо него, когда он уже лежит.
func panic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var exits: Dictionary = _d.exits
	var hero := _player.global_position
	var knock: float = _d.knock_time
	var fallen := {}
	for f: Dictionary in falls(_d, _level):
		fallen[f.index] = f
	var north: Array = exits.north
	var side := Vector3(-_fall_dir.z, 0.0, _fall_dir.x)
	# Кто пробежит мимо лежащего героя: ближайшие из тех, кто не падает; первый из них — сбивает
	var order := []
	var pos := _crowd.positions()
	for i in _crowd.count():
		if not fallen.has(i):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return pos[a].distance_to(hero) < pos[b].distance_to(hero))
	var passers := {}
	for k in mini(6, order.size()):
		passers[order[k]] = k
	for i in _crowd.count():
		var speed := rng.randf_range(_d.flee_speed.x, _d.flee_speed.y)
		var delay := rng.randf_range(_d.flee_delay.x, _d.flee_delay.y)
		var route := PackedVector3Array()
		var end := "hide"
		if fallen.has(i):
			route.append(fallen[i].from)
			end = "fall"
			delay = rng.randf_range(1.5, 4.0)
		else:
			if passers.has(i):
				var k: int = passers[i]
				# Сквозь героя (k = 0) или поперёк его взгляда на мостовой, в 1–3 м перед лицом
				var through := hero if k == 0 else hero + _fall_dir * (0.9 + 0.45 * k) + side * (2.5 if k % 2 == 0 else -2.5)
				var beyond := hero + (hero - pos[i]).normalized() * 2.0 if k == 0 \
					else hero + _fall_dir * (0.9 + 0.45 * k) - side * (2.5 if k % 2 == 0 else -2.5)
				var arrive := knock if k == 0 else knock + 0.5 + 0.45 * k
				var dist := pos[i].distance_to(through)
				speed = clampf(dist / maxf(arrive - 0.3, 0.5), 3.4, 6.0)
				delay = maxf(arrive - dist / speed, 0.0)
				route.append(through)
				route.append(beyond)
			var ce: Array = _d.crowd[i]
			var exit_name := "north"
			if not passers.has(i):
				if float(ce[1]) < -30.0 and i % 2 == 1:
					exit_name = "doors"
				elif float(ce[0]) > 10.0 and i % 2 == 0:
					exit_name = "east"
			if exit_name == "doors":
				var doors: Array = exits.doors
				var door: Vector2 = doors[0] if float(ce[0]) < -5.0 else doors[1]
				route.append(_level.map_point(door) + Vector3(rng.randf_range(-0.6, 0.6), 0.0, 0.0))
				end = "bang"
			else:
				for p: Vector2 in exits[exit_name]:
					route.append(_level.map_point(p) + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-0.8, 0.8)))
		_crowd.flee(i, route, speed, delay, end)
	if _barrier and is_instance_valid(_barrier):
		_barrier.queue_free()
		_barrier = null


## Звук паники: гомон и птицы обрываются, крики и топот.
func panic_sound() -> void:
	_level.fade_day_sound("", 1.2)
	AudioManager.clear_layer("bg", 1.5)
	for em in _wails:
		em.set_active(true)
	if _stampede:
		_stampede.set_active(true)


## Опрокинуть дневной предмет (кувшин, лоток): падает на бок, грохот.
func tip(prop_name: String) -> void:
	if not _day_props.has(prop_name):
		return
	var p: Dictionary = _day_props[prop_name]
	var pivot: Node3D = p.pivot
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:x", deg_to_rad(88.0), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pivot, "rotation:x", deg_to_rad(82.0), 0.08)
	tw.tween_property(pivot, "rotation:x", deg_to_rad(90.0), 0.1)
	_tweens.append(tw)
	var at := (p.root as Node3D).global_position
	get_tree().create_timer(0.38).timeout.connect(func() -> void:
		if not Cutscenes.skipping and state == State.CUTSCENE:
			AudioManager.play_3d("shard_break" if prop_name == "jar" else "alarm_stone_fall", at, {"db": 6.0}))


## Свое тело спрятать (камера «из глаз» лежит на мостовой) / вернуть.
func hero_body(on: bool) -> void:
	_player.set_body_visible(on)


## Обрыв: удар — и ничего. Тишина сразу.
func blackout() -> void:
	for em in _wails:
		em.set_active(false)
	if _stampede:
		_stampede.set_active(false)
	_level.fade_day_sound("", 0.05)
	AudioManager.clear_layer("bg", 0.05)


## Без сознания: глухо, урывками — то, что герой пропустил.
func blackout_sound() -> void:
	_montage = AudioManager.play_2d("blackout_montage")


## В черноте: всё уже произошло. Площадь пустая — затоптанные тела, брошенное, кровь, полосы волочения; тьма.
func aftermath() -> void:
	if _montage and is_instance_valid(_montage):
		_montage.queue_free()
	_montage = null
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	blackout()
	_crowd.vanish()
	_messenger.visible = false
	for n: String in _day_props:
		(_day_props[n].root as Node3D).queue_free()
	_day_props.clear()
	if _barrier and is_instance_valid(_barrier):
		_barrier.queue_free()
		_barrier = null
	_level.show_aftermath()
	_level.set_day(false, 8.0)
	_player.crouch(false)
	GameState.intro_done = true


## Дублёр героя (кадр со стороны): лежит там же, где герой, и тяжело встаёт / убрать.
func double(on: bool) -> void:
	_double.visible = on
	_double.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		_double.global_position = _player.global_position
		_double.rotation.y = atan2(-_fall_dir.x, -_fall_dir.z)
		_double.reset_motion()
		_double.play("get_up_slow", 0.0, 1.35, true)


func lamp_out() -> void:
	_player.set_lamp(true)
