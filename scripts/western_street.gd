extends Node3D
## Уровень 1 «Западная улица» (блокаут): от площади A у арки Робинсона через жилой квартал
## западнее Западной стены (долина Тиропеон) до ворот Антонии. Во тьме.
## Все координаты и размеры — в res://data/level_1_western_street.gd; здесь только сборка.
## Точки карты в игру переводит WorldCoords (k применяется только там); квартал строит QuarterBuilder.

## Герой вошёл в триггер за воротами Антонии.
signal level_finished

const D := preload("res://data/level_1_western_street.gd")
## Насколько низ построек уходит под мостовую, м: чтобы на уклоне не было щелей.
const SINK := 0.3
## Тонкие жерди лесов не режем на ячейки по 1 м: текстура на них почти не плывёт.
const THIN_CELL := 4.0
## Дальность «местной» геометрии (квартал, предметы): во тьме дальше тумана рисовать незачем.
const DETAIL_RANGE_DARK := 36.0
const DETAIL_RANGE_DAY := 70.0

## Пресеты освещения: «тьма» — вся игра, «день» — вступление (этап 4). Переключатель — в панели (0).
@export var darkness: LightingPreset
@export var day: LightingPreset

var _b: LevelBuilder
var _quarter: QuarterBuilder
var _glows := Glows.new()
var _m := {}
## Y верха стены Храмовой горы (платформы) в игре.
var _wall_top := 0.0
## Y мостовой площади A.
var _plaza_y := 0.0
var _finished := false
var _is_day := false

@onready var _player: Player = $Player
@onready var _geometry: Node3D = $Geometry
@onready var _sky: DarkSky = $DarkSky


func _ready() -> void:
	GameState.current_level = "level_1"
	_make_materials()
	_plaza_y = WorldCoords.gy(D.PLAZA.h)
	_wall_top = _plaza_y + D.TEMPLE_WALL.height
	_b = LevelBuilder.new(_geometry)
	var q: Dictionary = D.QUARTER.duplicate()
	q.shop = D.SHOP
	q.crown = D.WILSON_ARCH.crown
	q.styles = D.HOUSE_STYLES
	_quarter = QuarterBuilder.new(_b, _m, q, D.QUARTER_MAP, D.TERRACES,
		WorldCoords.point(D.QUARTER.x, D.QUARTER.y), _plaza_y, _wall_top)
	_quarter.build()
	var props := QuarterProps.new(_quarter, _b, D.PROP_DENSITY, _glows)
	props.build(D.ROOMS, D.PROPS, D.WALL_PROPS)
	_b.local = true
	for e in D.PLAZA_PROPS:
		var pos := WorldCoords.point(e[1], e[2])
		pos.y = _plaza_y
		props.place(e[0], pos, deg_to_rad(e[3]))
	_b.local = false
	_build_ground()
	_build_temple_mount()
	_build_royal_stoa()
	_build_robinson_arch()
	_build_wilson_causeway()
	_build_houses()
	_build_construction()
	_build_antonia()
	_build_bounds()
	_build_lights()
	_b.commit()
	_glows.commit(_geometry)
	_place_player()
	_apply_lighting()


## Y земли в точке z: в квартале — по террасам, южнее — площадь, севернее — у ворот Антонии.
func _ground_y(z: float) -> float:
	if _quarter == null or z > _quarter.z0 + _quarter.h:
		return _plaza_y
	return _quarter.ground_at_z(z)


# ─── Свет ────────────────────────────────────────────────────────────────────

func _current_preset() -> LightingPreset:
	return day if _is_day else darkness


func _apply_lighting() -> void:
	var preset := _current_preset()
	preset.apply($WorldEnvironment.environment, $Sun, _player.get_node("Head/Camera3D"), _sky,
		1 << (LevelBuilder.INTERIOR_LAYER - 1))
	_b.set_detail_range(DETAIL_RANGE_DAY if _is_day else DETAIL_RANGE_DARK)


## Для отладочной панели: день / тьма.
func toggle_day() -> void:
	_is_day = not _is_day
	_apply_lighting()


func is_day() -> bool:
	return _is_day


