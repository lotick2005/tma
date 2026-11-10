extends Node
## «Смерть, которая не смерть» (autoload Awaken, CLAUDE.md §1, тайна «Агасфер»).
## Поймали святые, сжёг ангел — никакой надписи «Вы погибли»: экран гаснет, звук глохнет, как в обмороке
## во вступлении (ФНЧ на шинах, сердце), пауза в черноте — и герой снова очнулся у последнего чекпойнта:
## глаза открываются рывками, картинка мутная, вдох, кряхтение; встаёт и достаёт светильник.
##
## Общий эффект: await Awaken.pass_out(player) — им же будет пользоваться ангел (этап 6).
## Святой: await Awaken.caught_by_saint(saint, player) — схватил, борьба, потом pass_out.
## Что делать в черноте (перенести героя, расставить святых по местам) — уровень задаёт respawn_handler.

## Герой в черноте (уровень переносит героя к чекпойнту и сбрасывает врагов).
signal blacked_out
## Герой очнулся, управление вернулось.
signal woke_up

## Шины, которые глохнут в черноте, и срез фильтра, Гц.
const MUFFLE_BUSES := ["SFX", "Voices", "Ambience", "Angel"]
const MUFFLE_CUTOFF := 380.0

## Сколько длится чернота, с (вместе со звуками «сквозь вату»).
@export var black_time := 5.5
## Глаза открываются: [доля открытия, за сколько с] по очереди — рывками, как во вступлении.
@export var lids := [[0.25, 0.5], [0.0, 0.35], [0.55, 0.8], [0.35, 0.4], [1.0, 1.4]]
## Сколько секунд картинка мутная после того, как открыл глаза.
@export var blur_time := 6.0

## Уровень: что делать в черноте (Callable без аргументов).
var respawn_handler := Callable()
var busy := false

var _ui: CanvasLayer
var _black: ColorRect
var _top: ColorRect
var _bottom: ColorRect
var _blur: ColorRect
var _shake := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ui = CanvasLayer.new()
	_ui.layer = 4
	add_child(_ui)
	_blur = ColorRect.new()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/wake_blur.gdshader")
	_blur.material = sm
	_blur.visible = false
	_ui.add_child(_blur)
	for i in 2:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		_ui.add_child(r)
		if i == 0:
			_top = r
		else:
			_bottom = r
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_black)


## Святой схватил героя: тянется, валит, держит; герой отбивается руками перед лицом; потом — чернота и «очнулся».
func caught_by_saint(saint: Saint, player: Player) -> void:
	if busy:
		return
	busy = true
	player.set_locked(true)
	if player.hands():
		player.hands().drop_all()
	# Светильник остаётся в руке: мечется перед лицом и выхватывает из тьмы повязку и руки святого
	var look := player.look_at_angles(saint.head_point())
	var from := player.get_look()
	AudioManager.play_3d("grab", saint.head_point(), {"db": 2.0})
	AudioManager.play_2d("struggle")
	AudioManager.play_2d("breath_struggle")
	player.arms().set_struggle(true)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		player.set_look(lerp_angle(from.x, look.x, k), lerpf(from.y, look.y, k)), 0.0, 1.0, 0.18)
	await _wait(0.3)
	saint.play_hold()
	AudioManager.play_3d("saint_growl", saint.head_point(), {"db": 3.0})
	# Борьба: взгляд дёргается, героя пригибает к земле
	_shake = 1.0
	var t := 0.0
	var choke_at := [1.0, 2.1]
	while t < 2.8:
		var dt := get_process_delta_time()
		t += dt
		var aim := player.look_at_angles(saint.head_point())
		var j := Vector2(sin(t * 37.0) * 0.04 + randf_range(-0.02, 0.02), sin(t * 29.0) * 0.03 - t * 0.06)
		player.set_look(aim.x + j.x, aim.y + j.y)
		if not choke_at.is_empty() and t >= choke_at[0]:
			choke_at.pop_front()
			AudioManager.play_2d("choke")
		if t > 1.4 and not player.is_crouched():
			player.crouch(true)
		await get_tree().process_frame
	_shake = 0.0
	busy = false
	await pass_out(player)
	player.arms().set_struggle(false)


## Общий эффект: чернота, глухо, пауза — перенос к чекпойнту (respawn_handler) — очнулся.
func pass_out(player: Player) -> void:
	busy = true
	player.set_locked(true)
	GameState.wakes += 1
	# Гаснет (быстро) и глохнет
	for b in MUFFLE_BUSES:
		AudioManager.set_bus_muffled(b, true, MUFFLE_CUTOFF)
	AudioManager.play_2d("body_fall", {"db": -4.0})
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.45)
	await tw.finished
	player.arms().set_struggle(false)
	# Чернота: сердце медленно, глухие звуки издалека
	_heartbeats(player, black_time)
	await _wait(0.8)
	blacked_out.emit()
	if respawn_handler.is_valid():
		respawn_handler.call()
	player.set_lamp(false, true)
	player.crouch(true)
	player.set_look(player.get_look().x, -0.75)
	await _wait(1.6)
	AudioManager.play_3d("thud_far", player.global_position + Vector3(14.0, 1.0, -9.0), {"db": -6.0})
	await _wait(maxf(black_time - 2.4, 0.5))
	await wake(player)
	busy = false


## Очнулся: веки поднимаются рывками, мутно, вдох; встаёт, достаёт светильник, управление возвращается.
func wake(player: Player) -> void:
	_set_lids(0.0)
	_top.visible = true
	_bottom.visible = true
	_black.color.a = 0.0
	_blur.visible = true
	(_blur.material as ShaderMaterial).set_shader_parameter("amount", 1.0)
	for b in MUFFLE_BUSES:
		AudioManager.set_bus_muffled(b, false)
	var blur_tw := create_tween()
	blur_tw.tween_method(func(a: float) -> void:
		(_blur.material as ShaderMaterial).set_shader_parameter("amount", a), 1.0, 0.0, blur_time) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	var first := true
	var open := 0.0
	var start_look := player.get_look()
	for step: Array in lids:
		if first:
			AudioManager.play_2d("gasp_wake")
		var tw := create_tween()
		tw.tween_method(_set_lids, open, float(step[0]), float(step[1])).set_trans(Tween.TRANS_SINE)
		await tw.finished
		open = step[0]
		if first:
			first = false
			get_tree().create_timer(1.6).timeout.connect(func() -> void: AudioManager.play_2d("wake_groan"))
	_top.visible = false
	_bottom.visible = false
	# Поднимает голову и встаёт
	var tw2 := create_tween()
	tw2.tween_method(func(k: float) -> void:
		player.set_look(start_look.x, lerpf(start_look.y, -0.1, k)), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	player.crouch(false)
	AudioManager.play_2d("wake_groan", {"db": -3.0})
	await _wait(0.6)
	player.set_lamp(true)
	await _wait(0.5)
	player.set_locked(false)
	woke_up.emit()
	await blur_tw.finished
	_blur.visible = false


func _set_lids(open: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var half := size.y * 0.5 * (1.0 - clampf(open, 0.0, 1.0))
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, half + 1.0)
	_bottom.position = Vector2(0.0, size.y - half - 1.0)
	_bottom.size = Vector2(size.x, half + 1.0)


func _heartbeats(_player: Player, time: float) -> void:
	var t := 0.0
	var gap := 1.25
	while t < time:
		AudioManager.play_2d("heartbeat", {"db": -2.0})
		await _wait(gap)
		t += gap
		gap = minf(gap + 0.12, 1.8)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout
