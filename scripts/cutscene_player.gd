extends Node
## Проигрыватель катсцен (autoload Cutscenes) — один на всю игру. CLAUDE.md §2 «Катсцены».
##
## Сценарий — данные: файл res://data/cutscenes/<имя>.gd с константой STEPS (массив шагов-словарей).
## Запуск: await Cutscenes.play_file("res://data/cutscenes/intro.gd", ctx)  (или play(steps, ctx)).
## Пока идёт катсцена: чёрные полосы сверху и снизу, субтитры внизу, управление героем отобрано.
## Пропуск — зажать E (SKIP_HOLD с, индикатор в углу). Esc не используется: в браузере он отпускает курсор.
##
## ctx — с чем работает сценарий:
##   "actors": {имя: Node3D}   — персонажи (CutsceneActor или любой Node3D);
##   "points": {имя: Vector3 или Callable() -> Vector3} — точки (Callable считается в момент шага);
##   "target": Object          — у кого вызывать шаги "call" (обычно скрипт сцены);
##   "level":  Object          — у кого вызывать blend_lighting(from, to, t) для шага "lighting";
##   "skippable": bool         — можно ли пропустить (по умолчанию да).
## Имена точек: "hero" — глаза героя, "hero_feet" — его ноги, имя актёра — его голова, имя из points.
##
## Шаги (тип — по ключу; у шагов с временем "ease": "linear" / "in" / "out", по умолчанию плавно с двух сторон):
##   {"camera": "look", "at": "messenger", "time": 1.0}          — повернуть взгляд на точку;
##       "follow": true — следить за движущейся целью time секунд (фоновый шаг в parallel — без time).
##       Пока камера «в глазах» — поворачивается сам герой (тело и руки вслед); отцепленная — сама камера.
##   {"camera": "move", "to": "p1", "look": "messenger", "time": 3.0} — отцепить камеру из глаз и вести в точку;
##   {"camera": "path", "points": ["p1", "p2", "p3"], "look": "x", "time": 5.0} — то же по плавной кривой;
##   {"camera": "eyes", "time": 1.5}                              — плавно вернуть камеру в глаза героя;
##   {"camera": "face", "at": "gate"}                             — мгновенно повернуть героя (за кадром, в черноте);
##       у "move" / "path" / "eyes" — "roll": градусы — завал горизонта к концу движения (у "eyes" — к нулю).
##
## Кадры — шаг "shot" (CLAUDE.md §2 «Язык камеры»). Правило: что герой переживает сам — из глаз ("camera": "eyes",
## "look"); что он видит со стороны — кадрами. Кадр ставится от актёра или точки, а не мировыми координатами:
##   {"shot": "close", "of": "messenger", "side": 25, "time": 3.0, "push": 0.3}
##   "shot" — тип:
##       "close"         — крупный план: камера на высоте точки (лица), в dist метрах (0,9);
##       "insert"        — вставка, деталь: близко (1,0 м) и чуть сверху (0,6 м) на предмет;
##       "low"           — нижний ракурс: камера у земли (0,25 м), смотрит снизу вверх (2,2 м от цели);
##       "high_wide"     — верхний общий план: высоко (8 м) и далеко (9 м), смотрит вниз;
##       "over_shoulder" — через плечо: из-за плеча "from" (по умолчанию героя) на "of";
##   "of"     — кто или что в кадре: имя актёра, точки или "hero" (у актёра цель — голова);
##   "side"   — с какой стороны камера, градусы вокруг цели: 0 — спереди (куда смотрит актёр), 90 — слева от него,
##              −90 — справа, 180 — сзади; или "front" / "left" / "right" / "back". У точки (не актёра) стороны —
##              по сторонам света: 0 — камера к северу от точки, 90 — к западу, −90 — к востоку, 180 — к югу.
##              У "over_shoulder" — через какое плечо: "right" (по умолчанию) или "left";
##   "dist", "height" — свои расстояние и высота камеры, м (высота: у close / insert — от цели, у low / high_wide —
##              от земли под целью, у over_shoulder — от головы "from");
##   "look"   — смотреть не на "of", а на эту точку;  "fov" — угол обзора (у close и insert по умолчанию уже);
##   "time"   — сколько держать кадр, с (шаг ждёт). Без time — кадр встал, сценарий идёт дальше;
##              фоновый шаг в parallel ("background": true) держит кадр, пока идут остальные;
##   "blend"  — плавный переход из прошлого положения камеры за столько секунд (по умолчанию жёсткая склейка);
##   "push"   — медленный наезд: за time камера подползает к цели на столько метров;
##   "shake"  — дрожь 0…1 на этот кадр (удар, давка, крик);  "roll" — завал горизонта, градусы (тревога);
##   "track": false — не следить за целью, если она движется (по умолчанию следит).
##   Из кадра в глаза героя — {"camera": "eyes", "time": 0} (склейка) или с временем (пролёт).
##   Дрожь и завал отдельно (работают и в глазах героя): {"effect": "shake", "amount": 0.8, "time": 1.5} — дрожь,
##   которая затухает за time (без time — держится, "amount": 0 — выключить); {"effect": "roll", "to": 12, "time": 2}.
##   {"actor": "messenger", "walk": ["p1", "p2"], "speed": 4.0}   — идти / бежать по точкам (ждёт, пока дойдёт);
##   {"actor": "messenger", "turn_to": "hero", "time": 0.4}       — повернуться;
##   {"actor": "messenger", "anim": "panic"}                      — анимация (CutsceneActor.anim);
##   {"actor": "messenger", "place": "p1", "face": "hero"}        — мгновенно поставить в точку / повернуть лицом;
##   {"actor": "messenger", "show": false}                        — показать / спрятать;
##   {"say": "Гробы открылись…", "who": "messenger", "sound": "voice_messenger", "time": 3.0} — реплика:
##       субтитры time секунд, звук — 3D из головы who (без who — не из точки);
##   {"sound": "shard_break", "at": "p1"}                         — разовый звук (без "at" — не из точки);
##   {"layer": "bg", "sound": "ambient_drone", "fade": 3.0}       — фон (AudioManager.set_layer); "clear": true — убрать;
##   {"effect": "fade", "to": 1.0, "time": 0.5}                   — затемнение экрана (0 — нет, 1 — черно), "color";
##   {"effect": "lighting", "from": "day", "to": "darkness", "time": 14.0} — смена пресета освещения;
##       "amount": 0.5 — дойти только до половины пути (солнце начало тускнеть);
##   {"effect": "global", "name": "psx_fog_end", "from": 2.0, "to": 13.5, "time": 7.0} — глобальный параметр шейдеров;
##   {"effect": "light", "id": "flash", "at": "p1", "color": Color.WHITE, "energy": 4.0, "range": 12.0, "time": 0.3}
##       — свет в точке (создаётся, яркость плавно до energy); "remove": true — убрать;
##   {"title": "Выбраться из города"}                             — надпись задачи (появится и исчезнет сама);
##   {"pause": 2.0}                                               — пауза;
##   {"parallel": [шаг, шаг, …]}                                  — шаги одновременно, дальше — когда кончатся все;
##       у шага "background": true — его не ждут, он идёт, пока идут остальные (камера следит за бегущим);
##   {"steps": [шаг, шаг, …]}                                     — шаги по очереди (удобно внутри parallel);
##   {"call": "aftermath", "args": [...]}                         — вызвать метод ctx.target (мгновенный).
## При пропуске оставшиеся шаги проигрываются мгновенно: время — ноль, реплики и разовые звуки — пропускаются,
## у "call" с "skip": true вызов пропускается (например, запуск звука), остальные вызываются (они меняют мир).

