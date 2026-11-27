class_name NotesUI
extends CanvasLayer
## Чтение записок и журнал (этап 5б, CLAUDE.md §6). Экран в низком разрешении (как вся игра, 320×240),
## тёмная подложка, игра на паузе.
##  • open_note(id) — прочитать записку из мира (зовёт HeroHands по ПКМ). ПКМ — дальше по страницам, на последней — закрыть.
##    Прочитанная попадает в журнал: GameState.read_notes (id в порядке прочтения).
##  • Священная записка — цитата, под ней подпись-источник, пустая строка и приписка (чуть темнее). Если всё вместе не
##    влезает в лист — две страницы: цитата с подписью, потом приписка. Шрифт не уменьшаем (BODY_FONT).
##  • Tab — журнал: список прочитанных. W / S (или колесо мыши) — выбрать, ПКМ (или ЛКМ) — перечитать, ПКМ — назад к
##    списку, Tab — закрыть.
## Звук: свиток — parchment, табличка и черепок — wood_clack (play_2d с «always»: на паузе тоже звучит).

enum Mode { NONE, READ, JOURNAL, JOURNAL_READ }

const TEXT_COLOR := {
	"sacred": Color(0.86, 0.79, 0.62),
	"soldier": Color(0.80, 0.77, 0.71),
	"madman": Color(0.84, 0.70, 0.62),
}
## Приписка под цитатой — чуть темнее цитаты.
const ADDENDUM_COLOR := Color(0.70, 0.63, 0.48)
## Размер шрифта текста записки (ниже 11 при 320×240 уже не читается) и высота места под текст на листе, пикселей.
const BODY_FONT := 11
const BODY_W := 248.0
const BODY_H := 132.0
## Зазор между подписью-источником и припиской («пустая строка»), пикселей.
const GAP := 8
const DIM := Color(0.55, 0.5, 0.43)
const SELECT := Color(1.0, 0.8, 0.5)
## Строка журнала для записки без подписи: начало текста, столько символов.
const LIST_CHARS := 30

var mode := Mode.NONE
## Страницы открытой записки: [{"quote": bool, "addendum": bool}], номер текущей.
var _pages: Array = []
var _page_i := 0

var _player: Player
var _sel := 0
var _dim: ColorRect
var _page: ColorRect
var _body: VBoxContainer
var _text: Label
var _source: Label
var _gap: Control
var _addendum: Label
var _hint: Label
var _journal: ColorRect
var _list: VBoxContainer
var _journal_hint: Label


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("notes_ui")
	_build()
	_show(Mode.NONE)


## Кто читает: пока герой «заперт» (катсцена, обморок), журнал не открывается.
func setup(player: Player) -> void:
	_player = player


func is_open() -> bool:
	return mode != Mode.NONE


## Прочитать записку из мира: экран чтения, пауза, звук; записка — в журнал.
func open_note(id: String) -> void:
	if Notes.info(id).is_empty() or is_open():
		return
	if not GameState.read_notes.has(id):
		GameState.read_notes.append(id)
	_fill_page(id)
	_sound(id)
	get_tree().paused = true
	_show(Mode.READ)


