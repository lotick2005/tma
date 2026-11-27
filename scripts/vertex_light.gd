class_name VertexLight
extends RefCounted
## Запечённый свет в вершинах (CLAUDE.md §7, как в Silent Hill / Resident Evil): при сборке уровня каждой вершине
## статичной геометрии считается множитель освещённости и пишется в COLOR.
##   COLOR.rgb — затенение (1 — открыто, 0,55 — угол стена–пол, низ стен, под сводом, в узком проходе);
##   COLOR.a   — 1 − тепло: тёплые пятна вокруг огоньков в нишах (WARM_NEAR м) и жаровен (WARM_FAR м).
## psx_lit.gdshader умножает albedo на затенение и добавляет тепло как свет; силу обоих задают глобальные
## параметры psx_ao_strength и psx_warm_strength (ползунки «Затенение» и «Тёплые пятна» в панели 0). У моделей
## без цвета вершин COLOR белый — ни затенения, ни тепла.
##
## Как считается (быстро — сборка в браузере не дольше +2 с): заслонители уровня (коробки коллизии, видимые
## коробки, треугольники рельефа и арок) растрируются в сетку занятости с ячейкой CELL м (у больших коробок —
## только оболочка SHELL ячеек: глубже лучи не заходят). Для вершины — до 13 направлений полусферы (вдоль
## поверхности тоже), отсчёты сетки на NEAR_T и FAR_T м: занято — направление закрыто.
## Тёплое пятно: затухание по расстоянию × Ламберт, и проверка по той же сетке, что огонь не за стеной.

## Ячейка сетки занятости, м.
const CELL := 0.5
## Толщина оболочки больших коробок, ячеек (лучи короче, глубже незачем).
const SHELL := 4
## Отступ от поверхности вдоль нормали, м: больше половины ячейки, иначе вершина видит свою же стену.
const OFFSET := 0.3
## Отсчёты вдоль направления, м (ближний — углы и стыки, дальний — узкие проходы, своды, комнаты).
const NEAR_T := 0.45
const FAR_T := 1.7
const NEAR_W := 0.6
const FAR_W := 0.4
## Максимум затенения (−45 %) и при какой доле закрытых направлений он достигается.
const AO_MAX := 0.45
const AO_FULL := 0.4
## Радиус тёплого пятна: огонёк в нише и жаровня, м.
const WARM_NEAR := 2.5
const WARM_FAR := 5.0
## Огоньки в одной клетке MERGE м сливаются в одно пятно, сила — сумма (не больше MERGE_MAX).
const MERGE := 1.0
const MERGE_MAX := 1.6
## Шаг проверки «огонь не за стеной», м, и сколько не проверять у самого огня (он сидит в нише, внутри заслонителя).
const WARM_STEP := 0.5
const WARM_SKIP := 0.7
## Больше ячеек — сетку не строить (защита от огромного уровня), запекание выключается с предупреждением.
const MAX_CELLS := 60000000

var _origin := Vector3.ZERO
var _nx := 0
var _ny := 0
var _nz := 0
var _nxz := 0
var _grid := PackedByteArray()
## Тёплые пятна: [позиция, радиус, сила].
var _warm_spots: Array = []
## Отсчёты для нормали (ключ — номер ближайшего из 26 направлений): PackedVector3Array смещений в ячейках,
## PackedFloat32Array весов и сумма весов.
var _dir_cache := {}
static var _dirs18: Array[Vector3] = []
var ok := false