## Катсцена кончилась (в том числе пропуском).
signal finished
## Нажали пропуск.
signal skipped

const BAR_HEIGHT := 30
const SKIP_HOLD := 1.0
const SUBTITLE_SIZE := 11

var playing := false
var skipping := false

var _ctx := {}
var _tweens: Array[Tween] = []
var _player: Player
## Своя камера: _cam — «штатив» (его двигают шаги), _lens — сама камера на нём (на ней — дрожь и завал).
var _cam: Node3D
var _lens: Camera3D
var _detached := false
## Дрожь 0…1 (и на сколько в секунду затухает), завал горизонта (рад) — и для своей камеры, и для глаз героя.
var _shake := 0.0
var _shake_decay := 0.0
var _roll := 0.0
var _shake_t := 0.0
## Номер текущего кадра: новый кадр или движение камеры прекращает удержание прошлого.
var _shot_id := 0
var _hold := 0.0
var _lights := {}
var _say_id := 0

var _ui: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _subtitle: Label
var _skip_box: Control
var _skip_fill: ColorRect
var _fade: ColorRect
var _title: Label
var _bars_tween: Tween
var _title_tween: Tween


func _ready() -> void:
	_build_ui()


# ─── Запуск ──────────────────────────────────────────────────────────────────

## Сценарий из файла данных (константа STEPS).
func play_file(path: String, ctx := {}) -> void:
	var script := load(path) as Script
	if script == null or not script.get_script_constant_map().has("STEPS"):
		push_error("Cutscenes: в %s нет STEPS" % path)
		return
	await play(script.get_script_constant_map().STEPS, ctx)


