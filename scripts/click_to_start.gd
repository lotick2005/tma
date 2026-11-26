extends CanvasLayer
## Экран «Кликни, чтобы начать» и захват курсора.
## В браузере мышь захватывается и звук включается только после клика по странице,
## поэтому игра стоит на паузе до первого клика.
## Esc отпускает курсор (браузер делает это и сам), клик возвращает его.
## Пауза (этап 5б): пока курсор отпущен — игра стоит, на экране «Кликни, чтобы продолжить» и два ползунка:
## чувствительность мыши и общая громкость (Settings, user://settings.cfg). Клик по ползунку курсор не захватывает.

## Игрок кликнул первый раз: мышь захвачена, браузер разрешил звук (AudioManager.unlock()).
signal started

## Пока true, экран «Кликни, чтобы продолжить» не показывается (открыта отладочная панель).
var blocked := false

var _started := false
## Паузу держит этот экран (а не конец демо) — ему её и снимать. Если пауза началась поверх записки или журнала,
## они закрываются, а пауза переходит к этому экрану.
var _paused_here := false
var _mouse_slider: HSlider
var _volume_slider: HSlider

@onready var _start_panel: Control = $StartPanel
@onready var _resume_panel: Control = $ResumePanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("click_to_start")
	_start_panel.show()
	_resume_panel.hide()
	_start_panel.gui_input.connect(_on_panel_input)
	_resume_panel.gui_input.connect(_on_panel_input)
	get_tree().paused = true
	Settings.load_and_apply()
	_build_sliders()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	# Курсор мог отпустить и сам браузер (Esc, переключение вкладки)
	if _started:
		var want := not blocked and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		if want == _resume_panel.visible:
			return
		_resume_panel.visible = want
		if want:
			# Пауза не рисуется поверх записки и журнала: сначала они закрываются (пауза теперь — наша)
			var closed := false
			for n in get_tree().get_nodes_in_group("notes_ui"):
				if n.is_open():
					n.close_for_pause()
					closed = true
			if closed or not get_tree().paused:
				get_tree().paused = true
				_paused_here = true
		else:
			get_viewport().gui_release_focus()
			if _paused_here:
				_paused_here = false
				get_tree().paused = false


func is_started() -> bool:
	return _started


func _on_panel_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _started:
		_started = true
		_start_panel.hide()
		get_tree().paused = false
		AudioManager.unlock()
		started.emit()


# ─── Ползунки паузы ──────────────────────────────────────────────────────────

func _build_sliders() -> void:
	var prompt := _resume_panel.get_node("Prompt") as Label
	prompt.offset_bottom = -40.0
	_mouse_slider = _slider("Чувствительность мыши", 142.0, Settings.MOUSE_MIN, Settings.MOUSE_MAX, 0.05, Settings.mouse)
	_mouse_slider.value_changed.connect(func(v: float) -> void:
		Settings.mouse = v
		Settings.save())
	_volume_slider = _slider("Громкость", 176.0, 0.0, 1.0, 0.05, Settings.volume)
	_volume_slider.value_changed.connect(func(v: float) -> void:
		Settings.volume = v
		Settings.apply()
		Settings.save())


func _slider(title: String, y: float, lo: float, hi: float, step: float, value: float) -> HSlider:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(60.0, y)
	label.size = Vector2(200.0, 14.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_panel.add_child(label)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.position = Vector2(80.0, y + 14.0)
	sl.size = Vector2(160.0, 16.0)
	sl.focus_mode = Control.FOCUS_NONE
	_resume_panel.add_child(sl)
	return sl
