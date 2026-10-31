extends CanvasLayer
## Отладочная панель подстройки картинки — только при tma/debug/keys = true.
## 0 — открыть / закрыть (курсор освобождается). Всё меняется вживую. Внизу — строка со всеми
## значениями: её можно выделить или скопировать кнопкой и прислать, чтобы вписать как значения по умолчанию.
## Ищет уровень через родителя: WorldEnvironment, Player (тело и светильник), солнце (если есть).
## Если уровень умеет (toggle_day) — кнопка «день / тьма».
## Переключатель «Подписи предметов»: по центру экрана — имя (kind) предмета под прицелом, луч из камеры до LABEL_RANGE м
## (PropRegistry). По этим именам удобно называть предметы в отзывах. Работает и с закрытой панелью.

const FONT_SIZE := 8
## Дальность луча подписей предметов, м.
const LABEL_RANGE := 6.0

var _values := {}
var _value_labels := {}
var _env: Environment
var _level: Node
var _sun: DirectionalLight3D
var _lamp: Node
var _body: HeroBody
var _panel: PanelContainer
var _out: LineEdit
var _labels_on := false
var _pick_label: Label


func _ready() -> void:
	if not ProjectSettings.get_setting("tma/debug/keys", false):
		queue_free()
		return
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind.call_deferred()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_0") and _panel:
		get_viewport().set_input_as_handled()
		_set_open(not _panel.visible)


## Параметры: ключ, подпись, мин, макс, шаг, начальное значение, применить.
func _params() -> Array:
	var fog: Color = PsxMaterial.global_param("psx_fog_color")
	var params := [
		["fog_start", "Туман от", 0.0, 40.0, 0.05, PsxMaterial.global_param("psx_fog_start"),
			func(v: float) -> void: PsxMaterial.set_global("psx_fog_start", v)],
		["fog_end", "Туман до", 1.0, 200.0, 0.1, PsxMaterial.global_param("psx_fog_end"),
			func(v: float) -> void: PsxMaterial.set_global("psx_fog_end", v)],
		["fog_r", "Туман R", 0.0, 1.0, 0.005, fog.r, func(_v: float) -> void: _apply_fog_color()],
		["fog_g", "Туман G", 0.0, 1.0, 0.005, fog.g, func(_v: float) -> void: _apply_fog_color()],
		["fog_b", "Туман B", 0.0, 1.0, 0.005, fog.b, func(_v: float) -> void: _apply_fog_color()],
		["lamp_energy", "Свет сила", 0.0, 3.0, 0.01, _lamp.light_energy,
			func(v: float) -> void: _lamp.light_energy = v],
		["lamp_range", "Свет радиус", 0.5, 10.0, 0.1, _lamp.light_range,
			func(v: float) -> void: _lamp.light_range = v],
		["ambient", "Фон. свет", 0.0, 1.5, 0.005, _env.ambient_light_energy,
			func(v: float) -> void: _env.ambient_light_energy = v],
		["arm_glow", "Подсв. рук", 0.0, 1.0, 0.01, _body.lamp_glow,
			func(v: float) -> void: _body.lamp_glow = v],
		["snap", "Дрожание", 0.0, 4.0, 0.1, PsxMaterial.global_param("psx_snap_pixels"),
			func(v: float) -> void: PsxMaterial.set_global("psx_snap_pixels", v)],
		["affine", "Аффинность", 0.0, 1.0, 0.01, PsxMaterial.global_param("psx_affine"),
			func(v: float) -> void: PsxMaterial.set_global("psx_affine", v)],
	]
	if _sun and _sun.visible:
		params.append(["sun", "Солнце", 0.0, 3.0, 0.01, _sun.light_energy,
			func(v: float) -> void: _sun.light_energy = v])
	return params