## bounds — где есть запекаемые вершины; boxes — [Transform3D центра, размер]; faces — треугольники в мире.
func build(bounds: AABB, boxes: Array, faces: PackedVector3Array, warm_spots: Array) -> void:
	bounds = bounds.grow(FAR_T + OFFSET + CELL * 2.0)
	_origin = bounds.position
	_nx = ceili(bounds.size.x / CELL) + 1
	_ny = ceili(bounds.size.y / CELL) + 1
	_nz = ceili(bounds.size.z / CELL) + 1
	_nxz = _nx * _nz
	if _nx * _ny * _nz > MAX_CELLS:
		push_warning("Запечённый свет: уровень слишком большой (%d×%d×%d ячеек), выключен" % [_nx, _ny, _nz])
		return
	_grid.resize(_nx * _ny * _nz)
	_grid.fill(0)
	for b: Array in boxes:
		_raster_box(b[0], b[1])
	_raster_faces(faces)
	# Огоньки ближе метра друг к другу (десятки светильников в молельне) — одно пятно: сила складывается
	var merged := {}
	for sp: Array in warm_spots:
		var p: Vector3 = sp[0]
		var key := Vector3i((p / MERGE).floor())
		if merged.has(key):
			var m: Array = merged[key]
			m[3] += 1
			m[0] = (m[0] as Vector3).lerp(p, 1.0 / m[3])
			m[1] = maxf(m[1], sp[1])
			m[2] = minf(MERGE_MAX, m[2] + sp[2])
		else:
			merged[key] = [p, sp[1], sp[2], 1]
	for m: Array in merged.values():
		_warm_spots.append([m[0], m[1], m[2]])
	if _dirs18.is_empty():
		for x in [-1, 0, 1]:
			for y in [-1, 0, 1]:
				for z in [-1, 0, 1]:
					var m := absi(x) + absi(y) + absi(z)
					if m == 1 or m == 2:
						_dirs18.append(Vector3(x, y, z).normalized())
	ok = true


## Цвета вершин меша (в координатах меша, origin — где меш стоит в мире).
func colors(verts: PackedVector3Array, normals: PackedVector3Array, origin: Vector3) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(verts.size())
	if verts.is_empty():
		return out
	# Тёплые пятна, которые достают до этого куска (у большинства кусков — ни одного)
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var box := AABB(lo + origin, hi - lo)
	var spots: Array = []
	for s: Array in _warm_spots:
		var r: float = s[1]
		if box.grow(r).has_point(s[0]):
			spots.append(s)
	var inv := 1.0 / CELL
	var base_shift := (origin - _origin) * inv
	var g := _grid
	var nx := _nx
	var nxz := _nxz
	var lim := Vector3(_nx - 1, _ny - 1, _nz - 1)
	var cache := {}
	var reach := FAR_T * inv + 1.0
	var safe_lo := Vector3.ONE * reach
	var safe_hi := lim - Vector3.ONE * reach
	var last_q := -1
	var offs := PackedVector3Array()
	var ws := PackedFloat32Array()
	var total := 1.0
	var sh := Vector3.ONE * (OFFSET * inv)
	for i in verts.size():
		var n := normals[i]
		# Нормаль — к ближайшему из 26 направлений: у одинаково повёрнутых граней одни и те же отсчёты
		var qv := Vector3i((n * 1.6).round())
		var qn := (qv.x + 1) * 9 + (qv.y + 1) * 3 + (qv.z + 1)
		if qn != last_q:
			last_q = qn
			var entry: Array = _dir_cache.get(qn, [])
			if entry.is_empty():
				entry = _make_dirs(Vector3(qv).normalized() if qv != Vector3i.ZERO else Vector3.UP)
				_dir_cache[qn] = entry
			offs = entry[0]
			ws = entry[1]
			total = entry[2]
		var b := verts[i] * inv + base_shift + n * sh
		var ao := 1.0
		var warm := 0.0
		if b.x >= 0.0 and b.y >= 0.0 and b.z >= 0.0 and b.x <= lim.x and b.y <= lim.y and b.z <= lim.z:
			# Вершины предметов густые: в одной ячейке с одним направлением нормали — одно значение
			var key := (int(b.x) + int(b.z) * nx + int(b.y) * nxz) * 27 + qn
			var cached: Variant = cache.get(key)
			if cached != null:
				ao = (cached as Vector2).x
				warm = (cached as Vector2).y
			else:
				var occ := 0.0
				if b.x >= safe_lo.x and b.y >= safe_lo.y and b.z >= safe_lo.z and b.x <= safe_hi.x and b.y <= safe_hi.y and b.z <= safe_hi.z:
					for k in offs.size():
						var q := b + offs[k]
						if g[int(q.x) + int(q.z) * nx + int(q.y) * nxz] != 0:
							occ += ws[k]
				else:
					for k in offs.size():
						var q := (b + offs[k]).clamp(Vector3.ZERO, lim)
						if g[int(q.x) + int(q.z) * nx + int(q.y) * nxz] != 0:
							occ += ws[k]
				ao = 1.0 - AO_MAX * minf(1.0, occ / total / AO_FULL)
				if not spots.is_empty():
					warm = _warm_at(verts[i] + origin, n, spots)
				cache[key] = Vector2(ao, warm)
		elif not spots.is_empty():
			warm = _warm_at(verts[i] + origin, n, spots)
		out[i] = Color(ao, ao, ao, 1.0 - warm)
	return out


