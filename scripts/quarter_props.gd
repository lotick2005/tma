class_name QuarterProps
extends RefCounted
## Расстановка предметов PropLibrary по кварталу (QuarterBuilder). Набор зависит от места:
##  • комнаты — по типу из ROOMS (жилая бедная, спальня богатая, кухня, кладовая, подвал);
##    тип manual — ничего само, всё вручную (уникальные места: гончарня, трапеза, молельня, разорённый дом);
##  • дворы — цистерна, печь или жернова, дерево, кувшин, корзина (тип manual — вручную);
##  • переулки — немного вещей у стен, черепки и камни на земле, бельё поперёк; главная дорога — чище;
##  • фасады — по отделке дома (QuarterBuilder.wall_style): у богатых (white) решётки на окнах, балконы-горницы,
##    синие и красные навесы; у бедных — ставни, охряные навесы с пучками трав;
##  • вручную — PROPS (рынок, пост стражи, тела, пустая одежда, кровь, римское снаряжение вдоль главной дороги),
##    WALL_PROPS (на стенах: горящие ниши, брызги крови, наружные лестницы) и PLAZA_PROPS (площадь).
## У предметов с огнём (KINDS: glow, smoke) огоньки и дым уходят в Glows.
## Ничего крупного не ставится на проход: в дверях, на лестницах, у их концов и в узких щелях — только плоское.
## Плотность — PROP_DENSITY в файле данных.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SIDES := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}
## У стен переулка: вещей с коллизией мало, кувшинов немного.
const ALLEY_WALL := ["basket", "sack", "rubble_block", "jar_small", "rope_coil", "crate", "stone_vessel", "jar_large"]
## На земле переулка: черепки, камни, брошенное.
const ALLEY_FLOOR := ["shards", "shards", "rubble_block", "sandals", "basket"]
## Что ставить в комнате каждого типа: «у стены» по очереди, «на середину» — по одному.
const ROOM_SETS := {
	"living": {"wall": ["mattress", "mat_rolled", "basket", "jug", "mattress", "jar_small", "pillow"], "mid": ["mat"]},
	"bedroom": {"wall": ["bed", "chest", "jar_large", "stool", "cushion"], "mid": ["table"]},
	"kitchen": {"wall": ["oven", "quern", "jar_large", "basket", "sack", "jug"], "mid": ["table"]},
	"storage": {"wall": ["jar_large", "sack", "jar_large", "basket", "stone_vessel", "sack"], "mid": []},
	"basement": {"wall": ["jar_large", "sack", "jar_large"], "mid": []},
	"hall": {"wall": ["mat_rolled", "basket"], "mid": []},
}

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
## Тип помещения по клетке (из ROOMS).
var _types := {}
## Клетки стен, на которых уже есть балкон, окно или навес (чтобы не лепить вплотную).
var _facade_used := {}


func _init(quarter: QuarterBuilder, builder: LevelBuilder, density: Dictionary, glows: Glows) -> void:
	_q = quarter
	_b = builder
	_glows = glows
	_d = density
	_rng.seed = int(density.get("seed", 7))
	_mat = PropLibrary.material()


func build(rooms: Array, explicit: Array, on_walls: Array = []) -> void:
	_b.local = true
	for e in rooms:
		_types[Vector2i(e[0], e[1])] = e[2]
	_mark_clear()
	_furnish_rooms()
	_furnish_courts()
	_furnish_alleys()
	_furnish_facades()
	for e in explicit:
		var c: int = e[1]
		var r: int = e[2]
		var p := _q.cell_center(c, r) + Vector3(e[4] if e.size() > 4 else 0.0, e[6] if e.size() > 6 else 0.0,
			e[5] if e.size() > 5 else 0.0)
		place(e[0], p, deg_to_rad(e[3]), _q.cell(c, r) in QuarterBuilder.INDOOR)
	for e in on_walls:
		var d: Vector2i = SIDES[e[3]]
		var c: int = e[1]
		var r: int = e[2]
		if not _is_wall(_q.cell(c + d.x, r + d.y)):
			push_warning("WALL_PROPS: у клетки (%d, %d) со стороны %s нет стены" % [c, r, e[3]])
		var along: float = e[4] if e.size() > 4 else 0.0
		place(e[0], _at_wall(c, r, d, 0.0, along), _yaw_from_wall(d), _q.cell(c, r) in QuarterBuilder.INDOOR)
	_b.local = false
	_b.layer = 1


