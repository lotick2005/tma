class_name PropLibrary
extends RefCounted
## Библиотека предметов: лоуполи-меши строятся кодом, все на одном материале — атласе 256×256
## из 16 процедурных текстур 64×64 (глина, дерево, лён, солома, камень…). Поэтому весь «быт»
## куска уровня рисуется за один вызов. Меш каждого предмета строится один раз и кешируется.
## Предмет в редакторе — сцена res://scenes/props/prop.tscn (поле kind), все сразу — catalog.tscn.
## Новый предмет: функция _make_<имя>() ниже + строка в KINDS.

## Плитки атласа (4×4 по 64 пикселя).
enum Tile { CLAY, CLAY_DARK, WOOD, WOOD_DARK, LINEN, CLOTH_RED, CLOTH_BLUE, STRAW, SACK, STONE, BASALT, LEAF, BARK, METAL, FOOD, PALM }

## Свойства предметов: collide — размер коробки коллизии (ноль — без неё, можно пройти/перешагнуть);
## mm — часто повторяется, рисуется через MultiMeshInstance3D; wall — вешается на стену (точка — у стены).
const KINDS := {
	# Быт
	"jar_small": {"collide": Vector3.ZERO, "mm": true},
	"jar_large": {"collide": Vector3(0.5, 0.75, 0.5)},
	"jug": {"collide": Vector3.ZERO, "mm": true},
	"stone_vessel": {"collide": Vector3.ZERO},
	"basket": {"collide": Vector3.ZERO},
	"sack": {"collide": Vector3(0.45, 0.6, 0.45)},
	"mat_rolled": {"collide": Vector3.ZERO},
	"mat": {"collide": Vector3.ZERO},
	"lamp_niche": {"collide": Vector3.ZERO, "wall": true},
	"rope_coil": {"collide": Vector3.ZERO},
	"laundry": {"collide": Vector3.ZERO},
	"herbs": {"collide": Vector3.ZERO, "wall": true},
	"shutter": {"collide": Vector3.ZERO, "wall": true},
	# Рынок
	"stall": {"collide": Vector3(2.0, 1.0, 1.0)},
	"scales": {"collide": Vector3.ZERO},
	"weights": {"collide": Vector3.ZERO},
	"crate": {"collide": Vector3(0.6, 0.5, 0.5)},
	"fruit": {"collide": Vector3.ZERO, "mm": true},
	"bread": {"collide": Vector3.ZERO, "mm": true},
	# Пасха
	"palm_branch": {"collide": Vector3.ZERO, "mm": true},
	"lamb_pen": {"collide": Vector3(2.2, 0.9, 1.6)},
	# Следы землетрясения (Мф 27:51)
	"crack": {"collide": Vector3.ZERO, "wall": true},
	"rubble_block": {"collide": Vector3.ZERO, "mm": true},
	"beam": {"collide": Vector3.ZERO},
	"shards": {"collide": Vector3.ZERO, "mm": true},
	# Следы людей
	"sandals": {"collide": Vector3.ZERO, "mm": true},
	"cloak": {"collide": Vector3.ZERO},
	"litter": {"collide": Vector3(1.9, 0.5, 0.7)},
	"body": {"collide": Vector3.ZERO},
	# Зелень
	"olive_tree": {"collide": Vector3(0.5, 2.0, 0.5)},
	"fig_tree": {"collide": Vector3(0.5, 2.0, 0.5)},
	"pergola": {"collide": Vector3.ZERO},
	# Римское
	"shield": {"collide": Vector3.ZERO},
	"helmet": {"collide": Vector3.ZERO},
	"spear": {"collide": Vector3.ZERO},
	# Интерьер
	"table_low": {"collide": Vector3(1.0, 0.4, 0.6)},
	"stool": {"collide": Vector3.ZERO},
	"loom": {"collide": Vector3(1.4, 1.8, 0.5)},
	"oven": {"collide": Vector3(0.8, 0.6, 0.8)},
	"quern": {"collide": Vector3.ZERO},
	"cistern": {"collide": Vector3(1.1, 0.5, 1.1)},
}

static var _material: ShaderMaterial
static var _meshes := {}


## Общий материал всех предметов (атлас).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = PsxMaterial.make(_atlas())
	return _material


static func mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		var m: Mesh = Callable(PropLibrary, "_make_" + kind).call()
		_meshes[kind] = m
	return _meshes[kind]


