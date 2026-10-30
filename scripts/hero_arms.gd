extends Node3D
## Руки героя в кадре (висят на камере): правая держит светильник, левая свободна —
## из неё на этапе 5 полетят черепки. F — достать / убрать светильник с анимацией,
## пока анимация идёт, повторное нажатие игнорируется.

## Светильник достали (true) или убрали (false). Срабатывает в начале анимации.
signal lamp_changed(out: bool)

## Длительность анимации «достать / убрать», с.
@export var lamp_anim_time := 0.45
## На сколько градусов рука опускается вниз, когда светильник убран.
@export var lamp_hide_angle_deg := 70.0

const SKIN := Color(0.72, 0.5, 0.36)

## В руке ли светильник. Сохранять — через GameState.lamp_out (это делает Player).
var lamp_out := true
## Насколько поднят светильник: 0 — убран, 1 — в руке.
var raise := 1.0

var _tween: Tween
var _right_held: Transform3D
var _skin: ShaderMaterial

@onready var _right: Node3D = $RightArm
@onready var _left: Node3D = $LeftArm
@onready var _lamp: Node3D = $RightArm/OilLamp


func _ready() -> void:
	_right_held = _right.transform
	_skin = PsxMaterial.make(ProcTextures.mottled(64, SKIN, 0.03, 0.06, 11), Color(1.0, 0.85, 0.7))
	_build_right()
	_build_left()


func _process(_delta: float) -> void:
	var hidden := Transform3D(
		_right_held.basis * Basis(Vector3.RIGHT, deg_to_rad(-lamp_hide_angle_deg)),
		_right_held.origin + Vector3(0.0, -0.12, 0.02)
	)
	_right.transform = hidden.interpolate_with(_right_held, raise)
	_right.visible = raise > 0.001
	_lamp.intensity = raise
	# Свой светильник руки не освещает — их подсвечивает его огонь
	_skin.set_shader_parameter("self_illum", _lamp.glow)


func is_busy() -> bool:
	return _tween != null and _tween.is_running()


## Достать / убрать. Возвращает false, если анимация ещё идёт.
func toggle_lamp() -> bool:
	if is_busy():
		return false
	set_lamp_out(not lamp_out)
	return true


func set_lamp_out(out: bool, instant: bool = false) -> void:
	lamp_out = out
	var target := 1.0 if out else 0.0
	if instant:
		raise = target
	else:
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "raise", target, lamp_anim_time)
	lamp_changed.emit(out)


## Правая рука: локоть — в начале координат RightArm (за краем кадра), ладонь под светильником.
func _build_right() -> void:
	var lt: Transform3D = _lamp.transform
	_add_box(_right, lt * Vector3(0.004, -0.012, 0.006), lt.basis, Vector3(0.07, 0.022, 0.09))  # ладонь
	_add_box(_right, lt * Vector3(-0.04, 0.004, 0.004), lt.basis, Vector3(0.018, 0.034, 0.024))  # большой палец
	_add_box(_right, lt * Vector3(0.04, 0.002, -0.004), lt.basis, Vector3(0.016, 0.03, 0.075))  # пальцы
	_add_limb(_right, Vector3.ZERO, lt * Vector3(0.0, -0.014, 0.05), 0.068, 0.048)


## Левая рука: свободна, пальцы вперёд.
func _build_left() -> void:
	var wrist := Vector3(0.1, 0.2, -0.18)
	_add_limb(_left, Vector3.ZERO, wrist, 0.068, 0.048)
	var dir := wrist.normalized()
	_add_limb(_left, wrist, wrist + dir * 0.085 + Vector3(0.0, -0.01, 0.0), 0.06, 0.05, 0.022)  # кисть
	_add_limb(_left, wrist + Vector3(-0.028, 0.0, 0.0), wrist + dir * 0.05 + Vector3(-0.035, 0.0, 0.0), 0.02, 0.016)  # большой палец


## Конечность от точки до точки: усечённая призма, ширина w0 → w1, толщина — та же или thick.
func _add_limb(parent: Node3D, from: Vector3, to: Vector3, w0: float, w1: float, thick: float = 0.0) -> void:
	var y := (to - from).normalized()
	var ref := Vector3.UP if absf(y.y) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	var mesh := MeshInstance3D.new()
	var t0 := thick if thick > 0.0 else w0
	var t1 := thick if thick > 0.0 else w1
	mesh.mesh = PsxMesh.frustum(Vector2(w0, t0), Vector2(w1, t1), from.distance_to(to), 0.1)
	mesh.transform = Transform3D(Basis(x, y, z), from)
	_finish(parent, mesh)


func _add_box(parent: Node3D, center: Vector3, basis: Basis, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = PsxMesh.box(size, 0.1, 1.0)
	mesh.transform = Transform3D(basis, center)
	_finish(parent, mesh)


func _finish(parent: Node3D, mesh: MeshInstance3D) -> void:
	mesh.material_override = _skin
	# Руки в кадре висят на камере и тень дали бы неправильную — тень даёт тело (hero_body.gd)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = 1 << (Player.VIEW_LAYER - 1)
	parent.add_child(mesh)