## Смещения отсчётов (в ячейках) и веса для нормали n. Направления — 18 (оси и диагонали граней куба) с
## dot(d, n) ≥ −0,05: вдоль поверхности тоже (так стена у пола видит пол, а пол у стены — стену). Ближний отсчёт —
## по нормали, диагоналям к ней и осям вдоль поверхности, дальний — по нормали и по осям вдоль поверхности (своды, стены узкого прохода). Вес — ближе к нормали больше.
func _make_dirs(n: Vector3) -> Array:
	var offs := PackedVector3Array()
	var ws := PackedFloat32Array()
	var total := 0.0
	for d in _dirs18:
		var c := d.dot(n)
		if c < -0.05:
			continue
		var w := 0.35 + 0.65 * maxf(c, 0.0)
		var axis := absf(d.x) + absf(d.y) + absf(d.z) < 1.01
		# Диагонали вдоль самой поверхности ближним отсчётом не проверяем: их закрывают соседние направления
		if c < 0.2 and not axis:
			continue
		offs.append(d * (NEAR_T / CELL))
		ws.append(w * NEAR_W)
		var far_w := w * FAR_W
		if c > 0.9 or (c < 0.2 and axis):
			offs.append(d * (FAR_T / CELL))
			ws.append(far_w)
		total += w * NEAR_W + far_w
	return [offs, ws, maxf(total, 0.001)]


## Тепло в точке p (мир) с нормалью n от пятен spots: 0..1.
func _warm_at(p: Vector3, n: Vector3, spots: Array) -> float:
	var sum := 0.0
	for s: Array in spots:
		var to: Vector3 = (s[0] as Vector3) - p
		var r: float = s[1]
		var d2 := to.length_squared()
		if d2 >= r * r:
			continue
		var d := sqrt(d2)
		var c := n.dot(to) / maxf(d, 0.001)
		if c < -0.1:
			continue
		var f := 1.0 - d / r
		var w: float = f * f * (0.25 + 0.75 * maxf(c, 0.0)) * float(s[2])
		if w < 0.01 or not _visible(p + n * OFFSET, s[0]):
			continue
		sum += w
		if sum >= 1.0:
			return 1.0
	return sum


## Нет ли заслонителя между a и огнём b (у самого огня не проверяем — он в нише).
func _visible(a: Vector3, b: Vector3) -> bool:
	var to := b - a
	var d := to.length()
	var steps := floori((d - WARM_SKIP) / WARM_STEP)
	if steps <= 0:
		return true
	var dir := to / d
	for k in steps:
		var q := a + dir * (WARM_STEP * (k + 1))
		if _occupied(q):
			return false
	return true


func _occupied(p: Vector3) -> bool:
	var q := (p - _origin) / CELL
	var x := int(q.x)
	var y := int(q.y)
	var z := int(q.z)
	if q.x < 0.0 or q.y < 0.0 or q.z < 0.0 or x >= _nx or y >= _ny or z >= _nz:
		return false
	return _grid[x + z * _nx + y * _nxz] != 0


