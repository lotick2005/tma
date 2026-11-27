class_name BlobShadows
extends RefCounted
## Тени-пятна (CLAUDE.md §7): тёмное размытое пятно-децаль на полу вместо настоящих теней.
## Неподвижные (тела) — квадраты в одном меше на строитель уровня (один вызов отрисовки): add(), потом commit().
## Подвижные (святые, герой, предметы с физикой) — узел BlobShadow, который каждый кадр ищет пол под целью.

const SHADER: Shader = preload("res://shaders/blob_shadow.gdshader")
## Пятно чуть шире габарита (размытый край) и приподнято над полом, м.
const GROW := 1.4
const LIFT := 0.02

static var _material: ShaderMaterial

var _quads: Array = []


## Общий материал пятен.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("opacity", 0.55)
	return _material


## Пятно под неподвижным: xf — где стоит предмет, aabb — его границы в своих осях (низ — пол).
## alpha — прозрачность пятна 0..1 (умножается на opacity материала).
func add(xf: Transform3D, aabb: AABB, alpha: float = 1.0) -> void:
	# Габарит по полу: углы границ в мире, по ним — прямоугольник в осях поворота предмета вокруг Y
	var fwd := xf.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		fwd = Vector3.BACK
	fwd = fwd.normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var floor_y := INF
	for k in 8:
		var p := xf * aabb.get_endpoint(k)
		var q := Vector2(p.dot(right), p.dot(fwd))
		lo = lo.min(q)
		hi = hi.max(q)
		floor_y = minf(floor_y, p.y)
	var c := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5 * GROW + Vector2(0.08, 0.08)
	var center := right * c.x + fwd * c.y
	center.y = floor_y + LIFT
	_quads.append([center, right * half.x, fwd * half.y, alpha])


## Меш пятен под узлом parent.
func commit(parent: Node3D) -> void:
	if _quads.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: Array in _quads:
		var c: Vector3 = q[0]
		var r: Vector3 = q[1]
		var f: Vector3 = q[2]
		var corners := [c - r - f, c + r - f, c + r + f, c - r + f]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_color(Color(1.0, 1.0, 1.0, q[3]))
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(corners[k])
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadows"
	mi.mesh = st.commit()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 40.0
	parent.add_child(mi)
	_quads.clear()