func play(steps: Array, ctx := {}) -> void:
	if playing:
		push_warning("Cutscenes: катсцена уже идёт")
		return
	playing = true
	skipping = false
	_hold = 0.0
	_ctx = ctx
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.set_locked(true)
	_set_bars(true)
	await _run(steps)
	# Конец: камера в глаза, полосы прочь, управление герою
	if _detached:
		await _exec({"camera": "eyes", "time": 0.0 if skipping else 1.0})
	_say_id += 1
	_subtitle.text = ""
	_skip_box.visible = false
	for id in _lights.keys():
		(_lights[id] as Node).queue_free()
	_lights.clear()
	_set_bars(false)
	_shake = 0.0
	_shake_decay = 0.0
	_roll = 0.0
	_shot_id += 1
	_apply_lens()
	if _player:
		_player.set_locked(false)
	playing = false
	skipping = false
	_tweens.clear()
	finished.emit()


## Пропустить: всё оставшееся — мгновенно.
func skip() -> void:
	if not playing or skipping:
		return
	skipping = true
	_skip_box.visible = false
	_say_id += 1
	_subtitle.text = ""
	for tw in _tweens.duplicate():
		if tw.is_valid() and tw.is_running():
			tw.custom_step(1.0e4)
	skipped.emit()


func _process(delta: float) -> void:
	if _detached and _lens and _player:
		_lens.far = _player.eye_camera().far
	if playing:
		_shake_t += delta
		if _shake_decay > 0.0:
			_shake = maxf(0.0, _shake - _shake_decay * delta)
		_apply_lens()
	if not playing or skipping:
		return
	if _ctx.get("skippable", true) and Input.is_action_pressed("interact"):
		_hold += delta
		_skip_box.visible = true
		_skip_fill.size.x = 60.0 * clampf(_hold / SKIP_HOLD, 0.0, 1.0)
		if _hold >= SKIP_HOLD:
			skip()
	else:
		_hold = maxf(0.0, _hold - delta * 2.0)
		_skip_fill.size.x = 60.0 * clampf(_hold / SKIP_HOLD, 0.0, 1.0)
		if _hold <= 0.0:
			_skip_box.visible = false


# ─── Шаги ────────────────────────────────────────────────────────────────────

func _run(steps: Array) -> void:
	for s in steps:
		await _exec(s)


func _exec(s: Dictionary) -> void:
	if s.has("parallel"):
		# Фоновые шаги ("background": true) не ждём: они идут, пока не кончатся остальные
		var left := [0]
		for sub: Dictionary in s.parallel:
			if not sub.get("background", false):
				left[0] += 1
		for sub: Dictionary in s.parallel:
			if sub.get("background", false):
				var bg := sub.duplicate()
				bg["_alive"] = func() -> bool: return left[0] > 0
				_exec(bg)
			else:
				_exec_counted(sub, left)
		while left[0] > 0:
			await get_tree().process_frame
	elif s.has("steps"):
		await _run(s.steps)
	elif s.has("pause"):
		await _sleep(float(s.pause))
	elif s.has("shot"):
		await _shot(s)
	elif s.has("camera"):
		await _camera_step(s)
	elif s.has("actor"):
		await _actor_step(s)
	elif s.has("say"):
		await _say(s)
	elif s.has("sound"):
		if not skipping:
			if s.has("at"):
				AudioManager.play_3d(s.sound, _point(s.at), s.get("opts", {}))
			else:
				AudioManager.play_2d(s.sound, s.get("opts", {}))
	elif s.has("layer"):
		if s.get("clear", false):
			AudioManager.clear_layer(s.layer, 0.01 if skipping else float(s.get("fade", 3.0)))
		else:
			AudioManager.set_layer(s.layer, s.sound, 0.01 if skipping else float(s.get("fade", 3.0)))
	elif s.has("effect"):
		await _effect(s)
	elif s.has("title"):
		show_title(s.title)
	elif s.has("call"):
		if skipping and s.get("skip", false):
			return
		var target: Object = _ctx.get("target")
		if target and target.has_method(s.call):
			target.callv(s.call, s.get("args", []))
		else:
			push_error("Cutscenes: нет метода %s у ctx.target" % s.call)
	else:
		push_error("Cutscenes: непонятный шаг %s" % s)


