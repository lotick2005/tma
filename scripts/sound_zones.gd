class_name SoundZones
extends Node3D
## Зоны эха (Area3D с reverb bus) — размечаются автоматически по символьной карте квартала:
##  • комната (_ :) — Reverb_Room: сухо и близко;
##  • подвал и миква (m M \) — Reverb_Cellar: долгое гулкое эхо;
##  • переулок, двор, проходы (. + , = / o d x *) — Reverb_Alley: короткое хлёсткое эхо от стен;
##  • площадка (открытое место, где вокруг клетки почти всё — улица) — Reverb_Plaza: широко.
## Плюс зоны вручную (площадь A у арки) — add_box(). Клетки одного типа сливаются в прямоугольники.
## Зоны лежат на слое физики SoundEmitter.ZONE_LAYER: их видят только «эхо-копии» звуков.
## Тут же — точки для ложных тревог (переулки и закрытые двери).

const ROOM := 1
const CELLAR := 2
const ALLEY := 3
const PLAZA := 4

## Тип зоны: шина эха, сколько звука отправлять в эхо, цвет отладки.
const KINDS := {
	ROOM: ["Reverb_Room", 0.5, Color(0.3, 0.5, 1.0, 0.18)],
	CELLAR: ["Reverb_Cellar", 0.9, Color(0.7, 0.3, 1.0, 0.22)],
	ALLEY: ["Reverb_Alley", 0.55, Color(1.0, 0.8, 0.2, 0.12)],
	PLAZA: ["Reverb_Plaza", 0.6, Color(0.2, 1.0, 0.6, 0.12)],
}
const CELLAR_CELLS := "mM\\"
const ROOM_CELLS := "_:"
const OPEN_CELLS := ".+,=/odx*b"
## Площадка: в квадрате (2·PLAZA_RADIUS+1)² вокруг клетки не меньше PLAZA_FILL открытых клеток.
const PLAZA_RADIUS := 3
const PLAZA_FILL := 0.72
## Высота зон над землёй, м: переулок — ниже крыш одноэтажных домов (на крыше эха нет), площадка — выше.
const ALLEY_HEIGHT := 3.4
const PLAZA_HEIGHT := 7.0

## Точки ложных тревог: "alley" (переулки, дворы, площадки), "door" (у закрытых дверей).
var alarm_points := {"alley": PackedVector3Array(), "door": PackedVector3Array()}
var zone_count := 0


## Разметить квартал. cfg — QUARTER из данных уровня (потолок, глубина подвала и миквы).
func build_quarter(q: QuarterBuilder, cfg: Dictionary) -> void:
	var kinds := PackedByteArray()
	kinds.resize(q.w * q.h)
	for r in q.h:
		for c in q.w:
			kinds[r * q.w + c] = _cell_kind(q, c, r)
	# Площадки: открытые клетки, вокруг которых почти всё открыто
	var plaza := kinds.duplicate()
	for r in q.h:
		for c in q.w:
			if kinds[r * q.w + c] != ALLEY:
				continue
			var open := 0
			var total := 0
			for dr in range(-PLAZA_RADIUS, PLAZA_RADIUS + 1):
				for dc in range(-PLAZA_RADIUS, PLAZA_RADIUS + 1):
					total += 1
					var cc := c + dc
					var rr := r + dr
					if cc >= 0 and rr >= 0 and cc < q.w and rr < q.h and kinds[rr * q.w + cc] == ALLEY:
						open += 1
			if float(open) / total >= PLAZA_FILL:
				plaza[r * q.w + c] = PLAZA
	kinds = plaza
	var ceiling: float = cfg.get("ceiling", 3.0)
	var cellar_depth: float = cfg.get("basement_depth", 2.6) + cfg.get("pool_depth", 1.5)
	var used := PackedByteArray()
	used.resize(q.w * q.h)
	for r in q.h:
		for c in q.w:
			var k := kinds[r * q.w + c]
			if k == 0 or used[r * q.w + c] != 0:
				continue
			# Жадный прямоугольник: вправо, потом вниз, пока весь ряд того же типа
			var c1 := c
			while c1 + 1 < q.w and kinds[r * q.w + c1 + 1] == k and used[r * q.w + c1 + 1] == 0:
				c1 += 1
			var r1 := r
			while r1 + 1 < q.h:
				var ok := true
				for cc in range(c, c1 + 1):
					if kinds[(r1 + 1) * q.w + cc] != k or used[(r1 + 1) * q.w + cc] != 0:
						ok = false
						break
				if not ok:
					break
				r1 += 1
			var g_lo := INF
			var g_hi := -INF
			for rr in range(r, r1 + 1):
				for cc in range(c, c1 + 1):
					used[rr * q.w + cc] = 1
				g_lo = minf(g_lo, q.ground[rr])
				g_hi = maxf(g_hi, q.ground[rr])
			var y0 := g_lo - 0.5
			var y1 := g_hi + ALLEY_HEIGHT
			match k:
				ROOM:
					y0 = g_lo - 0.2
					y1 = g_hi + ceiling
				CELLAR:
					y0 = g_lo - cellar_depth - 0.3
					y1 = g_hi - 0.05
				PLAZA:
					y1 = g_hi + PLAZA_HEIGHT
			add_box(k, Vector3(q.x0 + c, y0, q.z0 + r), Vector3(q.x0 + c1 + 1, y1, q.z0 + r1 + 1))
	# Точки ложных тревог
	for r in q.h:
		for c in q.w:
			var ch := q.cell(c, r)
			var k := kinds[r * q.w + c]
			if k == ALLEY or k == PLAZA:
				alarm_points.alley.append(q.cell_center(c, r) + Vector3.UP * 0.4)
			elif ch in "DBH":
				alarm_points.door.append(q.cell_center(c, r) + Vector3.UP * 1.0)


func _cell_kind(q: QuarterBuilder, c: int, r: int) -> int:
	var ch := q.cell(c, r)
	if ch in CELLAR_CELLS:
		return CELLAR
	if ch in ROOM_CELLS:
		return ROOM
	if ch in OPEN_CELLS:
		return ALLEY
	return 0


## Зона-коробка от угла a до угла b (мировые координаты).
func add_box(kind: int, a: Vector3, b: Vector3, priority := 1.0) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var size := hi - lo
	var center := (lo + hi) * 0.5
	var info: Array = KINDS[kind]
	var area := Area3D.new()
	area.name = "Zone_%s_%d" % [String(info[0]).trim_prefix("Reverb_"), zone_count]
	area.monitoring = false
	area.monitorable = true
	area.collision_layer = 1 << (SoundEmitter.ZONE_LAYER - 1)
	area.collision_mask = 0
	area.priority = priority
	area.reverb_bus_enabled = true
	area.reverb_bus_name = info[0]
	area.reverb_bus_amount = info[1]
	area.reverb_bus_uniformity = 0.0
	area.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	zone_count += 1
	# Отладка: полупрозрачная коробка (видна, когда включено «показать звуковые зоны и источники»)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size - Vector3.ONE * 0.04
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = info[2]
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = center
	mesh.visible = AudioManager.debug_visible
	mesh.add_to_group("sound_debug")
	add_child(mesh)