static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, {})


# ─── Атлас ───────────────────────────────────────────────────────────────────

static func _atlas() -> ImageTexture:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGB8)
	var tiles := [
		ProcTextures.mottled(64, Color(0.62, 0.36, 0.22), 0.05, 0.1, 61),          # CLAY
		ProcTextures.mottled(64, Color(0.45, 0.25, 0.16), 0.05, 0.1, 62),          # CLAY_DARK
		ProcTextures.wood(64, 4, Color(0.5, 0.36, 0.22), 63),                      # WOOD
		ProcTextures.wood(64, 3, Color(0.3, 0.2, 0.13), 64),                       # WOOD_DARK
		ProcTextures.mottled(64, Color(0.82, 0.78, 0.68), 0.04, 0.08, 65),         # LINEN
		ProcTextures.hemmed_cloth(64, Color(0.55, 0.14, 0.12), 8, 66),             # CLOTH_RED
		ProcTextures.stripes(64, 8, Color(0.75, 0.7, 0.6), Color(0.22, 0.25, 0.5), 67),  # CLOTH_BLUE
		ProcTextures.checker(64, 16, Color(0.72, 0.6, 0.36), Color(0.58, 0.46, 0.26), 0.05, 68),  # STRAW
		ProcTextures.mottled(64, Color(0.58, 0.5, 0.36), 0.08, 0.06, 69),          # SACK
		ProcTextures.mottled(64, Color(0.78, 0.74, 0.64), 0.04, 0.08, 70),         # STONE
		ProcTextures.mottled(64, Color(0.28, 0.27, 0.27), 0.05, 0.08, 71),         # BASALT
		ProcTextures.mottled(64, Color(0.3, 0.42, 0.2), 0.08, 0.14, 72),           # LEAF
		ProcTextures.wood(64, 6, Color(0.36, 0.3, 0.24), 73),                      # BARK
		ProcTextures.mottled(64, Color(0.6, 0.45, 0.22), 0.06, 0.12, 74),          # METAL (бронза)
		ProcTextures.mottled(64, Color(0.72, 0.48, 0.24), 0.08, 0.1, 75),          # FOOD
		ProcTextures.stripes(64, 16, Color(0.55, 0.6, 0.28), Color(0.4, 0.45, 0.2), 76),  # PALM
	]
	for i in tiles.size():
		var t: Image = (tiles[i] as ImageTexture).get_image()
		t.convert(Image.FORMAT_RGB8)
		img.blit_rect(t, Rect2i(0, 0, 64, 64), Vector2i((i % 4) * 64, (i / 4) * 64))
	return ImageTexture.create_from_image(img)


# ─── Построитель мешей ───────────────────────────────────────────────────────

