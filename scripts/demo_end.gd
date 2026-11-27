class_name DemoEnd
extends Node
## Конец демо у запертых ворот Антонии (этап 5б, CLAUDE.md §3 «Демо»; полировка демо 5 — чтобы было понятно):
##  1. управление отнимается, герой смотрит на створки и дёргает их GATE_TUGS раза: створка гремит (gate_rattle), засов
##     лязгает в скобе (bolt_clank), камера вздрагивает — заперто;
##  2. пауза PAUSE_TIME с, камера по-прежнему не своя: голова медленно поворачивается к скале (TURN_TIME); фон тьмы
##     приглушается на AMBIENCE_DUCK дБ, а из-за скалы ясно слышно (без окклюзии, громче фона): обряд (ritual_far),
##     напевы святых, треск огня (fire_crackle_far), удары молотка по одному (hammer_far, паузы HAMMER_PAUSE), крик
##     (scream_pain), стоны (groan_pain); над краем скалы — отсвет огня (glow), на последних CROSS_TIME с на его фоне
##     медленно поднимается тёмный силуэт креста, без деталей, балка скрипит под нагрузкой (wood_strain);
##  3. чернота и тишина (Master без звука, игра на паузе);
##  4. название, «Конец демо», через паузу — «Начать заново (ПКМ)»: GameState.reset_run() и уровень заново.
## Узел работает и на паузе (PROCESS_MODE_ALWAYS), таймеры — тоже.

## Рывков створки.
const GATE_TUGS := 3
const HAMMER_PAUSE := Vector2(1.5, 2.6)
## Пауза после рывков (поворот к скале, звуки, крест), с; поворот головы, с; крест поднимается последние CROSS_TIME с.
const PAUSE_TIME := 7.0
const TURN_TIME := 4.0
const CROSS_TIME := 2.0
## Сколько раз скрипит балка, пока поднимается крест (wood_strain).
const WOOD_STRAINS := 2
## Удар, после которого крик.
const SCREAM_AFTER := 2
## Насколько тише фон тьмы на время паузы, дБ; добавка к звукам из-за скалы, дБ (к реестру).
const AMBIENCE_DUCK := -10.0
const ROCK_DB := 6.0
## Крест: высота, ширина перекладины, толщина, м; насколько выходит над краем скалы в конце, м; дальше края на, м.
const CROSS_SIZE := Vector3(1.9, 3.4, 0.22)
const CROSS_RISE := 2.6
const CROSS_BEHIND := 3.5
## Насколько крест выходит над краем в конце, градусы (размер креста растёт с расстоянием).
const CROSS_ANGLE := 14.0
## Отсвет — дальше края на, м; голова смотрит ниже края на, градусы; в сторону звука — не дальше EDGE_YAW градусов
## от перпендикуляра к стене (дальше край стены виден слишком круто вверх).
const GLOW_BEHIND := 9.0
const VIEW_BELOW := 14.0
const EDGE_YAW := 35.0
## Отшатнулся от ворот на, м, за, с (в начале паузы).
const STEP_BACK := 4.5
const STEP_BACK_TIME := 3.0
## Отсвет огня за скалой: размер, м (ширина, высота), цвет и сила в конце.
const GLOW_SIZE := Vector2(16.0, 9.0)
const GLOW_COLOR := Color(1.0, 0.45, 0.16)
const GLOW_ALPHA := 0.55

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
var _cross: Node3D
var _cross_from := Vector3.ZERO
var _cross_to := Vector3.ZERO
var _glow: MeshInstance3D
var _view_point := Vector3.ZERO
var _boxes: Array[AABB] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## gate — середина створок у земли (со стороны героя), behind — откуда звук за скалой; boxes — коробки скалы,
## здания и башен Антонии и стены у ворот (край скалы на фоне неба).
func run(level: Node3D, player: Player, gate: Vector3, behind: Vector3, saints: Array, boxes: Array[AABB] = []) -> void:
	_level = level
	_boxes = boxes
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
	# 1. Смотрит на створки, дёргает: заперто — створка гремит, засов лязгает в скобе
	await _turn_to(_gate + Vector3.UP * 1.3, 0.7)
	for i in GATE_TUGS:
		AudioManager.play_3d("gate_rattle", _gate + Vector3.UP * 1.2)
		# Засов бьёт в скобу вслед за рывком: створка подалась — и встала
		_delay(0.22, func() -> void: AudioManager.play_3d("bolt_clank", _gate + Vector3.UP * 1.1))
		await _jolt(0.8)
		await _wait(0.3 + 0.25 * i)
	await _wait(0.5)
	# 2. Пауза: фон тише, из-за скалы ясно слышно; голова сама медленно поворачивается к скале; над краем — отсвет
	AudioManager.duck_ambience(AMBIENCE_DUCK, 1.5)
	var rock := {"db": ROCK_DB, "occlude": false}
	_emitters.append(AudioManager.add_emitter("ritual_far", _level, _behind, rock))
	# Огонь за скалой: треск (отсвет над краем — тот же огонь)
	_emitters.append(AudioManager.add_emitter("fire_crackle_far", _level, _behind + Vector3(-3.0, 0.5, -2.0), rock))
	_emitters.append(AudioManager.add_emitter("saint_chant_01", _level, _behind + Vector3(2.5, 0.0, -3.0), {"db": ROCK_DB + 6.0, "occlude": false}))
	_emitters.append(AudioManager.add_emitter("saint_chant_02", _level, _behind + Vector3(-2.0, 0.5, 2.5), {"db": ROCK_DB + 6.0, "occlude": false}))
	_emitters.append(AudioManager.add_emitter("saint_chant_01", _level, _behind + Vector3(5.0, 0.0, 1.5), {"db": ROCK_DB + 3.0, "occlude": false}))
	_hammer_on = true
	_hammer_loop()
	# Отшатнулся на несколько шагов; куда смотреть — от того места, где остановится
	var away := Vector3(_player.global_position.x - _gate.x, 0.0, _player.global_position.z - _gate.z)
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	_build_silhouette(_player.eye_camera().global_position + away * STEP_BACK)
	_step_back(away, STEP_BACK, STEP_BACK_TIME)
	_turn_to(_view_point, TURN_TIME)
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: _set_glow(a), 0.0, GLOW_ALPHA, 3.0)
	await _wait(PAUSE_TIME - CROSS_TIME)
	# Последние секунды: над краем скалы медленно поднимается тёмный крест
	_cross.visible = true
	# Крест поднимают: балка скрипит под нагрузкой, два раза за подъём
	for i in WOOD_STRAINS:
		_after(CROSS_TIME * i / WOOD_STRAINS + 0.1, func() -> void:
			AudioManager.play_3d("wood_strain", _behind + Vector3.UP * 2.0, {"db": ROCK_DB, "occlude": false}))
	var ct := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ct.tween_property(_cross, "global_position", _cross_to, CROSS_TIME)
	await _wait(CROSS_TIME)
	_blackout()