func _make_materials() -> void:
	var limestone := Color(0.84, 0.78, 0.64)
	_m.ashlar = PsxMaterial.make(ProcTextures.ashlar(128, 4, limestone, 11))
	_m.slab = PsxMaterial.make(ProcTextures.ashlar(128, 3, Color(0.8, 0.77, 0.68), 12, 0, false, 0.4, 0.9, 0.2, 0.025))
	_m.paving = PsxMaterial.make(ProcTextures.ashlar(64, 2, Color(0.7, 0.66, 0.58), 13, 0, false, 0.25, 0.6, 0.45, 0.05))
	# Главная дорога — крупные светлые плиты; боковые переулки — тёмная мелкая мостовая; водосток — тёмные крышки
	_m.paving_main = PsxMaterial.make(ProcTextures.ashlar(64, 2, Color(0.84, 0.8, 0.7), 15, 0, false, 0.3, 0.7, 0.3, 0.04))
	_m.paving_dark = PsxMaterial.make(ProcTextures.ashlar(64, 4, Color(0.48, 0.45, 0.4), 16, 0, false, 0.25, 0.55, 0.5, 0.06))
	_m.gutter = PsxMaterial.make(ProcTextures.stripes(64, 8, Color(0.2, 0.19, 0.18), Color(0.34, 0.32, 0.3), 17))
	_m.lintel = PsxMaterial.make(ProcTextures.ashlar(64, 2, Color(0.82, 0.78, 0.68), 14, 2, true, 0.4, 0.8, 0.35, 0.04))
	_m.plaster_a = PsxMaterial.make(ProcTextures.plaster(64, Color(0.84, 0.8, 0.7), 21))
	_m.plaster_b = PsxMaterial.make(ProcTextures.plaster(64, Color(0.82, 0.74, 0.64), 22))
	_m.plaster_in = PsxMaterial.make(ProcTextures.plaster(64, Color(0.78, 0.74, 0.66), 23))
	# Белая штукатурка богатых домов и охристая обмазка бедных
	_m.white = PsxMaterial.make(ProcTextures.plaster(64, Color(0.93, 0.92, 0.88), 18))
	_m.ochre = PsxMaterial.make(ProcTextures.plaster(64, Color(0.76, 0.58, 0.36), 19))
	_m.rubble = PsxMaterial.make(ProcTextures.rubble(64, 22, Color(0.7, 0.64, 0.52), Color(0.82, 0.78, 0.7), 24))
	_m.rubble_in = PsxMaterial.make(ProcTextures.rubble(64, 18, Color(0.6, 0.55, 0.46), Color(0.7, 0.66, 0.6), 25))
	_m.earth = PsxMaterial.make(ProcTextures.mottled(64, Color(0.55, 0.45, 0.33), 0.05, 0.1, 26))
	_m.floor = PsxMaterial.make(ProcTextures.mottled(64, Color(0.5, 0.43, 0.34), 0.04, 0.08, 27))
	_m.roof = PsxMaterial.make(ProcTextures.mottled(64, Color(0.68, 0.64, 0.56), 0.04, 0.1, 28))
	_m.ceiling = PsxMaterial.make(ProcTextures.wood(64, 6, Color(0.38, 0.27, 0.17), 29))
	_m.wood = PsxMaterial.make(ProcTextures.wood(64, 4, Color(0.5, 0.36, 0.22), 31))
	_m.door = PsxMaterial.make(ProcTextures.gate_door(64, Color(0.46, 0.32, 0.19), Color(0.36, 0.26, 0.17), 2, 32))
	_m.cedar = PsxMaterial.make(ProcTextures.wood(64, 8, Color(0.42, 0.27, 0.16), 32))
	_m.column = PsxMaterial.make(ProcTextures.mottled(64, Color(0.93, 0.91, 0.86), 0.03, 0.05, 41))
	_m.gate = PsxMaterial.make(ProcTextures.gate_door(64, Color(0.42, 0.28, 0.16), Color(0.66, 0.47, 0.2), 3, 51))
	_m.water = PsxMaterial.make(null, Color(0.08, 0.12, 0.13))


