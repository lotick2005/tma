extends Node
## Звук игры (autoload AudioManager). CLAUDE.md §5.
##
##  • Реестр звуков по именам — data/sounds.gd: у каждого либо файл из audio/, либо процедурная заглушка
##    (SoundSynth). Заглушки генерируются в фоне по одной за кадр, пока висит «Кликни, чтобы начать»
##    (сначала нужные во тьме); если звук понадобился раньше — генерируется сразу.
##  • play_3d() — разовый 3D-звук в точке; add_emitter() — постоянный источник (хор, птицы…).
##  • set_layer() / clear_layer() — слои фона (не 3D) с плавным фейдом; set_ambience_muted() — заглушить фон.
##  • Громкость шин: set_bus_volume() / get_bus_volume().
##  • Окклюзия: раз в OCCLUSION_INTERVAL с луч от слушателя к каждому 3D-источнику; за стеной — тише и глуше.
##  • Ложные тревоги: раз в 40–120 с где-то в переулке вне поля зрения (параметры — FALSE_ALARMS в data/sounds.gd).
##  • Всё звучит только после клика на «Кликни, чтобы начать» (unlock()): браузер иначе молчит.
## Отладка (tma/debug/keys): 2 — заглушить фон / вернуть, 3 — angel_chord рядом с игроком.

## Изменилось «показать звуковые зоны и источники» (для зон эха уровня).
signal debug_visible_changed(on: bool)

const REG := preload("res://data/sounds.gd")
## Шины (CLAUDE.md §5). Шины эха — Reverb_*, на них звук попадает через зоны (SoundZones).
const BUSES := ["Master", "Ambience", "SFX", "Voices", "Angel", "Music"]
## Как часто проверять стены между слушателем и источниками, с.
const OCCLUSION_INTERVAL := 0.15
## Слой физики стен (геометрия уровня).
const WALL_MASK := 1
## За сколько секунд фон гаснет / возвращается по «заглушить фон».
const MUTE_FADE := 1.5
## Угроза, при которой фон начинает уходить, и при которой он уже в тишине.
const THREAT_DUCK_FROM := 0.1
const THREAT_DUCK_TO := 0.7

## Звук разрешён (был клик).
var unlocked := false
## Откуда брать поверхность под ногами: Callable(pos: Vector3) -> "stone" / "earth" / "wood". Задаёт уровень.
var surface_provider := Callable()
## Точки для ложных тревог: "alley" / "door" → PackedVector3Array. Задаёт уровень.
var false_alarm_points := {}
## Ложные тревоги включены (во тьме — да, днём — нет).
var false_alarms_enabled := false
## Показывать отладочные зоны и источники.
var debug_visible := false

## Готовые потоки: имя → Array[AudioStream] (варианты).
var _streams := {}
## Очередь заглушек на фоновую генерацию.
var _pending: Array[String] = []
var _layers := {}
var _emitters: Array[SoundEmitter] = []
var _occlusion_timer := 0.0
var _occlusion_index := 0
## Громкость шин, выставленная игроком / панелью, дБ.
var _user_db := {}
## Заглушка фона: 1 — звучит, 0 — тишина (плавно).
var _ambience_on := 1.0
var _ambience_on_target := 1.0
var _alarm_timer := 0.0
var _debug_keys := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_keys = ProjectSettings.get_setting("tma/debug/keys", false)
	for bus in BUSES:
		var i := AudioServer.get_bus_index(bus)
		if i < 0:
			push_error("AudioManager: нет шины %s — проверь default_bus_layout.tres" % bus)
		else:
			_user_db[bus] = AudioServer.get_bus_volume_db(i)
	# Сначала то, что нужно сразу после клика во тьме (герой, ложные тревоги), потом остальное
	for sound_name in REG.SOUNDS:
		if REG.SOUNDS[sound_name].has("synth"):
			_pending.append(sound_name)
	var first := func(n: String) -> int: return 0 if n.begins_with("breath") or n.begins_with("step") or n == "heartbeat" \
		else (1 if n.begins_with("alarm") or n == "whisper" else 2)
	_pending.sort_custom(func(a: String, b: String) -> bool: return first.call(a) < first.call(b))
	_reset_alarm_timer()


## Первый клик игрока: браузер разрешил звук. Вызывает экран «Кликни, чтобы начать».
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	for layer_id in _layers:
		var layer: AmbienceLayer = _layers[layer_id]
		if is_instance_valid(layer) and layer.get_child_count() == 0:
			_start_layer(layer)
	for e in _emitters:
		if is_instance_valid(e):
			e.resume()


# ─── Реестр ──────────────────────────────────────────────────────────────────

func has_sound(sound_name: String) -> bool:
	return REG.SOUNDS.has(sound_name)


func entry(sound_name: String) -> Dictionary:
	return REG.SOUNDS.get(sound_name, {})


