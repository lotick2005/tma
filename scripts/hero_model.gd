class_name HeroModel
extends RefCounted
## Лоуполи-модель героя со скелетом: кости, меш и скиннинг строятся кодом.
## Поза покоя: стоит лицом в −Z, руки опущены вдоль тела, ладони смотрят на бёдра.
## Начало координат — между ступнями на земле. Все кости в покое без поворота (базис единичный),
## поэтому «вдоль кости» у конечностей — это локальная −Y.
## Одежда: красная туника до колен с короткими рукавами, кожаный пояс, калиги. Доспеха нет.

const UPPER_ARM := 0.29
const FOREARM := 0.26
const THIGH := 0.44
const SHIN := 0.42
## Высота щиколотки (кость стопы) над землёй.
const ANKLE_H := 0.07
const SHOULDER_X := 0.2
const HIP_X := 0.095
const PELVIS_Y := 0.95
const HIP_Y := 0.93

## Кости: имя, родитель, положение в покое (в пространстве скелета). Правая сторона — +X.
const BONES := [
	["pelvis", "", Vector3(0.0, PELVIS_Y, 0.0)],
	["spine", "pelvis", Vector3(0.0, 1.12, 0.0)],
	["chest", "spine", Vector3(0.0, 1.3, 0.0)],
	["neck", "chest", Vector3(0.0, 1.5, 0.0)],
	["head", "neck", Vector3(0.0, 1.6, 0.0)],
	["upper_arm.L", "chest", Vector3(-SHOULDER_X, 1.44, 0.0)],
	["forearm.L", "upper_arm.L", Vector3(-SHOULDER_X, 1.44 - UPPER_ARM, 0.0)],
	["hand.L", "forearm.L", Vector3(-SHOULDER_X, 1.44 - UPPER_ARM - FOREARM, 0.0)],
	["fingers.L", "hand.L", Vector3(-SHOULDER_X, 1.44 - UPPER_ARM - FOREARM - 0.09, 0.0)],
	["upper_arm.R", "chest", Vector3(SHOULDER_X, 1.44, 0.0)],
	["forearm.R", "upper_arm.R", Vector3(SHOULDER_X, 1.44 - UPPER_ARM, 0.0)],
	["hand.R", "forearm.R", Vector3(SHOULDER_X, 1.44 - UPPER_ARM - FOREARM, 0.0)],
	["fingers.R", "hand.R", Vector3(SHOULDER_X, 1.44 - UPPER_ARM - FOREARM - 0.09, 0.0)],
	["skirt", "pelvis", Vector3(0.0, HIP_Y, 0.0)],
	["thigh.L", "pelvis", Vector3(-HIP_X, HIP_Y, 0.0)],
	["shin.L", "thigh.L", Vector3(-HIP_X, HIP_Y - THIGH, 0.0)],
	["foot.L", "shin.L", Vector3(-HIP_X, ANKLE_H, 0.0)],
	["thigh.R", "pelvis", Vector3(HIP_X, HIP_Y, 0.0)],
	["shin.R", "thigh.R", Vector3(HIP_X, HIP_Y - THIGH, 0.0)],
	["foot.R", "shin.R", Vector3(HIP_X, ANKLE_H, 0.0)],
]

const SKIN_COLOR := Color(0.7, 0.5, 0.37)
## Тёмно-красная «римская» туника.
const TUNIC_COLOR := Color(0.45, 0.09, 0.07)
const LEATHER_COLOR := Color(0.32, 0.19, 0.1)

var _skel: Skeleton3D
var _st: SurfaceTool


## Заполняет пустой Skeleton3D костями из BONES.
static func build_skeleton(skel: Skeleton3D) -> void:
	for b in BONES:
		var idx := skel.add_bone(b[0])
		var parent_pos := Vector3.ZERO
		if b[1] != "":
			var p := skel.find_bone(b[1])
			skel.set_bone_parent(idx, p)
			parent_pos = _rest_pos(b[1])
		skel.set_bone_rest(idx, Transform3D(Basis(), b[2] - parent_pos))
	skel.reset_bone_poses()


static func _rest_pos(bone: String) -> Vector3:
	for b in BONES:
		if b[0] == bone:
			return b[2]
	return Vector3.ZERO