func _bind() -> void:
	var level := get_parent()
	_level = level
	var envs := level.find_children("*", "WorldEnvironment", true, false)
	var player := level.find_child("Player", true, false)
	if envs.is_empty() or player == null:
		push_warning("Отладочная панель: не нашла WorldEnvironment или Player")
		return
	_env = (envs[0] as WorldEnvironment).environment
	_body = player.get_node("Body")
	_lamp = player.get_node("Body/OilLamp")
	var suns := level.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		_sun = suns[0]
	_build()
	_set_open(false)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	bg.set_content_margin_all(3)
	_panel.add_theme_stylebox_override("panel", bg)
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_panel.theme = theme
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Отладка картинки — 0: закрыть"
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	box.add_child(grid)
	for p in _params():
		var key: String = p[0]
		_values[key] = float(p[5])
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = p[1]
		name_label.custom_minimum_size.x = 44
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = p[2]
		slider.max_value = p[3]
		slider.step = p[4]
		slider.value = _values[key]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 22
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		_value_labels[key] = value_label
		var apply: Callable = p[6]
		slider.value_changed.connect(func(v: float) -> void:
			_values[key] = v
			apply.call(v)
			_refresh())
		grid.add_child(row)

	if _level and _level.has_method("toggle_day"):
		var row := HBoxContainer.new()
		box.add_child(row)
		var day_btn := Button.new()
		day_btn.text = "Сейчас: " + ("день" if _level.is_day() else "тьма") + " — переключить"
		day_btn.pressed.connect(func() -> void:
			_level.toggle_day()
			_rebuild())
		row.add_child(day_btn)

	var labels_btn := CheckButton.new()
	labels_btn.text = "Подписи предметов (имя под прицелом)"
	labels_btn.button_pressed = _labels_on
	labels_btn.toggled.connect(func(on: bool) -> void: _labels_on = on)
	box.add_child(labels_btn)

	var hint := Label.new()
	hint.text = "Строка значений (выдели или нажми «Копировать»):"
	box.add_child(hint)
	_out = LineEdit.new()
	_out.editable = false
	_out.selecting_enabled = true
	box.add_child(_out)
	var copy := Button.new()
	copy.text = "Копировать"
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(_out.text))
	box.add_child(copy)
	_refresh()


func _process(_delta: float) -> void:
	if _pick_label == null:
		_pick_label = Label.new()
		_pick_label.add_theme_font_size_override("font_size", FONT_SIZE)
		_pick_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_pick_label.add_theme_constant_override("outline_size", 2)
		_pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pick_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_pick_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_pick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_pick_label)
	_pick_label.visible = _labels_on
	if not _labels_on:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	# Стены закрывают предметы за ними
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * LABEL_RANGE)
	var player := _level.find_child("Player", true, false) as CollisionObject3D
	if player:
		query.exclude = [player.get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	var limit: float = from.distance_to(hit.position) if not hit.is_empty() else INF
	var kind := PropRegistry.pick(from, dir, LABEL_RANGE, limit)
	_pick_label.text = "+\n" + kind


## Пересобрать панель после смены света: ползунки берут новые значения.
func _rebuild() -> void:
	_panel.queue_free()
	_values.clear()
	_value_labels.clear()
	_build()
	_set_open(true)


func _apply_fog_color() -> void:
	var c := Color(_values.get("fog_r", 0.0), _values.get("fog_g", 0.0), _values.get("fog_b", 0.0))
	PsxMaterial.set_global("psx_fog_color", c)
	_env.background_color = c


func _refresh() -> void:
	var parts: PackedStringArray = []
	for key in _values:
		var v: float = _values[key]
		_value_labels[key].text = "%.2f" % v if absf(v) < 10.0 else "%.1f" % v
		parts.append("%s=%.3f" % [key, v])
	_out.text = " ".join(parts)


func _set_open(open: bool) -> void:
	_panel.visible = open
	var cts := get_tree().get_first_node_in_group("click_to_start")
	if cts:
		cts.blocked = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif cts and cts.is_started():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