func _exec_counted(s: Dictionary, left: Array) -> void:
	await _exec(s)
	left[0] -= 1


## Пауза, которую прерывает пропуск.
func _sleep(t: float) -> void:
	var left := t
	while left > 0.0 and not skipping:
		await get_tree().process_frame
		left -= get_process_delta_time()


## Твин 0 → 1 за time: f(k) каждый кадр. При пропуске доходит до конца сразу.
func _animate(time: float, f: Callable, ease := "inout") -> void:
	if skipping or time <= 0.0:
		f.call(1.0)
		return
	var tw := create_tween()
	var tm := tw.tween_method(f, 0.0, 1.0, time)
	match ease:
		"linear":
			tm.set_trans(Tween.TRANS_LINEAR)
		"in":
			tm.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		"out":
			tm.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_:
			tm.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tw)
	await tw.finished
	_tweens.erase(tw)


## Точка по имени (см. шапку) или Vector3.
func _point(spec: Variant) -> Vector3:
	if spec is Vector3:
		return spec
	var key := String(spec)
	if key == "hero" and _player:
		return _player.eye_camera().global_position
	if key == "hero_feet" and _player:
		return _player.global_position
	var actors: Dictionary = _ctx.get("actors", {})
	if actors.has(key):
		var a: Node3D = actors[key]
		return a.head_point() if a.has_method("head_point") else a.global_position
	var points: Dictionary = _ctx.get("points", {})
	if points.has(key):
		var p: Variant = points[key]
		return p.call() if p is Callable else p
	push_error("Cutscenes: нет точки «%s»" % key)
	return Vector3.ZERO


func _actor(name: String) -> Node3D:
	var a: Node3D = (_ctx.get("actors", {}) as Dictionary).get(name)
	if a == null:
		push_error("Cutscenes: нет актёра «%s»" % name)
	return a


# ─── Камера ──────────────────────────────────────────────────────────────────

func _camera_step(s: Dictionary) -> void:
	var time := float(s.get("time", 1.0))
	var ease: String = s.get("ease", "inout")
	match s.camera:
		"look":
			if s.get("follow", false):
				await _follow(s.at, float(s.get("time", INF)), s.get("_alive", Callable()))
			else:
				var target := _point(s.at)
				if _detached:
					var from := _cam.global_basis.get_rotation_quaternion()
					var to := _look_basis(_cam.global_position, target).get_rotation_quaternion()
					await _animate(time, func(k: float) -> void: _cam.global_basis = Basis(from.slerp(to, k)), ease)
				elif _player:
					var a := _player.get_look()
					var b := _player.look_at_angles(target)
					var turn := func(k: float) -> void: _player.set_look(lerp_angle(a.x, b.x, k), lerpf(a.y, b.y, k))
					await _animate(time, turn, ease)
		"face":
			if _player:
				var b := _player.look_at_angles(_point(s.at))
				_player.set_look(b.x, float(s.get("pitch", b.y)))
		"move", "path":
			_detach()
			_shot_id += 1
			var roll0 := _roll
			var roll1 := deg_to_rad(float(s.roll)) if s.has("roll") else _roll
			var pts: Array[Vector3] = [_cam.global_position]
			if s.camera == "move":
				pts.append(_point(s.to))
			else:
				for p in s.points:
					pts.append(_point(p))
			var look: Variant = s.get("look")
			var from_q := _cam.global_basis.get_rotation_quaternion()
			var fly := func(k: float) -> void:
				_cam.global_position = _spline(pts, k)
				_roll = lerpf(roll0, roll1, k)
				if look != null:
					_cam.global_basis = _look_basis(_cam.global_position, _point(look))
			await _animate(time, fly, ease)
			if look == null:
				_cam.global_basis = Basis(from_q)
		"eyes":
			_shot_id += 1
			var roll0 := _roll
			var roll1 := deg_to_rad(float(s.get("roll", 0.0)))
			if not _detached:
				await _animate(time, func(k: float) -> void: _roll = lerpf(roll0, roll1, k), ease)
				return
			var start := _cam.global_transform
			var back := func(k: float) -> void:
				_roll = lerpf(roll0, roll1, k)
				_cam.global_transform = start.interpolate_with(_eye_transform(), k)
			await _animate(time, back, ease)
			_attach()
		_:
			push_error("Cutscenes: камера «%s»?" % s.camera)