## Тело без головы: одна фигура, поверхности — туника, кожа, пояс, калиги.
static func build_body(skel: Skeleton3D) -> ArrayMesh:
	var m := HeroModel.new()
	m._skel = skel
	var mesh := ArrayMesh.new()
	var tunic := PsxMaterial.make(ProcTextures.mottled(64, TUNIC_COLOR, 0.035, 0.08, 21))
	var tunic_hem := PsxMaterial.make(ProcTextures.hemmed_cloth(64, TUNIC_COLOR, 6, 22))
	var skin := PsxMaterial.make(ProcTextures.mottled(64, SKIN_COLOR, 0.03, 0.06, 11))
	var leather := PsxMaterial.make(ProcTextures.mottled(64, LEATHER_COLOR, 0.04, 0.08, 13))
	var caliga := PsxMaterial.make(ProcTextures.stripes(64, 12, LEATHER_COLOR, SKIN_COLOR, 14))

	m._begin()
	m._torso()
	m._commit(mesh, tunic)
	m._begin()
	m._skirt()
	for side in [-1.0, 1.0]:
		m._sleeve(side)
	m._commit(mesh, tunic_hem)
	m._begin()
	m._belt()
	m._commit(mesh, leather)
	m._begin()
	for side in [-1.0, 1.0]:
		m._arm(side)
		m._hand(side)
		m._leg_skin(side)
	m._commit(mesh, skin)
	m._begin()
	for side in [-1.0, 1.0]:
		m._caliga(side)
	m._commit(mesh, caliga)
	return mesh


## Голова с шеей — только для тени (камера внутри неё).
static func build_head(skel: Skeleton3D) -> ArrayMesh:
	var m := HeroModel.new()
	m._skel = skel
	var mesh := ArrayMesh.new()
	m._begin()
	m._tube([
		m._ring(Vector3(0, 1.48, 0.0), 0.06, 0.06, [["neck", 1.0]]),
		m._ring(Vector3(0, 1.6, 0.0), 0.06, 0.06, [["head", 1.0]]),
		m._ring(Vector3(0, 1.63, -0.01), 0.09, 0.1, [["head", 1.0]]),
		m._ring(Vector3(0, 1.72, -0.01), 0.1, 0.11, [["head", 1.0]]),
		m._ring(Vector3(0, 1.8, 0.0), 0.05, 0.06, [["head", 1.0]]),
	], 6, 0.2, true, true)
	m._commit(mesh, PsxMaterial.make(null, SKIN_COLOR))
	return mesh


# --- Части тела ---------------------------------------------------------------

func _torso() -> void:
	# Талия → живот → грудь → плечи → основание шеи; верх закрыт (смотрим сверху вниз)
	_tube([
		_ring(Vector3(0, 0.95, 0.0), 0.15, 0.11, [["pelvis", 1.0]]),
		_ring(Vector3(0, 1.1, -0.005), 0.15, 0.115, [["spine", 1.0]]),
		_ring(Vector3(0, 1.3, -0.015), 0.165, 0.125, [["chest", 1.0]]),
		_ring(Vector3(0, 1.43, 0.0), 0.185, 0.1, [["chest", 1.0]]),
		_ring(Vector3(0, 1.5, 0.0), 0.06, 0.055, [["neck", 1.0]]),
	], 8, 0.25, false, true)


## Подол до колен. Передняя половина висит на кости skirt (наклоняется вслед за бёдрами,
## в приседе ложится на колени), бока чуть следуют за своим бедром при шаге.
func _skirt() -> void:
	var hem_w := func(p: Vector3) -> Array:
		var front := clampf(-p.z / 0.15, 0.0, 1.0)
		var k := clampf(p.x / 0.15, -1.0, 1.0)
		return [["pelvis", 1.0 - 0.85 * front], ["skirt", 0.85 * front],
			["thigh.L", 0.15 * clampf(-k, 0.0, 1.0)], ["thigh.R", 0.15 * clampf(k, 0.0, 1.0)]]
	var mid_w := func(p: Vector3) -> Array:
		var front := clampf(-p.z / 0.15, 0.0, 1.0)
		return [["pelvis", 1.0 - 0.6 * front], ["skirt", 0.6 * front]]
	_tube([
		_ring(Vector3(0, 0.97, 0.0), 0.152, 0.112, [["pelvis", 1.0]]),
		_ring(Vector3(0, 0.8, 0.0), 0.19, 0.15, mid_w),
		_ring(Vector3(0, 0.53, 0.01), 0.21, 0.155, hem_w),
	], 10, 0.0, false, false)


## Короткий рукав туники.
func _sleeve(side: float) -> void:
	var x := SHOULDER_X * side
	var b := "upper_arm." + ("L" if side < 0.0 else "R")
	_tube([
		_ring(Vector3(x, 1.47, 0.0), 0.06, 0.06, [[b, 1.0]]),
		_ring(Vector3(x, 1.32, 0.0), 0.066, 0.064, [[b, 1.0]]),
	], 6, 0.0, false, false)


func _belt() -> void:
	_tube([
		_ring(Vector3(0, 0.92, 0.0), 0.162, 0.123, [["pelvis", 1.0]]),
		_ring(Vector3(0, 0.99, -0.003), 0.16, 0.12, [["pelvis", 1.0]]),
	], 8, 0.15, false, false)


