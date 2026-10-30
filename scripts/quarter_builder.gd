class_name QuarterBuilder
extends RefCounted
## Жилой квартал по символьной карте (data/level_1_western_street.gd: QUARTER, QUARTER_MAP, TERRACES).
## 1 символ = клетка 1×1 м, реальные метры. Каждая клетка — столбик из сплошных отрезков по высоте
## (земля, стена, потолок с крышей, перемычка двери…). Грани строятся только там, где сплошное
## соседствует с пустым, — как воксели: ни одной скрытой грани, рёбра по сетке 1 м без Т-стыков.
## Ступени, своды, двери, парапеты и мостки — отдельные детали поверх. Коллизии — те же отрезки,
## слитые в большие коробки, плюс наклонные пандусы под ступенями.
## Главная дорога (+) — светлая мостовая с водостоком посередине; боковые переулки (.) — темнее.

const WALLS := "#%Vr"
const ROOMS := "_:"
const DOORS := "DdxoBHc"
## Закрытые двери: не пройти (c — занавесь у бедных: за ней завалено, тоже не пройти).
const CLOSED_DOORS := "DBHc"
## Земля улиц и дворов, по которой ходят.
const OPEN_GROUND := ".+,*bo"
## Под крышей (внутренний свет): комнаты, подвал, лестница вниз.
const INDOOR := "_:mM\\"
## Ниже всего строится земля, м под уровнем клетки.
const BASE := -8.0

var map: Array
var w := 0
var h := 0
## Мировые X и Z северо-западного угла клетки (0, 0).
var x0 := 0.0
var z0 := 0.0
## Уровень земли в каждом ряду (нижняя ступень в переходах между террасами).
var ground: PackedFloat32Array
## Верх моста Уилсона (Y).
var deck_y := 0.0

var _cfg: Dictionary
var _terraces: Array
var _b: LevelBuilder
var _mat: Dictionary
var _band := PackedByteArray()
## Пакеты граней: ключ "материал|слой|кусок" -> FaceBatch.
var _faces := {}
## Кеши по клеткам (индекс r * w + c): отрезки, верх крыши, стиль стены.
var _sol := []
var _rt := PackedFloat32Array()
var _style := PackedStringArray()
var _ch := PackedStringArray()
var _rng := RandomNumberGenerator.new()


class FaceBatch:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var mat_key := ""
	var layer := 1


func _init(builder: LevelBuilder, materials: Dictionary, cfg: Dictionary, quarter_map: Array, terraces: Array,
		origin: Vector3, plaza_y: float, wall_top: float) -> void:
	_b = builder
	_mat = materials
	_cfg = cfg
	_terraces = terraces
	map = quarter_map
	h = map.size()
	w = (map[0] as String).length()
	x0 = origin.x
	z0 = origin.z
	deck_y = wall_top
	_rng.seed = 33
	ground.resize(h)
	_band.resize(h)
	for r in h:
		var g := plaza_y
		for t in terraces:
			var a: int = t[0]
			var n: int = t[1]
			g += float(t[2]) * clampf(float(a + n - 1 - r) / n, 0.0, 1.0)
			if r >= a and r < a + n:
				_band[r] = 1
		ground[r] = g


