extends Node
## Отладка (флаг tma/debug/keys): клавиша 1 — белый свет с тенями за спиной героя,
## чтобы увидеть тень тела. Так будет светить ангел (этап 6). Ищет узел Player у родителя.

var _light: OmniLight3D
var _player: Node3D


func _ready() -> void:
	if not ProjectSettings.get_setting("tma/debug/keys", false):
		queue_free()
		return
	_player = get_parent().get_node_or_null("Player")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_1") or _player == null:
		return
	if _light:
		_light.queue_free()
		_light = null
	else:
		_light = OmniLight3D.new()
		_light.light_color = Color(0.85, 0.9, 1.0)
		_light.light_energy = 2.0
		_light.omni_range = 25.0
		_light.shadow_enabled = true
		_light.shadow_bias = 0.05
		_light.shadow_normal_bias = 1.0
		get_parent().add_child(_light)


func _process(_delta: float) -> void:
	if _light:
		# За спиной и чуть выше головы — как будет светить ангел
		_light.global_position = _player.global_position + _player.global_basis.z * 2.5 + Vector3.UP * 2.2
