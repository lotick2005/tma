class_name Intro
extends Node
## Вступление уровня 1 (CLAUDE.md §2): утро на площади A, толпа, свободной ходьбы нет —
## вестник прибегает через free_time_min…max (3–5) секунд (или раньше, если герой дошёл до точки под аркой) → катсцена
## data/cutscenes/intro.gd: вестник → паника → героя сбивают с ног → без сознания → очнулся во тьме.
## Данные — INTRO в data/level_1_western_street.gd.
## Создаёт уровень (western_street.gd), только если GameState.intro_done ещё false.
## Отладка (tma/debug/keys): клавиша 4 — пропустить вступление (сразу во тьму).

const CUTSCENE := "res://data/cutscenes/intro.gd"
## Root motion анимаций падения к последнему кадру, м — в осях человека (лицом в −Z, +X — вправо).
## Замерено на модели (CharacterModel.motion); в animations/README.md те же числа «вперёд / вправо».
const FALL_MOTION := {
	"fall_flat": Vector3(-0.08, 0.0, -3.02),
	"fall_back": Vector3(0.55, 0.0, 0.78),
	"hit_fall": Vector3(0.19, 0.0, 1.43),
	"hit_collapse": Vector3(-0.49, 0.0, -1.21),
}
## Через сколько секунд от начала анимации падения тело бьётся о камень (звук body_fall).
const FALL_HIT := {"fall_flat": 0.9, "fall_back": 0.8, "hit_fall": 1.3, "hit_collapse": 2.2}

enum State { FREE, CUTSCENE, DONE }

var state := State.FREE

var _level: Node3D
var _d: Dictionary
var _player: Player
var _crowd: Crowd
var _messenger: CutsceneActor
var _double: CharacterModel
var _barrier: StaticBody3D
## Паника идёт (крики у бегущих), чернота началась, уже очнулся — чтобы отложенные звуки не звучали не вовремя.
var _panic_on := false
var _blackout_on := false
var _ring: AudioStreamPlayer
var _timer := 0.0
var _limit := 75.0
var _trigger := Vector3.ZERO
var _debug_keys := false
## Дневные предметы, которые опрокидывают в панике: имя → {pivot: Node3D, body: StaticBody3D, kind}.
var _day_props := {}
var _tweens: Array[Tween] = []
## Куда герой смотрит лёжа (по горизонтали) — туда же встаёт дублёр.
var _fall_dir := Vector3.FORWARD


## Затоптанные из INTRO.falls: [{index, from — где начал падать, at — где лежит тело, yaw, kind, anim}].
## Считается и здесь (кто куда бежит), и в уровне (где после тьмы лежат тела) — из одних данных.
## from = at минус root motion анимации падения (повёрнутый по ходу бега): упал — и лежит ровно в at.
static func falls(data: Dictionary, level: Node3D) -> Array:
	var out := []
	for e: Array in data.falls:
		var c: Array = data.crowd[e[0]]
		var home: Vector3 = level.map_point(Vector2(c[0], c[1]))
		var at: Vector3 = level.map_point(Vector2(e[1], e[2]))
		var anim: String = e[4] if e.size() > 4 else "fall_flat"
		var dir := at - home
		dir.y = 0.0
		dir = dir.normalized()
		var yaw := atan2(-dir.x, -dir.z)
		var from := at - Basis(Vector3.UP, yaw) * (FALL_MOTION.get(anim, Vector3.ZERO) as Vector3)
		from.y = at.y
		out.append({"index": e[0], "from": from, "at": at, "yaw": yaw, "kind": e[3], "anim": anim})
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

	_crowd.fell.connect(_on_fell)

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
	# Вестник бежит и кричит — часть людей оглядывается
	_crowd.alert()
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
	var crush := []
	for c: Array in _d.crush:
		crush.append([_level.map_point(Vector2(c[0], c[1])), c[2]])
	# Кто спотыкается: каждый третий из тех, кто не падает и не пробегает мимо героя
	var stumblers := {}
	for i in _crowd.count():
		if stumblers.size() < int(_d.stumblers) and not fallen.has(i) and not passers.has(i) and i % 3 == 1:
			stumblers[i] = rng.randf_range(_d.stumble_at.x, _d.stumble_at.y)
	for i in _crowd.count():
		var speed := rng.randf_range(_d.flee_speed.x, _d.flee_speed.y)
		var delay := rng.randf_range(_d.flee_delay.x, _d.flee_delay.y)
		var route := PackedVector3Array()
		var end := "hide"
		var opts := {}
		if fallen.has(i):
			route.append(fallen[i].from)
			end = "fall"
			delay = rng.randf_range(1.5, 4.0)
			opts = {"fall_anim": fallen[i].anim, "fall_yaw": fallen[i].yaw}
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
			# Не пробегающие мимо героя — в давке у выходов толкаются; кто-то спотыкается; кто ждал дольше — сжался
			if not passers.has(i):
				opts = {"crush": crush, "crush_anim": "push_walk" if i % 2 == 0 else "walk_shoved",
					"cower": delay > 1.5 and i % 3 == 0}
				if stumblers.has(i):
					opts.stumble_at = stumblers[i]
		_crowd.flee(i, route, speed, delay, end, opts)
	if _barrier and is_instance_valid(_barrier):
		_barrier.queue_free()
		_barrier = null