class PB:
	var st := SurfaceTool.new()
	var xf := Transform3D()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## uv 0..1 внутри плитки → атлас (с отступом в 1 пиксель от края плитки).
	func _uv(tile: int, uv: Vector2) -> Vector2:
		var inset := 1.0 / 64.0
		var u := clampf(uv.x, 0.0, 1.0) * (1.0 - inset * 2.0) + inset
		var v := clampf(uv.y, 0.0, 1.0) * (1.0 - inset * 2.0) + inset
		return Vector2((tile % 4 + u) / 4.0, (tile / 4 + v) / 4.0)

	## Четырёхугольник tl, tr, br, bl — по часовой, если смотреть на лицевую сторону.
	func quad(tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3, tile: int, both := false) -> void:
		var p := [xf * tl, xf * tr, xf * br, xf * bl]
		var n: Vector3 = ((p[3] - p[0]).cross(p[1] - p[0]))
		if n.length_squared() < 1e-12:
			n = (p[2] - p[0]).cross(p[1] - p[0])
		n = n.normalized()
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(_uv(tile, uvs[k]))
			st.add_vertex(p[k])
		if both:
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(-n)
				st.set_uv(_uv(tile, uvs[k]))
				st.add_vertex(p[k])

	## Ящик: центр, размер, поворот basis.
	func box(center: Vector3, size: Vector3, tile: int, basis := Basis()) -> void:
		var h := size * 0.5
		for f in [[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
				[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
				[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var hn := absf(h.dot(n))
			var hu := absf(h.dot(u))
			var hv := absf(h.dot(v))
			var c := n * hn
			quad(center + basis * (c - u * hu + v * hv), center + basis * (c + u * hu + v * hv),
				center + basis * (c + u * hu - v * hv), center + basis * (c - u * hu - v * hv), tile)

	## Тело вращения: профиль (радиус, высота) снизу вверх; scale_xz сплющивает (овальные предметы).
	func lathe(profile: Array, sides: int, tile: int, origin := Vector3.ZERO, basis := Basis(), scale_xz := Vector2.ONE) -> void:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			for j in profile.size() - 1:
				var p0: Vector2 = profile[j]
				var p1: Vector2 = profile[j + 1]
				var q := func(a: float, p: Vector2) -> Vector3:
					return origin + basis * Vector3(cos(a) * p.x * scale_xz.x, p.y, sin(a) * p.x * scale_xz.y)
				quad(q.call(a1, p1), q.call(a0, p1), q.call(a0, p0), q.call(a1, p0), tile)

	## Плоский лист/ткань с двух сторон: центр, ширина, длина, поворот.
	func sheet(center: Vector3, w: float, l: float, tile: int, basis := Basis()) -> void:
		var a := basis * Vector3(w * 0.5, 0, 0)
		var b := basis * Vector3(0, 0, l * 0.5)
		quad(center - a - b, center + a - b, center + a + b, center - a + b, tile, true)

	func commit() -> ArrayMesh:
		return st.commit()


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


# ─── Быт ─────────────────────────────────────────────────────────────────────

static func _make_jar_small() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.12, 0.08), Vector2(0.13, 0.2), Vector2(0.08, 0.3),
		Vector2(0.05, 0.33), Vector2(0.065, 0.37), Vector2(0.03, 0.36)], 7, Tile.CLAY)
	return b.commit()


static func _make_jar_large() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.1, 0.0), Vector2(0.22, 0.15), Vector2(0.26, 0.4), Vector2(0.22, 0.6),
		Vector2(0.12, 0.7), Vector2(0.1, 0.76), Vector2(0.13, 0.8), Vector2(0.05, 0.78)], 8, Tile.CLAY_DARK)
	b.box(Vector3(0.2, 0.62, 0), Vector3(0.05, 0.12, 0.04), Tile.CLAY_DARK)
	b.box(Vector3(-0.2, 0.62, 0), Vector3(0.05, 0.12, 0.04), Tile.CLAY_DARK)
	return b.commit()


static func _make_jug() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.1, 0.06), Vector2(0.1, 0.16), Vector2(0.05, 0.24),
		Vector2(0.045, 0.3), Vector2(0.06, 0.32), Vector2(0.02, 0.31)], 6, Tile.CLAY)
	b.box(Vector3(0.1, 0.22, 0), Vector3(0.03, 0.14, 0.03), Tile.CLAY)
	return b.commit()


static func _make_stone_vessel() -> Mesh:
	var b := PB.new()
	# Каменная кружка-мерка (каменные сосуды не оскверняются — их много в домах Иерусалима)
	b.lathe([Vector2(0, 0), Vector2(0.09, 0), Vector2(0.11, 0.02), Vector2(0.12, 0.24), Vector2(0.1, 0.25),
		Vector2(0.09, 0.08), Vector2(0, 0.08)], 8, Tile.STONE)
	b.box(Vector3(0.14, 0.15, 0), Vector3(0.05, 0.1, 0.04), Tile.STONE)
	return b.commit()


static func _make_basket() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.18, 0), Vector2(0.22, 0.22), Vector2(0.24, 0.26), Vector2(0.2, 0.26),
		Vector2(0.17, 0.06), Vector2(0, 0.06)], 8, Tile.STRAW)
	return b.commit()


static func _make_sack() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.18, 0), Vector2(0.23, 0.15), Vector2(0.22, 0.38), Vector2(0.12, 0.5),
		Vector2(0.05, 0.53), Vector2(0.07, 0.6), Vector2(0, 0.58)], 6, Tile.SACK, Vector3.ZERO, Basis(), Vector2(1.0, 0.8))
	return b.commit()


static func _make_mat_rolled() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, -0.45), Vector2(0.11, -0.45), Vector2(0.11, 0.45), Vector2(0, 0.45)], 6, Tile.STRAW,
		Vector3(0, 0.11, 0), Basis(Vector3.BACK, PI * 0.5))
	return b.commit()


