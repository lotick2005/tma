class_name Player
extends CharacterBody3D
## Герой: вид от первого лица, ходьба, бег с выносливостью, присед.
## Узел Player повёрнут туда, куда смотрит мышь (по нему считается движение WASD); тело — отдельно
## (hero_body.gd: стоит, пока взгляд не ушёл далеко, на ходу доворачивается). Камера — в голове тела:
## её ставит hero_body.gd (place_camera), отдельного покачивания нет — качает анимация шагов.
## Руки и светильник — hero_arms.gd (F — достать / убрать).
## Отладка (tma/debug/keys): клавиша 6 — камера со стороны, облёт мышью, колесо — ближе / дальше.
## Курсором управляет экран «Кликни, чтобы начать» (scripts/click_to_start.gd),
## здесь только обзор, пока курсор захвачен.

enum MoveMode { STAND, CROUCH, WALK, RUN }

## Слой отрисовки тела героя: от своего светильника тело тень не отбрасывает (от других — да).
const BODY_LAYER := 2
## Слой рук и модели светильника: свой огонь их напрямую не освещает (вплотную пересвечивал бы),
## они подсвечены через self_illum.
const VIEW_LAYER := 3

## Сменился режим движения: стоит / присел / идёт / бежит. Нужен для шума (этап 5).
signal move_mode_changed(mode: MoveMode)
## Нога встала на землю (по ступне анимации, hero_body.gd) — для звука шагов (HeroAudio).
signal footstep(mode: MoveMode)

@export_group("Скорость")
@export var walk_speed := 2.2
@export var run_speed := 4.6
@export var crouch_speed := 1.0
## Разгон и торможение, м/с².
@export var acceleration := 14.0

@export_group("Выносливость")
## Запас бега, секунд.
@export var stamina_max := 5.0
## Восстановление, секунд запаса за секунду без бега.
@export var stamina_regen := 0.8
## Если выдохся до нуля, бег вернётся, только когда запас дорастёт до этого значения.
@export var stamina_recover := 1.5

@export_group("Рост и присед")
## Высота коллизии стоя и в приседе, м. Глаза — из анимации (кость головы): стоя ≈1,64, в приседе ≈1,3.
## В приседе проходит под потолком от 1,4 м — это и есть самый низкий проход (канал, уровень 6, CLAUDE.md §3).
@export var stand_height := 1.8
@export var crouch_height := 1.4
## true — C переключает присед, false — надо держать.
@export var crouch_toggle := true
## Радиус коллизии: покрывает тело вместе с коленями в приседе.
@export var collision_radius := 0.35
## Через препятствие не выше этого герой перешагивает сам (пороги, камни, ступени), м.
@export var step_height := 0.35

@export_group("Обзор")
## Радиан на пиксель экрана.
@export var mouse_sensitivity := 0.0022
@export_range(10.0, 89.0) var pitch_limit_deg := 85.0

var move_mode: MoveMode = MoveMode.STAND
var stamina := 0.0
## Управление отобрано (катсцена): нет обзора мышью, движения, приседа и светильника по клавишам.
## Взгляд, присед и светильник катсцена меняет сама — через set_look(), crouch(), set_lamp().
var locked := false

var _crouched := false
var _exhausted := false
var _debug_keys := false
var _orbit: Camera3D
var _orbit_angles := Vector2(PI, -0.25)
var _orbit_dist := 2.2
## Камера со стороны смотрит на эту точку (в осях героя, от середины тела) — для крупных планов.
var orbit_focus := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _arms: Node3D = $Head/Camera3D/Arms
@onready var _body: HeroBody = $Body


func _ready() -> void:
	add_to_group("player")
	stamina = stamina_max
	# Своя копия формы, чтобы присед не менял общий ресурс сцены
	_collision.shape = CapsuleShape3D.new()
	_collision.shape.radius = collision_radius
	_set_body_height(stand_height)
	_head.position.y = 1.6
	_arms.set_lamp_out(GameState.lamp_out, true)
	_arms.lamp_changed.connect(func(out: bool) -> void: GameState.lamp_out = out)
	_body.foot_down.connect(func() -> void: footstep.emit(move_mode))
	_debug_keys = ProjectSettings.get_setting("tma/debug/keys", false)


func _unhandled_input(event: InputEvent) -> void:
	if _debug_keys and event.is_action_pressed("debug_6"):
		set_orbit(_orbit == null or not _orbit.current)
		return
	if _orbit and _orbit.current:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var o: Vector2 = event.screen_relative * mouse_sensitivity
			_orbit_angles = Vector2(_orbit_angles.x - o.x, clampf(_orbit_angles.y - o.y, -1.4, 1.4))
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_orbit_dist = maxf(0.6, _orbit_dist - 0.2)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_dist = minf(6.0, _orbit_dist + 0.2)
	if locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _orbit and _orbit.current:
			return
		# screen_relative — в пикселях экрана, не зависит от растяжения 320×240
		var d: Vector2 = event.screen_relative * mouse_sensitivity
		rotate_y(-d.x)
		var limit := deg_to_rad(pitch_limit_deg)
		_head.rotation.x = clampf(_head.rotation.x - d.y, -limit, limit)
	elif event.is_action_pressed("crouch") and crouch_toggle:
		_set_crouched(not _crouched)
	elif event.is_action_pressed("lamp_toggle"):
		_arms.toggle_lamp()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if not crouch_toggle and not locked:
		_set_crouched(Input.is_action_pressed("crouch"))

	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var has_input := input.length_squared() > 0.01
	var wants_run := has_input and Input.is_action_pressed("run")
	if wants_run and _crouched:
		_set_crouched(false)
	var running := wants_run and not _crouched and not _exhausted

	if running:
		stamina = maxf(0.0, stamina - delta)
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(stamina_max, stamina + stamina_regen * delta)
		if _exhausted and stamina >= stamina_recover:
			_exhausted = false

	var speed := crouch_speed if _crouched else (run_speed if running else walk_speed)
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	var target := dir * speed
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var from := global_position
	move_and_slide()
	_try_step(from, Vector3(target.x, 0.0, target.z) * delta)

	var moving := has_input and horizontal.length() > 0.1
	var mode := MoveMode.STAND
	if _crouched:
		mode = MoveMode.CROUCH
	elif moving:
		mode = MoveMode.RUN if running else MoveMode.WALK
	if mode != move_mode:
		move_mode = mode
		move_mode_changed.emit(move_mode)

	_body.set_motion(Vector3(velocity.x, 0.0, velocity.z) if moving else Vector3.ZERO, _crouched, walk_speed, run_speed)