## Поставить предмет: MultiMesh для частых, иначе в общий пакет; коллизия — коробка по KINDS.
func place(kind: String, pos: Vector3, yaw: float, indoor: bool = false) -> void:
	var inf := PropLibrary.info(kind)
	if not _solid_ok and inf.get("collide", Vector3.ZERO) != Vector3.ZERO:
		kind = "basket"
		inf = PropLibrary.info(kind)
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	_b.layer = LevelBuilder.INTERIOR_LAYER if indoor else 1
	if inf.get("mm", false):
		_b.add_instance(PropLibrary.mesh(kind), xf, _mat)
	else:
		_b.add_mesh(PropLibrary.mesh(kind), xf, _mat)
	var size: Vector3 = inf.get("collide", Vector3.ZERO)
	if size != Vector3.ZERO:
		var at: Vector3 = inf.get("collide_at", Vector3.ZERO)
		_b.collision_box(Transform3D(xf.basis, pos + xf.basis * at + Vector3.UP * size.y * 0.5), size)
	for g: Array in inf.get("glow", []):
		var far: bool = g.size() > 3 and g[3]
		_glows.add(xf * (g[0] as Vector3), g[1], Glows.Kind.FAR if far else Glows.Kind.NEAR, Glows.FIRE, g[2])
	for sm: Array in inf.get("smoke", []):
		_glows.add_smoke(xf * (sm[0] as Vector3), sm[1])
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


## Тип помещения из ROOMS по любой его клетке.
func _type_of(cells: Array, fallback: String) -> String:
	for p: Vector2i in cells:
		if _types.has(p):
			return _types[p]
	return fallback


# ─── Комнаты ─────────────────────────────────────────────────────────────────

func _furnish_rooms() -> void:
	var seen := {}
	for r in _q.h:
		for c in _q.w:
			var k := _q.cell(c, r)
			if (k != "_" and k != ":" and k != "m") or seen.has(Vector2i(c, r)):
				continue
			var cells := _flood(c, r, k, seen)
			if not _reachable(cells):
				continue
			var kind := _type_of(cells, "basement" if k == "m" else ("storage" if cells.size() <= 12 else "living"))
			if kind == "manual":
				continue
			_furnish_room(cells, kind, _door_count(cells) <= 1)
	_solid_ok = true


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
	var set: Dictionary = ROOM_SETS.get(kind, ROOM_SETS.living)
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
	# Одна ниша со светильником на комнату, иногда горящим
	if not edge.is_empty() and kind != "basement":
		var e: Array = edge[0]
		var d: Vector2i = e[1][0]
		place("lamp_niche_lit" if _rng.randf() < 0.35 else "lamp_niche", _at_wall(e[0].x, e[0].y, d, 0.0), _yaw_from_wall(d), true)
	var items: Array = set.wall
	for i in mini(items.size(), edge.size()):
		var e: Array = edge[i]
		var p: Vector2i = e[0]
		var d: Vector2i = e[1][_rng.randi() % (e[1] as Array).size()]
		var it: String = items[i]
		var yaw := _yaw_from_wall(d)
		# Тюфяк и ложе — вдоль стены, остальное — у стены лицом в комнату
		if it in ["mattress", "bed"]:
			var along := Vector3(d.y, 0, d.x)
			place(it, _at_wall(p.x, p.y, d, 0.45), atan2(along.x, along.z), true)
		else:
			place(it, _at_wall(p.x, p.y, d, 0.35, _rng.randf_range(-0.2, 0.2)), yaw + _rng.randf_range(-0.3, 0.3), true)
	if not inner.is_empty():
		for it: String in set.mid:
			var p: Vector2i = inner[_rng.randi() % inner.size()]
			var center := _q.cell_center(p.x, p.y)
			place(it, center, _rng.randf_range(-0.2, 0.2), true)
			if it == "table":
				place("stool", center + Vector3(0.75, 0, 0.1), _rng.randf() * TAU, true)
				place("jug", center + Vector3(-0.2, 0.705, 0), 0.0, true)
				place("bread", center + Vector3(0.2, 0.705, 0.05), 0.0, true)


# ─── Дворы ───────────────────────────────────────────────────────────────────

func _furnish_courts() -> void:
	var seen := {}
	for r in _q.h:
		for c in _q.w:
			if _q.cell(c, r) != "," or seen.has(Vector2i(c, r)):
				continue
			var cells := _flood(c, r, ",", seen)
			if _type_of(cells, "") == "manual":
				continue
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
			# Крупное — по углам: цистерна, дерево или жернова, печь
			var big := ["cistern", "fig_tree" if cells.size() >= 25 else "quern", "oven"]
			for i in mini(big.size(), corners.size()):
				var p: Vector2i = corners[i][0]
				var ws: Array = corners[i][1]
				var d1: Vector2i = ws[0]
				var d2: Vector2i = ws[1]
				var kind: String = big[i]
				var off := 0.75 if kind in ["fig_tree", "cistern"] else 0.45
				place(kind, _q.cell_center(p.x, p.y) + Vector3(d1.x + d2.x, 0, d1.y + d2.y) * (0.5 - off), _yaw_from_wall(d1))
				_used[p] = true
			# У стен — немного: кувшин, корзина, жернова, циновка
			for e in edge:
				if _used.has(e[0]) or _rng.randf() > _d.get("court", 0.3):
					continue
				var p: Vector2i = e[0]
				var d: Vector2i = e[1][0]
				var it: String = _pick(["jar_large", "basket", "quern", "mat_rolled", "jug", "sack"])
				place(it, _at_wall(p.x, p.y, d, 0.35, _rng.randf_range(-0.25, 0.25)), _rng.randf() * TAU)