## ─── Мостовая площади и у ворот ──────────────────────────────────────────────
func _build_ground() -> void:
	var p: Dictionary = D.PLAZA
	var flat := func(_x: float, _z: float) -> float: return _plaza_y
	# Площадь A (под аркой и южнее), на восток — вдоль Южной стены
	var z_n := WorldCoords.gz(p.y_north)
	var z_s := WorldCoords.gz(p.y_south) + 2.0
	_terrain(-17.5, 0.5, z_s, z_n, flat)
	_terrain(0.5, WorldCoords.gx(p.x_east) + 2.0, z_s, WorldCoords.gz(D.TEMPLE_WALL.y_south) - 0.5, flat)
	# У ворот Антонии и за ними — на уровне северной террасы
	var top := _quarter.ground[0]
	var gate_flat := func(_x: float, _z: float) -> float: return top
	_terrain(WorldCoords.gx(D.ANTONIA_GATE.x_west), 0.5, _quarter.z0 + 0.5, WorldCoords.gz(520.0), gate_flat)


## Рельеф кусками по 20 м: каждый кусок — свой пакет, чтобы камера отсекала дальние.
func _terrain(x0: float, x1: float, z_south: float, z_north: float, height_at: Callable) -> void:
	var z := z_south
	while z > z_north + 0.01:
		var z_next := maxf(z - 20.0, z_north)
		var mesh := PsxMesh.terrain(x0, x1, z, z_next, height_at, 4.0, _b.cell)
		_b.mesh_with_trimesh(mesh, Transform3D(), _m.paving, false)
		z = z_next


## ─── Храмовая гора: Западная и Южная стены ───────────────────────────────────
func _build_temple_mount() -> void:
	var w: Dictionary = D.TEMPLE_WALL
	var bottom := _plaza_y - 2.0
	var z_sw := WorldCoords.gz(w.y_south)
	var z_nw := WorldCoords.gz(w.y_north)
	var t: float = w.thickness
	# Южная стена от ЮЗ угла на восток; Западная — от неё на север (стык без двойных граней)
	_b.box_between(Vector3(0.0, bottom, z_sw), Vector3(WorldCoords.gx(w.x_east), _wall_top, z_sw - t),
		_m.ashlar, 4.0, true, PsxMesh.FACE_NORTH | PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP, 2.0)
	_b.box_between(Vector3(0.0, bottom, z_sw - t), Vector3(t, _wall_top, z_nw),
		_m.ashlar, 4.0, true, PsxMesh.FACE_EAST | PsxMesh.FACE_SOUTH | PsxMesh.FACE_NORTH | PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP, 2.0)
	# Над платформой: низкий парапет над Царской стоей и задняя стена Западного портика дальше на север
	var stoa_north := z_sw - D.ROYAL_STOA.rows[-1] - 3.0
	var ph: float = w.parapet_height
	_b.box_between(Vector3(0.0, _wall_top, z_sw), Vector3(WorldCoords.gx(w.x_east), _wall_top + ph, z_sw - 0.5),
		_m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM)
	_b.box_between(Vector3(0.0, _wall_top, z_sw - 0.5), Vector3(0.5, _wall_top + ph, stoa_north),
		_m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM)
	_b.box_between(Vector3(0.0, _wall_top, stoa_north), Vector3(w.upper_thickness, _wall_top + w.upper_height, z_nw),
		_m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM | PsxMesh.FACE_NORTH | PsxMesh.FACE_EAST, 2.0)


## ─── Царская стоя: колонны на краю платформы ────────────────────────────────
func _build_royal_stoa() -> void:
	var s: Dictionary = D.ROYAL_STOA
	var z_sw := WorldCoords.gz(D.TEMPLE_WALL.y_south)
	var x0 := WorldCoords.gx(s.x_from)
	var x1 := WorldCoords.gx(s.x_to)
	var top: float = _wall_top + s.column_height
	var x := x0
	while x <= x1:
		for row in s.rows:
			_b.column(Vector3(x, _wall_top, z_sw - row), s.column_radius, s.column_height, _m.column, 10, 2.0, false)
		x += s.step
	var rows: Array = s.rows
	var roof_n: float = z_sw - rows[-1] - 2.0
	_b.box_between(Vector3(x0 - 2.0, top, z_sw - 1.0), Vector3(x1 + 2.0, top + s.roof_thickness, roof_n),
		_m.cedar, 2.0, false, PsxMesh.FACE_TOP, 2.0)
	# Средний неф между вторым и третьим рядом — выше
	_b.box_between(Vector3(x0 - 2.0, top + s.roof_thickness, z_sw - rows[1]),
		Vector3(x1 + 2.0, top + s.roof_thickness + s.nave_raise, z_sw - rows[2]), _m.ashlar, 4.0, false,
		PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP, 2.0)