## Поток звука (случайный вариант).
func get_stream(sound_name: String) -> AudioStream:
	var list := _variants(sound_name)
	if list.is_empty():
		return null
	return list[randi() % list.size()]


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var e := entry(sound_name)
	if e.is_empty():
		push_error("AudioManager: нет звука «%s» в data/sounds.gd" % sound_name)
		_streams[sound_name] = []
		return []
	var list := []
	if e.has("file"):
		var files: Array = e.file if e.file is Array else [e.file]
		for path in files:
			var s := load(path) as AudioStream
			if s == null:
				push_error("AudioManager: не загрузился %s" % path)
				continue
			if e.get("loop", false):
				if s is AudioStreamOggVorbis:
					(s as AudioStreamOggVorbis).loop = true
				elif s is AudioStreamWAV:
					(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
					(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
			list.append(s)
	else:
		for v in int(e.get("variants", 1)):
			var w := SoundSynth.make(e.synth, v)
			if w:
				list.append(w)
	_streams[sound_name] = list
	_pending.erase(sound_name)
	return list


func _process(delta: float) -> void:
	# Фоновая генерация заглушек: по одной за кадр, пока ждём клика (потом — только по требованию,
	# чтобы не дёргать кадры во время игры)
	if not _pending.is_empty() and not unlocked:
		_variants(_pending[0])
	_update_buses(delta)
	_occlusion_timer -= delta
	if _occlusion_timer <= 0.0:
		_occlusion_timer = OCCLUSION_INTERVAL
		_update_occlusion()
	if unlocked and false_alarms_enabled and not get_tree().paused:
		_alarm_timer -= delta
		if _alarm_timer <= 0.0:
			_reset_alarm_timer()
			trigger_false_alarm()


func _unhandled_input(event: InputEvent) -> void:
	if not _debug_keys:
		return
	if event.is_action_pressed("debug_2"):
		set_ambience_muted(not is_ambience_muted())
	elif event.is_action_pressed("debug_3"):
		var cam := get_viewport().get_camera_3d()
		if cam:
			var forward := -cam.global_transform.basis.z
			play_3d("angel_chord", cam.global_position + forward * 2.5 + Vector3.UP * 0.5)


# ─── 3D-звуки ────────────────────────────────────────────────────────────────

## Разовый 3D-звук в точке мира. Вернёт источник (или null, если звука нет или ещё не было клика).
## opts: "db" — добавка громкости, "occlude" — проверять стены (по умолчанию да), "reverb" — эхо зон (да),
## "pitch" — своя высота (иначе случайный разброс из реестра).
func play_3d(sound_name: String, pos: Vector3, opts := {}) -> SoundEmitter:
	if not unlocked:
		return null
	var stream := get_stream(sound_name)
	if stream == null:
		return null
	var e := entry(sound_name)
	var em := _make_emitter(sound_name, e, opts)
	em.one_shot = true
	_scene_root().add_child(em)
	em.global_position = pos
	var pitch: float = opts.get("pitch", 1.0 + randf_range(-1.0, 1.0) * float(e.get("pitch", 0.0)))
	em.play_stream(stream, 0.0, pitch)
	return em


## Постоянный 3D-источник (зацикленный звук), ребёнок узла parent в точке local_pos.
## Начнёт звучать после клика (со случайного места). set_active(false) — выключить.
func add_emitter(sound_name: String, parent: Node3D, local_pos: Vector3, opts := {}) -> SoundEmitter:
	var stream := get_stream(sound_name)
	if stream == null:
		return null
	var e := entry(sound_name)
	var em := _make_emitter(sound_name, e, opts)
	em.one_shot = false
	em.position = local_pos
	parent.add_child(em)
	em.set_stream(stream)
	em.set_active(opts.get("active", true))
	return em


func _make_emitter(sound_name: String, e: Dictionary, opts: Dictionary) -> SoundEmitter:
	var em := SoundEmitter.new()
	em.name = "Sound_" + sound_name
	em.sound_name = sound_name
	em.occlude = opts.get("occlude", true)
	em.volume_db = opts.get("db", 0.0)
	# Фон дня (шина Ambience) — без эха: его гасит угроза и «заглушить фон», а шины эха — нет
	var reverb: bool = opts.get("reverb", e.get("bus", "SFX") != "Ambience")
	em.setup(e, reverb)
	if debug_visible:
		em.set_debug_visible(true)
	_emitters.append(em)
	em.tree_exiting.connect(func() -> void: _emitters.erase(em))
	return em


func _scene_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else get_tree().root


## Есть ли стена между слушателем и источниками — по кругу, все за один проход (их немного).
func _update_occlusion() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _emitters.is_empty():
		return
	var space := cam.get_world_3d().direct_space_state
	var from := cam.global_position
	var exclude: Array[RID] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject3D:
			exclude.append((p as CollisionObject3D).get_rid())
	for em in _emitters:
		if not is_instance_valid(em) or not em.occlude or not em.is_inside_tree():
			continue
		var to := em.global_position
		if from.distance_to(to) > em.hearing_range():
			continue
		var q := PhysicsRayQueryParameters3D.create(from, to, WALL_MASK, exclude)
		em.occlusion_target = 0.0 if space.intersect_ray(q).is_empty() else 1.0


## Слышно ли напрямую (без стены) точку pos — для ложных тревог.
func _line_clear(from: Vector3, to: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to, WALL_MASK)
	return cam.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ─── Слои фона ───────────────────────────────────────────────────────────────

## Слой фона layer_id (например, "bg"): плавно сменить звук на sound_name. Тот же звук — ничего не делает.
func set_layer(layer_id: String, sound_name: String, fade := 3.0) -> void:
	var old: AmbienceLayer = _layers.get(layer_id)
	if is_instance_valid(old):
		if old.sound_name == sound_name:
			return
		old.stop(fade)
	var layer := AmbienceLayer.new()
	layer.name = "Layer_%s_%s" % [layer_id, sound_name]
	layer.sound_name = sound_name
	layer.base_db = entry(sound_name).get("db", 0.0)
	layer.set_meta("fade", fade)
	add_child(layer)
	_layers[layer_id] = layer
	if unlocked:
		_start_layer(layer)


func clear_layer(layer_id: String, fade := 3.0) -> void:
	var old: AmbienceLayer = _layers.get(layer_id)
	if is_instance_valid(old):
		old.stop(fade)
	_layers.erase(layer_id)


func _start_layer(layer: AmbienceLayer) -> void:
	var stream := get_stream(layer.sound_name)
	if stream:
		layer.start(stream, entry(layer.sound_name).get("bus", "Ambience"), float(layer.get_meta("fade", 3.0)))


## Заглушить фон (шина Ambience) плавно или вернуть. Перед ангелом гаснет весь фон (CLAUDE.md §5).
func set_ambience_muted(muted: bool) -> void:
	_ambience_on_target = 0.0 if muted else 1.0


func is_ambience_muted() -> bool:
	return _ambience_on_target == 0.0


# ─── Шины ────────────────────────────────────────────────────────────────────

func set_bus_volume(bus: String, db: float) -> void:
	_user_db[bus] = db
	if bus != "Ambience":
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, db)


func get_bus_volume(bus: String) -> float:
	return _user_db.get(bus, 0.0)


## Шина фона = громкость игрока × «заглушить фон» × уход в тишину по угрозе.
func _update_buses(delta: float) -> void:
	_ambience_on = move_toward(_ambience_on, _ambience_on_target, delta / MUTE_FADE)
	var threat: float = ThreatDirector.threat
	var duck := 1.0 - smoothstep(THREAT_DUCK_FROM, THREAT_DUCK_TO, threat)
	var k := _ambience_on * duck
	var i := AudioServer.get_bus_index("Ambience")
	if i >= 0:
		AudioServer.set_bus_volume_db(i, _user_db.get("Ambience", 0.0) + linear_to_db(maxf(k, 1e-4)))


# ─── Поверхность и ложные тревоги ────────────────────────────────────────────

## Поверхность под ногами: "stone" — мостовая, "earth" — земля дворов и комнат, "wood" — мостки и лестницы.
func surface_at(pos: Vector3) -> String:
	if surface_provider.is_valid():
		return surface_provider.call(pos)
	return "stone"


func _reset_alarm_timer() -> void:
	_alarm_timer = randf_range(REG.FALSE_ALARMS.interval_min, REG.FALSE_ALARMS.interval_max)


## Ложная тревога сейчас: случайный звук из списка в точке переулка вне поля зрения, не ближе distance_min.
## force — играть и при высокой угрозе (кнопка в панели). Вернёт false, если подходящей точки нет.
func trigger_false_alarm(force := false) -> bool:
	var cfg: Dictionary = REG.FALSE_ALARMS
	if not force and ThreatDirector.threat > cfg.max_threat:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	# Взвешенный случайный порядок: у кого вес больше, тот чаще первый
	var sounds := []
	for s in cfg.sounds:
		sounds.append([pow(randf(), 1.0 / float(s[2])), s])
	sounds.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var from := cam.global_position
	var forward := -cam.global_transform.basis.z
	for pair in sounds:
		var s: Array = pair[1]
		var points: PackedVector3Array = false_alarm_points.get(s[1], PackedVector3Array())
		if points.is_empty():
			continue
		for attempt in 40:
			var p := points[randi() % points.size()]
			var d := from.distance_to(p)
			if d < cfg.distance_min or d > cfg.distance_max:
				continue
			# Вне поля зрения: за спиной / сбоку или за стеной
			var in_view := forward.dot((p - from).normalized()) > 0.45
			if in_view and _line_clear(from, p):
				continue
			play_3d(s[0], p)
			return true
	return false


# ─── Отладка ─────────────────────────────────────────────────────────────────

func set_debug_visible(on: bool) -> void:
	debug_visible = on
	for e in _emitters:
		if is_instance_valid(e):
			e.set_debug_visible(on)
	for n in get_tree().get_nodes_in_group("sound_debug"):
		(n as Node3D).visible = on
	debug_visible_changed.emit(on)


## Сколько заглушек ещё не сгенерировано (для проверки).
func pending_count() -> int:
	return _pending.size()