## Следить за целью time секунд (догоняет мягко).
func _follow(spec: Variant, time: float, alive := Callable()) -> void:
	var left := time
	while left > 0.0 and not skipping and (not alive.is_valid() or alive.call()):
		var dt := get_process_delta_time()
		var target := _point(spec)
		var w := 1.0 - exp(-4.0 * dt)
		if _detached:
			var q := _cam.global_basis.get_rotation_quaternion().slerp(
				_look_basis(_cam.global_position, target).get_rotation_quaternion(), w)
			_cam.global_basis = Basis(q)
		elif _player:
			var a := _player.get_look()
			var b := _player.look_at_angles(target)
			_player.set_look(lerp_angle(a.x, b.x, w), lerpf(a.y, b.y, w))
		await get_tree().process_frame
		left -= dt


func _look_basis(from: Vector3, to: Vector3) -> Basis:
	var d := to - from
	if d.length_squared() < 1e-6:
		return _cam.global_basis
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.BACK
	return Basis.looking_at(d, up)


## Кривая Катмулла — Рома через точки (k от 0 до 1).
func _spline(pts: Array[Vector3], k: float) -> Vector3:
	if pts.size() == 2:
		return pts[0].lerp(pts[1], k)
	var n := pts.size() - 1
	var f := clampf(k, 0.0, 1.0) * n
	var i := mini(floori(f), n - 1)
	var t := f - i
	var p0 := pts[maxi(i - 1, 0)]
	var p1 := pts[i]
	var p2 := pts[i + 1]
	var p3 := pts[mini(i + 2, n)]
	return p1.cubic_interpolate(p2, p0, p3, t)


## Отцепить камеру из глаз: своя камера встаёт ровно туда же, рывка нет.
func _detach() -> void:
	if _detached or _player == null:
		return
	var eye := _player.eye_camera()
	if _cam == null or not is_instance_valid(_cam):
		_cam = Node3D.new()
		_cam.name = "CutsceneCamera"
		_lens = Camera3D.new()
		_lens.name = "Lens"
		_cam.add_child(_lens)
	if _cam.get_parent() != get_tree().current_scene:
		if _cam.get_parent():
			_cam.get_parent().remove_child(_cam)
		get_tree().current_scene.add_child(_cam)
	_lens.fov = eye.fov
	_lens.near = eye.near
	_lens.far = eye.far
	_lens.cull_mask = eye.cull_mask
	_cam.global_transform = _eye_transform()
	eye.rotation = Vector3.ZERO
	_detached = true
	_apply_lens()
	_lens.make_current()
	# Камера ушла из глаз — голову героя видно
	_player.set_head_visible(true)


func _attach() -> void:
	if not _detached:
		return
	_detached = false
	_apply_lens()
	_player.eye_camera().make_current()
	_player.set_head_visible(false)


## Где глаза героя — без дрожи и завала (их добавляет _apply_lens).
func _eye_transform() -> Transform3D:
	var eye := _player.eye_camera()
	return (eye.get_parent() as Node3D).global_transform * Transform3D(Basis(), eye.position)


## Дрожь и завал горизонта — на своей камере или на глазах героя (поворот самой камеры, штатив не трогаем).
func _apply_lens() -> void:
	var t := _shake_t
	var a := _shake
	var rot := Vector3(
		(sin(t * 37.0) + sin(t * 61.3 + 1.7)) * 0.012 * a,
		(sin(t * 43.1 + 0.6) + sin(t * 71.7 + 2.9)) * 0.012 * a,
		_roll + sin(t * 29.3 + 4.1) * 0.02 * a)
	if _detached and _lens:
		_lens.rotation = rot
	elif _player:
		_player.eye_camera().rotation = rot


# ─── Кадры (шаг "shot") ──────────────────────────────────────────────────────