## ─── Арка Робинсона и лестница на 7 малых арках ─────────────────────────────
func _build_robinson_arch() -> void:
	var a: Dictionary = D.ROBINSON_ARCH
	var zc := WorldCoords.gz(a.y)
	var hw: float = a.width * 0.5
	var sy := _ground_y(zc) - 0.1
	var span: float = a.span
	var pier: float = a.pier
	var deck: float = sy + a.height
	# Арка от лица стены на запад; восточная опора уходит в стену
	var mesh := PsxMesh.arch_block(span + pier * 2.0, a.height, a.width, span, a.spring, 4.0, _b.cell)
	_b.mesh_with_trimesh(mesh, Transform3D(Basis(), Vector3(-span * 0.5, sy, zc)), _m.ashlar)
	# Парапеты моста и дверь в стене на уровне моста
	for side in [-1.0, 1.0]:
		var z: float = zc + side * (hw - 0.2)
		_b.box_between(Vector3(-span - pier, deck, z - 0.2), Vector3(0.0, deck + 1.1, z + 0.2), _m.ashlar, 4.0, false)
	_b.box_between(Vector3(-0.08, deck, zc - a.door_width * 0.5), Vector3(0.0, deck + a.door_height, zc + a.door_width * 0.5),
		_m.gate, 2.0, false, PsxMesh.FACE_EAST)

	# Лестница: от опоры на юг, вниз до мостовой. Пролёт 0 — у опоры, последний — внизу.
	var st: Dictionary = D.ROBINSON_STAIR
	var n: int = st.segments
	var seg: float = st.length / n
	var x_w := -span - pier
	var x_e := -span
	var z_top := zc + hw
	var z_foot: float = z_top + st.length
	var foot_y := _ground_y(z_foot)
	var stair_y := func(z: float) -> float: return lerpf(deck, foot_y, (z - z_top) / st.length)
	for i in n:
		var z_n := z_top + seg * i
		var z_s := z_n + seg
		var base := minf(_ground_y(z_s), _ground_y(z_n)) - SINK
		var block_top: float = stair_y.call(z_s)
		var bh := block_top - base
		if i < n - 1 and bh > 0.5:
			var r := minf(st.arch_span * 0.5, (bh - 0.6) * 0.5)
			var rot := Basis(Vector3.UP, PI * 0.5)
			var origin := Vector3((x_w + x_e) * 0.5, base, (z_n + z_s) * 0.5)
			if r >= 0.4:
				var spring := maxf(0.0, bh - r - 0.6)
				var arch := PsxMesh.arch_block(seg, bh, pier, r * 2.0, spring, 4.0, _b.cell)
				_b.mesh_with_trimesh(arch, Transform3D(rot, origin), _m.ashlar)
				# Задняя стенка ниши (под проходной аркой её нет — там ход в квартал)
				var zc_seg := (z_n + z_s) * 0.5
				if i != st.passage:
					_b.box_between(Vector3(x_w + 0.05, base, zc_seg - r), Vector3(x_e - st.niche_depth, base + spring + r, zc_seg + r),
						_m.ashlar, 4.0, false)
			else:
				_b.box_between(Vector3(x_w, base, z_n), Vector3(x_e, block_top, z_s), _m.ashlar, 4.0, true)
		else:
			block_top = base
		# Ступени поверх пролёта (верхние unfinished пролётов — недостроены)
		if i < st.unfinished:
			continue
		var rise: float = stair_y.call(z_n) - block_top
		var count := maxi(1, roundi(rise / st.step_rise))
		var tread := seg / count
		for k in count:
			var y_top := block_top + rise * (k + 1) / count
			_b.box_between(Vector3(x_w, block_top, z_s - tread * (k + 1)), Vector3(x_e, y_top, z_s - tread * k),
				_m.paving, 4.0, false)


