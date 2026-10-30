class_name QuarterProps
extends RefCounted
## Плотная «обжитая» расстановка предметов PropLibrary по кварталу (QuarterBuilder):
##  • комнаты — по типу из ROOMS (жилая, кладовая, кухня, мастерская, подвал);
##  • дворы — цистерна, печь, жернова, дерево или лоза, бельё, кувшины;
##  • переулки — вещи у стен, ветви и черепки на земле, трещины, травы и ставни на стенах, бельё поперёк;
##  • вручную — PROPS (рынок, пост стражи, тела, римское снаряжение вдоль главной дороги),
##    WALL_PROPS (на стенах: горящие ниши вдоль главной дороги) и PLAZA_PROPS (площадь).
## У предметов с огнём (KINDS: glow) огоньки уходят в Glows.
## Ничего крупного не ставится на проход: в дверях, на лестницах, у их концов и в узких щелях — только плоское.
## Плотность — PROP_DENSITY в файле данных.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ALLEY_WALL := ["jar_small", "jar_small", "jar_large", "basket", "sack", "crate", "rubble_block", "jug", "mat_rolled",
	"stone_vessel", "rope_coil", "basket", "jar_large"]
const ALLEY_FLOOR := ["palm_branch", "palm_branch", "palm_branch", "shards", "shards", "sandals", "cloak", "fruit", "bread"]
const WALL_DECOR := ["crack", "crack", "herbs", "lamp_niche"]

var _q: QuarterBuilder
var _b: LevelBuilder
var _glows: Glows
var _d: Dictionary
var _rng := RandomNumberGenerator.new()
var _mat: Material
## Клетки, где ничего с коллизией ставить нельзя (двери, лестницы и их концы, своды, мостки).
var _keep_clear := {}
## Клетки, уже занятые крупным предметом.
var _used := {}
## false — ставить только предметы без коллизии (проходные комнаты).
var _solid_ok := true


func _init(quarter: QuarterBuilder, builder: LevelBuilder, density: Dictionary, glows: Glows) -> void:
	_q = quarter
	_b = builder
	_glows = glows
	_d = density
	_rng.seed = int(density.get("seed", 7))
	_mat = PropLibrary.material()


func build(rooms: Array, explicit: Array, on_walls: Array = []) -> void:
	_b.local = true
	_mark_clear()
	_furnish_rooms(rooms)
	_furnish_courts()
	_furnish_alleys()
	for e in explicit:
		var c: int = e[1]
		var r: int = e[2]
		var p := _q.cell_center(c, r) + Vector3(e[4] if e.size() > 4 else 0.0, e[6] if e.size() > 6 else 0.0,
			e[5] if e.size() > 5 else 0.0)
		place(e[0], p, deg_to_rad(e[3]), _q.cell(c, r) in QuarterBuilder.INDOOR)
	for e in on_walls:
		var d: Vector2i = {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}[e[3]]
		var c: int = e[1]
		var r: int = e[2]
		if not _is_wall(_q.cell(c + d.x, r + d.y)):
			push_warning("WALL_PROPS: у клетки (%d, %d) со стороны %s нет стены" % [c, r, e[3]])
		place(e[0], _at_wall(c, r, d, 0.0), _yaw_from_wall(d), _q.cell(c, r) in QuarterBuilder.INDOOR)
	_b.local = false
	_b.layer = 1


## Поставить предмет: MultiMesh для частых, иначе в общий пакет; коллизия — коробка по KINDS.
func place(kind: String, pos: Vector3, yaw: float, indoor: bool = false) -> void:
	var inf := PropLibrary.info(kind)
	if not _solid_ok and inf.get("collide", Vector3.ZERO) != Vector3.ZERO:
		kind = "jar_small" if kind != "loom" else "basket"
		inf = PropLibrary.info(kind)
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	_b.layer = LevelBuilder.INTERIOR_LAYER if indoor else 1
	if inf.get("mm", false):
		_b.add_instance(PropLibrary.mesh(kind), xf, _mat)
	else:
		_b.add_mesh(PropLibrary.mesh(kind), xf, _mat)
	var size: Vector3 = inf.get("collide", Vector3.ZERO)
	if size != Vector3.ZERO:
		_b.collision_box(Transform3D(xf.basis, pos + Vector3.UP * size.y * 0.5), size)
	for g: Array in inf.get("glow", []):
		var far: bool = g.size() > 3 and g[3]
		_glows.add(xf * (g[0] as Vector3), g[1], Glows.Kind.FAR if far else Glows.Kind.NEAR, Glows.FIRE, g[2])
	_b.layer = 1