## Коробка в сетку: ячейки, чей центр внутри коробки (тоньше ячейки — не заслоняет), у больших — только оболочка.
func _raster_box(xf: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var basis := xf.basis
	var aligned := basis.x.is_equal_approx(Vector3.RIGHT) and basis.y.is_equal_approx(Vector3.UP) \
		and basis.z.is_equal_approx(Vector3.BACK)
	if aligned:
		var lo := (xf.origin - h - _origin) / CELL
		var hi := (xf.origin + h - _origin) / CELL
		var i0 := Vector3i(maxi(0, ceili(lo.x - 0.5)), maxi(0, ceili(lo.y - 0.5)), maxi(0, ceili(lo.z - 0.5)))
		var i1 := Vector3i(mini(_nx - 1, floori(hi.x - 0.5)), mini(_ny - 1, floori(hi.y - 0.5)), mini(_nz - 1, floori(hi.z - 0.5)))
		if i0.x > i1.x or i0.y > i1.y or i0.z > i1.z:
			return
		var thick_x := i1.x - i0.x > SHELL * 2
		for y in range(i0.y, i1.y + 1):
			var edge_y := y - i0.y < SHELL or i1.y - y < SHELL
			var row_y := y * _nxz
			for z in range(i0.z, i1.z + 1):
				var row := row_y + z * _nx
				if not edge_y and thick_x and z - i0.z >= SHELL and i1.z - z >= SHELL:
					for x in range(i0.x, i0.x + SHELL):
						_grid[row + x] = 1
					for x in range(i1.x - SHELL + 1, i1.x + 1):
						_grid[row + x] = 1
				else:
					for x in range(i0.x, i1.x + 1):
						_grid[row + x] = 1
		return
	# Повёрнутая коробка: все ячейки её AABB, центр — в осях коробки
	var ab := xf * AABB(-h, size)
	var lo2 := (ab.position - _origin) / CELL
	var hi2 := (ab.end - _origin) / CELL
	var j0 := Vector3i(maxi(0, ceili(lo2.x - 0.5)), maxi(0, ceili(lo2.y - 0.5)), maxi(0, ceili(lo2.z - 0.5)))
	var j1 := Vector3i(mini(_nx - 1, floori(hi2.x - 0.5)), mini(_ny - 1, floori(hi2.y - 0.5)), mini(_nz - 1, floori(hi2.z - 0.5)))
	if (j1.x - j0.x + 1) * (j1.y - j0.y + 1) * (j1.z - j0.z + 1) > 400000:
		return
	var inv := xf.affine_inverse()
	for y in range(j0.y, j1.y + 1):
		for z in range(j0.z, j1.z + 1):
			for x in range(j0.x, j1.x + 1):
				var p := inv * (_origin + Vector3(x + 0.5, y + 0.5, z + 0.5) * CELL)
				if absf(p.x) <= h.x and absf(p.y) <= h.y and absf(p.z) <= h.z:
					_grid[x + z * _nx + y * _nxz] = 1


## Треугольники (рельеф, арки): точки поверхности через ≤FACE_STEP м, сдвинутые внутрь на полъячейки
## (чтобы занятое не выступало над поверхностью больше чем на 0,25 м), и ещё одна ячейка вглубь — «толща».
const FACE_STEP := 0.5


func _raster_faces(faces: PackedVector3Array) -> void:
	var inv := 1.0 / CELL
	var t := 0
	while t + 2 < faces.size():
		var a := (faces[t] - _origin) * inv
		var b := (faces[t + 1] - _origin) * inv
		var c := (faces[t + 2] - _origin) * inv
		t += 3
		# Лицевая сторона в Godot — обход по часовой, поэтому наружу смотрит −(b − a) × (c − a)
		var nrm := (c - a).cross(b - a)
		if nrm.length_squared() < 1e-10:
			continue
		nrm = nrm.normalized()
		var n := maxi(1, ceili(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) * CELL / FACE_STEP))
		var du := (b - a) / n
		var dv := (c - a) / n
		var depth := [nrm * -0.5, nrm * -1.5]
		for i in n + 1:
			var row := a + du * i
			for j in n + 1 - i:
				var p := row + dv * j
				for dd: Vector3 in depth:
					var q := p + dd
					if q.x >= 0.0 and q.y >= 0.0 and q.z >= 0.0 and q.x < _nx and q.y < _ny and q.z < _nz:
						_grid[int(q.x) + int(q.z) * _nx + int(q.y) * _nxz] = 1
