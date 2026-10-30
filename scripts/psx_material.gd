class_name PsxMaterial
extends RefCounted
## Фабрика материалов на шейдере psx_lit и доступ к его глобальным параметрам.

const SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

## Значения глобальных параметров, изменённые во время игры (RenderingServer их обратно не отдаёт).
static var _globals := {}


static func make(texture: Texture2D = null, color: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if texture:
		mat.set_shader_parameter("albedo_texture", texture)
	mat.set_shader_parameter("albedo_color", color)
	return mat


## Текущее значение глобального параметра psx-шейдера (например, "psx_fog_color"):
## заданное через set_global(), а если его не меняли — из настроек проекта.
static func global_param(param: String) -> Variant:
	if _globals.has(param):
		return _globals[param]
	var entry: Dictionary = ProjectSettings.get_setting("shader_globals/" + param, {})
	return entry.get("value")


## Поменять глобальный параметр psx-шейдера во время игры (туман, свет — пресет освещения уровня).
static func set_global(param: String, value: Variant) -> void:
	_globals[param] = value
	RenderingServer.global_shader_parameter_set(param, value)
