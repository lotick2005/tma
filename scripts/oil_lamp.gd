extends Node3D
## Глиняный масляный светильник в руке героя: тёплый свет малого радиуса с мерцанием.

@export var light_color := Color(1.0, 0.62, 0.3)
@export var light_energy := 1.6
## Радиус света, м.
@export var light_range := 6.0
@export var shadows := true
## Сила мерцания: доля яркости, на которую пламя «проседает».
@export_range(0.0, 1.0) var flicker_amount := 0.25
## Скорость мерцания.
@export var flicker_speed := 9.0
## Насколько свет дрожит в пространстве, м.
@export var flicker_wobble := 0.008

var _noise := FastNoiseLite.new()
var _time := 0.0

@onready var _light: OmniLight3D = $Light
@onready var _flame: Node3D = $Flame
@onready var _light_origin: Vector3 = _light.position


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	_light.light_color = light_color
	_light.omni_range = light_range
	_light.shadow_enabled = shadows


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	var n := _noise.get_noise_1d(_time) * 0.5 + 0.5  # 0..1
	var k := 1.0 - flicker_amount * n
	_light.light_energy = light_energy * k
	_light.position = _light_origin + Vector3(
		_noise.get_noise_2d(_time, 17.0), _noise.get_noise_2d(_time, 43.0), _noise.get_noise_2d(_time, 71.0)
	) * flicker_wobble
	_flame.scale = Vector3(1.0, 0.7 + 0.5 * k, 1.0)
