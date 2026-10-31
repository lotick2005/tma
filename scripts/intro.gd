class_name Intro
extends Node
## Вступление уровня 1 (CLAUDE.md §2): утро на площади A, толпа, 1–2 минуты свободной ходьбы днём →
## вестник (через free_time_min…max секунд или раньше, если герой дошёл до точки под аркой) → катсцена
## data/cutscenes/intro.gd → тьма, герой свободно ходит. Данные — INTRO в data/level_1_western_street.gd.
## Создаёт уровень (western_street.gd), только если GameState.intro_done ещё false.
## Отладка (tma/debug/keys): клавиша 4 — пропустить вступление (сразу во тьму).

const CUTSCENE := "res://data/cutscenes/intro.gd"

enum State { FREE, CUTSCENE, DONE }

var state := State.FREE

var _level: Node3D
var _d: Dictionary
var _player: Player
var _crowd: Crowd
var _messenger: CutsceneActor
var _barrier: StaticBody3D
var _wails: Array[SoundEmitter] = []
var _timer := 0.0
var _limit := 75.0
var _trigger := Vector3.ZERO
var _debug_keys := false
var _flee := Vector3.ZERO


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
		var em := AudioManager.add_emitter("crowd_wail", level, pos, {"active": false})
		if em:
			_wails.append(em)

	# Утро: светильник убран (достанет во тьме, в конце катсцены)
	player.set_lamp(false, true)


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
	await Cutscenes.play_file(CUTSCENE, {"actors": {"messenger": _messenger}, "points": _points(), "target": self,
		"level": _level})
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
	var side := hero + Vector3(-to_hero.z, 0.0, to_hero.x).normalized() * 1.4
	# Убегает в дальний от арки угол площади (у Южной стены — на восток)
	var flee: Vector3 = _level.map_point(m.flee)
	if east:
		flee = Vector3(-flee.x, flee.y, flee.z)
	_flee = flee
	var dark: LightingPreset = _level.darkness
	var sun_dir := LightingPreset.direction(dark.black_sun_elevation, dark.black_sun_azimuth)
	return {
		"m_path": _level.map_point(path[0]),
		"m_corner": corner,
		"m_stop": stop,
		"m_side": side,
		"m_flee": flee,
		"sun": func() -> Vector3: return _player.eye_camera().global_position + sun_dir * 100.0,
		"crowd": func() -> Vector3: return _crowd.center() + Vector3.UP * 1.0,
		"goal": func() -> Vector3: return _level.goal_point(),
	}


# ─── Методы для шагов "call" катсцены ────────────────────────────────────────

func silence(sound_name: String, time: float) -> void:
	_level.fade_day_sound(sound_name, time)


## Голоса торговцев (гомон площади) уходят.
func voices_off(time: float) -> void:
	AudioManager.clear_layer("bg", time)


## Пение превращается в крик и плач.
func wail() -> void:
	_level.fade_day_sound("distant_singing", 1.5)
	for em in _wails:
		em.set_active(true)
	_crowd.set_wailing(true)


## Обрыв: тишина сразу.
func silence_all() -> void:
	for em in _wails:
		em.set_active(false)
	_level.fade_day_sound("", 0.05)
	AudioManager.clear_layer("bg", 0.05)


## В черноте: людей нет; на их местах — тела, корзины, черепки; тьма; герой на коленях смотрит в землю.
func aftermath() -> void:
	for em in _wails:
		em.set_active(false)
	_crowd.vanish()
	_messenger.visible = false
	# От вестника осталась одежда там, где он остановился
	var clothes := MeshInstance3D.new()
	clothes.mesh = PropLibrary.mesh(_d.messenger.leaves)
	clothes.material_override = PropLibrary.material()
	_level.add_child(clothes)
	clothes.global_position = Vector3(_messenger.global_position.x, _player.global_position.y, _messenger.global_position.z)
	clothes.rotation.y = _messenger.rotation.y
	_barrier.queue_free()
	_level.show_aftermath()
	_level.set_day(false, 8.0)
	_player.crouch(true)
	_player.set_look(_player.get_look().x, -1.0)
	GameState.intro_done = true


func stand() -> void:
	_player.crouch(false)


func lamp_out() -> void:
	_player.set_lamp(true)
