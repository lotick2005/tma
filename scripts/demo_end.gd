class_name DemoEnd
extends Node
## Конец демо у запертых ворот Антонии (этап 5б, CLAUDE.md §3 «Демо»). Ничего не показываем — только звук:
##  1. управление отнимается, герой смотрит на створки и дёргает их (gate_rattle, камера вздрагивает) — заперто;
##  2. из-за скалы справа (3D, за камнем — глухо): обряд (ritual_far) и напевы святых в несколько голосов,
##     удары молотка по гвоздю по одному (hammer_far, паузы HAMMER_PAUSE), крик (scream_pain), потом стоны (groan_pain);
##  3. герой против воли медленно поворачивает голову на звук — чернота и тишина (Master без звука, игра на паузе);
##  4. название, «Конец демо», через паузу — «Начать заново (E)»: GameState.reset_run() и уровень заново.
## Узел работает и на паузе (PROCESS_MODE_ALWAYS), таймеры — тоже.

const HAMMER_PAUSE := Vector2(1.5, 3.0)
## Сколько ударов до крика; после скольких ударов — поворот головы; после скольких — чернота.
const SCREAM_AFTER := 3
const TURN_AFTER := 4
const BLACK_AFTER := 8

var _level: Node3D
var _player: Player
var _gate: Vector3
var _behind: Vector3
var _emitters: Array[SoundEmitter] = []
var _hammer_on := false
var _can_restart := false
var _layer: CanvasLayer
var _black: ColorRect
var _title: Label
var _sub: Label
var _again: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## gate — середина створок у земли (со стороны героя), behind — откуда звук за скалой.
func run(level: Node3D, player: Player, gate: Vector3, behind: Vector3, saints: Array) -> void:
	_level = level
	_player = player
	_gate = gate
	_behind = behind
	player.set_locked(true)
	AudioManager.false_alarms_enabled = false
	# Святые замирают и замолкают: в конце никто не ловит
	for sn: Node in saints:
		if is_instance_valid(sn):
			sn.process_mode = Node.PROCESS_MODE_DISABLED
	_build_screen()
	# 1. Смотрит на створки, дёргает: заперто
	await _turn_to(_gate + Vector3.UP * 1.3, 0.7)
	for i in 2:
		AudioManager.play_3d("gate_rattle", _gate + Vector3.UP * 1.2)
		await _jolt(1.1)
		await _wait(0.5 + 0.4 * i)
	await _wait(0.8)
	# 2. Из-за скалы: обряд и напевы, потом молоток
	_emitters.append(AudioManager.add_emitter("ritual_far", _level, _behind))
	_emitters.append(AudioManager.add_emitter("saint_chant_01", _level, _behind + Vector3(2.5, 0.0, -3.0), {"db": 6.0}))
	_emitters.append(AudioManager.add_emitter("saint_chant_02", _level, _behind + Vector3(-2.0, 0.5, 2.5), {"db": 6.0}))
	_emitters.append(AudioManager.add_emitter("saint_chant_01", _level, _behind + Vector3(5.0, 0.0, 1.5), {"db": 3.0}))
	await _wait(2.5)
	_hammer_on = true
	var hits := 0
	while _hammer_on:
		AudioManager.play_3d("hammer_far", _behind)
		hits += 1
		if hits == SCREAM_AFTER:
			_after(0.35, func() -> void: AudioManager.play_3d("scream_pain", _behind + Vector3.UP))
		elif hits > SCREAM_AFTER and hits % 2 == 0:
			_after(0.4, func() -> void: AudioManager.play_3d("groan_pain", _behind + Vector3.UP))
		if hits == TURN_AFTER:
			# 3. Поворачивает голову на звук — медленно, против воли
			_turn_to(_behind + Vector3.UP * 2.5, 2.6)
		if hits >= BLACK_AFTER:
			break
		await _wait(randf_range(HAMMER_PAUSE.x, HAMMER_PAUSE.y))
	await _wait(0.9)
	_blackout()


func _unhandled_input(event: InputEvent) -> void:
	if _can_restart and event.is_action_pressed("interact"):
		_can_restart = false
		get_viewport().set_input_as_handled()
		_restart()


# ─── Чернота и титр ──────────────────────────────────────────────────────────

func _blackout() -> void:
	_hammer_on = false
	_black.color.a = 1.0
	# Тишина сразу: вся игра без звука и на паузе
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	get_tree().paused = true
	await _wait(2.5)
	for em in _emitters:
		if is_instance_valid(em):
			em.queue_free()
	_emitters.clear()
	AudioManager.stop_one_shots()
	await _fade(_title, 2.0)
	await _wait(1.0)
	await _fade(_sub, 1.2)
	await _wait(3.0)
	await _fade(_again, 1.0)
	_can_restart = true


func _restart() -> void:
	GameState.reset_run()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	get_tree().paused = false
	get_tree().reload_current_scene()


# ─── Помощники ───────────────────────────────────────────────────────────────

## Плавно повернуть взгляд на точку за time секунд (с замедлением в начале и в конце).
func _turn_to(point: Vector3, time: float) -> void:
	var from := _player.get_look()
	var to := _player.look_at_angles(point)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(_player):
			_player.set_look(lerp_angle(from.x, to.x, t), lerpf(from.y, to.y, t)), 0.0, 1.0, time)
	await tw.finished


## Рывки створки: камера мелко вздрагивает за time секунд.
func _jolt(time: float) -> void:
	var base := _player.get_look()
	var tw := create_tween()
	var n := 5
	for i in n:
		var k := 1.0 - float(i) / n
		var off := Vector2(randf_range(-0.012, 0.012), randf_range(0.01, 0.025)) * k
		tw.tween_method(func(o: Vector2) -> void: _player.set_look(base.x + o.x, base.y + o.y),
			Vector2.ZERO, off, time / n * 0.4)
		tw.tween_method(func(o: Vector2) -> void: _player.set_look(base.x + o.x, base.y + o.y),
			off, Vector2.ZERO, time / n * 0.6)
	await tw.finished


func _after(t: float, f: Callable) -> void:
	await _wait(t)
	if _hammer_on:
		f.call()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout


func _fade(node: Control, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, time)
	await tw.finished


func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 11
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	_title = _line("ТЬМА ПО ВСЕЙ ЗЕМЛЕ", 96.0, 16, Color(0.85, 0.8, 0.7))
	_sub = _line("Конец демо", 122.0, 10, Color(0.6, 0.56, 0.5))
	_again = _line("Начать заново (E)", 196.0, 10, Color(1.0, 0.8, 0.5))
	# Пока идёт конец, экран «Кликни, чтобы продолжить» не нужен (E работает и без захваченного курсора)
	for cts in get_tree().get_nodes_in_group("click_to_start"):
		cts.blocked = true


func _line(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0.0, y)
	l.size = Vector2(320.0, 20.0)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l