func _process(_delta: float) -> void:
	if _orbit and _orbit.current:
		var center := global_position + Vector3.UP * (0.8 if _crouched else 1.1) + global_basis * orbit_focus
		var dir := Basis.from_euler(Vector3(_orbit_angles.y, _orbit_angles.x, 0.0)) * Vector3.BACK
		_orbit.global_position = center + dir * _orbit_dist
		_orbit.look_at(center)


## Камера со стороны (клавиша 6): облёт героя мышью, WASD по-прежнему двигает героя относительно его взгляда.
func set_orbit(on: bool) -> void:
	if on and _orbit == null:
		_orbit = Camera3D.new()
		_orbit.name = "OrbitCamera"
		_orbit.top_level = true
		_orbit.near = 0.05
		add_child(_orbit)
	if _orbit == null:
		return
	_orbit.fov = _camera.fov
	_orbit.far = _camera.far
	if on:
		_orbit_angles.x = rotation.y + PI
		_orbit.make_current()
	else:
		_camera.make_current()
	_body.set_head_visible(on)


## Наклон взгляда, рад (вниз — минус).
func get_pitch() -> float:
	return _head.rotation.x


## Базис взгляда в мире (как у камеры в глазах).
func eye_basis() -> Basis:
	return _head.global_basis


## Камеру ставит тело (hero_body.gd): глаза — на кости головы. pos — в осях Player.
func place_camera(pos: Vector3) -> void:
	_head.position = pos


# ─── Для катсцен (scripts/cutscene_player.gd) ────────────────────────────────

## Отобрать / вернуть управление.
func set_locked(on: bool) -> void:
	locked = on


## Камера в глазах героя.
func eye_camera() -> Camera3D:
	return _camera


## Взгляд: (поворот тела вокруг Y, наклон головы), радианы.
func get_look() -> Vector2:
	return Vector2(rotation.y, _head.rotation.x)


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	var limit := deg_to_rad(pitch_limit_deg)
	_head.rotation.x = clampf(pitch, -limit, limit)


## Какой взгляд нужен, чтобы смотреть из глаз на точку.
func look_at_angles(point: Vector3) -> Vector2:
	var d := point - _camera.global_position
	var flat := Vector2(d.x, d.z).length()
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, maxf(flat, 0.001)))


func crouch(on: bool) -> void:
	_set_crouched(on)


func set_lamp(out: bool, instant := false) -> void:
	if _arms.lamp_out != out:
		_arms.set_lamp_out(out, instant)


func set_head_visible(on: bool) -> void:
	_body.set_head_visible(on or (_orbit != null and _orbit.current))


func _set_crouched(value: bool) -> void:
	if value == _crouched:
		return
	if not value and not _can_stand():
		return
	_crouched = value
	_set_body_height(crouch_height if _crouched else stand_height)


func _set_body_height(height: float) -> void:
	var capsule := _collision.shape as CapsuleShape3D
	capsule.height = height
	_collision.position.y = height * 0.5


## Шаг через невысокое препятствие: если упёрлись в него, пробуем «поднять ногу» на step_height,
## пройти вперёд и опуститься на то, что под ногами. Камера опускается обратно плавно.
func _try_step(from: Vector3, motion: Vector3) -> void:
	if not is_on_floor() or motion.length_squared() < 1e-8:
		return
	var moved := global_position - from
	moved.y = 0.0
	if moved.length() > motion.length() * 0.6:
		return
	var blocked := false
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < 0.7:
			blocked = true
	if not blocked:
		return
	var xf := global_transform
	# Шагаем вперёд хотя бы на полрадиуса: иначе край ступеньки приходится на бок капсулы, а не под неё
	var rest := motion.normalized() * maxf((motion - moved).length(), collision_radius * 0.5)
	if test_move(xf, Vector3.UP * step_height):
		return
	xf.origin += Vector3.UP * step_height
	if test_move(xf, rest):
		return
	xf.origin += rest
	var params := PhysicsTestMotionParameters3D.new()
	params.from = xf
	params.motion = Vector3.DOWN * (step_height + 0.05)
	var res := PhysicsTestMotionResult3D.new()
	if not PhysicsServer3D.body_test_motion(get_rid(), params, res):
		return
	if res.get_collision_normal().y < 0.7:
		return
	var rise := xf.origin.y + res.get_travel().y - global_position.y
	if rise <= 0.01:
		return
	global_position = xf.origin + res.get_travel()
	_body.add_step(rise)


## Есть ли место над головой, чтобы встать.
func _can_stand() -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = collision_radius * 0.9
	probe.height = stand_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (stand_height * 0.5 + 0.05))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