## Удары молотка по одному, крик после SCREAM_AFTER-го, потом стоны — пока идёт пауза.
func _hammer_loop() -> void:
	await _wait(0.6)
	var hits := 0
	while _hammer_on:
		AudioManager.play_3d("hammer_far", _behind, {"db": ROCK_DB, "occlude": false})
		hits += 1
		if hits == SCREAM_AFTER:
			_after(0.35, func() -> void: AudioManager.play_3d("scream_pain", _behind + Vector3.UP, {"db": ROCK_DB, "occlude": false}))
		elif hits > SCREAM_AFTER and hits % 2 == 0:
			_after(0.4, func() -> void: AudioManager.play_3d("groan_pain", _behind + Vector3.UP, {"db": ROCK_DB, "occlude": false}))
		await _wait(randf_range(HAMMER_PAUSE.x, HAMMER_PAUSE.y))


## Край скалы на фоне неба (Антония: скала, здание, башни — коробки уровня) в сторону звука, но не дальше EDGE_YAW от
## перпендикуляра к стене: луч из глаз поднимается, пока не уйдёт мимо всех коробок. Там отсвет огня и (спрятанный за
## краем) крест; крест — такого размера, чтобы над краем был виден под углом CROSS_ANGLE.
func _build_silhouette(eye: Vector3) -> void:
	var to := Vector3(_behind.x - eye.x, 0.0, _behind.z - eye.z).normalized()
	var yaw := clampf(atan2(-to.x, -to.z), -deg_to_rad(EDGE_YAW), deg_to_rad(EDGE_YAW))
	var flat := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var edge_pitch := deg_to_rad(40.0)
	var r_wall := 20.0
	var prev := -1.0
	for i in 170:
		var p := deg_to_rad(i * 0.5)
		var dir := flat * cos(p) + Vector3.UP * sin(p)
		var hd := -1.0
		for box: AABB in _boxes:
			var hit: Variant = box.intersects_segment(eye, eye + dir * 300.0)
			if hit != null:
				var h := Vector2((hit as Vector3).x - eye.x, (hit as Vector3).z - eye.z).length()
				hd = h if hd < 0.0 else minf(hd, h)
		if hd < 0.0:
			edge_pitch = p
			r_wall = maxf(prev, 2.0)
			break
		prev = hd
	var d := r_wall + CROSS_BEHIND
	# Край неровный (зубцы, башни): основание креста — чуть выше найденного края
	var sky_y := eye.y + tan(edge_pitch + deg_to_rad(1.5)) * d
	# Размер креста — по расстоянию: над краем он виден под углом CROSS_ANGLE
	var los := d / cos(edge_pitch)
	var k := maxf(1.0, los * tan(deg_to_rad(CROSS_ANGLE)) / CROSS_RISE)
	# Смотрит ниже края: край стены — в верхней части кадра
	_view_point = eye + flat * r_wall + Vector3.UP * (tan(edge_pitch - deg_to_rad(VIEW_BELOW)) * r_wall)
	# Крест: тёмный, без света и тумана — плоский силуэт
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.015, 0.012, 0.012)
	_cross = Node3D.new()
	_cross.name = "CrossSilhouette"
	_level.add_child(_cross)
	var cs := CROSS_SIZE * k
	for part: Array in [[Vector3(cs.z, cs.y, cs.z), Vector3(0.0, cs.y * 0.5, 0.0)],
			[Vector3(cs.x, cs.z, cs.z), Vector3(0.0, cs.y * 0.74, 0.0)]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mi.mesh = box
		mi.material_override = black
		mi.position = part[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cross.add_child(mi)
	_cross_to = eye + flat * d + Vector3.UP * (sky_y - eye.y + (CROSS_RISE - CROSS_SIZE.y) * k)
	_cross_from = _cross_to - Vector3.UP * (CROSS_RISE + 0.4) * k
	_cross.global_transform = Transform3D(Basis(Vector3.UP, yaw), _cross_from)
	_cross.visible = false
	# Отсвет огня: тёплое пятно за краем стены (дальше креста), нижняя часть — за стеной
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _glow_texture()
	mat.albedo_color = Color(GLOW_COLOR, 0.0)
	_glow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	var gk := (d + GLOW_BEHIND) / cos(edge_pitch) / 25.0
	quad.size = GLOW_SIZE * maxf(1.0, gk)
	_glow.mesh = quad
	_glow.material_override = mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level.add_child(_glow)
	var gd := d + GLOW_BEHIND
	_glow.global_position = eye + flat * gd + Vector3.UP * (tan(edge_pitch) * gd + quad.size.y * 0.1)


## Отшатнулся от ворот: несколько медленных шагов назад (от створок), со звуком шагов.
func _step_back(away: Vector3, dist: float, time: float) -> void:
	var from := _player.global_position
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(_player):
			_player.global_position = from + away * dist * k, 0.0, 1.0, time)
	var n := maxi(int(dist / 0.7), 1)
	for i in n:
		await _wait(time / n)
		if is_instance_valid(_player):
			_player.footstep.emit(Player.MoveMode.WALK)


func _set_glow(a: float) -> void:
	if _glow:
		(_glow.material_override as StandardMaterial3D).albedo_color = Color(GLOW_COLOR, a)


## Мягкое пятно 32×32: ярче в середине, к краям в ноль.
func _glow_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r := Vector2((x - 15.5) / 15.5, (y - 15.5) / 15.5).length()
			var k := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, k * k))
	return ImageTexture.create_from_image(img)


func _delay(t: float, f: Callable) -> void:
	await _wait(t)
	f.call()


func _unhandled_input(event: InputEvent) -> void:
	if _can_restart and event.is_action_pressed("interact"):
		_can_restart = false
		get_viewport().set_input_as_handled()
		_restart()


# ─── Чернота и титр ──────────────────────────────────────────────────────────

func _blackout() -> void:
	_hammer_on = false
	_black.color.a = 1.0
	if _cross:
		_cross.queue_free()
	if _glow:
		_glow.queue_free()
	# Тишина сразу: вся игра без звука и на паузе
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	get_tree().paused = true
	await _wait(2.5)
	for em in _emitters:
		if is_instance_valid(em):
			em.queue_free()
	_emitters.clear()
	AudioManager.stop_one_shots()
	AudioManager.duck_ambience(0.0, 0.01)
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
	_again = _line("Начать заново (ПКМ)", 196.0, 10, Color(1.0, 0.8, 0.5))
	# Пока идёт конец, экран «Кликни, чтобы продолжить» не нужен (ПКМ работает и без захваченного курсора)
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
