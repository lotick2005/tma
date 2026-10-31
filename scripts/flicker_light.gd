extends OmniLight3D
## Мерцание огня у настоящего источника света (жаровни): яркость «проседает» по шуму.

@export_range(0.0, 1.0) var flicker_amount := 0.3
@export var flicker_speed := 7.0

var _base := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_base = light_energy
	_noise.frequency = 1.0
	_noise.seed = randi()


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	light_energy = _base * (1.0 - flicker_amount * (_noise.get_noise_1d(_time) * 0.5 + 0.5))
