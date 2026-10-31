class_name SoundEmitter
extends Node3D
## 3D-источник звука (создаёт AudioManager: play_3d — разовый, add_emitter — постоянный).
##
## Внутри два плеера:
##  • main — сам звук на своей шине (SFX, Voices, Angel…), зоны эха его не трогают;
##  • twin — копия того же звука только для эха. Он видит зоны эха (Area3D, слой ZONE_LAYER), и в зоне
##    движок отправляет его на шину эха этой зоны (Reverb_Alley…), а вне зон — на заглушённую Reverb_None.
##    Почему так: в Godot 4 звук внутри Area3D с эхом уходит ТОЛЬКО на шину эха, своя шина пропадает.
## Окклюзия: AudioManager раз в OCCLUSION_INTERVAL с проверяет луч от слушателя; если между ними стена —
## occlusion_target = 1, и звук плавно становится тише и глуше (ФНЧ встроенного фильтра затухания).

## Слой физики, на котором лежат зоны эха (Area3D). Больше на нём ничего нет.
const ZONE_LAYER := 20
## Без стены / за стеной: срез фильтра, Гц; сила фильтра, дБ; приглушение, дБ.
const CUTOFF_CLEAR := 5000.0
const CUTOFF_OCCLUDED := 600.0
const FILTER_DB_CLEAR := -24.0
const FILTER_DB_OCCLUDED := -60.0
const OCCLUDED_DB := -12.0
## За сколько секунд звук полностью «уходит за стену» или возвращается.
const OCCLUSION_FADE := 0.3

## Имя звука в реестре.
var sound_name := ""
## Проверять ли стены между слушателем и источником (свои шаги героя — нет).
var occlude := true
## Удалить себя, когда доиграл.
var one_shot := true
## Громкость, дБ (добавка поверх реестра).
var volume_db := 0.0
## 0 — слышно напрямую, 1 — за стеной.
var occlusion := 0.0
var occlusion_target := 0.0

var main: AudioStreamPlayer3D
var twin: AudioStreamPlayer3D
var _base_db := 0.0
var _range := 30.0
var _active := true
var _debug_mesh: MeshInstance3D


func setup(entry: Dictionary, reverb: bool) -> void:
	_base_db = entry.get("db", 0.0)
	_range = entry.get("range", 30.0)
	main = _make_player(entry, entry.get("bus", "SFX"), 0)
	if reverb:
		twin = _make_player(entry, "Reverb_None", 1 << (ZONE_LAYER - 1))
	main.finished.connect(_on_finished)
	_apply()


func _make_player(entry: Dictionary, bus: String, area_mask: int) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.area_mask = area_mask
	p.unit_size = entry.get("unit", 3.0)
	p.max_distance = _range
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	return p


func play_stream(stream: AudioStream, from := 0.0, pitch := 1.0) -> void:
	for p in _players():
		p.stream = stream
		p.pitch_scale = pitch
		if _active:
			p.play(from)


func is_playing() -> bool:
	return main != null and main.playing


## Поток без проигрывания (постоянный источник: заиграет по set_active / resume).
func set_stream(stream: AudioStream) -> void:
	for p in _players():
		p.stream = stream


## Включить / выключить постоянный источник (например, птицы только днём). До клика только запоминает.
func set_active(on: bool) -> void:
	_active = on
	if on:
		resume()
	else:
		for p in _players():
			p.stop()


## Заиграть, если включён и ещё не играет (после клика «Кликни, чтобы начать»).
func resume() -> void:
	if not _active or main == null or main.stream == null or main.playing or not AudioManager.unlocked:
		return
	# Со случайного места: несколько одинаковых источников не звучат в унисон
	var from := randf() * _length(main.stream)
	for p in _players():
		p.play(from)


func is_active() -> bool:
	return _active


## Дальность слышимости, м.
func hearing_range() -> float:
	return _range


func _length(stream: AudioStream) -> float:
	var l := stream.get_length()
	return l * 0.95 if l > 0.0 else 0.0


func _players() -> Array[AudioStreamPlayer3D]:
	var out: Array[AudioStreamPlayer3D] = []
	if main:
		out.append(main)
	if twin:
		out.append(twin)
	return out


func _process(delta: float) -> void:
	if occlusion != occlusion_target:
		occlusion = move_toward(occlusion, occlusion_target, delta / OCCLUSION_FADE)
		_apply()
	if _debug_mesh:
		var mat := _debug_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.2, 1.0, 0.3).lerp(Color(1.0, 0.2, 0.2), occlusion)
		_debug_mesh.visible = _active


func _apply() -> void:
	var db := _base_db + volume_db + OCCLUDED_DB * occlusion
	var cutoff := lerpf(CUTOFF_CLEAR, CUTOFF_OCCLUDED, occlusion)
	var filter_db := lerpf(FILTER_DB_CLEAR, FILTER_DB_OCCLUDED, occlusion)
	for p in _players():
		p.volume_db = db
		p.attenuation_filter_cutoff_hz = cutoff
		p.attenuation_filter_db = filter_db


## Отладка (панель 0, «показать звуковые зоны и источники»): шарик — зелёный, если слышно напрямую, красный — за стеной.
func set_debug_visible(on: bool) -> void:
	if on and _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		sphere.radial_segments = 8
		sphere.rings = 4
		_debug_mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_debug_mesh.material_override = mat
		_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_debug_mesh)
	if _debug_mesh:
		_debug_mesh.visible = on and _active
		set_process(true)
		if not on:
			_debug_mesh.queue_free()
			_debug_mesh = null


func _on_finished() -> void:
	if one_shot:
		queue_free()
