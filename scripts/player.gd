class_name Player
extends CharacterBody3D
## Герой: вид от первого лица, ходьба, бег с выносливостью, присед, покачивание камеры.
## Тело со скелетом — hero_body.gd, руки и светильник — hero_arms.gd (F — достать / убрать).
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
@export var stand_height := 1.8
@export var crouch_height := 1.25
@export var stand_eye_height := 1.62
@export var crouch_eye_height := 1.1
## Скорость, с которой камера опускается и поднимается.
@export var crouch_camera_speed := 8.0
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

@export_group("Покачивание")
## Амплитуда покачивания при ходьбе, м.
@export var bob_amount := 0.03
## Длина шага, м: за шаг камера проседает один раз.
@export var bob_step_length := 0.8
@export var bob_run_scale := 1.7
@export var bob_crouch_scale := 0.6

var move_mode: MoveMode = MoveMode.STAND
var stamina := 0.0

var _crouched := false
var _exhausted := false
var _bob_phase := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _arms: Node3D = $Head/Camera3D/Arms
@onready var _body: HeroBody = $Body


func _ready() -> void:
	stamina = stamina_max
	# Своя копия формы, чтобы присед не менял общий ресурс сцены
	_collision.shape = CapsuleShape3D.new()
	_collision.shape.radius = collision_radius
	_set_body_height(stand_height)
	_head.position.y = stand_eye_height
	_arms.set_lamp_out(GameState.lamp_out, true)
	_arms.lamp_changed.connect(func(out: bool) -> void: GameState.lamp_out = out)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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

	if not crouch_toggle:
		_set_crouched(Input.is_action_pressed("crouch"))

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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

	var eye := crouch_eye_height if _crouched else stand_eye_height
	_head.position.y = lerpf(_head.position.y, eye, 1.0 - exp(-crouch_camera_speed * delta))
	_update_bob(delta, moving)
	var speed_ratio := horizontal.length() / walk_speed if moving else 0.0
	_body.update_pose(_head.position.y, _head.rotation.x, _bob_phase, speed_ratio)


func _update_bob(delta: float, moving: bool) -> void:
	var offset := Vector3.ZERO
	if moving and is_on_floor():
		var dist := Vector2(velocity.x, velocity.z).length() * delta
		_bob_phase = fmod(_bob_phase + dist / bob_step_length * PI, TAU)
		var amount := bob_amount
		if move_mode == MoveMode.RUN:
			amount *= bob_run_scale
		elif move_mode == MoveMode.CROUCH:
			amount *= bob_crouch_scale
		# Вниз на каждом шаге, вбок — раз в два шага
		offset = Vector3(sin(_bob_phase) * amount * 0.5, (cos(_bob_phase * 2.0) - 1.0) * 0.5 * amount, 0.0)
	_camera.position = _camera.position.lerp(offset, 1.0 - exp(-12.0 * delta))


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
	_head.position.y -= rise


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