func _arm(side: float) -> void:
	var x := SHOULDER_X * side
	var s := "L" if side < 0.0 else "R"
	var elbow_y := 1.44 - UPPER_ARM
	var wrist_y := elbow_y - FOREARM
	_tube([
		_ring(Vector3(x, 1.34, 0.0), 0.05, 0.05, [["upper_arm." + s, 1.0]]),
		_ring(Vector3(x, elbow_y + 0.03, 0.0), 0.042, 0.044, [["upper_arm." + s, 1.0]]),
		_ring(Vector3(x, elbow_y, 0.005), 0.04, 0.045, [["upper_arm." + s, 0.5], ["forearm." + s, 0.5]]),
		_ring(Vector3(x, elbow_y - 0.07, 0.0), 0.043, 0.04, [["forearm." + s, 1.0]]),
		_ring(Vector3(x, wrist_y + 0.01, 0.0), 0.028, 0.032, [["forearm." + s, 1.0]]),
	], 6, 0.15, false, false)


## Кисть: ладонь, два «пучка» пальцев и большой палец. Ладонь плоская по X (к бедру), широкая по Z.
func _hand(side: float) -> void:
	var x := SHOULDER_X * side
	var s := "L" if side < 0.0 else "R"
	var wy := 1.44 - UPPER_ARM - FOREARM
	var hand := [["hand." + s, 1.0]]
	var fingers := [["fingers." + s, 1.0]]
	_tube([
		_ring(Vector3(x, wy + 0.01, 0.0), 0.022, 0.03, hand),
		_ring(Vector3(x, wy - 0.05, 0.0), 0.017, 0.042, hand),
		_ring(Vector3(x, wy - 0.09, 0.0), 0.014, 0.04, fingers),
	], 4, 0.1, false, false)
	for z in [-0.019, 0.019]:
		_tube([
			_ring(Vector3(x, wy - 0.088, z), 0.013, 0.018, fingers),
			_ring(Vector3(x, wy - 0.15, z * 0.9), 0.01, 0.014, fingers),
			_ring(Vector3(x, wy - 0.17, z * 0.8), 0.006, 0.009, fingers),
		], 4, 0.1, false, true)
	# Большой палец — спереди (−Z), чуть к телу
	_tube([
		_ring(Vector3(x - 0.008 * side, wy - 0.02, -0.03), 0.013, 0.013, hand),
		_ring(Vector3(x - 0.012 * side, wy - 0.075, -0.05), 0.009, 0.009, hand),
	], 4, 0.1, false, true)


func _leg_skin(side: float) -> void:
	var x := HIP_X * side
	var s := "L" if side < 0.0 else "R"
	var knee_y := HIP_Y - THIGH
	_tube([
		_ring(Vector3(x, HIP_Y - 0.03, 0.0), 0.075, 0.08, [["thigh." + s, 0.8], ["pelvis", 0.2]]),
		_ring(Vector3(x, 0.72, -0.005), 0.075, 0.08, [["thigh." + s, 1.0]]),
		_ring(Vector3(x, knee_y + 0.03, -0.01), 0.055, 0.06, [["thigh." + s, 1.0]]),
		_ring(Vector3(x, knee_y, -0.012), 0.052, 0.058, [["thigh." + s, 0.5], ["shin." + s, 0.5]]),
		_ring(Vector3(x, knee_y - 0.1, 0.008), 0.055, 0.058, [["shin." + s, 1.0]]),
		_ring(Vector3(x, 0.25, 0.0), 0.042, 0.045, [["shin." + s, 1.0]]),
	], 6, 0.2, false, false)


## Калига: ремешки по голени + стопа с подошвой.
func _caliga(side: float) -> void:
	var x := HIP_X * side
	var s := "L" if side < 0.0 else "R"
	var shin := [["shin." + s, 1.0]]
	var foot := [["foot." + s, 1.0]]
	_tube([
		_ring(Vector3(x, 0.25, 0.0), 0.043, 0.046, shin),
		_ring(Vector3(x, 0.12, 0.005), 0.036, 0.04, shin),
		_ring(Vector3(x, ANKLE_H + 0.01, 0.01), 0.04, 0.045, [["shin." + s, 0.5], ["foot." + s, 0.5]]),
	], 6, 0.1, false, false)
	# Стопа вдоль −Z: пятка → подъём → пальцы. Сечение в плоскости XY.
	_tube([
		_ring_xy(Vector3(x, 0.035, 0.05), 0.038, 0.035, foot),
		_ring_xy(Vector3(x, 0.04, -0.02), 0.045, 0.04, foot),
		_ring_xy(Vector3(x, 0.025, -0.13), 0.045, 0.025, foot),
		_ring_xy(Vector3(x, 0.015, -0.2), 0.035, 0.015, foot),
	], 6, 0.1, true, true)