## Звук паники: гомон и птицы обрываются; крики толпы и топот (стерео-петли, слои фона), поверх — отдельные
## крики у бегущих людей (3D).
func panic_sound() -> void:
	_level.fade_day_sound("", 1.2)
	AudioManager.clear_layer("bg", 1.5)
	AudioManager.set_layer("panic", "crowd_panic", 0.8)
	AudioManager.set_layer("stampede", "crowd_stampede", 1.5)
	_panic_on = true
	_scream_loop()


## Пока паника — раз в scream_gap секунд кричит кто-то из бегущих (ближе 25 м к камере).
func _scream_loop() -> void:
	while _panic_on and state == State.CUTSCENE and not Cutscenes.skipping:
		var cam := get_viewport().get_camera_3d()
		var pos := _crowd.positions()
		if cam and pos.size() > 0:
			var near := []
			for p in pos:
				if p.distance_to(cam.global_position) < 25.0:
					near.append(p)
			if not near.is_empty():
				var at: Vector3 = near[randi() % near.size()]
				AudioManager.play_3d("scream_man", at + Vector3.UP * float(_d.scream_height))
		await get_tree().create_timer(randf_range(_d.scream_gap.x, _d.scream_gap.y)).timeout


## Затоптанный упал: тело бьётся о камень, когда доходит до земли в анимации.
func _on_fell(at: Vector3, anim: String) -> void:
	await get_tree().create_timer(float(FALL_HIT.get(anim, 0.9))).timeout
	if _panic_on and state == State.CUTSCENE and not Cutscenes.skipping:
		AudioManager.play_3d("body_fall", at, {"db": 4.0})


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
			AudioManager.play_3d("pot_break" if prop_name == "jar" else "wood_fall", at, {"db": 4.0}))


## Свое тело спрятать (камера «из глаз» лежит на мостовой) / вернуть.
func hero_body(on: bool) -> void:
	_player.set_body_visible(on)


## Удар по голове: глухой удар, сразу звон в ушах (затихает в черноте), голова бьётся о камень.
func head_blow() -> void:
	AudioManager.play_2d("hit_head")
	_ring = AudioManager.play_2d("ring_ears")
	if _ring:
		var tw := create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(_ring, "volume_db", _ring.volume_db - 40.0, 5.5).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.12).timeout
	if state == State.CUTSCENE and not Cutscenes.skipping:
		AudioManager.play_2d("body_fall", {"db": -2.0})


## Чернота: крики у бегущих кончились; всё, что ещё звучит (крики толпы, топот), — глухо, как сквозь вату,
## и затихает за blackout_fade секунд. Дневной фон — сразу.
func blackout() -> void:
	_panic_on = false
	_blackout_on = true
	_level.fade_day_sound("", 0.05)
	AudioManager.clear_layer("bg", 0.05)
	AudioManager.set_bus_muffled("Ambience", true)
	AudioManager.clear_layer("panic", float(_d.blackout_fade) * 0.6)
	AudioManager.clear_layer("stampede", float(_d.blackout_fade))


## Без сознания: глухо, урывками — то, что герой пропустил (INTRO.blackout_sounds): далёкие крики, удары в двери.
## Где-то в городе, за стенами (SoundEmitter.set_muffled).
func blackout_sound() -> void:
	var t0 := Time.get_ticks_msec() / 1000.0
	var hero := _player.global_position
	for e: Array in _d.blackout_sounds:
		var wait: float = float(e[0]) - (Time.get_ticks_msec() / 1000.0 - t0)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		if not _blackout_on or Cutscenes.skipping or state != State.CUTSCENE:
			return
		var a := randf() * TAU
		var at := hero + Vector3(cos(a), 0.0, sin(a)) * float(e[2]) + Vector3.UP * 2.0
		var em := AudioManager.play_3d(e[1], at, {"db": 6.0, "occlude": false})
		if em:
			em.set_muffled()


## Тишина сразу: все звуки паники и черноты, ФНЧ с шины фона.
func _silence() -> void:
	_panic_on = false
	_blackout_on = false
	_level.fade_day_sound("", 0.05)
	AudioManager.clear_layer("bg", 0.05)
	AudioManager.clear_layer("panic", 0.05)
	AudioManager.clear_layer("stampede", 0.05)
	AudioManager.set_bus_muffled("Ambience", false)
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _exit_tree() -> void:
	AudioManager.set_bus_muffled("Ambience", false)


## В черноте: всё уже произошло. Площадь пустая — затоптанные тела, брошенное, кровь, полосы волочения; тьма.
func aftermath() -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	_silence()
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
		if not Cutscenes.skipping:
			AudioManager.play_2d("wake_groan", {"db": -2.0})


func lamp_out() -> void:
	_player.set_lamp(true)
