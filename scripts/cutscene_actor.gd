class_name CutsceneActor
extends Node3D
## Персонаж катсцены (вестник во вступлении): лоуполи-фигура PropLibrary.person_mesh, анимации — без скелета,
## наклонами и покачиванием всей фигуры, как у простых NPC на PS1. Двигает его проигрыватель катсцен
## (Cutscenes, шаги «actor»): идти по точкам, повернуться, анимация. Сам актёр только рисует походку и шаги.
##
## Анимации (поле anim): "idle" — стоит, дышит; "panic" — дрожит, дёргается, озирается;
## "sway" — покачивается вперёд-назад (поёт, молится); "kneel" — осел на колени, согнулся.
## Пока идёт (позиция меняется), походка — сама: подпрыгивание и наклон вперёд, на бегу — сильнее.

## Голова — куда смотреть камере и откуда звучит голос, м над землёй.
const HEAD_HEIGHT := 1.58

@export var variant := 0
@export var anim := "idle"
## Звук шагов: идёт — step_stone, бежит (быстрее run_from м/с) — step_stone_run. Пусто — без шагов.
@export var steps := true
@export var run_from := 2.6
## Длина шага, м (на бегу ×1,4).
@export var stride := 0.75

var _figure: MeshInstance3D
var _t := 0.0
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _walked := 0.0
var _kneel := 0.0


func _ready() -> void:
	_figure = MeshInstance3D.new()
	_figure.mesh = PropLibrary.person_mesh(variant)
	_figure.material_override = PropLibrary.material()
	add_child(_figure)
	_last_pos = global_position
	_t = randf() * 10.0


## Точка головы в мире (камера смотрит сюда, голос звучит отсюда).
func head_point() -> Vector3:
	return global_position + Vector3.UP * HEAD_HEIGHT * (1.0 - 0.35 * _kneel)


## Повернуться лицом (−Z) к точке по горизонтали — мгновенно.
func face(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length_squared() > 1e-6:
		rotation.y = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	_t += delta
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var inst := moved.length() / maxf(delta, 1e-4)
	_speed = lerpf(_speed, inst, 1.0 - exp(-10.0 * delta))
	_kneel = move_toward(_kneel, 1.0 if anim == "kneel" else 0.0, delta * 1.5)

	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	if _speed > 0.2:
		var running := _speed > run_from
		var step_len := stride * (1.4 if running else 1.0)
		var phase := _walked / step_len * PI
		pos.y = absf(sin(phase)) * (0.07 if running else 0.03)
		rot.x = -(0.22 if running else 0.06)
		rot.z = sin(phase) * 0.04
		var was := floori(_walked / step_len)
		_walked += moved.length()
		if steps and floori(_walked / step_len) != was:
			AudioManager.play_3d("step_stone_run" if running else "step_stone", global_position, {"db": 8.0})
	match anim:
		"panic":
			# Дрожь и резкие рывки головой-корпусом
			rot.x += 0.05 * sin(_t * 31.0) - 0.08
			rot.z += 0.04 * sin(_t * 23.0)
			rot.y = 0.25 * sin(_t * 2.3) * sin(_t * 0.9)
		"sway":
			rot.x += 0.1 * sin(_t * 2.2)
		_:
			rot.x += 0.015 * sin(_t * 1.3)
	if _kneel > 0.0:
		pos.y -= 0.45 * _kneel
		rot.x -= 0.45 * _kneel
	_figure.position = pos
	_figure.rotation = rot
