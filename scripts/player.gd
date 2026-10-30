class_name Player
extends CharacterBody3D
## Герой: вид от первого лица, ходьба, бег с выносливостью, присед, покачивание камеры.
## Курсором управляет экран «Кликни, чтобы начать» (scripts/click_to_start.gd),
## здесь только обзор, пока курсор захвачен.

enum MoveMode { STAND, CROUCH, WALK, RUN }

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
@export var crouch_height := 1.0
@export var stand_eye_height := 1.62
@export var crouch_eye_height := 0.85
## Скорость, с которой камера опускается и поднимается.
@export var crouch_camera_speed := 8.0
## true — C переключает присед, false — надо держать.
@export var crouch_toggle := true
@export var collision_radius := 0.3

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


func _ready() -> void:
	stamina = stamina_max
	# Своя копия формы, чтобы присед не менял общий ресурс сцены
	_collision.shape = CapsuleShape3D.new()
	_collision.shape.radius = collision_radius
	_set_body_height(stand_height)
	_head.position.y = stand_eye_height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative — в пикселях экрана, не зависит от растяжения 320×240
		var d: Vector2 = event.screen_relative * mouse_sensitivity
		rotate_y(-d.x)
		var limit := deg_to_rad(pitch_limit_deg)
		_head.rotation.x = clampf(_head.rotation.x - d.y, -limit, limit)
	elif event.is_action_pressed("crouch") and crouch_toggle:
		_set_crouched(not _crouched)


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
	move_and_slide()

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