## Настройки кадров по умолчанию: расстояние, высота, сторона (градусы), угол обзора (0 — как у глаз).
const SHOTS := {
	"close": {"dist": 0.9, "height": 0.0, "side": 20.0, "fov": 50.0},
	"insert": {"dist": 1.0, "height": 0.6, "side": 30.0, "fov": 48.0},
	"low": {"dist": 2.2, "height": 0.25, "side": 15.0, "fov": 0.0},
	"high_wide": {"dist": 9.0, "height": 8.0, "side": 0.0, "fov": 0.0},
	"over_shoulder": {"dist": 0.55, "height": 0.12, "side": "right", "fov": 0.0},
}
const SIDES := {"front": 0.0, "left": 90.0, "right": -90.0, "back": 180.0}


## Куда смотрит тот, кто в кадре (по горизонтали): актёр — лицом (−Z), герой — взглядом, точка — на север.
func _facing(spec: Variant) -> Vector3:
	var key := String(spec) if not spec is Vector3 else ""
	if key == "hero" or key == "hero_feet":
		return -_player.global_basis.z
	var actors: Dictionary = _ctx.get("actors", {})
	if actors.has(key):
		var b := (actors[key] as Node3D).global_basis
		return Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	return Vector3.FORWARD


## Земля под тем, кто в кадре.
func _base_y(spec: Variant) -> float:
	var key := String(spec) if not spec is Vector3 else ""
	if key == "hero" or key == "hero_feet":
		return _player.global_position.y
	var actors: Dictionary = _ctx.get("actors", {})
	if actors.has(key):
		return (actors[key] as Node3D).global_position.y
	return _point(spec).y


## Где стоит камера кадра и куда смотрит: [позиция, цель].
func _shot_frame(s: Dictionary, pushed: float) -> Array:
	var kind: String = s.shot
	var def: Dictionary = SHOTS.get(kind, SHOTS.close)
	var subject := _point(s.of)
	var target: Vector3 = _point(s.look) if s.has("look") else subject
	var dist := float(s.get("dist", def.dist))
	var height := float(s.get("height", def.height))
	var side: Variant = s.get("side", def.side)
	var pos: Vector3
	if kind == "over_shoulder":
		var from := _point(s.get("from", "hero"))
		var to := subject - from
		to.y = 0.0
		to = to.normalized() if to.length_squared() > 1e-6 else Vector3.FORWARD
		var right := to.cross(Vector3.UP)
		var sgn := -1.0 if String(side) == "left" else 1.0
		pos = from - to * dist + right * 0.32 * sgn + Vector3.UP * height
	else:
		var deg := float(SIDES[side]) if side is String else float(side)
		var dir := _facing(s.of).rotated(Vector3.UP, deg_to_rad(deg))
		pos = subject + dir * dist
		if kind == "low" or kind == "high_wide":
			pos.y = _base_y(s.of) + height
			if kind == "low" and not s.has("look"):
				target = subject + Vector3.UP * 0.15
			if kind == "high_wide" and not s.has("look"):
				target = Vector3(subject.x, _base_y(s.of) + 0.8, subject.z)
		else:
			pos.y = subject.y + height
	if pushed > 0.0:
		var to_t := target - pos
		pos += to_t.normalized() * minf(pushed, maxf(to_t.length() - 0.35, 0.0))
	return [pos, target]


func _shot(s: Dictionary) -> void:
	if _player == null:
		return
	_detach()
	_shot_id += 1
	var id := _shot_id
	var def: Dictionary = SHOTS.get(s.shot, SHOTS.close)
	var fov := float(s.get("fov", def.fov))
	var fov1 := fov if fov > 0.0 else _player.eye_camera().fov
	var roll1 := deg_to_rad(float(s.get("roll", 0.0)))
	var frame := _shot_frame(s, 0.0)
	var blend := float(s.get("blend", 0.0))
	if blend > 0.0 and not skipping:
		# Плавный переход из прошлого положения камеры
		var from := _cam.global_transform
		var fov0 := _lens.fov
		var roll0 := _roll
		var fly := func(k: float) -> void:
			var f := _shot_frame(s, 0.0)
			var to := Transform3D(_look_basis(f[0], f[1]), f[0])
			_cam.global_transform = from.interpolate_with(to, k)
			_lens.fov = lerpf(fov0, fov1, k)
			_roll = lerpf(roll0, roll1, k)
		await _animate(blend, fly, s.get("ease", "inout"))
	else:
		_cam.global_position = frame[0]
		_cam.global_basis = _look_basis(frame[0], frame[1])
	_lens.fov = fov1
	_roll = roll1
	_shake = float(s.get("shake", 0.0))
	_shake_decay = 0.0
	_apply_lens()
	# Удержание: следим за целью, наезжаем. Без time (и не фоновый) — кадр встал, сценарий идёт дальше
	var alive: Callable = s.get("_alive", Callable())
	var time := float(s.get("time", INF if alive.is_valid() else 0.0))
	var push := float(s.get("push", 0.0))
	var track: bool = s.get("track", true)
	var t := 0.0
	while t < time and not skipping and id == _shot_id and (not alive.is_valid() or alive.call()):
		await get_tree().process_frame
		t += get_process_delta_time()
		if id != _shot_id:
			break
		if track or push > 0.0:
			var k := clampf(t / time, 0.0, 1.0) if time < INF else 0.0
			var f := _shot_frame(s, push * k)
			_cam.global_position = f[0]
			_cam.global_basis = _look_basis(f[0], f[1])