static func _make_mat() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.01, 0), Vector3(1.8, 0.02, 0.9), Tile.STRAW)
	return b.commit()


## Ниша для светильника: каменный подоконник и арочная рамка из тёсаного камня, на полке — светильник.
static func _make_lamp_niche() -> Mesh:
	var b := PB.new()
	# Точка — у стены на высоте 0; ниша смотрит в −Z
	b.box(Vector3(0, 1.3, -0.06), Vector3(0.5, 0.06, 0.14), Tile.STONE)
	b.box(Vector3(-0.22, 1.5, -0.03), Vector3(0.06, 0.4, 0.06), Tile.STONE)
	b.box(Vector3(0.22, 1.5, -0.03), Vector3(0.06, 0.4, 0.06), Tile.STONE)
	b.box(Vector3(0, 1.72, -0.03), Vector3(0.5, 0.06, 0.06), Tile.STONE)
	b.box(Vector3(0, 1.5, -0.005), Vector3(0.38, 0.38, 0.01), Tile.SACK)
	b.lathe([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.05, 0.02), Vector2(0.02, 0.035), Vector2(0, 0.03)], 6,
		Tile.CLAY, Vector3(0, 1.33, -0.07))
	b.box(Vector3(0, 1.35, -0.13), Vector3(0.03, 0.015, 0.06), Tile.CLAY)
	return b.commit()


static func _make_rope_coil() -> Mesh:
	var b := PB.new()
	for k in 3:
		var r := 0.16 + k * 0.035
		b.lathe([Vector2(r - 0.02, 0.0 + k * 0.03), Vector2(r + 0.02, 0.0 + k * 0.03), Vector2(r + 0.02, 0.04 + k * 0.03),
			Vector2(r - 0.02, 0.04 + k * 0.03)], 8, Tile.SACK)
	return b.commit()


## Бельё на верёвке поперёк переулка 2 м: верёвка и несколько тряпок.
static func _make_laundry() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0, 0), Vector3(0.02, 0.02, 2.0), Tile.SACK)
	var rng := _rng(5)
	var z := -0.75
	while z < 0.8:
		var w := rng.randf_range(0.3, 0.55)
		var l := rng.randf_range(0.4, 0.8)
		var tile: int = [Tile.LINEN, Tile.CLOTH_RED, Tile.CLOTH_BLUE, Tile.LINEN][rng.randi() % 4]
		b.quad(Vector3(0, 0, z), Vector3(0, 0, z + w), Vector3(0.02, -l, z + w), Vector3(0.02, -l, z), tile, true)
		z += w + rng.randf_range(0.05, 0.2)
	return b.commit()


## Пучок сушёных трав на гвозде (у стены, на высоте ~1,9 м).
static func _make_herbs() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0.0, 1.45), Vector2(0.09, 1.5), Vector2(0.06, 1.75), Vector2(0.02, 1.9), Vector2(0, 1.9)], 5,
		Tile.LEAF, Vector3(0, 0, -0.09))
	b.box(Vector3(0, 1.9, -0.05), Vector3(0.03, 0.03, 0.1), Tile.WOOD_DARK)
	return b.commit()


## Деревянные ставни на окне (закрыты) — на стене двухэтажного дома.
static func _make_shutter() -> Mesh:
	var b := PB.new()
	b.box(Vector3(-0.2, 3.6, -0.03), Vector3(0.38, 0.75, 0.05), Tile.WOOD_DARK)
	b.box(Vector3(0.2, 3.6, -0.03), Vector3(0.38, 0.75, 0.05), Tile.WOOD_DARK)
	b.box(Vector3(0, 3.2, -0.06), Vector3(0.9, 0.06, 0.12), Tile.STONE)
	return b.commit()


# ─── Рынок ───────────────────────────────────────────────────────────────────

static func _make_stall() -> Mesh:
	var b := PB.new()
	for x in [-0.95, 0.95]:
		b.box(Vector3(x, 1.0, 0.45), Vector3(0.08, 2.0, 0.08), Tile.WOOD)
		b.box(Vector3(x, 0.8, -0.45), Vector3(0.08, 1.6, 0.08), Tile.WOOD)
	b.box(Vector3(0, 0.85, 0), Vector3(2.0, 0.06, 1.0), Tile.WOOD)
	b.box(Vector3(0, 0.45, 0.45), Vector3(2.0, 0.7, 0.04), Tile.WOOD_DARK)
	# Тканевый навес наклоном вперёд, с двух сторон
	b.quad(Vector3(-1.05, 2.02, 0.55), Vector3(1.05, 2.02, 0.55), Vector3(1.05, 1.62, -0.75), Vector3(-1.05, 1.62, -0.75),
		Tile.CLOTH_BLUE, true)
	return b.commit()


