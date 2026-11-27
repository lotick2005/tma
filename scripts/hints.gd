class_name Hints
extends CanvasLayer
## Подсказки управления (этап 5б): каждая — один раз за игру, когда впервые нужна; одна строка внизу, без рамок,
## появляется и гаснет. Никаких обучающих окон. Что уже показано — GameState.hints_shown.
##  • «C — присесть», «F — светильник» — после катсцены первого святого (уровень зовёт request) или когда впервые
##    растёт угроза (святой рядом);
##  • «ПКМ — взять» — светильник лежит под взглядом (его подбирают сами); «F — светильник» — только когда он уже у героя;
##  • «ПКМ — подобрать» — впервые под взглядом предмет, который можно взять; «ЛКМ — бросить» — только пока что-то в руке
##    (опустела рука — подсказка пропадает сразу, в том числе после поимки и «очнулся»);
##  • «ПКМ — читать» — впервые под взглядом записка; «Tab — журнал» — после первой прочитанной записки;
##  • «Q / E — выглянуть» — у первого угла рядом со святым (уровень зовёт request, PEEK_HINT в данных уровня).
## Пока катсцена, обморок или пауза — ждут; на паузе строка спрятана.

const TEXT := {
	"crouch": "C — присесть",
	"lamp": "F — светильник",
	"take_lamp": "ПКМ — взять",
	"pick": "ПКМ — подобрать",
	"throw": "ЛКМ — бросить",
	"read": "ПКМ — читать",
	"journal": "Tab — журнал",
	"peek": "Q / E — выглянуть",
}
## Сколько строка видна, с; появление и угасание; пауза между двумя подсказками подряд.
const SHOW_TIME := 4.0
const FADE := 0.5
const GAP := 0.6
## Угроза, с которой «нужны» присед и светильник (если игрок обошёл катсцену первого святого).
const THREAT_FROM := 0.3

var _player: Player
var _queue: Array[String] = []
var _label: Label
var _t := 0.0
var _busy := false
var _check := 0.0
var _shown_id := ""
var _tween: Tween


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0.0, 214.0)
	_label.size = Vector2(320.0, 16.0)
	_label.modulate.a = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func setup(player: Player) -> void:
	_player = player


## Подсказка нужна сейчас (если ещё не показана и не в очереди).
func request(id: String) -> void:
	if GameState.hints_shown.has(id) or _queue.has(id) or not TEXT.has(id):
		return
	# Про светильник на F — только когда он у героя; про бросок — только пока что-то в руке
	if id == "lamp" and not GameState.has_lamp:
		return
	if id == "throw" and not _has_held():
		return
	_queue.append(id)


func _has_held() -> bool:
	var hands := _player.hands() if _player else null
	return hands != null and hands.held_count > 0


func _process(delta: float) -> void:
	# На паузе (записка, журнал, пауза), при поимке и «очнулся» строку не видно
	var hidden := get_tree().paused or Awaken.busy or (_player != null and _player.locked)
	_label.visible = not hidden
	# Бросать нечего (отдал, поймали, очнулся) — «ЛКМ — бросить» гаснет сразу и не стоит в очереди
	if _player != null and not _has_held():
		_queue.erase("throw")
		if _shown_id == "throw":
			_cancel_shown()
	# Светильник уже взят — «ПКМ — взять» не нужна
	if GameState.has_lamp:
		_queue.erase("take_lamp")
		if _shown_id == "take_lamp":
			_cancel_shown()
	if get_tree().paused:
		return
	if _player == null or _player.locked or Awaken.busy or not GameState.intro_done:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.2
		_watch()
	if not _busy and not _queue.is_empty():
		_show(_queue.pop_front())


## Что игроку нужно прямо сейчас.
func _watch() -> void:
	if ThreatDirector.threat > THREAT_FROM:
		request("crouch")
		request("lamp")
	var hands := _player.hands()
	if hands == null:
		return
	if hands.lamp_pickable():
		request("take_lamp")
	if hands.held_count > 0:
		request("throw")
	if not GameState.read_notes.is_empty() and (hands.notes_ui == null or not hands.notes_ui.is_open()):
		request("journal")
	var cam := _player.eye_camera()
	var dir := -cam.global_basis.z
	if hands.notes and not GameState.hints_shown.has("read"):
		if not hands.notes.readable(cam.global_position, dir, [_player.get_rid()]).is_empty():
			request("read")
	if hands.props and not GameState.hints_shown.has("pick"):
		var p := hands.props.pickable(cam.global_position, dir)
		if p and p.pick_limit() > 0:
			request("pick")


func _show(id: String) -> void:
	_busy = true
	_shown_id = id
	GameState.hints_shown[id] = true
	_label.text = TEXT[id]
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, FADE)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE)
	_tween.tween_interval(GAP)
	_tween.tween_callback(func() -> void:
		_busy = false
		_shown_id = "")


## Убрать показанную подсказку сразу; она не засчитана как показанная (покажется, когда снова понадобится).
func _cancel_shown() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	GameState.hints_shown.erase(_shown_id)
	_shown_id = ""
	_label.modulate.a = 0.0
	_busy = false
