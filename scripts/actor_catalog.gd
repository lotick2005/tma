extends Node3D
## Каталог персонажей (scenes/actors/catalog.tscn): все модели из res://models/ в ряд, у каждого по очереди
## проигрываются все анимации Anims.LIST (одна и та же у всех сразу — удобно сравнивать), над головой — имя
## анимации. Сзади второй ряд — тела (Corpses): позы, запечённые в статичный меш, и они же в пепле.
## Управление: ← / → — предыдущая / следующая анимация, пробел — пауза на текущей. Свет ровный, без тумана.

const STEP := 1.35
## Цикл показывается не меньше этого (с), разовая — целиком и ещё HOLD секунд стоит в последнем кадре.
const LOOP_TIME := 4.0
const HOLD := 1.0

var _models: Array[CharacterModel] = []
var _labels: Array[Label3D] = []
var _names: Array = []
var _index := 0
var _timer := 0.0
var _paused := false
var _title: Label


func _ready() -> void:
	PsxMaterial.set_global("psx_fog_start", 500.0)
	PsxMaterial.set_global("psx_fog_end", 600.0)
	_names = Anims.LIST.keys()
	var x0 := -(CharacterModel.MODELS.size() - 1) * STEP * 0.5
	for i in CharacterModel.MODELS.size():
		var m := CharacterModel.new()
		m.model = CharacterModel.MODELS[i]
		m.cast_shadows = true
		add_child(m)
		m.build()
		m.position = Vector3(x0 + i * STEP, 0.0, 0.0)
		m.rotation.y = PI  # лицом к камере
		_models.append(m)
		var name_label := _label(CharacterModel.MODELS[i], m.position + Vector3(0, 0.02, 0.55), 0.006)
		name_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		name_label.rotation_degrees.x = -70.0
		var l := _label("", m.position + Vector3(0, 1.95, 0), 0.007)
		_labels.append(l)
	# Второй ряд — тела
	var kinds := Corpses.KINDS.keys()
	var cx0 := -(kinds.size() - 1) * 1.1 * 0.5
	for i in kinds.size():
		var mi := MeshInstance3D.new()
		mi.mesh = Corpses.mesh(kinds[i])
		mi.material_override = Corpses.material(kinds[i])
		mi.position = Vector3(cx0 + i * 1.1, 0.0, -2.6)
		add_child(mi)
		var l := _label(kinds[i], mi.position + Vector3(0, 0.55, 0.0), 0.006)
		l.modulate = Color(0.85, 0.85, 0.85)
	var ui := CanvasLayer.new()
	add_child(ui)
	_title = Label.new()
	_title.position = Vector2(4, 2)
	_title.add_theme_font_size_override("font_size", 8)
	ui.add_child(_title)
	_show(0)


func _label(text: String, pos: Vector3, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 6
	l.position = pos
	add_child(l)
	return l


func _show(i: int) -> void:
	_index = posmod(i, _names.size())
	var n: String = _names[_index]
	for m in _models:
		m.reset_motion()
		m.play(n, 0.0, 1.0, true)
	var kind: String = Anims.LIST[n][0]
	var sp := Anims.speed(n)
	for l in _labels:
		l.text = n
	_title.text = "%d/%d  %s  (%s%s)   ← → — листать, пробел — пауза" % [_index + 1, _names.size(), n,
		{"loop": "цикл", "once": "разово", "pose": "поза"}[kind], (", %.2f м/с" % sp) if sp > 0.0 else ""]
	var length := Anims.library().get_animation(n).length
	_timer = maxf(LOOP_TIME, length) if kind == "loop" else length + HOLD
	if kind == "pose":
		_timer = 2.0


func _process(delta: float) -> void:
	if _paused:
		return
	_timer -= delta
	if _timer <= 0.0:
		_show(_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_RIGHT:
				_show(_index + 1)
			KEY_LEFT:
				_show(_index - 1)
			KEY_SPACE:
				_paused = not _paused