static func _make_scales() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.2, 0), Vector3(0.03, 0.4, 0.03), Tile.WOOD_DARK)
	b.box(Vector3(0, 0.4, 0), Vector3(0.4, 0.02, 0.02), Tile.METAL)
	for x in [-0.19, 0.19]:
		b.lathe([Vector2(0, 0), Vector2(0.08, 0.02), Vector2(0.09, 0.03), Vector2(0, 0.025)], 6, Tile.METAL, Vector3(x, 0.22, 0))
		b.box(Vector3(x, 0.32, 0), Vector3(0.005, 0.18, 0.005), Tile.SACK)
	b.box(Vector3(0, 0.005, 0), Vector3(0.18, 0.01, 0.12), Tile.WOOD_DARK)
	return b.commit()


static func _make_weights() -> Mesh:
	var b := PB.new()
	var rng := _rng(9)
	for i in 5:
		var s := 0.03 + i * 0.012
		b.box(Vector3(rng.randf_range(-0.15, 0.15), s * 0.5, rng.randf_range(-0.1, 0.1)), Vector3(s, s, s), Tile.BASALT,
			Basis(Vector3.UP, rng.randf() * PI))
	return b.commit()


static func _make_crate() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.5), Tile.WOOD)
	b.box(Vector3(0, 0.25, 0.255), Vector3(0.62, 0.06, 0.02), Tile.WOOD_DARK)
	b.box(Vector3(0, 0.25, -0.255), Vector3(0.62, 0.06, 0.02), Tile.WOOD_DARK)
	return b.commit()


static func _make_fruit() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.035, 0.012), Vector2(0.04, 0.04), Vector2(0.03, 0.065), Vector2(0, 0.07)], 5, Tile.FOOD)
	return b.commit()


static func _make_bread() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.11, 0.02), Vector2(0.08, 0.04), Vector2(0, 0.045)], 7, Tile.FOOD)
	return b.commit()


# ─── Пасха ───────────────────────────────────────────────────────────────────

## Пальмовая ветвь на мостовой: черешок и листья ёлочкой (Ин 12:13).
static func _make_palm_branch() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.012, 0), Vector3(0.025, 0.02, 1.5), Tile.WOOD)
	for i in 6:
		var z := -0.6 + i * 0.22
		var l := 0.45 - absf(i - 2.5) * 0.06
		for s in [-1.0, 1.0]:
			var root := Vector3(0, 0.015, z)
			var tip := Vector3(s * l, 0.01, z + 0.2)
			b.quad(root + Vector3(0, 0, -0.04), tip + Vector3(0, 0, -0.03), tip + Vector3(0, 0, 0.03), root + Vector3(0, 0, 0.04),
				Tile.PALM, true)
	return b.commit()


## Пустой загон для пасхальных ягнят: жерди и перекладины.
static func _make_lamb_pen() -> Mesh:
	var b := PB.new()
	var hx := 1.1
	var hz := 0.8
	for p in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz), Vector2(0, -hz), Vector2(0, hz)]:
		b.box(Vector3(p.x, 0.45, p.y), Vector3(0.07, 0.9, 0.07), Tile.WOOD)
	for y in [0.35, 0.75]:
		b.box(Vector3(0, y, -hz), Vector3(hx * 2, 0.05, 0.04), Tile.WOOD)
		b.box(Vector3(0, y, hz), Vector3(hx * 2, 0.05, 0.04), Tile.WOOD)
		b.box(Vector3(-hx, y, 0), Vector3(0.04, 0.05, hz * 2), Tile.WOOD)
		b.box(Vector3(hx, y, 0.35), Vector3(0.04, 0.05, hz * 2 - 0.7), Tile.WOOD)
	b.box(Vector3(0, 0.01, 0), Vector3(hx * 1.8, 0.02, hz * 1.6), Tile.STRAW)
	return b.commit()


# ─── Землетрясение ───────────────────────────────────────────────────────────