## Символ клетки; за краем карты — «нет квартала».
func cell(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= w or r >= h:
		return " "
	if not _ch.is_empty():
		return _ch[r * w + c]
	return (map[r] as String)[c]


## Мировые координаты центра клетки на уровне её земли.
func cell_center(c: int, r: int) -> Vector3:
	return Vector3(x0 + c + 0.5, ground[r], z0 + r + 0.5)


## Высота земли (Y) в точке мира z — для уровня: что под ногами вне клеток.
func ground_at_z(z: float) -> float:
	var r := clampi(floori(z - z0), 0, h - 1)
	return ground[r]


func build() -> void:
	_ch.resize(w * h)
	for r in h:
		var row: String = map[r]
		for c in w:
			_ch[r * w + c] = row[c]
	_sol.resize(w * h)
	_rt.resize(w * h)
	_style.resize(w * h)
	for r in h:
		for c in w:
			var i := r * w + c
			_sol[i] = _solids_calc(c, r)
			_rt[i] = _roof_top_calc(c, r)
			_style[i] = _wall_style_calc(c, r)
	_b.local = true
	_check_rooms()
	_build_faces()
	_build_gutters()
	_flush_faces()
	_build_collision()
	_build_band_steps()
	_build_stairs()
	_build_vaults()
	_build_doors()
	_build_parapets()
	_build_bridges()
	_build_rubble()
	_build_shops()
	_b.local = false
	_b.layer = 1


# ─── Высоты ──────────────────────────────────────────────────────────────────

## Высота дома над землёй для стены, двери и т. п.: двухэтажные стены по соседству — 6,6 м.
func _house_height(c: int, r: int) -> float:
	var k := cell(c, r)
	if k == "%" or k == ":":
		return _cfg.wall_height_2
	if k == "#" or k == "_" or k in "mM\\":
		return _cfg.wall_height
	var best := 0.0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := cell(c + d.x, r + d.y)
		if n == "%" or n == ":":
			best = maxf(best, _cfg.wall_height_2)
		elif n == "#" or n == "_":
			best = maxf(best, _cfg.wall_height)
	return best if best > 0.0 else _cfg.wall_height


## Сплошные отрезки клетки [низ, верх] в мировых Y. Пусто — «нет квартала» (null).
func solids(c: int, r: int) -> Variant:
	if c < 0 or r < 0 or c >= w or r >= h:
		return null
	return _sol[r * w + c]


func _solids_calc(c: int, r: int) -> Variant:
	var k := cell(c, r)
	if k == " ":
		return null
	var g := ground[r]
	var lo := g + BASE
	var hh := _house_height(c, r)
	var top := g + hh
	var ceil_y: float = g + _cfg.ceiling
	var bd: float = _cfg.basement_depth
	match k:
		"#", "%":
			return [Vector2(lo, top)]
		"V":
			return [Vector2(lo, deck_y)]
		"_", ":":
			return [Vector2(lo, g), Vector2(ceil_y, top)]
		"D", "d", "x", "o", "B", "H", "c":
			return [Vector2(lo, g), Vector2(g + _cfg.door_height, top)]
		"r":
			return [Vector2(lo, g + _ruin_height(c, r))]
		"m":
			return [Vector2(lo, g - bd), Vector2(g - 0.25, g), Vector2(ceil_y, top)]
		"M":
			return [Vector2(lo, g - bd - _cfg.pool_depth), Vector2(g - 0.25, g), Vector2(ceil_y, top)]
		"\\":
			return [Vector2(lo, g - bd), Vector2(ceil_y, top)]
		"b":
			return [Vector2(lo, g), Vector2(g + _cfg.wall_height - 0.12, g + _cfg.wall_height)]
		_:
			# Переулок, двор, завал, лестница, свод, лавка — только земля (остальное — отдельные детали)
			return [Vector2(lo, g)]


## Высота обломка стены рухнувшего дома (символ r): неровно, 1–3 м.
static func _ruin_height(c: int, r: int) -> float:
	var hsh := absi((c * 73856093) ^ (r * 19349663)) % 1000
	return 1.0 + 2.0 * hsh / 1000.0


static func _subtract(a: Array, b: Array) -> Array:
	var out := []
	for seg: Vector2 in a:
		var parts := [seg]
		for cut: Vector2 in b:
			var next := []
			for p: Vector2 in parts:
				if cut.y <= p.x or cut.x >= p.y:
					next.append(p)
					continue
				if cut.x > p.x:
					next.append(Vector2(p.x, cut.x))
				if cut.y < p.y:
					next.append(Vector2(cut.y, p.y))
			parts = next
		out.append_array(parts)
	return out


# ─── Грани ───────────────────────────────────────────────────────────────────

## Отделка наружной стены дома (ключ материала): white — белая штукатурка богатого дома (цоколь — тёсаный камень),
## plaster_a / plaster_b — кремовая штукатурка, ochre — охристая обмазка, rubble — рваный камень (бедные).
## Дома из HOUSE_STYLES в данных — как указано, остальные — пятнами по кварталу.
func wall_style(c: int, r: int) -> String:
	return _wall_style(c, r)


func _wall_style(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= w or r >= h:
		return "plaster_a"
	return _style[r * w + c]


func _wall_style_calc(c: int, r: int) -> String:
	for e: Array in _cfg.get("styles", []):
		if c >= e[0] and r >= e[1] and c <= e[2] and r <= e[3]:
			return e[4]
	var hsh := (int(c / 6) * 73856093) ^ (int(r / 8) * 19349663)
	return ["plaster_a", "plaster_b", "ochre", "rubble"][absi(hsh) % 4]


func _build_faces() -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for r in h:
		for c in w:
			var a: Variant = solids(c, r)
			if a == null:
				continue
			var k := cell(c, r)
			var indoor := k in INDOOR
			# Боковые грани: что у меня сплошное, а у соседа пусто
			for d: Vector2i in dirs:
				var bsol: Variant = solids(c + d.x, r + d.y)
				if bsol == null or bsol == a:
					continue
				var exposed := _subtract(a, bsol)
				if exposed.is_empty():
					continue
				var nk := cell(c + d.x, r + d.y)
				_side_faces(c, r, d, exposed, k, nk)
			# Верх и низ отрезков
			var segs: Array = a
			for i in segs.size():
				var s: Vector2 = segs[i]
				var top_open := i == segs.size() - 1 or (segs[i + 1] as Vector2).x > s.y + 0.001
				var bottom_open := i > 0 and (segs[i - 1] as Vector2).y < s.x - 0.001
				if top_open:
					_top_face(c, r, s.y, k, i, segs.size())
				if bottom_open:
					_bottom_face(c, r, s.x, k, indoor)


func _side_faces(c: int, r: int, d: Vector2i, exposed: Array, k: String, nk: String) -> void:
	# Плоскость — граница клеток, нормаль смотрит к соседу
	var n := Vector3(d.x, 0.0, d.y)
	var cx := x0 + c + 0.5 + d.x * 0.5
	var cz := z0 + r + 0.5 + d.y * 0.5
	var right := Vector3.UP.cross(n)
	var p_left := Vector3(cx, 0.0, cz) - right * 0.5
	var p_right := Vector3(cx, 0.0, cz) + right * 0.5
	var neighbor_in := nk in INDOOR
	var layer := LevelBuilder.INTERIOR_LAYER if neighbor_in else 1
	var g := ground[r]
	for seg: Vector2 in exposed:
		# Режем по мировой сетке 1 м — у соседних клеток одинаковые рёбра
		var ys := PackedFloat32Array([seg.x])
		var y := floorf(seg.x) + 1.0
		while y < seg.y - 0.001:
			ys.append(y)
			y += 1.0
		ys.append(seg.y)
		for i in ys.size() - 1:
			var y0 := ys[i]
			var y1 := ys[i + 1]
			var mat_key := _side_material(k, nk, y0 - g, neighbor_in, c, r)
			_quad_v(mat_key, layer, p_left, p_right, y0, y1, n, right)


func _side_material(k: String, nk: String, rel_y: float, neighbor_in: bool, c: int, r: int) -> String:
	if k == "V":
		return "ashlar"
	if k == "r":
		return "rubble"
	if k in DOORS or nk in DOORS:
		return "lintel"
	if neighbor_in:
		return "rubble_in" if rel_y < 0.0 else "plaster_in"
	if rel_y < 0.05:
		# Подступенки и края земли
		return "paving"
	if k in WALLS or k in ROOMS or k in INDOOR:
		var style := _wall_style(c, r)
		if rel_y < 0.9:
			# Цоколь: у богатых — тёсаный камень, у остальных — бут
			return "ashlar" if style == "white" else "rubble"
		return style
	return "paving"


func _top_face(c: int, r: int, y: float, k: String, index: int, count: int) -> void:
	var g := ground[r]
	var mat_key := "roof"
	var layer := 1
	if k == "V":
		mat_key = "ashlar"
	elif index == 0 and count > 1 and k in "_:":
		mat_key = "floor"
		layer = LevelBuilder.INTERIOR_LAYER
	elif k in "mM\\" and index == 0:
		mat_key = "floor"
		layer = LevelBuilder.INTERIOR_LAYER
	elif k == "m" and index == 1:
		# Над подвалом — пол комнаты
		mat_key = "floor"
		layer = LevelBuilder.INTERIOR_LAYER
	elif k == "M" and index == 1:
		mat_key = "floor"
		layer = LevelBuilder.INTERIOR_LAYER
	elif k == "r":
		mat_key = "rubble"
	elif index == 0 and absf(y - g) < 0.01:
		if k == ",":
			mat_key = "earth"
		elif k in DOORS:
			mat_key = "lintel"
		elif k == "+":
			mat_key = "paving_main"
		elif k == ".":
			mat_key = "paving_dark"
		else:
			mat_key = "paving"
	elif k == "b":
		mat_key = "wood"
	var a := Vector3(x0 + c, y, z0 + r)
	_quad_h(mat_key, layer, a, Vector3.UP)


func _bottom_face(c: int, r: int, y: float, k: String, indoor: bool) -> void:
	var mat_key := "ceiling"
	var layer := LevelBuilder.INTERIOR_LAYER
	if k in DOORS:
		mat_key = "lintel"
		layer = 1
	elif k == "b":
		mat_key = "wood"
		layer = 1
	elif not indoor:
		layer = 1
	_quad_h(mat_key, layer, Vector3(x0 + c, y, z0 + r), Vector3.DOWN)


## Вертикальный четырёхугольник от p_left до p_right (как видно снаружи), высоты y0..y1.
func _quad_v(mat_key: String, layer: int, p_left: Vector3, p_right: Vector3, y0: float, y1: float,
		n: Vector3, right: Vector3) -> void:
	var tl := Vector3(p_left.x, y1, p_left.z)
	var tr := Vector3(p_right.x, y1, p_right.z)
	var br := Vector3(p_right.x, y0, p_right.z)
	var bl := Vector3(p_left.x, y0, p_left.z)
	var tile := _tile(mat_key)
	var fb := _batch(mat_key, layer, (tl + br) * 0.5)
	fb.v.append_array([tl, tr, br, tl, br, bl])
	fb.n.append_array([n, n, n, n, n, n])
	var ul := p_left.dot(right) / tile
	var ur := p_right.dot(right) / tile
	var vt := -y1 / tile
	var vb := -y0 / tile
	fb.uv.append_array([Vector2(ul, vt), Vector2(ur, vt), Vector2(ur, vb), Vector2(ul, vt), Vector2(ur, vb), Vector2(ul, vb)])


## Горизонтальная клетка 1×1 с северо-западным углом a; n — вверх или вниз.
func _quad_h(mat_key: String, layer: int, a: Vector3, n: Vector3) -> void:
	var p00 := a
	var p10 := a + Vector3(1, 0, 0)
	var p11 := a + Vector3(1, 0, 1)
	var p01 := a + Vector3(0, 0, 1)
	var tile := _tile(mat_key)
	var fb := _batch(mat_key, layer, a + Vector3(0.5, 0.0, 0.5))
	# Сверху: по часовой, если смотреть сверху (-Z — «вверх» картинки)
	var order := [p00, p10, p11, p00, p11, p01] if n.y > 0.0 else [p01, p11, p10, p01, p10, p00]
	for p: Vector3 in order:
		fb.v.append(p)
		fb.n.append(n)
		fb.uv.append(Vector2(p.x, p.z) / tile)


func _tile(mat_key: String) -> float:
	match mat_key:
		"plaster_a", "plaster_b", "plaster_in":
			return 3.0
		"gutter":
			return 1.0
		"ashlar", "paving":
			return 4.0
		"lintel":
			return 2.0
		_:
			return 2.0


func _batch(mat_key: String, layer: int, p: Vector3) -> FaceBatch:
	var key := "%s|%d|%d|%d" % [mat_key, layer, floori(p.x / LevelBuilder.LOCAL_CHUNK), floori(p.z / LevelBuilder.LOCAL_CHUNK)]
	var fb: FaceBatch = _faces.get(key)
	if fb == null:
		fb = FaceBatch.new()
		fb.mat_key = mat_key
		fb.layer = layer
		_faces[key] = fb
	return fb


func _flush_faces() -> void:
	for key in _faces:
		var fb: FaceBatch = _faces[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = fb.v
		arrays[Mesh.ARRAY_NORMAL] = fb.n
		arrays[Mesh.ARRAY_TEX_UV] = fb.uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_b.layer = fb.layer
		_b.add_mesh(mesh, Transform3D(), _mat[fb.mat_key])
	_b.layer = 1
	_faces.clear()


# ─── Проверка комнат ─────────────────────────────────────────────────────────

## Комната, куда можно войти, — не меньше 3×4 м. Меньше — предупреждение: закрой дверь (D, B, H).
func _check_rooms() -> void:
	var seen := {}
	for r in h:
		for c in w:
			var k := cell(c, r)
			if k not in ROOMS or seen.has(Vector2i(c, r)):
				continue
			var lo := Vector2i(c, r)
			var hi := Vector2i(c, r)
			var open := false
			var q: Array[Vector2i] = [Vector2i(c, r)]
			seen[Vector2i(c, r)] = true
			while not q.is_empty():
				var p: Vector2i = q.pop_back()
				lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
				hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = p + d
					var nk := cell(nb.x, nb.y)
					if nk in "dxo,.+\\":
						open = true
					if not seen.has(nb) and (nk in ROOMS or nk in "mM\\"):
						seen[nb] = true
						q.append(nb)
			var size := hi - lo + Vector2i.ONE
			if open and (mini(size.x, size.y) < 3 or maxi(size.x, size.y) < 4):
				push_warning("Квартал: в комнату %d×%d м у клетки (%d, %d) можно войти — меньше 3×4 м, закрой дверь" %
					[size.x, size.y, c, r])


# ─── Водосток посередине главной дороги ───────────────────────────────────────

## Клетка — середина главной дороги шириной 3 м: водосток идёт вдоль дороги через её центр.
## Тёмная полоса крышек с прорезями чуть выше мостовой, без коллизии. В рядах ступеней его нет.
func _build_gutters() -> void:
	var gw := 0.32
	for r in h:
		if _band[r] == 1:
			continue
		for c in w:
			if cell(c, r) != "+":
				continue
			var y := ground[r] + 0.012
			var p := cell_center(c, r)
			# Дорога на север: слева и справа ровно по одной клетке дороги, дальше — не дорога
			if _road_run(c, r, Vector2i(1, 0)) == 3 and cell(c - 1, r) == "+" and cell(c + 1, r) == "+":
				_flat_quad("gutter", Vector3(p.x - gw * 0.5, y, p.z - 0.5), Vector3(p.x + gw * 0.5, y, p.z + 0.5))
			if _road_run(c, r, Vector2i(0, 1)) == 3 and cell(c, r - 1) == "+" and cell(c, r + 1) == "+":
				_flat_quad("gutter", Vector3(p.x - 0.5, y, p.z - gw * 0.5), Vector3(p.x + 0.5, y, p.z + gw * 0.5))


## Сколько клеток главной дороги подряд через клетку (c, r) вдоль направления d.
func _road_run(c: int, r: int, d: Vector2i) -> int:
	var n := 1
	var p := Vector2i(c, r) - d
	while cell(p.x, p.y) == "+":
		n += 1
		p -= d
	p = Vector2i(c, r) + d
	while cell(p.x, p.y) == "+":
		n += 1
		p += d
	return n


## Горизонтальный прямоугольник лицом вверх (a — северо-западный угол, b — юго-восточный).
func _flat_quad(mat_key: String, a: Vector3, b: Vector3) -> void:
	var fb := _batch(mat_key, 1, (a + b) * 0.5)
	var tile := _tile(mat_key)
	var pts := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, a.z),
		Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]
	for pt: Vector3 in pts:
		fb.v.append(pt)
		fb.n.append(Vector3.UP)
		fb.uv.append(Vector2(pt.x, pt.z) / tile)


# ─── Коллизии ────────────────────────────────────────────────────────────────

## Клетки с одинаковыми отрезками сливаются в прямоугольники; переходы между террасами — пандусы.
func _build_collision() -> void:
	var open_rects := {}
	var done := []
	for r in h:
		var runs := {}
		var c := 0
		while c < w:
			var sig := _col_sig(c, r)
			if sig.is_empty():
				c += 1
				continue
			var c1 := c
			while c1 + 1 < w and _col_sig(c1 + 1, r) == sig:
				c1 += 1
			runs["%d:%d:%s" % [c, c1, sig]] = [c, c1, r]
			c = c1 + 1
		# Продлить прямоугольники из прошлого ряда или закрыть их
		var next := {}
		for key in runs:
			if open_rects.has(key):
				var rect: Array = open_rects[key]
				rect[3] = r
				next[key] = rect
			else:
				var run: Array = runs[key]
				next[key] = [run[0], run[1], r, r, key]
		for key in open_rects:
			if not next.has(key):
				done.append(open_rects[key])
		open_rects = next
	for key in open_rects:
		done.append(open_rects[key])
	for rect: Array in done:
		var c0: int = rect[0]
		var c1: int = rect[1]
		var r0: int = rect[2]
		var r1: int = rect[3]
		var segs: Array = _col_segs(c0, r0)
		for s: Vector2 in segs:
			var size := Vector3(c1 - c0 + 1, s.y - s.x, r1 - r0 + 1)
			var center := Vector3(x0 + (c0 + c1 + 1) * 0.5, (s.x + s.y) * 0.5, z0 + (r0 + r1 + 1) * 0.5)
			_b.collision_box(Transform3D(Basis(), center), size)
	# Пандусы под ступенями переходов между террасами: на всю ширину квартала
	for t in _terraces:
		var a: int = t[0]
		var n: int = t[1]
		var z_n := z0 + a
		var z_s := z0 + a + n
		var y_s := ground[a + n] if a + n < h else ground[h - 1]
		var y_n := ground[a - 1] if a > 0 else ground[0]
		_ramp(Vector3(x0 + w * 0.5, y_s, z_s), Vector3(x0 + w * 0.5, y_n, z_n), float(w))


## Пандус-коллизия от точки from до to (центры нижнего и верхнего края), ширина width.
func _ramp(from: Vector3, to: Vector3, width: float) -> void:
	var dir := to - from
	var length := dir.length()
	var fwd := dir / length
	var side := Vector3.UP.cross(Vector3(fwd.x, 0.0, fwd.z).normalized())
	var up := fwd.cross(side).normalized()
	if up.y < 0.0:
		up = -up
		side = -side
	var thick := 0.4
	var basis := Basis(side, up, fwd)
	var center := (from + to) * 0.5 - up * thick * 0.5
	_b.collision_box(Transform3D(basis.orthonormalized(), center), Vector3(width, thick, length + 0.3))


## Отрезки клетки для коллизии (без земли в переходах между террасами и под деталями со своей коллизией).
func _col_segs(c: int, r: int) -> Array:
	var a: Variant = solids(c, r)
	if a == null:
		return []
	var k := cell(c, r)
	var segs: Array = (a as Array).duplicate()
	var g := ground[r]
	# Земля в переходах между террасами — пандусом; под лестницей в подвал и в микве — их пандусы
	if (_band[r] == 1 and k not in WALLS) or k == "\\" or k == "M":
		segs.remove_at(0)
	return segs


func _col_sig(c: int, r: int) -> String:
	var segs := _col_segs(c, r)
	if segs.is_empty():
		return ""
	var parts := PackedStringArray()
	for s: Vector2 in segs:
		parts.append("%.3f,%.3f" % [s.x, s.y])
	return ";".join(parts)


# ─── Ступени между террасами ─────────────────────────────────────────────────

## В рядах перехода — по две ступени на клетку: южная половина на уровне ряда, северная — выше.
func _build_band_steps() -> void:
	for t in _terraces:
		var a: int = t[0]
		var n: int = t[1]
		var half: float = float(t[2]) / n * 0.5
		for r in range(a, a + n):
			var c := 0
			while c < w:
				if not _is_ground_open(c, r):
					c += 1
					continue
				var c1 := c
				while c1 + 1 < w and _is_ground_open(c1 + 1, r):
					c1 += 1
				var y := ground[r]
				_b.box_between(Vector3(x0 + c, y - 0.3, z0 + r), Vector3(x0 + c1 + 1, y + half, z0 + r + 0.5),
					_mat.paving, 2.0, false)
				c = c1 + 1


func _is_ground_open(c: int, r: int) -> bool:
	var k := cell(c, r)
	return k in OPEN_GROUND or k in DOORS


# ─── Лестницы ────────────────────────────────────────────────────────────────

## Группы клеток лестниц: [символ, клетки, ось (Vector2i вверх по лестнице), нижний край, верхний край].
func _stair_runs() -> Array:
	var seen := {}
	var out := []
	for r in h:
		for c in w:
			var k := cell(c, r)
			if k != "/" and k != "\\" or seen.has(Vector2i(c, r)):
				continue
			var run: Array[Vector2i] = []
			var q: Array[Vector2i] = [Vector2i(c, r)]
			seen[Vector2i(c, r)] = true
			while not q.is_empty():
				var p: Vector2i = q.pop_back()
				run.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = p + d
					if not seen.has(nb) and cell(nb.x, nb.y) == k:
						seen[nb] = true
						q.append(nb)
			var lo := run[0]
			var hi := run[0]
			for p in run:
				lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
				hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
			var horiz := hi.x - lo.x >= hi.y - lo.y
			# Верх лестницы на крышу — у стены/комнаты, лестницы в подвал — у подвала
			var dir := Vector2i(1, 0) if horiz else Vector2i(0, 1)
			var end_a := lo - dir
			var end_b := hi + dir
			var a_is_top := false
			if k == "/":
				a_is_top = cell(end_a.x, end_a.y) in WALLS or cell(end_a.x, end_a.y) in ROOMS
			else:
				a_is_top = cell(end_b.x, end_b.y) in "mM"
			var up := -dir if a_is_top else dir
			out.append([k, run, up, lo, hi])
	return out


func _build_stairs() -> void:
	var step: float = _cfg.step
	for st: Array in _stair_runs():
		var k: String = st[0]
		var up: Vector2i = st[2]
		var lo: Vector2i = st[3]
		var hi: Vector2i = st[4]
		var along := Vector3(up.x, 0.0, up.y)
		var cells_long := (hi.x - lo.x if up.x != 0 else hi.y - lo.y) + 1
		var across_lo := Vector2(x0 + lo.x, z0 + lo.y)
		var across_hi := Vector2(x0 + hi.x + 1, z0 + hi.y + 1)
		var g := ground[lo.y]
		var y_bottom: float
		var y_top: float
		if k == "/":
			y_bottom = g
			# Верх — крыша клетки за верхним концом
			var top_cell := (lo + up) if (up.x < 0 or up.y < 0) else (hi + up)
			y_top = ground[clampi(top_cell.y, 0, h - 1)] + _house_height(top_cell.x, top_cell.y)
		else:
			y_bottom = g - _cfg.basement_depth
			y_top = g
		var count := maxi(2, roundi((y_top - y_bottom) / step))
		var tread := float(cells_long) / count
		# Начало лестницы (низ) — край, противоположный направлению вверх
		var start := Vector2(across_lo.x if up.x > 0 else across_hi.x, across_lo.y if up.y > 0 else across_hi.y)
		var layer_prev := _b.layer
		_b.layer = LevelBuilder.INTERIOR_LAYER if k == "\\" else 1
		for i in count:
			var s0 := start + Vector2(up.x, up.y) * tread * i
			var s1 := start + Vector2(up.x, up.y) * tread * (i + 1)
			var y := y_bottom + (y_top - y_bottom) * (i + 1) / count
			var a := Vector3(minf(s0.x, s1.x) if up.x != 0 else across_lo.x, y_bottom - 0.2, minf(s0.y, s1.y) if up.y != 0 else across_lo.y)
			var b := Vector3(maxf(s0.x, s1.x) if up.x != 0 else across_hi.x, y, maxf(s0.y, s1.y) if up.y != 0 else across_hi.y)
			_b.box_between(a, b, _mat.lintel, 2.0, false)
		_b.layer = layer_prev
		# Пандус: от нижнего края до верхнего, ширина — поперёк лестницы
		var width := (across_hi.y - across_lo.y) if up.x != 0 else (across_hi.x - across_lo.x)
		var mid_cross := Vector2((across_lo.x + across_hi.x) * 0.5, (across_lo.y + across_hi.y) * 0.5)
		var from := Vector3(start.x if up.x != 0 else mid_cross.x, y_bottom, start.y if up.y != 0 else mid_cross.y)
		var to := from + along * cells_long
		to.y = y_top
		_ramp(from, to, width)
	_build_pools()


## Миква: ступени вниз по длине бассейна от края у лестницы, тёмная вода.
func _build_pools() -> void:
	var cells := []
	for r in h:
		for c in w:
			if cell(c, r) == "M":
				cells.append(Vector2i(c, r))
	if cells.is_empty():
		return
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for p: Vector2i in cells:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	var g := ground[lo.y]
	var floor_y: float = g - _cfg.basement_depth
	var bottom: float = floor_y - _cfg.pool_depth
	# Спуск вдоль длинной стороны: с восточного края (ближе к лестнице вниз) на запад
	var x_start := float(x0 + hi.x + 1)
	var x_end := float(x0 + lo.x)
	var count := maxi(3, roundi(_cfg.pool_depth / 0.25))
	var tread := (x_start - x_end) / count
	_b.layer = LevelBuilder.INTERIOR_LAYER
	for i in count:
		var y: float = floor_y - _cfg.pool_depth * (i + 1) / count
		_b.box_between(Vector3(x_start - tread * (i + 1), bottom - 0.3, z0 + lo.y),
			Vector3(x_start - tread * i, y, z0 + hi.y + 1), _mat.plaster_in, 2.0, false)
	var water := PsxMesh.box(Vector3(x_start - x_end, 0.02, hi.y - lo.y + 1), 2.0, 1.0)
	_b.add_mesh(water, Transform3D(Basis(), Vector3((x_start + x_end) * 0.5, bottom + 0.55, z0 + (lo.y + hi.y + 1) * 0.5)), _mat.water)
	_b.layer = 1
	_ramp(Vector3(x_start, floor_y, z0 + (lo.y + hi.y + 1) * 0.5), Vector3(x_end, bottom, z0 + (lo.y + hi.y + 1) * 0.5), hi.y - lo.y + 1)
	# Пол бассейна
	_b.collision_box(Transform3D(Basis(), Vector3((x_start + x_end) * 0.5, bottom - 0.25, z0 + (lo.y + hi.y + 1) * 0.5)),
		Vector3(x_start - x_end, 0.5, hi.y - lo.y + 1))


# ─── Своды: низкие проходы под домами и арки моста Уилсона ───────────────────

func _build_vaults() -> void:
	# Низкие проходы (=): прямоугольник, проход — вдоль сторон, к которым примыкает пустое
	for comp: Array in _components("="):
		var lo: Vector2i = comp[0]
		var hi: Vector2i = comp[1]
		var along_z := cell(lo.x, lo.y - 1) not in WALLS or cell(lo.x, hi.y + 1) not in WALLS
		var g := ground[hi.y]
		var top := g + _house_height(lo.x, lo.y)
		var width := float(hi.x - lo.x + 1) if along_z else float(hi.y - lo.y + 1)
		var depth := float(hi.y - lo.y + 1) if along_z else float(hi.x - lo.x + 1)
		var spring := clampf(top - g - width * 0.5 - 0.25, 0.5, 2.0)
		var mesh := PsxMesh.arch_block(width, top - g, depth, width, spring, 2.0, 1.0)
		var basis := Basis() if along_z else Basis(Vector3.UP, PI * 0.5)
		var center := Vector3(x0 + (lo.x + hi.x + 1) * 0.5, g, z0 + (lo.y + hi.y + 1) * 0.5)
		_b.mesh_with_trimesh(mesh, Transform3D(basis, center), _mat.lintel)
	# Мост Уилсона: в рядах с V каждый промежуток между опорами — арка до верха моста
	var rows := []
	for r in h:
		if (map[r] as String).contains("V"):
			rows.append(r)
	if rows.is_empty():
		return
	var r0: int = rows[0]
	var r1: int = rows[rows.size() - 1]
	var g := ground[r1]
	var c := 0
	while c < w:
		if cell(c, r0) == "V":
			c += 1
			continue
		var c1 := c
		while c1 + 1 < w and cell(c1 + 1, r0) != "V":
			c1 += 1
		var span := float(c1 - c + 1)
		var height := deck_y - g
		var spring := maxf(0.0, height - span * 0.5 - _cfg.get("crown", 2.5))
		var mesh := PsxMesh.arch_block(span, height, r1 - r0 + 1, span, spring, 4.0, 2.0)
		_b.mesh_with_trimesh(mesh, Transform3D(Basis(), Vector3(x0 + (c + c1 + 1) * 0.5, g, z0 + (r0 + r1 + 1) * 0.5)), _mat.ashlar)
		c = c1 + 1


## Связные группы клеток символа k: [левый верхний, правый нижний].
func _components(k: String) -> Array:
	var seen := {}
	var out := []
	for r in h:
		for c in w:
			if cell(c, r) != k or seen.has(Vector2i(c, r)):
				continue
			var lo := Vector2i(c, r)
			var hi := Vector2i(c, r)
			var q: Array[Vector2i] = [Vector2i(c, r)]
			seen[Vector2i(c, r)] = true
			while not q.is_empty():
				var p: Vector2i = q.pop_back()
				lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
				hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = p + d
					if not seen.has(nb) and cell(nb.x, nb.y) == k:
						seen[nb] = true
						q.append(nb)
			out.append([lo, hi])
	return out


# ─── Двери ───────────────────────────────────────────────────────────────────

func _build_doors() -> void:
	var leaf_size := Vector3(0.94, 2.06, 0.07)
	for r in h:
		for c in w:
			var k := cell(c, r)
			if k not in DOORS:
				continue
			var g := ground[r]
			# Ось прохода: где пусто с двух сторон
			var ns := _passable(c, r - 1) or _passable(c, r + 1)
			var axis := Vector2i(0, 1) if ns else Vector2i(1, 0)
			var center := cell_center(c, r)
			# Внутренняя сторона — где комната, иначе двор: створка распахивается туда, а не в переулок
			var inner := axis
			if _inner_rank(cell(c - axis.x, r - axis.y)) > _inner_rank(cell(c + axis.x, r + axis.y)):
				inner = -axis
			var outer := -inner
			var out3 := Vector3(outer.x, 0.0, outer.y)
			var in3 := -out3
			# Перемычка снаружи: светлый камень чуть шире проёма, если снаружи не стена
			if cell(c + outer.x, r + outer.y) not in WALLS + DOORS:
				var lp: Vector3 = center + out3 * 0.53 + Vector3.UP * (_cfg.door_height + 0.0)
				var lsize := Vector3(1.5, 0.3, 0.1) if axis.x == 0 else Vector3(0.1, 0.3, 1.5)
				_b.box(lp, lsize, _mat.lintel, 1.0, false)
				# Порог
				_b.box(center + out3 * 0.35 - Vector3.UP * 0.05, Vector3(1.0, 0.09, 0.3) if axis.x == 0 else Vector3(0.3, 0.09, 1.0),
					_mat.lintel, 1.0, false)
			if k == "o":
				continue
			# Ставить створку только у одной клетки толстой стены — у той, что ближе к комнате
			if cell(c + inner.x, r + inner.y) in DOORS:
				continue
			var yaw := atan2(-in3.x, -in3.z) + PI
			var hinge := center + in3 * 0.42 - Basis(Vector3.UP, yaw) * Vector3.RIGHT * 0.47
			var leaf_mesh := PsxMesh.box(leaf_size, 1.0, 1.0)
			match k:
				"D", "H":
					var xf := Transform3D(Basis(Vector3.UP, yaw), center + in3 * 0.42 + Vector3.UP * (leaf_size.y * 0.5 + 0.02))
					_b.add_mesh(leaf_mesh, xf, _mat.door)
					_b.collision_box(xf, leaf_size)
					if k == "H":
						# Кровавые ладони и царапины на наружной стороне створки
						var face := center + in3 * (0.42 - leaf_size.z * 0.5) + Vector3.UP * 0.02
						_b.add_mesh(PropLibrary.mesh("blood_hands"), Transform3D(Basis.looking_at(out3), face), PropLibrary.material())
				"B":
					# Приоткрыта на щель, изнутри подпёрта мебелью: не пройти, но в щель видно завал
					var basis := Basis(Vector3.UP, yaw - deg_to_rad(18.0 + _rng.randf() * 6.0))
					var xf := Transform3D(basis, hinge + basis * Vector3(leaf_size.x * 0.5, leaf_size.y * 0.5 + 0.02, 0.0))
					_b.add_mesh(leaf_mesh, xf, _mat.door)
					_b.collision_box(Transform3D(Basis(Vector3.UP, yaw), center + in3 * 0.3 + Vector3.UP * 1.05), Vector3(1.0, 2.1, 0.5))
					_barricade(center + in3 * 1.0, yaw)
				"c":
					# Занавесь в проёме, край отогнут; за ней темно, пройти нельзя
					var xf := Transform3D(Basis(Vector3.UP, yaw), center + out3 * 0.2)
					_b.add_mesh(PropLibrary.mesh("curtain"), xf, PropLibrary.material())
					_b.collision_box(Transform3D(Basis(Vector3.UP, yaw), center + in3 * 0.2 + Vector3.UP * 1.05), Vector3(1.0, 2.1, 0.4))
				"d":
					var open := deg_to_rad(65.0 + _rng.randf() * 20.0)
					var basis := Basis(Vector3.UP, yaw - open)
					var xf := Transform3D(basis, hinge + basis * Vector3(leaf_size.x * 0.5, leaf_size.y * 0.5 + 0.02, 0.0))
					_b.add_mesh(leaf_mesh, xf, _mat.door)
					_b.collision_box(xf, leaf_size)
				"x":
					# Выбитая створка лежит снаружи, наискось
					var basis := Basis(Vector3.UP, yaw + _rng.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, PI * 0.5)
					var p := center + out3 * 1.4 + Vector3.UP * 0.05
					_b.add_mesh(leaf_mesh, Transform3D(basis, p), _mat.door)


## Мебель за заваленной дверью (внутри, у проёма): опрокинутый стол, сундук, кувшин. Виден в щель.
func _barricade(at: Vector3, yaw: float) -> void:
	var layer_prev := _b.layer
	_b.layer = LevelBuilder.INTERIOR_LAYER
	var basis := Basis(Vector3.UP, yaw)
	var mat := PropLibrary.material()
	_b.add_mesh(PropLibrary.mesh("table_tipped"), Transform3D(basis, at + basis * Vector3(0.0, 0.0, 0.25)), mat)
	_b.add_mesh(PropLibrary.mesh("chest"), Transform3D(basis.rotated(Vector3.UP, 0.3), at + basis * Vector3(0.3, 0.0, -0.4)), mat)
	_b.add_mesh(PropLibrary.mesh("jar_large"), Transform3D(basis, at + basis * Vector3(-0.55, 0.0, -0.3)), mat)
	_b.add_mesh(PropLibrary.mesh("stool"), Transform3D(basis.rotated(Vector3.FORWARD, 1.4), at + basis * Vector3(-0.1, 0.62, 0.0)), mat)
	_b.layer = layer_prev


func _inner_rank(k: String) -> int:
	if k in INDOOR:
		return 3
	if k in DOORS:
		return 2
	if k == ",":
		return 1
	return 0


func _passable(c: int, r: int) -> bool:
	var k := cell(c, r)
	return k != " " and k not in WALLS


# ─── Парапеты на крышах ──────────────────────────────────────────────────────

## Край крыши, где рядом ниже на 0,4 м и больше, — парапет (кроме верха лестниц и мостков).
func _build_parapets() -> void:
	var stair_tops := {}
	for st: Array in _stair_runs():
		if st[0] != "/":
			continue
		var up: Vector2i = st[2]
		var lo: Vector2i = st[3]
		var hi: Vector2i = st[4]
		var top_cell: Vector2i = (lo + up) if (up.x < 0 or up.y < 0) else (hi + up)
		var top_stair: Vector2i = lo if (up.x < 0 or up.y < 0) else hi
		var dd: Vector2i = top_stair - top_cell
		stair_tops["%d,%d,%d,%d" % [top_cell.x, top_cell.y, dd.x, dd.y]] = true
	var ph: float = _cfg.parapet
	var t := 0.25
	# Края, где нужен парапет: d -> {клетка -> высота}; потом соседние по линии сливаются
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var need := {}
		for r in h:
			for c in w:
				var top := _roof_top(c, r)
				if is_nan(top):
					continue
				var nk := cell(c + d.x, r + d.y)
				if nk == " ":
					continue
				var ntop := _roof_top(c + d.x, r + d.y)
				if not is_nan(ntop) and ntop > top - 0.4:
					continue
				if nk == "b" or stair_tops.has("%d,%d,%d,%d" % [c, r, d.x, d.y]):
					continue
				need[Vector2i(c, r)] = top
		var along := Vector2i(d.y, d.x).abs()
		for p: Vector2i in need:
			# Начало линии: у предыдущей клетки по линии парапета нет или он другой высоты
			var prev: Vector2i = p - along
			if need.has(prev) and absf(need[prev] - need[p]) < 0.01 and _wall_style(prev.x, prev.y) == _wall_style(p.x, p.y):
				continue
			var n := 1
			while need.has(p + along * n) and absf(need[p + along * n] - need[p]) < 0.01 \
					and _wall_style((p + along * n).x, (p + along * n).y) == _wall_style(p.x, p.y):
				n += 1
			var top: float = need[p]
			var first := Vector3(x0 + p.x + 0.5, top, z0 + p.y + 0.5)
			var center := first + Vector3(along.x, 0, along.y) * (n - 1) * 0.5 + Vector3(d.x, 0, d.y) * (0.5 - t * 0.5)
			var size := Vector3(t, ph, n) if d.x != 0 else Vector3(n, ph, t)
			var k := cell(p.x, p.y)
			var mat: Material = _mat.ashlar if k == "V" or _is_under_bridge(p.x, p.y) else _mat[_wall_style(p.x, p.y)]
			# Коллизия нужна только там, куда можно подняться (одноэтажные крыши)
			var reachable: bool = top - ground[p.y] < _cfg.wall_height + 0.5
			_b.box(center, size, mat, 2.0, reachable, 0.0, PsxMesh.FACE_BOTTOM, 2.0)


## Верх крыши клетки или NAN, если клетка не крыша (переулок, двор, лестница, свод — свой верх).
func _roof_top(c: int, r: int) -> float:
	if c < 0 or r < 0 or c >= w or r >= h:
		return NAN
	return _rt[r * w + c]


func _roof_top_calc(c: int, r: int) -> float:
	var k := cell(c, r)
	if k == "V":
		return deck_y
	if k == "r":
		return NAN
	if k in WALLS or k in ROOMS or k in DOORS or k in "mM\\":
		return ground[r] + _house_height(c, r)
	if k == "=":
		return ground[r] + _house_height(c, r)
	# Под мостом Уилсона верх — мост
	if _is_under_bridge(c, r):
		return deck_y
	return NAN


func _is_under_bridge(c: int, r: int) -> bool:
	return (map[r] as String).contains("V") and cell(c, r) != "V"


# ─── Мостки, завалы, лавки ───────────────────────────────────────────────────

func _build_bridges() -> void:
	for comp: Array in _components("b"):
		var lo: Vector2i = comp[0]
		var hi: Vector2i = comp[1]
		var y: float = ground[lo.y] + _cfg.wall_height
		var a := Vector3(x0 + lo.x - 0.3, y - 0.1, z0 + lo.y + 0.15)
		var b := Vector3(x0 + hi.x + 1.3, y + 0.04, z0 + hi.y + 0.85)
		_b.box_between(a, b, _mat.wood, 1.0, true)


## Завал (символ *): рухнувшая кладка в рост человека и выше, во всю ширину прохода, из неё торчат балки.
## Видно сразу: здесь не пройти. Коллизия — коробка 2,8 м.
func _build_rubble() -> void:
	for comp: Array in _components("*"):
		var lo: Vector2i = comp[0]
		var hi: Vector2i = comp[1]
		var g := ground[hi.y]
		var size := Vector3(hi.x - lo.x + 1, 2.8, hi.y - lo.y + 1)
		var center := Vector3(x0 + (lo.x + hi.x + 1) * 0.5, g, z0 + (lo.y + hi.y + 1) * 0.5)
		_b.collision_box(Transform3D(Basis(), center + Vector3.UP * size.y * 0.5), size)
		# Куча блоков: крупные внизу и по всей площади, выше — мельче и ближе к середине
		# Слои по 0,45 м: вершина кучи — около 2,4 м, выше глаз
		for layer_i in 6:
			var y := g - 0.1 + layer_i * 0.45
			var shrink := 1.0 - layer_i * 0.13
			var n := int((size.x * size.z) * (1.0 - layer_i * 0.12)) + 1
			for i in n:
				var s := Vector3(_rng.randf_range(0.6, 1.2), _rng.randf_range(0.55, 0.85), _rng.randf_range(0.5, 1.0)) * (1.0 - layer_i * 0.08)
				var p := center + Vector3(_rng.randf_range(-0.5, 0.5) * size.x, 0.0, _rng.randf_range(-0.5, 0.5) * size.z) * shrink
				p.y = y
				_b.box(p, s, _mat.rubble if i % 3 == 0 else _mat.ashlar, 2.0, false, _rng.randf() * PI)
		# Балки перекрытий торчат из кучи наискось
		var beams := clampi(int(size.x * size.z / 3.0), 2, 6)
		for i in beams:
			var p := center + Vector3(_rng.randf_range(-0.35, 0.35) * size.x, _rng.randf_range(1.6, 2.4), _rng.randf_range(-0.35, 0.35) * size.z)
			var basis := Basis(Vector3.UP, _rng.randf() * PI) * Basis(Vector3.RIGHT, _rng.randf_range(0.5, 1.1))
			_b.add_mesh(PsxMesh.box(Vector3(0.22, 0.18, _rng.randf_range(2.6, 3.6)), 1.0, 1.0), Transform3D(basis, p), _mat.wood)


func _build_shops() -> void:
	var shop: Dictionary = _cfg.shop
	for comp: Array in _components("S"):
		var lo: Vector2i = comp[0]
		var hi: Vector2i = comp[1]
		var depth := float(hi.x - lo.x + 1)
		var rows := hi.y - lo.y + 1
		var count := maxi(1, floori(rows / shop.width))
		var unit := float(rows) / count
		var mesh := PsxMesh.arch_block(unit, shop.height, depth, shop.span, shop.spring, 4.0, 1.0)
		var rot := Basis(Vector3.UP, PI * 0.5)
		for i in count:
			var zc := z0 + lo.y + unit * (i + 0.5)
			var g := ground[clampi(lo.y + int(unit * (i + 0.5)), 0, h - 1)]
			_b.mesh_with_trimesh(mesh, Transform3D(rot, Vector3(x0 + lo.x + depth * 0.5, g - 0.05, zc)), _mat.ashlar)
			var cx := x0 + lo.x + 0.2
			_b.box_between(Vector3(cx, g, zc - shop.span * 0.5), Vector3(cx + shop.counter_depth, g + shop.counter_height, zc),
				_mat.wood, 1.0, true)