## ─── Мост Уилсона западнее квартала (над кварталом — опоры V на карте) ─────────
func _build_wilson_causeway() -> void:
	var rows := []
	for r in _quarter.h:
		if (D.QUARTER_MAP[r] as String).contains("V"):
			rows.append(r)
	if rows.is_empty():
		return
	var z_n: float = _quarter.z0 + rows[0]
	var z_s: float = _quarter.z0 + rows[rows.size() - 1] + 1
	var g := _quarter.ground_at_z(z_s - 0.5)
	_b.box_between(Vector3(WorldCoords.gx(D.WILSON_ARCH.causeway_x), g - 1.0, z_n), Vector3(_quarter.x0, _wall_top, z_s),
		_m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM | PsxMesh.FACE_EAST, 2.0)


## ─── Дома на юге площади и Верхний город фоном ───────────────────────────────
func _build_houses() -> void:
	for i in D.PLAZA_HOUSES.size():
		var e: Array = D.PLAZA_HOUSES[i]
		_house(WorldCoords.gx(e[0]), WorldCoords.gx(e[1]), WorldCoords.gz(e[3]), WorldCoords.gz(e[2]), e[4],
			_m.plaster_a if i % 2 else _m.plaster_b, Vector3.FORWARD, i + 100)
	for i in D.BACKDROP.size():
		var e: Array = D.BACKDROP[i]
		var z_s := WorldCoords.gz(e[2])
		var z_n := WorldCoords.gz(e[3])
		_b.box_between(Vector3(WorldCoords.gx(e[0]), _plaza_y - SINK, z_s), Vector3(WorldCoords.gx(e[1]), _plaza_y + e[4], z_n),
			_m.plaster_b if i % 2 else _m.plaster_a, 4.0, false, PsxMesh.FACE_BOTTOM, 4.0)


## Дом-коробка с плоской крышей, парапетом, закрытой дверью и ставнями на северном фасаде.
func _house(x0: float, x1: float, z_n: float, z_s: float, height: float, mat: Material, _facing: Vector3, seed: int) -> void:
	var base := minf(_ground_y(z_s), _ground_y(z_n)) - SINK
	var top: float = _ground_y((z_n + z_s) * 0.5) + height
	_b.box_between(Vector3(x0, base, z_n), Vector3(x1, top, z_s), mat, 3.0, true,
		PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP | PsxMesh.FACE_SOUTH)
	var p := 0.25
	var ph: float = D.QUARTER.parapet
	_b.box_between(Vector3(x0, top - 0.1, z_n - 0.03), Vector3(x1, top + ph, z_n + p), mat, 3.0, false, PsxMesh.FACE_BOTTOM)
	_b.box_between(Vector3(x0, top - 0.1, z_n + p), Vector3(x0 + p, top + ph, z_s), mat, 3.0, false, PsxMesh.FACE_BOTTOM)
	_b.box_between(Vector3(x1 - p, top - 0.1, z_n + p), Vector3(x1, top + ph, z_s), mat, 3.0, false, PsxMesh.FACE_BOTTOM)
	# Дверь (закрытая створка в проёме) с каменной перемычкой и ставни на окнах
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var gy := _ground_y(z_n)
	var dh: float = D.QUARTER.door_height
	var dx := rng.randf_range(x0 + 1.5, x1 - 1.5)
	_b.box_between(Vector3(dx - 0.48, gy, z_n - 0.06), Vector3(dx + 0.48, gy + dh, z_n), _m.door, 1.0, false, PsxMesh.FACE_SOUTH)
	_b.box_between(Vector3(dx - 0.75, gy + dh, z_n - 0.1), Vector3(dx + 0.75, gy + dh + 0.3, z_n), _m.lintel, 1.0, false, PsxMesh.FACE_SOUTH)
	if height >= 6.0:
		var n := maxi(1, floori((x1 - x0) / 4.0))
		for k in n:
			var wx := lerpf(x0 + 1.0, x1 - 1.0, (k + 0.5) / n)
			var wy := top - 2.4
			_b.box_between(Vector3(wx - 0.35, wy, z_n - 0.07), Vector3(wx + 0.35, wy + 0.8, z_n), _m.wood, 1.0, false, PsxMesh.FACE_SOUTH)