func _mark_clear() -> void:
	for r in _q.h:
		for c in _q.w:
			var k := _q.cell(c, r)
			if k in QuarterBuilder.DOORS or k in "/\\=bmM":
				_keep_clear[Vector2i(c, r)] = true
				for d: Vector2i in DIRS:
					_keep_clear[Vector2i(c, r) + d] = true


## Рядом (в 8 соседях) дверь, лестница или свод — крупное сюда не ставить.
func _near_clear(p: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var n := p + Vector2i(dx, dy)
			var k := _q.cell(n.x, n.y)
			if k in QuarterBuilder.DOORS or k in "/\\=b":
				return true
	return false


func _is_wall(k: String) -> bool:
	return k in QuarterBuilder.WALLS or k == " "


## Стены вокруг клетки (направления к ним), без дверей.
func _walls_around(c: int, r: int) -> Array:
	var out := []
	for d: Vector2i in DIRS:
		if _is_wall(_q.cell(c + d.x, r + d.y)):
			out.append(d)
	return out


## У стены: точка на полу у стены d, на offset от неё; along — сдвиг вдоль стены.
func _at_wall(c: int, r: int, d: Vector2i, offset: float, along: float = 0.0) -> Vector3:
	var p := _q.cell_center(c, r)
	var side := Vector3(d.y, 0, d.x)
	return p + Vector3(d.x, 0, d.y) * (0.5 - offset) + side * along


## Поворот предмета, который смотрит от стены d (локальная −Z — в сторону клетки).
static func _yaw_from_wall(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y))


func _pick(list: Array) -> String:
	return list[_rng.randi() % list.size()]


# ─── Комнаты ─────────────────────────────────────────────────────────────────

func _furnish_rooms(rooms: Array) -> void:
	var types := {}
	for e in rooms:
		types[Vector2i(e[0], e[1])] = e[2]
	var seen := {}
	for r in _q.h:
		for c in _q.w:
			var k := _q.cell(c, r)
			if (k != "_" and k != ":" and k != "m") or seen.has(Vector2i(c, r)):
				continue
			var cells := _flood(c, r, k, seen)
			if not _reachable(cells):
				continue
			var kind := "storage" if cells.size() <= 6 else "living"
			if k == "m":
				kind = "basement"
			for p: Vector2i in cells:
				if types.has(p):
					kind = types[p]
			var doors := _door_count(cells)
			_furnish_room(cells, kind, doors <= 1)
	_solid_ok = true


func _flood(c: int, r: int, k: String, seen: Dictionary) -> Array:
	var out := []
	var q: Array[Vector2i] = [Vector2i(c, r)]
	seen[Vector2i(c, r)] = true
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		out.append(p)
		for d: Vector2i in DIRS:
			var n: Vector2i = p + d
			if not seen.has(n) and _q.cell(n.x, n.y) == k:
				seen[n] = true
				q.append(n)
	return out


## В комнату можно войти (есть открытая/приоткрытая/выбитая дверь или открытый край во двор).
func _reachable(cells: Array) -> bool:
	for p: Vector2i in cells:
		for d: Vector2i in DIRS:
			var k := _q.cell(p.x + d.x, p.y + d.y)
			if k in "dxo,.+\\" or (k == "_" and _q.cell(p.x, p.y) == "m"):
				return true
	return _q.cell(cells[0].x, cells[0].y) == "m"


func _door_count(cells: Array) -> int:
	var n := 0
	for p: Vector2i in cells:
		for d: Vector2i in DIRS:
			var k := _q.cell(p.x + d.x, p.y + d.y)
			if k in "dxo" or k in ",.+":
				n += 1
	return n


