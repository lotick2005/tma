class_name CutsceneActor
extends Node3D
## Персонаж катсцены (вестник во вступлении): модель Meshy на скелете Mixamo (CharacterModel) с мокап-анимациями.
## Двигает его проигрыватель катсцен (Cutscenes, шаги «actor»): идти по точкам, повернуться, анимация.
## Сам актёр выбирает походку по скорости (walk / run, speed_scale — чтобы ноги не скользили) и звучит шагами.
##
## Анимации (поле anim): любое имя из Anims.LIST (animations/README.md) или старые имена шагов катсцен:
## "idle" — стоит, дышит; "panic" — ужас, озирается (terrified); "sway" — покачивается (молится, поёт —
## pray_stand); "kneel" — опускается на колени (kneel_down). Пока идёт (позиция меняется), походка — сама.

## Старые имена анимаций катсцен → мокап.
const ALIASES := {"panic": "terrified", "sway": "pray_stand", "kneel": "kneel_down"}

## Кто: 0, 2 — горожанин, 1, 3 — горожанка (как варианты толпы). Пусто model — по варианту.
@export var variant := 0
@export var model := ""
@export var anim := "idle"
## Звук шагов: идёт — step_stone, бежит (быстрее run_from м/с) — step_stone_run. false — без шагов.
@export var steps := true
@export var run_from := 2.6
## Ходьба: эта анимация, пока скорость ниже run_from; бег — run (или run_fast быстрее 5 м/с).
@export var walk_anim := "walk"

var character: CharacterModel

var _last_pos := Vector3.ZERO
var _speed := 0.0
var _walked := 0.0
var _head := -1


## Модель по варианту толпы: чётные — горожанин, нечётные — горожанка.
static func model_for_variant(v: int) -> String:
	return "townswoman" if posmod(v, 2) == 1 else "townsman"


func _ready() -> void:
	character = CharacterModel.new()
	character.name = "Model"
	character.model = model if model != "" else model_for_variant(variant)
	add_child(character)
	character.build()
	_head = character.skeleton.find_bone("Head")
	_last_pos = global_position
	_update_anim()


## Точка головы в мире (камера смотрит сюда, голос звучит отсюда).
func head_point() -> Vector3:
	if character and _head >= 0:
		var sk := character.skeleton
		return sk.global_transform * sk.get_bone_global_pose(_head).origin + Vector3.UP * 0.08
	return global_position + Vector3.UP * 1.58


## Повернуться лицом (−Z) к точке по горизонтали — мгновенно.
func face(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length_squared() > 1e-6:
		rotation.y = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var inst := moved.length() / maxf(delta, 1e-4)
	_speed = lerpf(_speed, inst, 1.0 - exp(-10.0 * delta))
	if _speed > 0.2 and steps:
		var running := _speed > run_from
		var step_len := 1.2 if running else 0.75
		var was := floori(_walked / step_len)
		_walked += moved.length()
		if floori(_walked / step_len) != was:
			AudioManager.play_3d("step_stone_run" if running else "step_stone", global_position, {"db": 8.0})
	_update_anim()


func _update_anim() -> void:
	if character == null:
		return
	if _speed > 0.2:
		var a := walk_anim
		if _speed > run_from:
			a = "run_fast" if _speed > 5.0 else "run"
		character.play(a, 0.2, clampf(Anims.scale_for(a, _speed), 0.4, 2.5))
	else:
		var a: String = ALIASES.get(anim, anim)
		character.play(a, 0.3, 1.0)