## ─── Стройка: леса и кучи камня ──────────────────────────────────────────────
func _build_construction() -> void:
	for e in D.SCAFFOLDS:
		var x := WorldCoords.gx(e[0])
		var z := WorldCoords.gz(e[1])
		_scaffold(Vector3(x, _ground_y(z), z), Vector3(e[2], e[3], e[4]))
	for e in D.STONE_PILES:
		var x := WorldCoords.gx(e[0])
		var z := WorldCoords.gz(e[1])
		_stone_pile(Vector3(x, 0.0, z), e[2], e[3])


## Леса: стойки по периметру, перекладины через 2 м, настил через ярус вдоль длинных сторон.
## Внутрь не зайти: коллизия — одна коробка на весь объём.
func _scaffold(base: Vector3, size: Vector3) -> void:
	var pole := 0.12
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var nx := maxi(1, ceili(size.x / 2.0))
	var nz := maxi(1, ceili(size.z / 2.0))
	var y0 := base.y - SINK
	var top := base.y + size.y
	for i in nx + 1:
		for j in nz + 1:
			if i != 0 and i != nx and j != 0 and j != nz:
				continue
			var p := base + Vector3(lerpf(-hx, hx, float(i) / nx), 0.0, lerpf(-hz, hz, float(j) / nz))
			_b.box(Vector3(p.x, y0, p.z), Vector3(pole, top - y0, pole), _m.wood, 1.0, false, 0.0, 0, THIN_CELL)
	var levels := floori(size.y / 2.0)
	for l in levels:
		var y := base.y + 2.0 * (l + 1)
		for zs in [-hz, hz]:
			_b.box(Vector3(base.x, y, base.z + zs), Vector3(size.x + pole, 0.1, 0.1), _m.wood, 1.0, false, 0.0, 0, THIN_CELL)
		for xs in [-hx, hx]:
			_b.box(Vector3(base.x + xs, y, base.z), Vector3(0.1, 0.1, size.z + pole), _m.wood, 1.0, false, 0.0, 0, THIN_CELL)
		if l % 2 == 1:
			# Настил вдоль длинных сторон
			if size.x >= size.z:
				for zs in [-hz, hz]:
					_b.box(Vector3(base.x, y + 0.1, base.z + zs * 0.85), Vector3(size.x, 0.06, minf(0.9, size.z * 0.3)), _m.wood, 1.0, false,
						0.0, 0, THIN_CELL)
			else:
				for xs in [-hx, hx]:
					_b.box(Vector3(base.x + xs * 0.85, y + 0.1, base.z), Vector3(minf(0.9, size.x * 0.3), 0.06, size.z), _m.wood, 1.0, false,
						0.0, 0, THIN_CELL)
	_b.collision_box(Transform3D(Basis(), Vector3(base.x, base.y + size.y * 0.5, base.z)), Vector3(size.x, size.y, size.z))