func _furnish_room(cells: Array, kind: String, dead_end: bool) -> void:
	# Через проходную комнату идёт путь: там только то, через что можно пройти
	_solid_ok = dead_end
	var edge := []
	var inner := []
	for p: Vector2i in cells:
		if _keep_clear.has(p) or _q.cell(p.x, p.y) == "M":
			continue
		var ws := _walls_around(p.x, p.y)
		if ws.is_empty():
			inner.append(p)
		else:
			edge.append([p, ws])
	edge.shuffle()
	var niches := 0
	for e in edge:
		var p: Vector2i = e[0]
		var d: Vector2i = e[1][_rng.randi() % (e[1] as Array).size()]
		var yaw := _yaw_from_wall(d)
		# Ниши со светильниками — в каждой комнате по одной-две
		if niches < 2 and _rng.randf() < 0.5:
			place("lamp_niche", _at_wall(p.x, p.y, d, 0.0), yaw, true)
			niches += 1
		var items: Array
		match kind:
			"storage", "basement":
				items = ["jar_large", "jar_large", "sack", "jar_small", "basket", "jar_large", "stone_vessel"]
			"kitchen":
				items = ["oven", "quern", "jar_small", "basket", "jug", "jar_large", "sack"]
			"workshop":
				items = ["loom", "basket", "jar_small", "rope_coil", "stool"]
			"hall":
				items = ["mat_rolled", "jar_small", "basket", "stone_vessel"]
			_:
				items = ["mat_rolled", "jar_small", "basket", "jug", "stone_vessel", "loom", "herbs"]
		if _rng.randf() < 0.85:
			var it: String = _pick(items)
			if it in ["oven", "loom"]:
				if _used.has(it + str(cells[0])):
					it = "jar_small"
				_used[it + str(cells[0])] = true
			if PropLibrary.info(it).get("wall", false):
				place(it, _at_wall(p.x, p.y, d, 0.0), yaw, true)
			else:
				place(it, _at_wall(p.x, p.y, d, 0.35, _rng.randf_range(-0.2, 0.2)), yaw + _rng.randf_range(-0.3, 0.3), true)
		if kind in ["storage", "basement"] and _rng.randf() < 0.5:
			place("jar_small", _at_wall(p.x, p.y, d, 0.7, _rng.randf_range(-0.3, 0.3)), _rng.randf() * TAU, true)
	# Середина комнаты: циновки, столик и табуреты (только в тупиковых комнатах — не на проходе)
	if kind in ["living", "workshop", "kitchen"] and not inner.is_empty():
		var p: Vector2i = inner[_rng.randi() % inner.size()]
		var center := _q.cell_center(p.x, p.y)
		place("mat", center + Vector3(0, 0.005, 0), _rng.randf() * PI, true)
		if dead_end:
			place("table_low", center, _rng.randf_range(-0.2, 0.2), true)
			place("stool", center + Vector3(0.7, 0, 0.1), _rng.randf() * TAU, true)
			place("stool", center + Vector3(-0.7, 0, -0.1), _rng.randf() * TAU, true)
			place("bread", center + Vector3(0.15, 0.39, 0.05), 0.0, true)
			place("jug", center + Vector3(-0.2, 0.39, 0), 0.0, true)


# ─── Дворы ───────────────────────────────────────────────────────────────────

func _furnish_courts() -> void:
	var seen := {}
	for r in _q.h:
		for c in _q.w:
			if _q.cell(c, r) != "," or seen.has(Vector2i(c, r)):
				continue
			var cells := _flood(c, r, ",", seen)
			var edge := []
			var corners := []
			for p: Vector2i in cells:
				if _keep_clear.has(p):
					continue
				var ws := _walls_around(p.x, p.y)
				if ws.size() >= 2 and not _near_clear(p):
					corners.append([p, ws])
				elif ws.size() == 1:
					edge.append([p, ws])
			corners.shuffle()
			edge.shuffle()
			# Крупное — по углам: цистерна, дерево или лоза, печь
			var big := ["cistern", "olive_tree" if cells.size() >= 25 else "quern", "oven", "fig_tree"]
			if cells.size() < 16:
				big = ["quern", "jar_large"]
			if cells.size() >= 30:
				big.append("pergola")
			var bi := 0
			for e in corners:
				if bi >= big.size() or bi >= 3:
					break
				var p: Vector2i = e[0]
				var ws: Array = e[1]
				var d1: Vector2i = ws[0]
				var d2: Vector2i = ws[1]
				var kind: String = big[bi]
				var off := 0.75 if kind in ["olive_tree", "fig_tree", "pergola", "cistern"] else 0.45
				var pos := _q.cell_center(p.x, p.y) + Vector3(d1.x + d2.x, 0, d1.y + d2.y) * (0.5 - off)
				place(kind, pos, _yaw_from_wall(d1), false)
				_used[p] = true
				bi += 1
			# У стен — жернова, кувшины, корзины, бельё
			for e in edge:
				if _used.has(e[0]) or _rng.randf() > _d.get("court", 0.6):
					continue
				var p: Vector2i = e[0]
				var d: Vector2i = e[1][0]
				var it: String = _pick(["quern", "jar_large", "jar_small", "basket", "jug", "sack", "mat_rolled", "herbs", "lamp_niche"])
				if PropLibrary.info(it).get("wall", false):
					place(it, _at_wall(p.x, p.y, d, 0.0), _yaw_from_wall(d))
				else:
					place(it, _at_wall(p.x, p.y, d, 0.35, _rng.randf_range(-0.25, 0.25)), _rng.randf() * TAU)