## Трещина в стене: ломаная тёмная полоса снизу вверх, чуть перед стеной (смотрит в −Z).
static func _make_crack() -> Mesh:
	var b := PB.new()
	var rng := _rng(13)
	var p := Vector3(0, 0.2, -0.015)
	for i in 7:
		var q := p + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.25, 0.45), 0)
		var w := 0.05 - i * 0.005
		b.quad(Vector3(q.x - w, q.y, p.z), Vector3(q.x + w, q.y, p.z), Vector3(p.x + w, p.y, p.z), Vector3(p.x - w, p.y, p.z), Tile.BASALT)
		if i == 3:
			var br := p + Vector3(0.35, 0.3, 0)
			b.quad(Vector3(br.x - 0.02, br.y, p.z), Vector3(br.x + 0.02, br.y, p.z), Vector3(p.x + 0.03, p.y, p.z),
				Vector3(p.x - 0.03, p.y, p.z), Tile.BASALT)
		p = q
	return b.commit()


static func _make_rubble_block() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.45), Tile.STONE, Basis(Vector3.FORWARD, 0.15))
	b.box(Vector3(0.45, 0.1, 0.2), Vector3(0.3, 0.2, 0.25), Tile.STONE, Basis(Vector3.UP, 0.6))
	return b.commit()


## Упавшая балка перекрытия: одним концом на земле, другим на камне.
static func _make_beam() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.25, 0), Vector3(0.2, 0.18, 2.6), Tile.WOOD_DARK, Basis(Vector3.RIGHT, 0.18))
	b.box(Vector3(0.05, 0.12, -1.1), Vector3(0.4, 0.24, 0.35), Tile.STONE)
	return b.commit()


## Разбитый кувшин: черепки дугами на земле.
static func _make_shards() -> Mesh:
	var b := PB.new()
	var rng := _rng(17)
	for i in 6:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.05, 0.3)
		var c := Vector3(cos(a) * r, 0.02, sin(a) * r)
		var s := rng.randf_range(0.05, 0.12)
		b.quad(c + Vector3(-s, 0.0, -s * 0.5), c + Vector3(s, 0.03, -s * 0.4), c + Vector3(s * 0.8, 0.0, s * 0.5),
			c + Vector3(-s * 0.7, 0.02, s * 0.4), Tile.CLAY, true)
	b.lathe([Vector2(0.12, 0), Vector2(0.13, 0.08), Vector2(0.1, 0.13)], 6, Tile.CLAY, Vector3(0.1, 0, 0.05))
	return b.commit()


# ─── Следы людей ─────────────────────────────────────────────────────────────

static func _make_sandals() -> Mesh:
	var b := PB.new()
	b.box(Vector3(-0.07, 0.01, 0), Vector3(0.09, 0.02, 0.25), Tile.WOOD_DARK, Basis(Vector3.UP, 0.2))
	b.box(Vector3(0.12, 0.01, 0.06), Vector3(0.09, 0.02, 0.25), Tile.WOOD_DARK, Basis(Vector3.UP, -0.5))
	b.box(Vector3(-0.07, 0.03, 0.03), Vector3(0.1, 0.02, 0.02), Tile.SACK, Basis(Vector3.UP, 0.2))
	return b.commit()


## Брошенный плащ: смятая ткань бугром.
static func _make_cloak() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0.0), Vector2(0.55, 0.0), Vector2(0.45, 0.06), Vector2(0.25, 0.14), Vector2(0, 0.16)], 7,
		Tile.CLOTH_RED, Vector3.ZERO, Basis(Vector3.UP, 0.4), Vector2(1.0, 0.65))
	return b.commit()


## Опрокинутые носилки: две жерди и полотно, на боку.
static func _make_litter() -> Mesh:
	var b := PB.new()
	var tilt := Basis(Vector3.BACK, 1.25)
	for z in [-0.3, 0.3]:
		b.box(Vector3(0, 0.35, z), Vector3(2.0, 0.06, 0.06), Tile.WOOD, tilt)
	b.box(Vector3(0, 0.3, 0), Vector3(1.4, 0.03, 0.6), Tile.LINEN, tilt)
	b.box(Vector3(0.6, 0.06, 0), Vector3(0.6, 0.1, 0.5), Tile.LINEN, Basis(Vector3.UP, 0.3))
	return b.commit()