## Куча отёсанных блоков: нижний ряд, на нём поменьше, сверху один.
func _stone_pile(center: Vector3, size: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var counts := [5, 3, 1]
	var y := _ground_y(center.z) - 0.05
	var radius := size * 0.4
	for layer in counts.size():
		var lowest := INF
		for k in counts[layer]:
			var a := rng.randf() * TAU
			var r := rng.randf() * radius
			var s := Vector3(rng.randf_range(0.7, 1.4), rng.randf_range(0.45, 0.8), rng.randf_range(0.6, 1.1)) * (size / 3.0)
			var p := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
			p.y = y
			_b.box(p, s, _m.ashlar, 2.0, true, rng.randf() * PI)
			lowest = minf(lowest, s.y)
		y += lowest - 0.08
		radius *= 0.5


## ─── Антония и ворота ────────────────────────────────────────────────────────
func _build_antonia() -> void:
	var a: Dictionary = D.ANTONIA
	var x0 := WorldCoords.gx(a.x_from)
	var x1 := WorldCoords.gx(a.x_to)
	var z_s := WorldCoords.gz(a.y_from)
	var z_n := WorldCoords.gz(a.y_to)
	var sy := _ground_y(z_s)
	var rock_top: float = sy + a.rock
	# Скала, облицованная гладкими плитами
	_b.box_between(Vector3(x0, sy - 2.0, z_s), Vector3(x1, rock_top, z_n), _m.slab, 4.0, true,
		PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP | PsxMesh.FACE_EAST | PsxMesh.FACE_NORTH, 2.0)
	# Низкая стенка по краю скалы
	var lw: float = a.low_wall
	_b.box_between(Vector3(x0, rock_top, z_s - 0.4), Vector3(x1, rock_top + lw, z_s), _m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM)
	_b.box_between(Vector3(x0, rock_top, z_n), Vector3(x0 + 0.4, rock_top + lw, z_s - 0.4), _m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM)
	# Здание
	var ins: float = a.inset
	_b.box_between(Vector3(x0 + ins, rock_top, z_s - ins), Vector3(x1 - ins, rock_top + a.building, z_n + ins),
		_m.ashlar, 4.0, false, PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP, 2.0)
	_merlons(Vector3(x0 + ins, 0.0, z_s - ins), Vector3(x1 - ins, 0.0, z_s - ins), rock_top + a.building)
	_merlons(Vector3(x0 + ins, 0.0, z_n + ins), Vector3(x0 + ins, 0.0, z_s - ins), rock_top + a.building)
	# Башни по углам: ЮЗ, СЗ, СВ, ЮВ
	var ts: float = a.tower_size
	var corners := [Vector2(x0 + 0.5, z_s - 0.5), Vector2(x0 + 0.5, z_n + 0.5 + ts), Vector2(x1 - 0.5 - ts, z_n + 0.5 + ts),
		Vector2(x1 - 0.5 - ts, z_s - 0.5)]
	for i in 4:
		var c: Vector2 = corners[i]
		var th: float = rock_top + a.towers[i]
		_b.box_between(Vector3(c.x, rock_top - 0.2, c.y - ts), Vector3(c.x + ts, th, c.y), _m.ashlar, 4.0, false,
			PsxMesh.FACE_BOTTOM | PsxMesh.FACE_TOP, 2.0)
		_merlons(Vector3(c.x, 0.0, c.y), Vector3(c.x + ts, 0.0, c.y), th)
		_merlons(Vector3(c.x, 0.0, c.y - ts), Vector3(c.x, 0.0, c.y), th)
		_merlons(Vector3(c.x + ts, 0.0, c.y - ts), Vector3(c.x + ts, 0.0, c.y), th)
		_merlons(Vector3(c.x, 0.0, c.y - ts), Vector3(c.x + ts, 0.0, c.y - ts), th)
		if i == a.beacon_tower:
			_beacon(Vector3(c.x + a.beacon_offset.x, th, c.y - a.beacon_offset.y))

	# Стена поперёк улицы с воротами
	var g: Dictionary = D.ANTONIA_GATE
	var zg := WorldCoords.gz(g.y)
	var gy := _ground_y(zg) - 0.2
	var ht: float = g.thickness * 0.5
	var gx := WorldCoords.gx(g.x)
	var pier := 2.5
	var gw: float = g.span + pier * 2.0
	var gate := PsxMesh.arch_block(gw, g.height, g.thickness, g.span, g.spring, 4.0, _b.cell)
	_b.mesh_with_trimesh(gate, Transform3D(Basis(), Vector3(gx, gy, zg)), _m.ashlar)
	_b.box_between(Vector3(WorldCoords.gx(g.x_west), gy, zg + ht), Vector3(gx - gw * 0.5, gy + g.height, zg - ht), _m.ashlar, 4.0, true)
	_b.box_between(Vector3(gx + gw * 0.5, gy, zg + ht), Vector3(x0, gy + g.height, zg - ht), _m.ashlar, 4.0, true)
	_merlons(Vector3(WorldCoords.gx(g.x_west), 0.0, zg + ht - 0.3), Vector3(x0, 0.0, zg + ht - 0.3), gy + g.height)
	# Створки — сразу за проёмом, закрыты
	var door_h: float = g.spring + g.span * 0.5 + 0.3
	var leaf: float = g.span * 0.5 + 0.25
	for side in [-1.0, 1.0]:
		var xa: float = gx + side * 0.015
		var xb: float = gx + side * leaf
		_b.box_between(Vector3(minf(xa, xb), gy, zg - ht - 0.25), Vector3(maxf(xa, xb), gy + door_h, zg - ht),
			_m.gate, 2.25, true)
	# Перед воротами — триггер «конец уровня»: подошёл к створкам вплотную
	var area := Area3D.new()
	area.name = "LevelExit"
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(g.span + 2.0, 3.0, g.trigger_depth)
	area.add_child(shape)
	area.position = Vector3(gx, gy + 1.5, zg + ht + g.trigger_depth * 0.5)
	area.body_entered.connect(_on_exit_body_entered)
	add_child(area)


## Маяк — сигнальный огонь на башне Антонии: железная корзина с огнём и большое мерцающее пятно,
## видное сквозь туман через весь уровень (огоньки FAR). Это цель уровня.
func _beacon(base: Vector3) -> void:
	_b.box(base, Vector3(1.2, 0.5, 1.2), _m.ashlar, 2.0, false)
	_b.add_mesh(PropLibrary.mesh("brazier"), Transform3D(Basis.from_scale(Vector3.ONE * 1.6), base + Vector3.UP * 0.5),
		PropLibrary.material())
	var fire := base + Vector3.UP * 2.3
	_glows.add(fire, 1.3, Glows.Kind.FAR, Glows.FIRE, 2.2)
	_glows.add(fire + Vector3.UP * 0.8, 4.5, Glows.Kind.FAR, Glows.FIRE, 1.2)
	_glows.add(fire + Vector3.UP * 2.0, 11.0, Glows.Kind.FAR, Color(0.9, 0.4, 0.15), 0.7)


## Настоящий свет у жаровен (LIGHTS в данных): тёплый, мерцает, без теней.
func _build_lights() -> void:
	for e in D.LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = e[3]
		light.omni_range = e[4]
		light.omni_attenuation = 0.9
		light.shadow_enabled = false
		light.position = _quarter.cell_center(e[0], e[1]) + Vector3.UP * float(e[2])
		light.set_script(preload("res://scripts/flicker_light.gd"))
		add_child(light)


## Зубцы по отрезку a → b (по XZ) на высоте y: 0,8 м зубец, 0,8 м промежуток.
func _merlons(a: Vector3, b: Vector3, y: float) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	var n := floori(length / 1.6)
	if n < 1:
		return
	var yaw := atan2(-d.z, d.x)
	for i in n:
		var p := a + d * ((i + 0.5) / n)
		_b.box(Vector3(p.x, y, p.z), Vector3(0.8, 1.2, 0.5), _m.ashlar, 4.0, false, yaw, PsxMesh.FACE_BOTTOM)


## ─── Невидимые границы ───────────────────────────────────────────────────────
func _build_bounds() -> void:
	for e in D.BOUNDS:
		var a := WorldCoords.point(e[0], e[1])
		var b := WorldCoords.point(e[2], e[3])
		var d := b - a
		var center := (a + b) * 0.5
		center.y = _ground_y(center.z) + 10.0
		_b.collision_box(Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)), center), Vector3(d.length() + 1.0, 40.0, 1.0))


func _place_player() -> void:
	var z := WorldCoords.gz(D.SPAWN.y)
	_player.position = Vector3(WorldCoords.gx(D.SPAWN.x), _ground_y(z) + 0.05, z)
	_player.rotation.y = deg_to_rad(D.SPAWN_YAW)


func _on_exit_body_entered(body: Node3D) -> void:
	if _finished or not body is Player:
		return
	_finished = true
	level_finished.emit()
	# Уровня 2 пока нет: затемнение и надпись
	var layer := CanvasLayer.new()
	layer.layer = 10
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	var label := Label.new()
	label.text = "Конец уровня 1"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.modulate.a = 0.0
	layer.add_child(label)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.5)
	tw.tween_property(label, "modulate:a", 1.0, 0.5)
