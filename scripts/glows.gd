class_name Glows
extends RefCounted
## Огоньки уровня (shaders/glow.gdshader): пламя в нишах, жаровни, маяк. Тёплые точки видны сквозь
## туман и ведут игрока. Все огоньки одного вида — один меш, то есть один вызов отрисовки.
## Виды: NEAR — ближние (ниши, светильники: гаснут к ~45 м), FAR — дальние (жаровни, маяк: видны через весь уровень),
## SMOKE — дым (печь гончара): клубы поднимаются и тают, подсвечены огнём снизу (shaders/smoke.gdshader).
## Настоящий свет (OmniLight3D) огоньки не дают — только картинку; где нужен свет, его ставит уровень.

enum Kind { NEAR, FAR, SMOKE }

## Тёплый цвет огня.
const FIRE := Color(1.0, 0.58, 0.22)

var _quads := {Kind.NEAR: [], Kind.FAR: [], Kind.SMOKE: []}


## Огонёк: центр в мировых координатах, радиус (м), цвет, яркость.
func add(pos: Vector3, radius: float, kind: Kind = Kind.NEAR, color: Color = FIRE, intensity: float = 1.0) -> void:
	(_quads[kind] as Array).append([pos, radius, Color(color.r, color.g, color.b, intensity)])


## Столб дыма над точкой pos: несколько клубов радиуса radius с разной фазой подъёма.
func add_smoke(pos: Vector3, radius: float, clouds: int = 10) -> void:
	for i in clouds:
		# Центры чуть разные — по ним шейдер даёт каждому клубу свою фазу
		var p := pos + Vector3(0.013 * i, 0.0, -0.011 * i)
		(_quads[Kind.SMOKE] as Array).append([p, radius, Color(0.32, 0.2, 0.16, 0.55)])


## Создать меши под узлом parent. Вызвать один раз в конце сборки.
func commit(parent: Node3D) -> void:
	var tex := _texture()
	var params := {
		Kind.NEAR: {"fade_start": 30.0, "fade_end": 45.0, "flicker": 0.3, "min_angle": 0.011},
		Kind.FAR: {"fade_start": 400.0, "fade_end": 500.0, "flicker": 0.22, "min_angle": 0.022},
		Kind.SMOKE: {"rise": 9.0, "speed": 0.05},
	}
	for kind in _quads:
		var list: Array = _quads[kind]
		if list.is_empty():
			continue
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var col := PackedColorArray()
		var corners := [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
		for q: Array in list:
			for c: Vector2 in corners:
				v.append(q[0])
				uv.append(Vector2(c.x * 0.5 + 0.5, 0.5 - c.y * 0.5))
				uv2.append(c * float(q[1]))
				col.append(q[2])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_COLOR] = col
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/smoke.gdshader") if kind == Kind.SMOKE else preload("res://shaders/glow.gdshader")
		mat.set_shader_parameter("glow_texture", tex)
		for key in params[kind]:
			mat.set_shader_parameter(key, params[kind][key])
		var mi := MeshInstance3D.new()
		mi.name = "Glows" + ["Near", "Far", "Smoke"][kind]
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Квадраты разворачиваются в шейдере: границы меша — только центры, добавим запас
		mi.extra_cull_margin = 16.0
		parent.add_child(mi)


## Круглое пятно: яркая серединка и мягкий ореол (альфа), 32×32.
static func _texture() -> ImageTexture:
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := (Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE).length()
			var halo := clampf(1.0 - r, 0.0, 1.0)
			var core := clampf(1.0 - r * 3.2, 0.0, 1.0)
			var a := clampf(halo * halo * 0.55 + core, 0.0, 1.0)
			# Серединка белее: огонь светится жёлто-белым, ореол — цветом огня
			img.set_pixel(x, y, Color(1.0, lerpf(0.75, 1.0, core), lerpf(0.55, 1.0, core), a))
	return ImageTexture.create_from_image(img)