## Тело, укрытое тканью: вытянутый бугор с головой.
static func _make_body() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, -0.85), Vector2(0.14, -0.8), Vector2(0.22, -0.3), Vector2(0.24, 0.2), Vector2(0.18, 0.55),
		Vector2(0.12, 0.62), Vector2(0.13, 0.82), Vector2(0, 0.9)], 6, Tile.LINEN, Vector3(0, 0.12, 0),
		Basis(Vector3.RIGHT, PI * 0.5), Vector2(1.0, 0.45))
	return b.commit()


# ─── Зелень ──────────────────────────────────────────────────────────────────

## Олива: кривой ствол и низкая серо-зелёная крона из нескольких комков.
static func _make_olive_tree() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0.18, 0), Vector2(0.14, 0.8), Vector2(0.1, 1.5)], 6, Tile.BARK)
	b.lathe([Vector2(0.1, 0), Vector2(0.06, 0.8)], 5, Tile.BARK, Vector3(0, 1.4, 0), Basis(Vector3.BACK, 0.6))
	b.lathe([Vector2(0.09, 0), Vector2(0.05, 0.7)], 5, Tile.BARK, Vector3(0, 1.3, 0), Basis(Vector3.BACK, -0.5))
	var rng := _rng(21)
	for i in 5:
		var c := Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(1.8, 2.5), rng.randf_range(-0.9, 0.9))
		var r := rng.randf_range(0.5, 0.8)
		b.lathe([Vector2(0, -r * 0.6), Vector2(r, -r * 0.2), Vector2(r * 0.8, r * 0.4), Vector2(0, r * 0.6)], 6, Tile.LEAF, c)
	return b.commit()


## Смоковница: короткий ствол и широкая плоская крона.
static func _make_fig_tree() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0.15, 0), Vector2(0.12, 1.2)], 6, Tile.BARK)
	for i in 3:
		var a := TAU * i / 3.0
		b.lathe([Vector2(0.07, 0), Vector2(0.04, 1.0)], 5, Tile.BARK, Vector3(0, 1.1, 0), Basis(Vector3(cos(a), 0, sin(a)), 0.7))
	b.lathe([Vector2(0, 1.7), Vector2(1.5, 1.85), Vector2(1.4, 2.4), Vector2(0.6, 2.8), Vector2(0, 2.85)], 7, Tile.LEAF)
	return b.commit()


## Лоза на перголе: четыре столба, жерди сверху, листья комками.
static func _make_pergola() -> Mesh:
	var b := PB.new()
	for p in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)]:
		b.box(Vector3(p.x, 1.2, p.y), Vector3(0.1, 2.4, 0.1), Tile.WOOD)
	for z in [-1.2, -0.4, 0.4, 1.2]:
		b.box(Vector3(0, 2.42, z), Vector3(2.6, 0.06, 0.06), Tile.WOOD)
	b.lathe([Vector2(0.06, 0), Vector2(0.04, 2.4)], 5, Tile.BARK, Vector3(-1.1, 0, -1.1))
	var rng := _rng(25)
	for i in 9:
		var c := Vector3(rng.randf_range(-1.1, 1.1), 2.5, rng.randf_range(-1.1, 1.1))
		b.sheet(c, rng.randf_range(0.5, 0.9), rng.randf_range(0.5, 0.9), Tile.LEAF, Basis(Vector3.UP, rng.randf() * PI))
	return b.commit()


# ─── Римское (брошено у поста стражи) ────────────────────────────────────────

static func _make_shield() -> Mesh:
	var b := PB.new()
	# Овальный плоский щит ауксилия, лежит на земле
	b.lathe([Vector2(0, 0), Vector2(0.4, 0.0), Vector2(0.42, 0.03), Vector2(0.05, 0.06), Vector2(0, 0.06)], 8, Tile.CLOTH_RED,
		Vector3(0, 0.0, 0), Basis(), Vector2(0.7, 1.0))
	b.lathe([Vector2(0, 0), Vector2(0.08, 0), Vector2(0, 0.04)], 6, Tile.METAL, Vector3(0, 0.06, 0))
	return b.commit()


static func _make_helmet() -> Mesh:
	var b := PB.new()
	# Шлем типа Coolus: полусфера и назатыльник, на боку
	var tilt := Basis(Vector3.BACK, 1.3)
	b.lathe([Vector2(0.11, 0), Vector2(0.12, 0.05), Vector2(0.1, 0.12), Vector2(0.05, 0.16), Vector2(0, 0.17)], 7,
		Tile.METAL, Vector3(0, 0.11, 0), tilt)
	b.box(Vector3(-0.05, 0.03, 0.0), Vector3(0.12, 0.02, 0.2), Tile.METAL, tilt)
	return b.commit()