# ─── Переулки и главная дорога ───────────────────────────────────────────────

## Ширина прохода поперёк стены d (сколько открытых клеток подряд).
func _width_across(c: int, r: int, d: Vector2i) -> int:
	var n := 1
	var p := Vector2i(c, r) - d
	while n < 4 and not _is_wall(_q.cell(p.x, p.y)) and _q.cell(p.x, p.y) != " ":
		n += 1
		p -= d
	return n


func _furnish_alleys() -> void:
	var p_wall: float = _d.get("alley_wall", 0.2)
	var p_floor: float = _d.get("alley_floor", 0.1)
	var p_decor: float = _d.get("wall_decor", 0.15)
	var p_laundry: float = _d.get("laundry", 0.07)
	for r in _q.h:
		for c in _q.w:
			var k := _q.cell(c, r)
			if k != "." and k != "*" and k != "+":
				continue
			var cell := Vector2i(c, r)
			var clear := _keep_clear.has(cell)
			var center := _q.cell_center(c, r)
			if k == "*":
				# Вокруг завала — разлетевшиеся камни (без коллизии)
				for i in 2:
					place("rubble_block", center + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)), _rng.randf() * TAU)
				continue
			var ws := _walls_around(c, r)
			# Главная дорога чище: только трещины на стенах (вещи на ней — вручную)
			if k == "+":
				for d: Vector2i in ws:
					if _rng.randf() < p_decor * 0.4:
						place("crack", _at_wall(c, r, d, 0.0, _rng.randf_range(-0.25, 0.25)), _yaw_from_wall(d))
				continue
			for d: Vector2i in ws:
				var width := _width_across(c, r, d)
				var yaw := _yaw_from_wall(d)
				if _rng.randf() < p_wall:
					var it: String = _pick(ALLEY_WALL)
					if PropLibrary.info(it).get("collide", Vector3.ZERO) != Vector3.ZERO and (width < 2 or clear):
						it = _pick(["shards", "rubble_block", "basket"])
					place(it, _at_wall(c, r, d, 0.3, _rng.randf_range(-0.3, 0.3)), yaw + _rng.randf_range(-0.6, 0.6))
				if _rng.randf() < p_decor:
					place("crack", _at_wall(c, r, d, 0.0, _rng.randf_range(-0.25, 0.25)), yaw)
			if _rng.randf() < p_floor:
				place(_pick(ALLEY_FLOOR), center + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)), _rng.randf() * TAU)
			# Бельё поперёк переулка шириной 2 м, на высоте 2,7 м
			if ws.size() == 1 and _rng.randf() < p_laundry:
				var d: Vector2i = ws[0]
				if _width_across(c, r, d) == 2:
					var mid := _q.cell_center(c, r) - Vector3(d.x, 0, d.y) * 0.5 + Vector3.UP * 2.7
					place("laundry", mid, _yaw_from_wall(d))


# ─── Фасады ──────────────────────────────────────────────────────────────────

## Окна, балконы и навесы на стенах вдоль улиц и дворов — по отделке дома: богатый (white) или бедный.
func _furnish_facades() -> void:
	var p_window: float = _d.get("windows", 0.16)
	for r in _q.h:
		for c in _q.w:
			if _q.cell(c, r) not in ".+,":
				continue
			for d: Vector2i in DIRS:
				var wc := Vector2i(c + d.x, r + d.y)
				var wk := _q.cell(wc.x, wc.y)
				var yaw := _yaw_from_wall(d)
				var rich := _q.wall_style(wc.x, wc.y) == "white"
				# Над дверью — навес (у бедных охряный и пучки трав под ним)
				if wk in QuarterBuilder.DOORS and not _facade_used.has(wc) and _rng.randf() < 0.6:
					var at := _at_wall(c, r, d, 0.0)
					if rich:
						place(_pick(["awning_blue", "awning_red"]), at, yaw)
					else:
						place("awning_ochre", at, yaw)
						place("herbs", at + Vector3(d.y, 0, d.x) * 0.85, yaw)
					_mark_facade(wc, d)
					continue
				if wk != "%" or _facade_used.has(wc):
					continue
				if rich and _rng.randf() < 0.04 and _width_across(c, r, d) >= 2:
					place("balcony", _at_wall(c, r, d, 0.0), yaw)
					_mark_facade(wc, d, 2)
				elif _rng.randf() < p_window:
					place("window_grille" if rich else "shutter", _at_wall(c, r, d, 0.0), yaw)
					_mark_facade(wc, d)


## Пометить клетки стены (и соседей вдоль неё), чтобы следующее украшение не встало вплотную.
func _mark_facade(wc: Vector2i, d: Vector2i, spread: int = 1) -> void:
	var along := Vector2i(d.y, d.x)
	for i in range(-spread, spread + 1):
		_facade_used[wc + along * i] = true