# ─── Персонажи ───────────────────────────────────────────────────────────────

func _actor_step(s: Dictionary) -> void:
	var a := _actor(s.actor)
	if a == null:
		return
	if s.has("show"):
		a.visible = s.show
	if s.has("place"):
		a.global_position = _point(s.place)
	if s.has("face"):
		var fd := _point(s.face) - a.global_position
		if Vector2(fd.x, fd.z).length_squared() > 1e-6:
			a.rotation.y = atan2(-fd.x, -fd.z)
	if s.has("anim") and "anim" in a:
		a.anim = s.anim
	if s.has("turn_to"):
		var d := _point(s.turn_to) - a.global_position
		var from := a.rotation.y
		var to := atan2(-d.x, -d.z)
		await _animate(float(s.get("time", 0.4)), func(k: float) -> void: a.rotation.y = lerp_angle(from, to, k))
	if s.has("walk"):
		var pts: Array[Vector3] = [a.global_position]
		for p in s.walk:
			var q := _point(p)
			pts.append(q)
		var length := 0.0
		for i in pts.size() - 1:
			length += pts[i].distance_to(pts[i + 1])
		var speed := float(s.get("speed", 1.4))
		var go := func(k: float) -> void:
			var d := k * length
			for i in pts.size() - 1:
				var seg := pts[i].distance_to(pts[i + 1])
				if d <= seg or i == pts.size() - 2:
					var dir := pts[i + 1] - pts[i]
					a.global_position = pts[i].lerp(pts[i + 1], clampf(d / maxf(seg, 1e-4), 0.0, 1.0))
					if Vector2(dir.x, dir.z).length_squared() > 1e-6:
						a.rotation.y = lerp_angle(a.rotation.y, atan2(-dir.x, -dir.z), 0.25)
					break
				d -= seg
		await _animate(length / maxf(speed, 0.01), go, "linear")


# ─── Реплики, эффекты, надписи ───────────────────────────────────────────────

func _say(s: Dictionary) -> void:
	if skipping:
		return
	_say_id += 1
	var id := _say_id
	_subtitle.text = s.say
	if s.has("sound"):
		if s.has("who"):
			AudioManager.play_3d(s.sound, _point(s.who))
		else:
			AudioManager.play_2d(s.sound)
	await _sleep(float(s.get("time", 2.5)))
	if id == _say_id:
		_subtitle.text = ""