static func _make_spear() -> Mesh:
	var b := PB.new()
	# Прислонено к стене: точка — у стены, древко наклонено к ней
	var lean := Basis(Vector3.RIGHT, -0.2)
	b.box(Vector3(0, 1.0, -0.2), Vector3(0.04, 2.0, 0.04), Tile.WOOD, lean)
	b.box(lean * Vector3(0, 2.1, 0) + Vector3(0, 0, -0.2), Vector3(0.05, 0.25, 0.015), Tile.METAL, lean)
	return b.commit()


# ─── Интерьер ────────────────────────────────────────────────────────────────

static func _make_table_low() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.36, 0), Vector3(1.0, 0.05, 0.6), Tile.WOOD)
	for p in [Vector2(-0.42, -0.24), Vector2(0.42, -0.24), Vector2(0.42, 0.24), Vector2(-0.42, 0.24)]:
		b.box(Vector3(p.x, 0.17, p.y), Vector3(0.05, 0.34, 0.05), Tile.WOOD_DARK)
	return b.commit()


static func _make_stool() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.3, 0), Vector3(0.35, 0.04, 0.3), Tile.WOOD)
	for p in [Vector2(-0.13, -0.1), Vector2(0.13, -0.1), Vector2(0.13, 0.1), Vector2(-0.13, 0.1)]:
		b.box(Vector3(p.x, 0.14, p.y), Vector3(0.04, 0.28, 0.04), Tile.WOOD_DARK)
	return b.commit()


## Вертикальный ткацкий станок с грузилами: стойки, навой, полотно, глиняные грузила внизу.
static func _make_loom() -> Mesh:
	var b := PB.new()
	for x in [-0.65, 0.65]:
		b.box(Vector3(x, 0.9, 0), Vector3(0.08, 1.8, 0.08), Tile.WOOD, Basis(Vector3.RIGHT, -0.12))
	b.box(Vector3(0, 1.72, 0.1), Vector3(1.4, 0.07, 0.07), Tile.WOOD_DARK)
	b.quad(Vector3(-0.55, 1.68, 0.12), Vector3(0.55, 1.68, 0.12), Vector3(0.55, 0.55, -0.02), Vector3(-0.55, 0.55, -0.02),
		Tile.LINEN, true)
	for i in 8:
		var x := -0.5 + i * 0.143
		b.lathe([Vector2(0, 0), Vector2(0.03, 0.01), Vector2(0.03, 0.06), Vector2(0, 0.07)], 4, Tile.CLAY, Vector3(x, 0.45, -0.03))
	return b.commit()


## Глиняная печь-табун: купол с отверстием сверху.
static func _make_oven() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0.38, 0), Vector2(0.4, 0.25), Vector2(0.3, 0.5), Vector2(0.14, 0.6), Vector2(0.1, 0.58), Vector2(0.1, 0.4)],
		8, Tile.CLAY_DARK)
	b.box(Vector3(0, 0.12, -0.39), Vector3(0.22, 0.16, 0.04), Tile.BASALT)
	return b.commit()


## Ручные жернова: нижний и верхний камни из базальта, рукоять.
static func _make_quern() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.25, 0), Vector2(0.25, 0.1), Vector2(0, 0.12)], 8, Tile.BASALT)
	b.lathe([Vector2(0.04, 0.12), Vector2(0.22, 0.12), Vector2(0.22, 0.2), Vector2(0.05, 0.21)], 8, Tile.BASALT)
	b.box(Vector3(0.17, 0.26, 0), Vector3(0.03, 0.12, 0.03), Tile.WOOD)
	return b.commit()


## Устье цистерны: каменный круглый бортик и деревянная крышка.
static func _make_cistern() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0.55, 0), Vector2(0.55, 0.45), Vector2(0.4, 0.48), Vector2(0.38, 0.4)], 8, Tile.STONE)
	b.lathe([Vector2(0, 0.4), Vector2(0.4, 0.4), Vector2(0.4, 0.44), Vector2(0, 0.45)], 8, Tile.WOOD)
	return b.commit()
