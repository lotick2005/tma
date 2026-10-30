class_name PsxMaterial
extends RefCounted
## Фабрика материалов на шейдере psx_lit и доступ к его глобальным параметрам.

const SHADER: Shader = preload("res://shaders/psx_lit.gdshader")


static func make(texture: Texture2D = null, color: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if texture:
		mat.set_shader_parameter("albedo_texture", texture)
	mat.set_shader_parameter("albedo_color", color)
	return mat


## Значение глобального параметра psx-шейдера из настроек проекта (например, "psx_fog_color").
static func global_param(param: String) -> Variant:
	var entry: Dictionary = ProjectSettings.get_setting("shader_globals/" + param, {})
	return entry.get("value")