func _effect(s: Dictionary) -> void:
	var time := float(s.get("time", 1.0))
	var ease: String = s.get("ease", "inout")
	match s.effect:
		"fade":
			var c: Color = s.get("color", Color.BLACK)
			var a0 := _fade.color.a
			var a1 := float(s.get("to", 1.0))
			await _animate(time, func(k: float) -> void: _fade.color = Color(c.r, c.g, c.b, lerpf(a0, a1, k)), ease)
		"lighting":
			var level: Object = _ctx.get("level")
			if level == null or not level.has_method("blend_lighting"):
				push_error("Cutscenes: у ctx.level нет blend_lighting")
				return
			var amount := float(s.get("amount", 1.0))
			await _animate(time, func(k: float) -> void: level.blend_lighting(s.from, s.to, k * amount), s.get("ease", "linear"))
		"shake":
			_shake = float(s.get("amount", 0.5))
			_shake_decay = _shake / time if s.has("time") and time > 0.0 else 0.0
			if skipping:
				_shake = 0.0
		"roll":
			var r0 := _roll
			var r1 := deg_to_rad(float(s.get("to", 0.0)))
			await _animate(time if s.has("time") else 0.0, func(k: float) -> void: _roll = lerpf(r0, r1, k), ease)
		"global":
			var n: String = s.name
			var v0: float = s.get("from", PsxMaterial.global_param(n))
			var v1: float = s.to
			await _animate(time, func(k: float) -> void: PsxMaterial.set_global(n, lerpf(v0, v1, k)), ease)
		"light":
			var id: String = s.get("id", "light")
			if s.get("remove", false):
				if _lights.has(id):
					(_lights[id] as Node).queue_free()
					_lights.erase(id)
				return
			var light: OmniLight3D = _lights.get(id)
			if light == null:
				light = OmniLight3D.new()
				light.light_energy = 0.0
				get_tree().current_scene.add_child(light)
				_lights[id] = light
			if s.has("at"):
				light.global_position = _point(s.at)
			light.light_color = s.get("color", Color.WHITE)
			light.omni_range = float(s.get("range", 10.0))
			light.shadow_enabled = s.get("shadows", false)
			var e0 := light.light_energy
			var e1 := float(s.get("energy", 1.0))
			await _animate(time, func(k: float) -> void: light.light_energy = lerpf(e0, e1, k), ease)
		_:
			push_error("Cutscenes: эффект «%s»?" % s.effect)


## Надпись задачи в PS1-стиле: появляется, держится и исчезает сама (и после конца катсцены).
func show_title(text: String) -> void:
	_title.text = text
	if _title_tween:
		_title_tween.kill()
	_title.modulate.a = 0.0
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "modulate:a", 1.0, 1.2)
	_title_tween.tween_interval(3.5)
	_title_tween.tween_property(_title, "modulate:a", 0.0, 2.0)


## Затемнение экрана мгновенно (для сцен, которым нужно начать из черноты).
func set_fade(alpha: float, color := Color.BLACK) -> void:
	_fade.color = Color(color.r, color.g, color.b, alpha)


func _set_bars(on: bool) -> void:
	if _bars_tween:
		_bars_tween.kill()
	_bars_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	var h := float(BAR_HEIGHT) if on else 0.0
	_bars_tween.tween_property(_bar_top, "custom_minimum_size:y", h, 0.6)
	_bars_tween.tween_property(_bar_bottom, "custom_minimum_size:y", h, 0.6)


# ─── Интерфейс (320×240, как всё) ────────────────────────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	# Над пост-эффектом (слой 1) и под экраном «Кликни» (10)
	_ui.layer = 5
	add_child(_ui)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_fade)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	_ui.add_child(box)
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar_top)
	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mid)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar_bottom)

	_subtitle = Label.new()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_top = -BAR_HEIGHT - 2
	_subtitle.offset_bottom = -2
	_subtitle.offset_left = 12
	_subtitle.offset_right = -12
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	_subtitle.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle.add_theme_constant_override("outline_size", 3)
	_ui.add_child(_subtitle)

	# Индикатор пропуска: «Держи E — пропустить» и полоска, которая заполняется
	_skip_box = Control.new()
	_skip_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip_box.offset_left = -96
	_skip_box.offset_top = 6
	_skip_box.offset_right = -6
	_skip_box.offset_bottom = 26
	_skip_box.visible = false
	_ui.add_child(_skip_box)
	var skip_label := Label.new()
	skip_label.text = "E — пропустить"
	skip_label.add_theme_font_size_override("font_size", 9)
	skip_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	_skip_box.add_child(skip_label)
	var back := ColorRect.new()
	back.color = Color(0.25, 0.23, 0.2)
	back.position = Vector2(0, 14)
	back.size = Vector2(60, 3)
	_skip_box.add_child(back)
	_skip_fill = ColorRect.new()
	_skip_fill.color = Color(1.0, 0.8, 0.5)
	_skip_fill.position = Vector2(0, 14)
	_skip_fill.size = Vector2(0, 3)
	_skip_box.add_child(_skip_fill)

	_title = Label.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_left = -150
	_title.offset_right = 150
	_title.offset_top = 70
	_title.offset_bottom = 92
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 4)
	_title.modulate.a = 0.0
	_ui.add_child(_title)