# ─── Переулки ────────────────────────────────────────────────────────────────

## Ширина прохода поперёк стены d (сколько открытых клеток подряд).
func _width_across(c: int, r: int, d: Vector2i) -> int:
	var n := 1
	var p := Vector2i(c, r) - d
	while n < 4 and not _is_wall(_q.cell(p.x, p.y)) and _q.cell(p.x, p.y) != " ":
		n += 1
		p -= d
	return n


func _furnish_alleys() -> void:
	var p_wall: float = _d.get("alley_wall", 0.35)
	var p_floor: float = _d.get("alley_floor", 0.18)
	var p_decor: float = _d.get("wall_decor", 0.25)
	var p_laundry: float = _d.get("laundry", 0.06)
	for r in _q.h:
		for c in _q.w:
			var k := _q.cell(c, r)
			if k != "." and k != "*" and k != "+":
				continue
			var cell := Vector2i(c, r)
			var clear := _keep_clear.has(cell)
			var center := _q.cell_center(c, r)
			if k == "*":
				# Вокруг завала — разлетевшиеся камни
				for i in 2:
					place("rubble_block", center + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)), _rng.randf() * TAU)
				continue
			var ws := _walls_around(c, r)
			# Главная дорога — чище переулков: только трещины и ниши на стенах (вещи на ней — вручную)
			if k == "+":
				for d: Vector2i in ws:
					if _rng.randf() < p_decor * 0.5:
						place(_pick(["crack", "crack", "lamp_niche"]), _at_wall(c, r, d, 0.0, _rng.randf_range(-0.25, 0.25)), _yaw_from_wall(d))
				continue
			for d: Vector2i in ws:
				var width := _width_across(c, r, d)
				var yaw := _yaw_from_wall(d)
				# Вещи у стены: крупные — только где проход не уже 2 м и не у дверей и лестниц
				if _rng.randf() < p_wall:
					var it: String = _pick(ALLEY_WALL)
					if PropLibrary.info(it).get("collide", Vector3.ZERO) != Vector3.ZERO and (width < 2 or clear):
						it = _pick(["jar_small", "palm_branch", "shards", "jug"])
					place(it, _at_wall(c, r, d, 0.3, _rng.randf_range(-0.3, 0.3)), yaw + _rng.randf_range(-0.6, 0.6))
				# На стене: трещины, травы, ниши; на двухэтажных — ставни
				if _rng.randf() < p_decor:
					var dec: String = _pick(WALL_DECOR)
					place(dec, _at_wall(c, r, d, 0.0, _rng.randf_range(-0.25, 0.25)), yaw)
				if _q.cell(c + d.x, r + d.y) == "%" and _rng.randf() < p_decor * 0.6:
					place("shutter", _at_wall(c, r, d, 0.0), yaw)
			# На земле: пальмовые ветви, черепки, брошенное
			if _rng.randf() < p_floor:
				var it: String = _pick(ALLEY_FLOOR)
				if it == "fruit":
					for i in 4:
						place("fruit", center + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)), _rng.randf() * TAU)
				else:
					place(it, center + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)), _rng.randf() * TAU)
			# Бельё поперёк переулка шириной 2 м, на высоте 2,7 м
			if ws.size() == 1 and _rng.randf() < p_laundry:
				var d: Vector2i = ws[0]
				if _width_across(c, r, d) == 2:
					var mid := _q.cell_center(c, r) - Vector3(d.x, 0, d.y) * 0.5 + Vector3.UP * 2.7
					place("laundry", mid, _yaw_from_wall(d))
