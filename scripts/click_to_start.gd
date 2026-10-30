extends CanvasLayer
## Экран «Кликни, чтобы начать» и захват курсора.
## В браузере мышь захватывается и звук включается только после клика по странице,
## поэтому игра стоит на паузе до первого клика.
## Esc отпускает курсор (браузер делает это и сам), клик возвращает его.
## Полноценная пауза — этап 10.

## Игрок кликнул первый раз: мышь захвачена, браузер разрешил звук.
signal started

var _started := false

@onready var _start_panel: Control = $StartPanel
@onready var _resume_panel: Control = $ResumePanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_panel.show()
	_resume_panel.hide()
	_start_panel.gui_input.connect(_on_panel_input)
	_resume_panel.gui_input.connect(_on_panel_input)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	# Курсор мог отпустить и сам браузер (Esc, переключение вкладки)
	if _started:
		_resume_panel.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _on_panel_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _started:
		_started = true
		_start_panel.hide()
		get_tree().paused = false
		started.emit()