func _input(event: InputEvent) -> void:
	if mode == Mode.NONE:
		if event.is_action_pressed("journal") and _can_open_journal():
			get_viewport().set_input_as_handled()
			_sel = maxi(GameState.read_notes.size() - 1, 0)
			_fill_list()
			get_tree().paused = true
			_show(Mode.JOURNAL)
		return
	if event is InputEventMouseMotion:
		return
	match mode:
		Mode.READ:
			if event.is_action_pressed("interact"):
				_close()
		Mode.JOURNAL_READ:
			if event.is_action_pressed("interact") or _is_click(event):
				_show(Mode.JOURNAL)
			elif event.is_action_pressed("journal"):
				_close()
		Mode.JOURNAL:
			var n := GameState.read_notes.size()
			if event.is_action_pressed("journal"):
				_close()
			elif n > 0 and (event.is_action_pressed("interact") or _is_click(event)):
				var id: String = GameState.read_notes[_sel]
				_fill_page(id)
				_sound(id)
				_show(Mode.JOURNAL_READ)
			elif n > 0 and (event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up") or _wheel(event, MOUSE_BUTTON_WHEEL_UP)):
				_sel = (_sel - 1 + n) % n
				_fill_list()
			elif n > 0 and (event.is_action_pressed("move_back") or event.is_action_pressed("ui_down") or _wheel(event, MOUSE_BUTTON_WHEEL_DOWN)):
				_sel = (_sel + 1) % n
				_fill_list()
	# Пока экран открыт, клавиши и клики до игры не доходят (Esc — пропускаем: записка закроется, включится пауза,
	# её ведёт ClickToStart: курсор отпущен — он закрывает записку и ставит паузу)
	if not event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()


func _can_open_journal() -> bool:
	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	return _player == null or not _player.locked


func _close() -> void:
	_show(Mode.NONE)
	get_tree().paused = false


## Закрыть записку или журнал, не снимая паузу: её теперь держит экран паузы (ClickToStart — Esc, курсор отпущен).
func close_for_pause() -> void:
	_show(Mode.NONE)


func _is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _wheel(event: InputEvent, button: MouseButton) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == button


func _sound(id: String) -> void:
	var form: String = Notes.info(id).get("form", "scroll")
	if form == "scroll":
		AudioManager.play_2d("parchment", {"always": true})
	else:
		AudioManager.play_2d("wood_clack", {"always": true, "db": -4.0})


func _show(m: Mode) -> void:
	mode = m
	_dim.visible = m != Mode.NONE
	_page.visible = m == Mode.READ or m == Mode.JOURNAL_READ
	_journal.visible = m == Mode.JOURNAL
	_update_hint()


# ─── Наполнение ──────────────────────────────────────────────────────────────

## Наполнить лист запиской id и поставить первую страницу.
func _fill_page(id: String) -> void:
	var inf := Notes.info(id)
	var type: String = inf.get("type", "soldier")
	var sacred: bool = type == "sacred"
	var color: Color = TEXT_COLOR.get(type, TEXT_COLOR.soldier)
	_text.text = inf.get("text", "")
	_text.add_theme_color_override("font_color", color)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if sacred else HORIZONTAL_ALIGNMENT_LEFT
	_source.text = inf.get("source", "")
	_addendum.text = inf.get("addendum", "")
	_addendum.add_theme_color_override("font_color", ADDENDUM_COLOR)
	_pages = [{"quote": true, "addendum": true}]
	# Не влезло одним листом — цитата с подписью, потом приписка
	if inf.has("addendum") and _height_of({"quote": true, "addendum": true}) > BODY_H:
		_pages = [{"quote": true, "addendum": false}, {"quote": false, "addendum": true}]
	_page_i = 0
	_show_page()


func _turn_page() -> void:
	_page_i += 1
	_show_page()
	AudioManager.play_2d("parchment", {"always": true, "db": -8.0})


func _show_page() -> void:
	var pg: Dictionary = _pages[_page_i]
	_text.visible = pg.quote
	_source.visible = pg.quote and _source.text != ""
	_gap.visible = pg.quote and pg.addendum
	_addendum.visible = pg.addendum and _addendum.text != ""
	_body.size = Vector2(BODY_W, BODY_H)
	_update_hint()


func _update_hint() -> void:
	if _hint == null:
		return
	var last := _page_i >= _pages.size() - 1
	if mode == Mode.READ:
		_hint.text = "ПКМ — закрыть" if last else "ПКМ — дальше"
	else:
		_hint.text = ("ПКМ — назад · Tab — закрыть" if last else "ПКМ — дальше · Tab — закрыть")


## Высота страницы (какие части видны), пикселей, при ширине BODY_W.
func _height_of(pg: Dictionary) -> float:
	var h := 0.0
	if pg.quote:
		h += _label_h(_text)
		if _source.text != "":
			h += _label_h(_source)
		if pg.addendum:
			h += GAP
	if pg.addendum:
		h += _label_h(_addendum)
	return h


func _label_h(l: Label) -> float:
	l.size = Vector2(BODY_W, 1.0)
	return l.get_minimum_size().y


func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ids := GameState.read_notes
	if ids.is_empty():
		_list.add_child(_label("Пусто", 10, DIM))
		_journal_hint.text = "Tab — закрыть"
		return
	_journal_hint.text = "W / S — выбрать · ПКМ — читать · Tab — закрыть"
	# Окно списка: не больше 9 строк вокруг выбранной
	var first := clampi(_sel - 4, 0, maxi(ids.size() - 9, 0))
	for i in range(first, mini(first + 9, ids.size())):
		var inf := Notes.info(ids[i])
		var title: String = inf.title if inf.has("title") else (inf.source.trim_prefix("— ") if inf.has("source") else _short(inf.get("text", "")))
		var on := i == _sel
		_list.add_child(_label(("› " if on else "  ") + title, 10, SELECT if on else DIM))


func _short(t: String) -> String:
	t = t.replace("\n", " ")
	if t.length() <= LIST_CHARS:
		return t
	var cut := t.substr(0, LIST_CHARS)
	var sp := cut.rfind(" ")
	if sp > LIST_CHARS / 2:
		cut = cut.substr(0, sp)
	return cut.rstrip(" .,:—") + "…"


# ─── Узлы ────────────────────────────────────────────────────────────────────

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	# Лист: тёмная подложка по центру. Текст в столбце: цитата, подпись-источник (справа), зазор, приписка
	_page = _panel(Vector2(276, 176))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.position = Vector2(14, 12)
	_body.size = Vector2(BODY_W, BODY_H)
	_page.add_child(_body)
	_text = _label("", BODY_FONT, TEXT_COLOR.soldier)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_text)
	_source = _label("", BODY_FONT, DIM)
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_body.add_child(_source)
	_gap = Control.new()
	_gap.custom_minimum_size = Vector2(0, GAP)
	_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_gap)
	_addendum = _label("", BODY_FONT, ADDENDUM_COLOR)
	_addendum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_addendum)

	_journal = _panel(Vector2(276, 176))
	var title := _label("Журнал", 11, TEXT_COLOR.sacred)
	title.position = Vector2(14, 8)
	_journal.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.position = Vector2(14, 28)
	_list.size = Vector2(248, 130)
	_journal.add_child(_list)
	_journal_hint = _label("", 8, DIM)
	_journal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal_hint.position = Vector2(0, 160)
	_journal_hint.size = Vector2(276, 12)
	_journal.add_child(_journal_hint)

	_hint = _label("", 8, DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 160)
	_hint.size = Vector2(276, 12)
	_page.add_child(_hint)


func _panel(size: Vector2) -> ColorRect:
	var p := ColorRect.new()
	p.color = Color(0.055, 0.045, 0.035, 0.94)
	p.size = size
	p.position = (Vector2(320, 240) - size) * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