# --- Построение трубок со скиннингом -------------------------------------------

## Кольцо сечения: центр, полуоси по X и по Z, веса — [[кость, вес], …] или Callable(точка) → такой же список.
func _ring(c: Vector3, rx: float, rz: float, w: Variant) -> Dictionary:
	return {"c": c, "u": Vector3.RIGHT, "v": Vector3.BACK, "ru": rx, "rv": rz, "w": w}


## Кольцо в плоскости XY (для стопы, которая лежит вдоль Z).
func _ring_xy(c: Vector3, rx: float, ry: float, w: Variant) -> Dictionary:
	return {"c": c, "u": Vector3.RIGHT, "v": Vector3.UP, "ru": rx, "rv": ry, "w": w}


func _begin() -> void:
	_st = SurfaceTool.new()
	_st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _commit(mesh: ArrayMesh, mat: Material) -> void:
	_st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## Трубка через кольца. v_tile > 0 — V в метрах / v_tile (текстура повторяется),
## v_tile = 0 — V от 0 до 1 по всей длине (кайма туники ложится на край).
func _tube(rings: Array, sides: int, v_tile: float, cap_start: bool, cap_end: bool) -> void:
	var pts: Array = []
	var total := 0.0
	var lens: Array[float] = [0.0]
	for i in rings.size():
		var r: Dictionary = rings[i]
		var ring_pts: Array[Vector3] = []
		for j in sides:
			# Поворот на полшага, чтобы у 4- и 6-гранников грань, а не ребро, смотрела вперёд
			var a := TAU * (j + 0.5) / sides
			ring_pts.append(r.c + r.u * cos(a) * r.ru + r.v * sin(a) * r.rv)
		pts.append(ring_pts)
		if i > 0:
			total += (r.c - rings[i - 1].c).length()
			lens.append(total)
	for i in rings.size() - 1:
		var axis_mid: Vector3 = (rings[i].c + rings[i + 1].c) * 0.5
		for j in sides:
			var j1 := (j + 1) % sides
			var q: Array[Vector3] = [pts[i][j], pts[i][j1], pts[i + 1][j1], pts[i + 1][j]]
			var w: Array = [rings[i].w, rings[i].w, rings[i + 1].w, rings[i + 1].w]
			var v0 := lens[i] / v_tile if v_tile > 0.0 else lens[i] / total
			var v1 := lens[i + 1] / v_tile if v_tile > 0.0 else lens[i + 1] / total
			var u0 := float(j) / sides
			var u1 := float(j + 1) / sides
			var uv: Array[Vector2] = [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			var outward: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25 - axis_mid
			_quad(q, uv, w, outward)
	for k in 2:
		if (k == 0 and not cap_start) or (k == 1 and not cap_end):
			continue
		var i := 0 if k == 0 else rings.size() - 1
		var other := 1 if k == 0 else rings.size() - 2
		var c: Vector3 = rings[i].c
		var out: Vector3 = c - rings[other].c
		for j in sides:
			var j1 := (j + 1) % sides
			var q: Array[Vector3] = [c, pts[i][j], pts[i][j1], c]
			var uv: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 0.5)]
			_quad(q, uv, [rings[i].w, rings[i].w, rings[i].w, rings[i].w], out)


## Плоский четырёхугольник (или треугольник, если две вершины совпали) с плоской нормалью.
func _quad(q: Array[Vector3], uv: Array[Vector2], w: Array, outward: Vector3) -> void:
	var n := Vector3.ZERO
	for i in 4:
		var a := q[i]
		var b := q[(i + 1) % 4]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	# Лицевая сторона в Godot — обход по часовой (см. PsxMesh._quad)
	var order := [0, 2, 1, 0, 3, 2]
	if n.dot(outward) < 0.0:
		n = -n
		order = [0, 1, 2, 0, 2, 3]
	for k in order:
		var bones := PackedInt32Array([0, 0, 0, 0])
		var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		var wl: Array = w[k].call(q[k]) if w[k] is Callable else w[k]
		var sum := 0.0
		var slot := 0
		for bw in wl:
			if bw[1] <= 0.0 or slot >= 4:
				continue
			bones[slot] = _skel.find_bone(bw[0])
			weights[slot] = bw[1]
			sum += bw[1]
			slot += 1
		for s in slot:
			weights[s] /= sum
		_st.set_normal(n)
		_st.set_uv(uv[k])
		_st.set_bones(bones)
		_st.set_weights(weights)
		_st.add_vertex(q[k])
