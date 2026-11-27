class_name PropLibrary
extends RefCounted
## Библиотека предметов: лоуполи-меши строятся кодом, все на одном материале — атласе 256×384
## из 24 процедурных текстур 64×64 (глина, дерево, лён, солома, камень…). Поэтому весь «быт»
## куска уровня рисуется за один вызов. Меш каждого предмета строится один раз и кешируется.
## Предмет в редакторе — сцена res://scenes/props/prop.tscn (поле kind), все сразу — catalog.tscn.
## Новый предмет: функция _make_<имя>() ниже + строка в KINDS.
## Предметы-модели (models/prop_*.glb из Meshy, models/CREDITS.md «Предметы»): в KINDS поле "model" — имя файла;
## _make_<имя>() запекает меш модели в нужную позу (_model), материал — PS1 с текстурой модели
## (CharacterModel.material, как у светильника oil_lamp.glb), не атлас: такие предметы рисуются своим вызовом на кусок.

## Плитки атласа (4 в ряд, ATLAS_ROWS рядов по 64 пикселя).
enum Tile { CLAY, CLAY_DARK, WOOD, WOOD_DARK, LINEN, CLOTH_RED, CLOTH_BLUE, STRAW, SACK, STONE, BASALT, LEAF, BARK, METAL, FOOD, PALM,
	BLOOD, BLOOD_DARK, SHROUD, DUST, CLOTH_OCHRE, SOOT, IRON, COIN, SKIN, HAIR, GRASS, BLOOD_BLACK,
	# Полотнища рынка (без каймы — на сетке квадратов кайма повторялась бы полосами): выцветший красный, охра, грязно-белый
	CLOTH_FADED, CLOTH_SAND, CLOTH_WHITE }
const ATLAS_ROWS := 8

## Свойства предметов: collide — размер коробки коллизии (ноль — без неё, можно пройти/перешагнуть), collide_at — её сдвиг;
## mm — часто повторяется, рисуется через MultiMeshInstance3D; wall — вешается на стену (точка — у стены);
## glow — огоньки (Glows): [точка в координатах предмета, радиус м, яркость, true — виден издалека];
## model — меш и текстура из models/<model>.glb (материал свой, см. выше);
## also — что ставится вместе с предметом: [[вид, сдвиг в координатах предмета, поворот рад], …] (корзина под плодами,
## череп в оссуарии) — у части из модели и у части из атласа разные материалы, поэтому это два вида;
## smoke — дым (Glows): [точка, радиус клуба м].
## Масштаб — по человеку (герой 1,75 м): стол 0,7 м, табурет 0,45 м, большой кувшин 0,8 м, дверь 2,1 м;
## низкий стол для трапезы лёжа — 0,4 м. Всё видно рядом с фигурой героя в каталоге (scenes/props/catalog.tscn).
const KINDS := {
	# Быт
	"jar_small": {"collide": Vector3.ZERO, "mm": true},
	"jar_large": {"collide": Vector3(0.5, 0.75, 0.5)},
	"jug": {"collide": Vector3.ZERO, "mm": true},
	"stone_vessel": {"collide": Vector3.ZERO},
	"basket": {"collide": Vector3.ZERO, "model": "prop_basket"},
	"sack": {"collide": Vector3(0.45, 0.6, 0.45), "model": "prop_sack"},
	"mat_rolled": {"collide": Vector3.ZERO},
	"mat": {"collide": Vector3.ZERO},
	"lamp_niche": {"collide": Vector3.ZERO, "wall": true},
	"lamp_niche_lit": {"collide": Vector3.ZERO, "wall": true, "glow": [[Vector3(0.0, 1.385, -0.15), 0.07, 1.0]]},
	"rope_coil": {"collide": Vector3.ZERO},
	"laundry": {"collide": Vector3.ZERO},
	"herbs": {"collide": Vector3.ZERO, "wall": true},
	"table": {"collide": Vector3(1.1, 0.72, 0.65)},
	"mattress": {"collide": Vector3.ZERO},
	"pillow": {"collide": Vector3.ZERO},
	"bed": {"collide": Vector3(1.95, 0.6, 0.9)},
	"lamp_floor": {"collide": Vector3.ZERO, "mm": true},
	"lamp_floor_lit": {"collide": Vector3.ZERO, "glow": [[Vector3(0.0, 0.05, -0.085), 0.05, 0.9]]},
	"shutter": {"collide": Vector3.ZERO, "wall": true},
	# Рынок
	"stall": {"collide": Vector3(2.0, 1.0, 1.0)},
	"scales": {"collide": Vector3.ZERO},
	"weights": {"collide": Vector3.ZERO},
	"crate": {"collide": Vector3(0.6, 0.5, 0.5)},
	"fruit": {"collide": Vector3.ZERO, "mm": true},
	"basket_pomegranates": {"collide": Vector3.ZERO, "also": [["basket", Vector3.ZERO, 0.0]]},
	"basket_figs": {"collide": Vector3.ZERO, "also": [["basket", Vector3.ZERO, 0.0]]},
	"coins": {"collide": Vector3.ZERO, "mm": true},
	"stall_overturned": {"collide": Vector3(2.0, 0.9, 1.1)},
	# Полотнища на каркасах лотков и высыпанное зерно (полировка демо 4); точка — та же, что у лотка (stall), тот же поворот
	"stall_cloth_red": {"collide": Vector3.ZERO},
	"stall_cloth_ochre": {"collide": Vector3.ZERO},
	"stall_cloth_white": {"collide": Vector3.ZERO},
	"grain_spill": {"collide": Vector3.ZERO},
	"bread": {"collide": Vector3.ZERO, "mm": true},
	# Пасха
	"palm_branch": {"collide": Vector3.ZERO, "mm": true},
	"lamb_pen": {"collide": Vector3(2.2, 0.9, 1.6)},
	# Прерванная пасхальная трапеза: низкий стол, ложа, опресноки, чаши, горькие травы, кости ягнёнка
	"table_feast": {"collide": Vector3(2.0, 0.4, 0.9)},
	"couch": {"collide": Vector3(2.0, 0.5, 0.8)},
	"cushion": {"collide": Vector3.ZERO},
	"matzah": {"collide": Vector3.ZERO, "mm": true},
	"cup": {"collide": Vector3.ZERO, "mm": true},
	"cup_spilled": {"collide": Vector3.ZERO},
	"bitter_herbs": {"collide": Vector3.ZERO},
	"lamb_bones": {"collide": Vector3.ZERO},
	# Мастерская гончара
	"kiln": {"collide": Vector3(1.7, 1.7, 1.7), "glow": [[Vector3(0.0, 0.35, -0.86), 0.16, 1.1], [Vector3(0.0, 0.4, -0.95), 0.4, 0.35]],
		"smoke": [[Vector3(0.0, 1.9, 0.0), 0.7]]},
	"potters_wheel": {"collide": Vector3(0.7, 0.6, 0.7)},
	"pot_shelf": {"collide": Vector3(1.6, 1.8, 0.45), "collide_at": Vector3(0.0, 0.0, -0.23), "wall": true},
	"shard_heap": {"collide": Vector3.ZERO},
	# Следы землетрясения (Мф 27:51)
	"crack": {"collide": Vector3.ZERO, "wall": true},
	"rubble_block": {"collide": Vector3.ZERO, "mm": true},
	"beam": {"collide": Vector3.ZERO},
	"beam_leaning": {"collide": Vector3.ZERO},
	"shards": {"collide": Vector3.ZERO, "mm": true},
	# Следы людей
	"sandals": {"collide": Vector3.ZERO, "mm": true},
	"cloak": {"collide": Vector3.ZERO},
	"litter": {"collide": Vector3(1.9, 0.5, 0.7)},
	# Полотно, которым накрыли убитого: кладётся поверх тела-модели (Corpses: corpse_laid) в ту же точку
	"cover_cloth": {"collide": Vector3.ZERO},
	# Ужас: кровь (тёмно-бордовая, не красная), святые прошли — пелены и пыль
	"blood_pool": {"collide": Vector3.ZERO, "mat": "blood"},
	"blood_drag": {"collide": Vector3.ZERO, "mat": "blood"},
	"blood_steps": {"collide": Vector3.ZERO, "mat": "blood"},
	"blood_splatter": {"collide": Vector3.ZERO, "wall": true, "mat": "blood"},
	# Тела унесли: куски следа волочения 0,6 × 2,4 м (кладутся цепочкой, DRAG_TRAILS). Четыре рисунка на своей
	# текстуре с прозрачностью (trail_material): 1 — ровный след, 2 — с разрывом и отпечатком ладони, 3 — смаз,
	# 4 — борозды от пяток и отпечатки ступней
	"blood_trail_1": {"collide": Vector3.ZERO, "mm": true, "mat": "trail"},
	"blood_trail_2": {"collide": Vector3.ZERO, "mm": true, "mat": "trail"},
	"blood_trail_3": {"collide": Vector3.ZERO, "mm": true, "mat": "trail"},
	"blood_trail_4": {"collide": Vector3.ZERO, "mm": true, "mat": "trail"},
	# Забиты святыми: окровавленный камень и кирпич рядом с телом
	"stone_bloody": {"collide": Vector3.ZERO},
	"brick_bloody": {"collide": Vector3.ZERO},
	# Сожжены ангелом: кучка пепла с вещью внутри (пряжка римского пояса), выжженный силуэт на стене
	"ash_pile": {"collide": Vector3.ZERO},
	"scorch_silhouette": {"collide": Vector3.ZERO, "wall": true},
	# Рука свисает с края крыши (одноэтажный дом, парапет на 4,5 м); растоптанная корзина
	"hand_hanging": {"collide": Vector3.ZERO, "wall": true},
	"basket_crushed": {"collide": Vector3.ZERO, "mm": true, "model": "prop_basket"},
	"shroud_strip": {"collide": Vector3.ZERO},
	"burial_dust": {"collide": Vector3.ZERO},
	"table_overturned": {"collide": Vector3(1.1, 0.75, 0.65)},
	# Маленькие истории
	"shroud_pile": {"collide": Vector3.ZERO},
	"graffiti_greek": {"collide": Vector3.ZERO, "wall": true},
	"rope_cut": {"collide": Vector3.ZERO},
	"bucket": {"collide": Vector3.ZERO},
	"toy_bird": {"collide": Vector3.ZERO},
	"toy_cart": {"collide": Vector3.ZERO},
	"hearth_embers": {"collide": Vector3.ZERO,
		"glow": [[Vector3(0.05, 0.08, 0.0), 0.1, 0.8], [Vector3(-0.1, 0.07, 0.08), 0.07, 0.6], [Vector3(0.0, 0.1, -0.1), 0.06, 0.5]]},
	"bowl_food": {"collide": Vector3.ZERO},
	"ladder_fallen": {"collide": Vector3.ZERO},
	# Зелень в щелях и на крышах
	"grass_tuft": {"collide": Vector3.ZERO, "mm": true},
	"bush_small": {"collide": Vector3.ZERO},
	"herb_pot": {"collide": Vector3.ZERO},
	# Зелень
	"olive_tree": {"collide": Vector3(0.5, 2.0, 0.5)},
	"fig_tree": {"collide": Vector3(0.5, 2.0, 0.5)},
	"pergola": {"collide": Vector3.ZERO},
	# Римское
	"shield": {"collide": Vector3.ZERO, "model": "prop_shield"},
	"shield_leaning": {"collide": Vector3.ZERO, "wall": true, "model": "prop_shield"},
	"spear_broken": {"collide": Vector3.ZERO, "model": "prop_spear"},
	"helmet": {"collide": Vector3.ZERO},
	"spear": {"collide": Vector3.ZERO, "model": "prop_spear"},
	"spear_fallen": {"collide": Vector3.ZERO, "model": "prop_spear"},
	"caliga": {"collide": Vector3.ZERO, "mm": true},
	"brazier_overturned": {"collide": Vector3.ZERO,
		"glow": [[Vector3(0.5, 0.05, 0.2), 0.08, 0.7], [Vector3(0.8, 0.04, -0.1), 0.06, 0.5], [Vector3(0.35, 0.05, -0.25), 0.07, 0.6]]},
	"brazier_smoldering": {"collide": Vector3(0.6, 1.0, 0.6),
		"glow": [[Vector3(0.0, 1.03, 0.0), 0.22, 0.7, true], [Vector3(0.0, 1.15, 0.0), 0.6, 0.25, true]]},
	"brazier": {"collide": Vector3(0.6, 1.0, 0.6),
		"glow": [[Vector3(0.0, 1.05, 0.0), 0.3, 1.2, true], [Vector3(0.0, 1.3, 0.0), 0.9, 0.45, true]]},
	# Двери: кровавые отпечатки ладоней и царапины (на створке), мебель, которой заваливают дверь изнутри
	"blood_hands": {"collide": Vector3.ZERO, "wall": true},
	"curtain": {"collide": Vector3.ZERO},
	# Фасады: деревянная горница-балкон, навесы трёх цветов, решётка на окне, наружная лестница к горнице
	"balcony": {"collide": Vector3.ZERO, "wall": true},
	"awning_ochre": {"collide": Vector3.ZERO, "wall": true},
	"awning_blue": {"collide": Vector3.ZERO, "wall": true},
	"awning_red": {"collide": Vector3.ZERO, "wall": true},
	"window_grille": {"collide": Vector3.ZERO, "wall": true},
	"stair_ext": {"collide": Vector3(3.9, 3.3, 0.9), "collide_at": Vector3(0.3, 0.0, -0.45), "wall": true},
	"table_tipped": {"collide": Vector3.ZERO},
	"chest": {"collide": Vector3(0.9, 0.55, 0.5)},
	# Интерьер
	"table_low": {"collide": Vector3(1.0, 0.4, 0.6)},
	"stool": {"collide": Vector3.ZERO, "model": "prop_stool"},
	"loom": {"collide": Vector3(1.4, 1.8, 0.5)},
	"oven": {"collide": Vector3(0.8, 0.6, 0.8)},
	"quern": {"collide": Vector3.ZERO},
	"cistern": {"collide": Vector3(1.1, 0.5, 1.1)},
	# Предметы с физикой (этап 5, scripts/phys_prop.gd): один черепок, камень для броска, камень в руке святого
	"shard_piece": {"collide": Vector3.ZERO},
	"stone_throw": {"collide": Vector3.ZERO},
	"stone_held": {"collide": Vector3.ZERO},
	# Открытый оссуарий (маленькая история, CLAUDE.md §6): каменный ящик для костей, крышка сдвинута и лежит рядом,
	# внутри кости и череп (череп — модель, отдельным видом). Точка — у стены (задняя сторона ящика к +Z).
	"ossuary": {"collide": Vector3(0.62, 0.32, 0.32), "also": [["skull", Vector3(0.14, 0.13, 0.0), 2.6]]},
	"skull": {"collide": Vector3.ZERO, "model": "prop_skull"},
}

static var _material: ShaderMaterial
static var _meshes := {}


## Общий материал всех предметов (атлас).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = PsxMaterial.make(_atlas())
	return _material


## Материал предмета: у следов волочения — свой (текстура с прозрачностью), у моделей — своя текстура,
## у остальных — общий атлас.
static func material_for(kind: String) -> ShaderMaterial:
	var inf: Dictionary = KINDS.get(kind, {})
	if inf.has("model"):
		return CharacterModel.material(inf.model)
	match inf.get("mat", ""):
		"trail":
			return trail_material()
		"blood":
			return blood_material()
	return material()


static func mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		var m: Mesh = Callable(PropLibrary, "_make_" + kind).call()
		_meshes[kind] = m
	return _meshes[kind]


static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, {})


# ─── Предметы-модели ─────────────────────────────────────────────────────────

## Меш модели models/<name>.glb, запечённый в позу xf (поворот, сдвиг, масштаб — в координатах предмета).
static func _model(name: String, xf := Transform3D()) -> ArrayMesh:
	return _model_parts(name, [[xf, Vector2(-INF, INF)]])


## Несколько копий модели в одном меше: [[xf, от–до по X модели (Vector2)], …]. Отрезок по X режет треугольники
## по плоскости (обломки копья); срез не закрывается — на тонком древке дыры не видно.
## Нормалей в файлах нет — считаются заново, сглаженные (где у соседних треугольников общие вершина и uv).
static func _model_parts(name: String, parts: Array) -> ArrayMesh:
	var inst: Node = (load(CharacterModel.MODEL_DIR + name + ".glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var own := mi.transform
	inst.free()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in verts.size():
			idx.append(i)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var xf: Transform3D = (part[0] as Transform3D) * own
		var cut: Vector2 = part[1]
		for t in range(0, idx.size(), 3):
			# Вершина многоугольника: [точка, uv] в координатах модели
			var poly := []
			for k in 3:
				var i := idx[t + k]
				poly.append([verts[i], uvs[i]])
			if cut.x > -INF:
				poly = _clip_x(poly, cut.x, 1.0)
			if cut.y < INF and poly.size() >= 3:
				poly = _clip_x(poly, cut.y, -1.0)
			for k in range(1, poly.size() - 1):
				for v: Array in [poly[0], poly[k], poly[k + 1]]:
					st.set_uv(v[1])
					st.add_vertex(xf * (v[0] as Vector3))
	st.index()
	st.generate_normals()
	return st.commit()


## Отрезать от многоугольника всё, где side × (x − at) < 0 (Сазерленд — Ходжмен; uv — по интерполяции).
static func _clip_x(poly: Array, at: float, side: float) -> Array:
	var out := []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var da: float = side * ((a[0] as Vector3).x - at)
		var db: float = side * ((b[0] as Vector3).x - at)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var f := da / (da - db)
			out.append([(a[0] as Vector3).lerp(b[0], f), (a[1] as Vector2).lerp(b[1], f)])
	return out


## Череп без нижней челюсти (модель prop_skull, 0,2 м; лицо — к +Z). Ставится в оссуарий (KINDS ossuary: also).
static func _make_skull() -> Mesh:
	return _model("prop_skull")


## Оссуарий — известняковый ящик для костей 0,6 × 0,3 × 0,3 м (задняя стенка — к +Z, к стене), на передней стенке
## резьба: рамка и две шестилепестковые розетки (циркульные дуги, процарапаны тёмным). Крышка сдвинута и лежит
## на полу перед ящиком, одним краем на обломке. Внутри — кости (цилиндры с утолщениями) кучей; череп — отдельно (skull).
static func _make_ossuary() -> Mesh:
	var b := PB.new()
	var w := 0.6
	var d := 0.3
	var h := 0.3
	var t := 0.035
	# Дно и четыре стенки (тонкие ящики — внутренние грани видны сверху)
	b.box(Vector3(0, 0.02, 0), Vector3(w, 0.04, d), Tile.STONE)
	b.box(Vector3(0, h * 0.5, -d * 0.5 + t * 0.5), Vector3(w, h, t), Tile.STONE)
	b.box(Vector3(0, h * 0.5, d * 0.5 - t * 0.5), Vector3(w, h, t), Tile.STONE)
	b.box(Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), Vector3(t, h, d - t * 2.0), Tile.STONE)
	b.box(Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), Vector3(t, h, d - t * 2.0), Tile.STONE)
	# Ножки-выступы снизу по углам
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			b.box(Vector3(x * (w * 0.5 - 0.04), 0.01, z * (d * 0.5 - 0.03)), Vector3(0.07, 0.02, 0.05), Tile.STONE)
	# Резьба на передней стенке (лицо — −Z): канавки чуть выступают над гранью
	var fz := -d * 0.5 - 0.002
	var groove := func(p0: Vector2, p1: Vector2) -> void:
		var m := (p0 + p1) * 0.5
		var dir := p1 - p0
		b.box(Vector3(m.x, m.y, fz), Vector3(dir.length() + 0.006, 0.006, 0.004), Tile.BASALT,
			Basis(Vector3.BACK, atan2(dir.y, dir.x)))
	# Рамка
	var fr := [Vector2(-0.27, 0.035), Vector2(0.27, 0.035), Vector2(0.27, 0.27), Vector2(-0.27, 0.27)]
	for i in 4:
		groove.call(fr[i], fr[(i + 1) % 4])
	# Две розетки: окружность радиуса r и шесть дуг того же радиуса с центрами на ней
	for cx in [-0.13, 0.13]:
		var c := Vector2(cx, 0.152)
		var r := 0.085
		for i in 16:
			groove.call(c + Vector2.from_angle(TAU * i / 16.0) * r, c + Vector2.from_angle(TAU * (i + 1) / 16.0) * r)
		for k in 6:
			var q := c + Vector2.from_angle(TAU * k / 6.0) * r
			var a0 := TAU * k / 6.0 + PI * 2.0 / 3.0
			for j in 4:
				var p0 := q + Vector2.from_angle(a0 + (PI * 2.0 / 3.0) * j / 4.0) * r
				var p1 := q + Vector2.from_angle(a0 + (PI * 2.0 / 3.0) * (j + 1) / 4.0) * r
				groove.call(p0, p1)
	# Кости внутри: длинные (бедро, голень, плечо) кучей вдоль ящика, сверху несколько поперёк, мелкие
	var rng := _rng(311)
	var bones := [[0.44, 0.05, 0.0], [0.4, 0.06, 0.06], [0.36, 0.07, -0.06], [0.42, 0.11, 0.03], [0.3, 0.12, -0.04],
		[0.34, 0.15, 0.05], [0.26, 0.17, -0.02]]
	for i in bones.size():
		var bn: Array = bones[i]
		var bl: float = bn[0]
		var yaw := rng.randf_range(-0.25, 0.25) + (PI * 0.5 if i == 4 else 0.0)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.12, 0.12))
		var c := Vector3(rng.randf_range(-0.05, 0.05) if i != 4 else -0.15, bn[1], bn[2])
		if i == 4:
			bl = 0.2
		b.lathe([Vector2(0.0, -bl * 0.5), Vector2(0.022, -bl * 0.5), Vector2(0.026, -bl * 0.5 + 0.03),
			Vector2(0.012, -bl * 0.5 + 0.06), Vector2(0.011, bl * 0.5 - 0.06), Vector2(0.024, bl * 0.5 - 0.025),
			Vector2(0.02, bl * 0.5), Vector2(0.0, bl * 0.5)], 6, Tile.DUST, c, basis)
	for i in 8:
		var c := Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.09, 0.15), rng.randf_range(-0.09, 0.09))
		b.box(c, Vector3(0.05, 0.018, 0.022), Tile.DUST, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)))
	# Крышка: плоская плита с покатым верхом, сдвинута — лежит перед ящиком, одним краем на обломке
	var lid := Basis(Vector3.UP, 0.22) * Basis(Vector3.BACK, 0.09)
	var lc := Vector3(0.06, 0.05, -0.43)
	b.box(Vector3(0.33, 0.025, -0.47), Vector3(0.06, 0.05, 0.07), Tile.STONE, Basis(Vector3.UP, 0.6))
	b.box(lc, Vector3(w + 0.02, 0.035, d + 0.02), Tile.STONE, lid)
	b.box(lc + lid * Vector3(0, 0.03, 0), Vector3(w - 0.04, 0.025, d - 0.1), Tile.STONE, lid)
	return b.commit()


# ─── Атлас ───────────────────────────────────────────────────────────────────

static func _atlas() -> ImageTexture:
	var tiles := [
		ProcTextures.mottled(64, Color(0.62, 0.36, 0.22), 0.05, 0.1, 61),          # CLAY
		ProcTextures.mottled(64, Color(0.45, 0.25, 0.16), 0.05, 0.1, 62),          # CLAY_DARK
		_ph(ProcTextures.wood(64, 4, Color(0.5, 0.36, 0.22), 63), "old_wood_floor", Color(0.5, 0.36, 0.22), Vector2i.ZERO, true),  # WOOD
		_ph(ProcTextures.wood(64, 3, Color(0.3, 0.2, 0.13), 64), "dark_wooden_planks", Color(0.3, 0.2, 0.13), Vector2i.ZERO, true),  # WOOD_DARK
		_ph(ProcTextures.mottled(64, Color(0.82, 0.78, 0.68), 0.04, 0.08, 65), "jogging_melange", Color(0.82, 0.78, 0.68)),  # LINEN
		_ph(ProcTextures.hemmed_cloth(64, Color(0.55, 0.14, 0.12), 8, 66), "hessian_380", Color(0.55, 0.14, 0.12), Vector2i.ZERO, false, 8),  # CLOTH_RED
		ProcTextures.with_grain(ProcTextures.stripes(64, 8, Color(0.75, 0.7, 0.6), Color(0.22, 0.25, 0.5), 67), "hessian_380", 0.8, true),  # CLOTH_BLUE
		_ph(ProcTextures.checker(64, 16, Color(0.72, 0.6, 0.36), Color(0.58, 0.46, 0.26), 0.05, 68), "hessian_230", Color(0.7, 0.58, 0.34)),  # STRAW
		_ph(ProcTextures.mottled(64, Color(0.58, 0.5, 0.36), 0.08, 0.06, 69), "hessian_230", Color(0.58, 0.5, 0.36), Vector2i(64, 64)),  # SACK
		_ph(ProcTextures.mottled(64, Color(0.78, 0.74, 0.64), 0.04, 0.08, 70), "sandstone_blocks_04", Color(0.78, 0.74, 0.64), Vector2i(32, 32)),  # STONE
		ProcTextures.mottled(64, Color(0.28, 0.27, 0.27), 0.05, 0.08, 71),         # BASALT
		ProcTextures.mottled(64, Color(0.3, 0.42, 0.2), 0.08, 0.14, 72),           # LEAF
		ProcTextures.wood(64, 6, Color(0.36, 0.3, 0.24), 73),                      # BARK
		ProcTextures.mottled(64, Color(0.6, 0.45, 0.22), 0.06, 0.12, 74),          # METAL (бронза)
		ProcTextures.mottled(64, Color(0.72, 0.48, 0.24), 0.08, 0.1, 75),          # FOOD
		ProcTextures.stripes(64, 16, Color(0.56, 0.46, 0.26), Color(0.42, 0.33, 0.18), 76),  # PALM — увядшая, бурая
		ProcTextures.mottled(64, Color(0.42, 0.045, 0.05), 0.05, 0.14, 77),        # BLOOD — тёмно-красная
		ProcTextures.mottled(64, Color(0.31, 0.035, 0.042), 0.05, 0.12, 78),       # BLOOD_DARK — запёкшаяся
		ProcTextures.with_grain(ProcTextures.stripes(64, 6, Color(0.86, 0.84, 0.78), Color(0.72, 0.7, 0.64), 79), "jogging_melange", 1.0, true),  # SHROUD — погребальные пелены
		ProcTextures.mottled(64, Color(0.82, 0.81, 0.77), 0.05, 0.12, 80),         # DUST — погребальная пыль
		_ph(ProcTextures.hemmed_cloth(64, Color(0.68, 0.48, 0.2), 6, 81), "hessian_380", Color(0.68, 0.48, 0.2), Vector2i(64, 0), false, 6),  # CLOTH_OCHRE
		ProcTextures.mottled(64, Color(0.045, 0.04, 0.035), 0.03, 0.05, 82),       # SOOT — тёмное углубление, копоть
		ProcTextures.mottled(64, Color(0.24, 0.22, 0.21), 0.06, 0.1, 83),          # IRON
		ProcTextures.mottled(64, Color(0.74, 0.72, 0.64), 0.08, 0.1, 84),          # COIN — серебро
		ProcTextures.mottled(64, Color(0.62, 0.45, 0.34), 0.03, 0.06, 85),         # SKIN
		ProcTextures.mottled(64, Color(0.13, 0.1, 0.08), 0.04, 0.06, 86),          # HAIR
		ProcTextures.stripes(64, 10, Color(0.38, 0.42, 0.2), Color(0.5, 0.48, 0.26), 87),  # GRASS — сухая трава
		ProcTextures.mottled(64, Color(0.22, 0.026, 0.032), 0.03, 0.08, 88),      # BLOOD_BLACK — самая тёмная, но не чёрная
		_ph(ProcTextures.mottled(64, Color(0.5, 0.2, 0.17), 0.04, 0.12, 91), "hessian_380", Color(0.5, 0.2, 0.17), Vector2i(0, 64)),  # CLOTH_FADED
		_ph(ProcTextures.mottled(64, Color(0.66, 0.5, 0.24), 0.04, 0.1, 92), "hessian_380", Color(0.66, 0.5, 0.24), Vector2i(64, 64)),  # CLOTH_SAND
		_ph(ProcTextures.mottled(64, Color(0.7, 0.66, 0.55), 0.05, 0.16, 93), "hessian_230", Color(0.7, 0.66, 0.55), Vector2i(0, 64)),  # CLOTH_WHITE
	]
	var img := Image.create_empty(256, 64 * ATLAS_ROWS, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t: Image = (tiles[i] as ImageTexture).get_image()
		t.convert(Image.FORMAT_RGB8)
		img.blit_rect(t, Rect2i(0, 0, 64, 64), Vector2i((i % 4) * 64, (i / 4) * 64))
	return ImageTexture.create_from_image(img)


## Плитка атласа из фото (кусок 64×64 в родном разрешении — ~0,5–1,5 м поверхности, по размеру предметов),
## средний цвет подогнан к target; hem — тёмная кайма снизу (подол, край навеса). Не прочиталось фото — fallback.
static func _ph(fallback: ImageTexture, name: String, target: Color, origin := Vector2i.ZERO, rotate := false,
		hem := 0) -> ImageTexture:
	var t := ProcTextures.photo_tile(name, 64, target, origin, 1.0, rotate)
	if t == null:
		return fallback
	if hem == 0:
		return t
	var img := t.get_image()
	for y in range(64 - hem, 64):
		for x in 64:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35))
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
		return Vector2((tile % 4 + u) / 4.0, (tile / 4 + v) / float(ATLAS_ROWS))

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


## Построитель децалей крови: плоские квадраты с одной текстурой пятна (blood_material), вершинный цвет — прозрачность.
class DB:
	var st := SurfaceTool.new()
	var xf := Transform3D()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _quad(p: Array, n: Vector3, a: float, flip: bool) -> void:
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		if flip:
			uvs = [Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(1.0, 1.0, 1.0, a))
			st.set_normal(xf.basis * n)
			st.set_uv(uvs[k])
			st.add_vertex(xf * (p[k] as Vector3))

	## Пятно на полу: центр, размер (по x и по z), поворот вокруг Y, прозрачность, зеркало текстуры.
	func floor_spot(c: Vector3, w: float, l: float, yaw := 0.0, a := 1.0, flip := false) -> void:
		var rot := Basis(Vector3.UP, yaw)
		var hw := w * 0.5
		var hl := l * 0.5
		_quad([c + rot * Vector3(-hw, 0, -hl), c + rot * Vector3(hw, 0, -hl), c + rot * Vector3(hw, 0, hl),
			c + rot * Vector3(-hw, 0, hl)], Vector3.UP, a, flip)

	## Пятно на стене (смотрит в +Z, xf разворачивает): центр (x, y), размер, отступ от стены z, поворот в плоскости.
	func wall_spot(c: Vector2, w: float, h: float, z: float, rot := 0.0, a := 1.0) -> void:
		var r := Basis(Vector3.BACK, rot)
		var hw := w * 0.5
		var hh := h * 0.5
		var o := Vector3(c.x, c.y, z)
		_quad([o + r * Vector3(-hw, hh, 0), o + r * Vector3(hw, hh, 0), o + r * Vector3(hw, -hh, 0),
			o + r * Vector3(-hw, -hh, 0)], Vector3.BACK, a, false)

	func commit() -> Mesh:
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


## Корзина (модель prop_basket: Ø 0,41, выс. 0,32).
static func _make_basket() -> Mesh:
	return _model("prop_basket")


## Мешок с зерном, завязан (модель prop_sack, выс. 0,6).
static func _make_sack() -> Mesh:
	return _model("prop_sack")


static func _make_mat_rolled() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, -0.45), Vector2(0.11, -0.45), Vector2(0.11, 0.45), Vector2(0, 0.45)], 6, Tile.STRAW,
		Vector3(0, 0.11, 0), Basis(Vector3.BACK, PI * 0.5))
	return b.commit()


static func _make_mat() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.01, 0), Vector3(1.8, 0.02, 0.9), Tile.STRAW)
	return b.commit()


## Ниша для светильника: тёмное углубление в стене (копоть), каменная рамка и полка, на полке — светильник.
## Точка — у стены на высоте 0, ниша смотрит в −Z. Горящий вариант — lamp_niche_lit (огонёк из KINDS).
static func _make_lamp_niche() -> Mesh:
	var b := PB.new()
	# Тёмное «углубление» и копоть над ним
	b.box(Vector3(0, 1.52, -0.012), Vector3(0.36, 0.38, 0.02), Tile.SOOT)
	b.box(Vector3(0, 1.88, -0.008), Vector3(0.24, 0.2, 0.012), Tile.SOOT)
	# Рамка из светлого тёсаного камня и выступающая полка
	b.box(Vector3(0, 1.31, -0.08), Vector3(0.54, 0.07, 0.17), Tile.STONE)
	b.box(Vector3(-0.23, 1.53, -0.035), Vector3(0.08, 0.42, 0.07), Tile.STONE)
	b.box(Vector3(0.23, 1.53, -0.035), Vector3(0.08, 0.42, 0.07), Tile.STONE)
	b.box(Vector3(0, 1.75, -0.035), Vector3(0.54, 0.08, 0.07), Tile.STONE)
	# Светильник: круглое тело и носик (к огоньку)
	b.lathe([Vector2(0, 0), Vector2(0.045, 0), Vector2(0.055, 0.02), Vector2(0.025, 0.04), Vector2(0, 0.035)], 6,
		Tile.CLAY, Vector3(0, 1.345, -0.09))
	b.box(Vector3(0, 1.365, -0.13), Vector3(0.035, 0.018, 0.06), Tile.CLAY)
	return b.commit()


static func _make_lamp_niche_lit() -> Mesh:
	return _make_lamp_niche()


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


## Пучки сушёных трав вниз головой на гвоздях (под навесом, ~2 м): веер буро-зелёных стеблей,
## перевязанных бечёвкой у верхушки, метёлки расходятся книзу.
static func _make_herbs() -> Mesh:
	var b := PB.new()
	var rng := _rng(59)
	b.box(Vector3(0, 2.05, -0.03), Vector3(0.75, 0.03, 0.03), Tile.WOOD_DARK)
	for i in 3:
		var x := -0.24 + i * 0.24
		var len := 0.34 + (i % 2) * 0.1
		var top := Vector3(x, 1.93, -0.07)
		# Бечёвка с гвоздя и перевязка
		b.box(Vector3(x, 1.99, -0.05), Vector3(0.008, 0.1, 0.008), Tile.SACK)
		b.box(top, Vector3(0.045, 0.03, 0.035), Tile.SACK)
		# Стебли веером: узкие полоски от перевязки вниз и в стороны
		for k in 7:
			var spread := (k - 3) * 0.028 + rng.randf_range(-0.01, 0.01)
			var bottom := top + Vector3(spread * 2.2, -len * rng.randf_range(0.8, 1.0), rng.randf_range(-0.04, 0.03))
			var w := 0.012 + rng.randf() * 0.01
			b.quad(top + Vector3(spread * 0.3 - w * 0.5, 0, 0), top + Vector3(spread * 0.3 + w * 0.5, 0, 0),
				bottom + Vector3(w, 0, 0), bottom - Vector3(w, 0, 0), Tile.PALM if k % 3 else Tile.STRAW, true)
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


## Полотнище поверх каркаса лотка (то же место и поворот, что у stall): провисает, края рваные — дыры, оторванный
## угол; спереди свисает кайма неровной длины. Лежит на 6–10 см выше синей ткани лотка, чтобы грани не слипались.
static func _stall_cloth(tile: int, seed: int) -> Mesh:
	var b := PB.new()
	var rng := _rng(seed)
	var nx := 6
	var nz := 4
	var x0 := -1.2
	var x1 := 1.2
	var z0 := 0.66
	var z1 := -0.9
	var grid := []
	for j in nz + 1:
		var row := []
		var v := float(j) / nz
		var z := lerpf(z0, z1, v)
		for i in nx + 1:
			var u := float(i) / nx
			var edge := i == 0 or i == nx or j == nz
			var jit := 0.06 if edge else 0.0
			var y := 2.12 + (z - 0.55) * 0.3077 - 0.05 * sin(PI * u) * sin(PI * v) + rng.randf_range(-0.012, 0.012)
			row.append(Vector3(lerpf(x0, x1, u) + rng.randf_range(-jit, jit), y, z + rng.randf_range(-jit, jit)))
		grid.append(row)
	for j in nz:
		for i in nx:
			# Рваная ткань: по краю пропуски, задний угол оторван
			var boundary := i == 0 or i == nx - 1 or j == nz - 1
			if (boundary and rng.randf() < 0.22) or (i == nx - 1 and j == nz - 1):
				continue
			b.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], tile, true)
	# Кайма спереди: полосы разной длины, одна почти оборвана
	var yf := 2.12 + (z0 - 0.55) * 0.3077
	var vn := 6
	var drops := []
	for i in vn + 1:
		drops.append(rng.randf_range(0.2, 0.55))
	drops[2] = 0.1
	drops[3] = 0.14
	for i in vn:
		var xa := lerpf(x0, x1, float(i) / vn)
		var xb := lerpf(x0, x1, float(i + 1) / vn)
		b.quad(Vector3(xa, yf, z0 + 0.01), Vector3(xb, yf, z0 + 0.01), Vector3(xb, yf - drops[i + 1], z0 + 0.07),
			Vector3(xa, yf - drops[i], z0 + 0.07), tile, true)
	return b.commit()


static func _make_stall_cloth_red() -> Mesh:
	return _stall_cloth(Tile.CLOTH_FADED, 301)


static func _make_stall_cloth_ochre() -> Mesh:
	return _stall_cloth(Tile.CLOTH_SAND, 302)


static func _make_stall_cloth_white() -> Mesh:
	return _stall_cloth(Tile.CLOTH_WHITE, 303)


## Высыпанное зерно: неровное пятно соломенного цвета и россыпь зёрен вокруг.
static func _make_grain_spill() -> Mesh:
	var b := PB.new()
	var rng := _rng(311)
	_blob(b, Vector3(0.0, 0.012, 0.0), 0.34, 0.27, Tile.STRAW, 312, 8)
	for i in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.15, 0.62)
		b.box(Vector3(cos(a) * r, 0.008, sin(a) * r * 0.8), Vector3(0.035, 0.012, 0.03), Tile.STRAW if i % 3 else Tile.FOOD,
			Basis(Vector3.UP, rng.randf() * PI))
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
	# Лицом в +Z и разворот на 180°: лицевая сторона смотрит в −Z, от стены
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var p := Vector3(0, 0.2, 0.015)
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

static func _make_helmet() -> Mesh:
	var b := PB.new()
	# Шлем типа Coolus: полусфера и назатыльник, на боку
	var tilt := Basis(Vector3.BACK, 1.3)
	b.lathe([Vector2(0.11, 0), Vector2(0.12, 0.05), Vector2(0.1, 0.12), Vector2(0.05, 0.16), Vector2(0, 0.17)], 7,
		Tile.METAL, Vector3(0, 0.11, 0), tilt)
	b.box(Vector3(-0.05, 0.03, 0.0), Vector3(0.12, 0.02, 0.2), Tile.METAL, tilt)
	return b.commit()


## Копьё прислонено к стене: точка — у стены, древко наклонено к ней (модель prop_spear: вдоль X, наконечник — +X).
static func _make_spear() -> Mesh:
	var lean := Basis(Vector3.RIGHT, -0.2)
	return _model("prop_spear", Transform3D(lean * Basis(Vector3.BACK, PI * 0.5), lean * Vector3(0.0, 0.99, 0.0)))


## Копьё, упавшее на мостовую: вдоль Z, наконечник — к −Z.
static func _make_spear_fallen() -> Mesh:
	return _model("prop_spear", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.002, 0.0)))


## Калига: солдатская сандалия на толстой подошве с ремешками, слетела с ноги на бегу.
static func _make_caliga() -> Mesh:
	var b := PB.new()
	var tilt := Basis(Vector3.BACK, 0.25)
	b.box(Vector3(0, 0.025, 0), Vector3(0.11, 0.035, 0.28), Tile.WOOD_DARK, tilt)
	for z in [-0.08, -0.01, 0.06]:
		b.box(Vector3(0, 0.06, z), Vector3(0.12, 0.05, 0.025), Tile.SACK, tilt)
	b.box(Vector3(0, 0.1, 0.11), Vector3(0.1, 0.09, 0.04), Tile.SACK, tilt)
	return b.commit()


## Жаровня на треноге: железная чаша с углями. Огонь — огоньки из KINDS.
static func _make_brazier() -> Mesh:
	var b := PB.new()
	for i in 3:
		var a := TAU * i / 3.0
		b.box(Vector3(cos(a) * 0.2, 0.42, sin(a) * 0.2), Vector3(0.04, 0.9, 0.04), Tile.IRON,
			Basis(Vector3(-sin(a), 0, cos(a)), -0.18))
	b.lathe([Vector2(0.08, 0.82), Vector2(0.3, 0.9), Vector2(0.34, 1.02), Vector2(0.3, 1.0), Vector2(0, 0.95)], 8, Tile.IRON)
	b.lathe([Vector2(0.28, 0.99), Vector2(0.15, 1.06), Vector2(0, 1.07)], 7, Tile.CLAY_DARK)
	return b.commit()


# ─── Двери: кровь, завалы ────────────────────────────────────────────────────

## Неровное пятно на вертикальной плоскости (лицом в +Z до разворота b.xf): веер треугольников с рваным краем.
static func _blob_v(b: PB, center: Vector2, rx: float, ry: float, z: float, tile: int, seed: int, points: int = 8) -> void:
	var rng := _rng(seed)
	var ring := []
	for i in points:
		var a := TAU * i / points
		var k := rng.randf_range(0.6, 1.2)
		ring.append(Vector3(center.x + cos(a) * rx * k, center.y + sin(a) * ry * k, z))
	var c3 := Vector3(center.x, center.y, z)
	for i in points:
		b.quad(c3, ring[(i + 1) % points], ring[i], c3, tile)


## Кровавые отпечатки ладоней, царапины и потёки на створке. Точка — на поверхности, смотрит в −Z.
static func _make_blood_hands() -> Mesh:
	var b := PB.new()
	var rng := _rng(31)
	# Рисуем лицом в +Z и разворачиваем на 180°: лицевая сторона смотрит в −Z, от стены
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var z := 0.004
	var hands := [Vector3(-0.18, 1.32, 0.15), Vector3(0.1, 1.48, -0.1), Vector3(0.22, 1.1, 0.3), Vector3(-0.05, 0.95, -0.25)]
	for hnd: Vector3 in hands:
		_hand(b, Vector2(hnd.x, hnd.y), hnd.z, z, Tile.BLOOD)
	# Царапины: пучки тонких полос сверху вниз
	for i in 5:
		var x := -0.3 + i * 0.05 + rng.randf_range(-0.01, 0.01)
		var top := rng.randf_range(1.5, 1.75)
		var bot := top - rng.randf_range(0.12, 0.25)
		b.quad(Vector3(x - 0.006, top, z), Vector3(x + 0.006, top, z), Vector3(x + 0.02 + 0.006, bot, z), Vector3(x + 0.02 - 0.006, bot, z),
			Tile.BLOOD_DARK)
	# Потёки вниз от ладоней
	for hnd: Vector3 in hands:
		var len := rng.randf_range(0.06, 0.16)
		b.quad(Vector3(hnd.x - 0.012, hnd.y - 0.05, z), Vector3(hnd.x + 0.012, hnd.y - 0.05, z),
			Vector3(hnd.x + 0.006, hnd.y - 0.05 - len, z), Vector3(hnd.x - 0.006, hnd.y - 0.05 - len, z), Tile.BLOOD)
	return b.commit()


## Отпечаток ладони: ладонь, четыре пальца, большой палец; angle — наклон, z — смещение от поверхности.
static func _hand(b: PB, at: Vector2, angle: float, z: float, tile: int) -> void:
	var rot := func(p: Vector2) -> Vector3:
		var q := p.rotated(angle) + at
		return Vector3(q.x, q.y, z)
	var rect := func(c: Vector2, w: float, h: float) -> void:
		b.quad(rot.call(c + Vector2(-w, h)), rot.call(c + Vector2(w, h)), rot.call(c + Vector2(w, -h)), rot.call(c + Vector2(-w, -h)), tile)
	rect.call(Vector2.ZERO, 0.045, 0.05)
	for i in 4:
		rect.call(Vector2(-0.033 + i * 0.022, 0.09 - absf(i - 1.5) * 0.008), 0.008, 0.04)
	rect.call(Vector2(0.06, 0.02), 0.009, 0.03)


## Столик, опрокинутый на бок, — им подпёрли дверь изнутри.
static func _make_table_tipped() -> Mesh:
	var b := PB.new()
	var tip := Basis(Vector3.RIGHT, PI * 0.5)
	b.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.05, 0.6), Tile.WOOD, tip)
	for x in [-0.42, 0.42]:
		for y in [0.06, 0.54]:
			b.box(Vector3(x, y, 0.2), Vector3(0.05, 0.05, 0.36), Tile.WOOD_DARK)
	return b.commit()


## Деревянный сундук с обитыми углами.
static func _make_chest() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.5), Tile.WOOD_DARK)
	b.box(Vector3(0, 0.52, 0), Vector3(0.92, 0.05, 0.52), Tile.WOOD)
	for x in [-0.43, 0.43]:
		b.box(Vector3(x, 0.27, 0), Vector3(0.05, 0.52, 0.53), Tile.IRON)
	return b.commit()


# ─── Интерьер ────────────────────────────────────────────────────────────────

static func _make_table_low() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.36, 0), Vector3(1.0, 0.05, 0.6), Tile.WOOD)
	for p in [Vector2(-0.42, -0.24), Vector2(0.42, -0.24), Vector2(0.42, 0.24), Vector2(-0.42, 0.24)]:
		b.box(Vector3(p.x, 0.17, p.y), Vector3(0.05, 0.34, 0.05), Tile.WOOD_DARK)
	return b.commit()


## Табурет 0,46 м (модель prop_stool).
static func _make_stool() -> Mesh:
	return _model("prop_stool")


## Стол 0,7 м (кухня, мастерская, дом).
static func _make_table() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.68, 0), Vector3(1.1, 0.05, 0.65), Tile.WOOD)
	for p in [Vector2(-0.48, -0.26), Vector2(0.48, -0.26), Vector2(0.48, 0.26), Vector2(-0.48, 0.26)]:
		b.box(Vector3(p.x, 0.33, p.y), Vector3(0.06, 0.66, 0.06), Tile.WOOD_DARK)
	b.box(Vector3(0, 0.15, 0), Vector3(0.96, 0.04, 0.04), Tile.WOOD_DARK)
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


# ─── Сон: тюфяки, подушки, ложе ──────────────────────────────────────────────

## Тюфяк на полу, развёрнутый: набитый соломой мешок, сверху сбитое одеяло и подушка.
static func _make_mattress() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.05, 0), Vector3(0.75, 0.1, 1.8), Tile.SACK)
	b.box(Vector3(0.03, 0.115, 0.2), Vector3(0.72, 0.04, 1.1), Tile.CLOTH_BLUE, Basis(Vector3.UP, 0.08))
	b.box(Vector3(0.12, 0.15, 0.55), Vector3(0.45, 0.06, 0.3), Tile.CLOTH_BLUE, Basis(Vector3.FORWARD, 0.25))
	b.box(Vector3(0, 0.14, -0.7), Vector3(0.5, 0.1, 0.3), Tile.LINEN)
	return b.commit()


static func _make_pillow() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.06, 0), Vector3(0.5, 0.12, 0.32), Tile.CLOTH_RED, Basis(Vector3.UP, 0.2))
	return b.commit()


## Деревянное ложе в богатом доме: рама на ножках, тюфяк, покрывало, валик под голову.
static func _make_bed() -> Mesh:
	var b := PB.new()
	for p in [Vector2(-0.4, -0.9), Vector2(0.4, -0.9), Vector2(0.4, 0.9), Vector2(-0.4, 0.9)]:
		b.box(Vector3(p.x, 0.22, p.y), Vector3(0.07, 0.44, 0.07), Tile.WOOD_DARK)
	b.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.06, 1.9), Tile.WOOD)
	b.box(Vector3(0, 0.5, 0), Vector3(0.82, 0.14, 1.8), Tile.LINEN)
	b.box(Vector3(0, 0.585, 0.25), Vector3(0.86, 0.04, 1.3), Tile.CLOTH_RED)
	b.lathe([Vector2(0, -0.38), Vector2(0.1, -0.38), Vector2(0.1, 0.38), Vector2(0, 0.38)], 6, Tile.LINEN,
		Vector3(0, 0.66, -0.75), Basis(Vector3.BACK, PI * 0.5))
	b.box(Vector3(0, 0.62, -0.95), Vector3(0.9, 0.3, 0.06), Tile.WOOD_DARK)
	return b.commit()


## Глиняный светильник на полу (носик в −Z).
static func _make_lamp_floor() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.05, 0.02), Vector2(0.022, 0.038), Vector2(0, 0.033)], 6, Tile.CLAY)
	b.box(Vector3(0, 0.022, -0.055), Vector3(0.032, 0.018, 0.06), Tile.CLAY)
	return b.commit()


static func _make_lamp_floor_lit() -> Mesh:
	return _make_lamp_floor()


# ─── Рынок ───────────────────────────────────────────────────────────────────

## Корзина гранатов: тёмно-красные шары горкой.
static func _make_basket_pomegranates() -> Mesh:
	return _fruit_basket(Tile.CLOTH_RED, 0.055, 41)


## Корзина смокв: мелкие тёмные плоды.
static func _make_basket_figs() -> Mesh:
	return _fruit_basket(Tile.BASALT, 0.035, 43)


## Плоды горкой; сама корзина — модель (вид basket, KINDS: also), её край — на 0,32 м.
static func _fruit_basket(tile: int, r: float, seed: int) -> Mesh:
	var b := PB.new()
	var rng := _rng(seed)
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf() * 0.15
		var y := 0.26 + (0.15 - d) * 0.4 + rng.randf() * 0.03
		b.lathe([Vector2(0, -r), Vector2(r, -r * 0.3), Vector2(r * 0.9, r * 0.5), Vector2(0, r)], 5, tile,
			Vector3(cos(a) * d, y, sin(a) * d))
	return b.commit()


## Рассыпанные монеты: серебряные и бронзовые кружки на мостовой.
static func _make_coins() -> Mesh:
	var b := PB.new()
	var rng := _rng(47)
	for i in 14:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.45)
		b.lathe([Vector2(0, 0), Vector2(0.012, 0), Vector2(0.012, 0.004), Vector2(0, 0.004)], 5,
			Tile.COIN if i % 3 else Tile.METAL, Vector3(cos(a) * d, 0.003, sin(a) * d))
	return b.commit()


# ─── Пасхальная трапеза ──────────────────────────────────────────────────────

## Низкий стол для трапезы лёжа (0,4 м).
static func _make_table_feast() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.38, 0), Vector3(2.0, 0.05, 0.9), Tile.WOOD)
	for p in [Vector2(-0.9, -0.38), Vector2(0.9, -0.38), Vector2(0.9, 0.38), Vector2(-0.9, 0.38)]:
		b.box(Vector3(p.x, 0.18, p.y), Vector3(0.07, 0.36, 0.07), Tile.WOOD_DARK)
	return b.commit()


## Ложе для трапезы: деревянное основание, тюфяк, валик.
static func _make_couch() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.2, 0), Vector3(2.0, 0.4, 0.8), Tile.WOOD_DARK)
	b.box(Vector3(0, 0.45, 0), Vector3(1.95, 0.1, 0.76), Tile.CLOTH_RED)
	b.lathe([Vector2(0, -0.36), Vector2(0.09, -0.36), Vector2(0.09, 0.36), Vector2(0, 0.36)], 6, Tile.LINEN,
		Vector3(-0.85, 0.58, 0), Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI * 0.5))
	return b.commit()


## Подушка, сброшенная на пол.
static func _make_cushion() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.07, 0), Vector3(0.55, 0.14, 0.45), Tile.CLOTH_BLUE, Basis(Vector3.FORWARD, 0.15))
	return b.commit()


## Опреснок — тонкая пресная лепёшка.
static func _make_matzah() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.11, 0), Vector2(0.115, 0.008), Vector2(0, 0.012)], 7, Tile.FOOD)
	return b.commit()


static func _make_cup() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.045, 0.06), Vector2(0.05, 0.09), Vector2(0.04, 0.085), Vector2(0, 0.02)], 6,
		Tile.CLAY)
	return b.commit()


## Опрокинутая чаша и лужица вина.
static func _make_cup_spilled() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.045, 0.06), Vector2(0.05, 0.09), Vector2(0.04, 0.085), Vector2(0, 0.02)], 6,
		Tile.CLAY, Vector3(0, 0.045, 0), Basis(Vector3.BACK, PI * 0.5))
	_blob(b, Vector3(-0.2, 0.002, 0.05), 0.18, 0.1, Tile.BLOOD_DARK, 49)
	return b.commit()


## Горькие травы на блюде.
static func _make_bitter_herbs() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.14, 0.0), Vector2(0.15, 0.025), Vector2(0, 0.015)], 7, Tile.CLAY)
	var rng := _rng(51)
	for i in 6:
		var a := rng.randf() * TAU
		b.sheet(Vector3(cos(a) * 0.05, 0.03 + i * 0.004, sin(a) * 0.05), 0.06, 0.14, Tile.LEAF, Basis(Vector3.UP, a))
	return b.commit()


## Кости ягнёнка на блюде.
static func _make_lamb_bones() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.17, 0.0), Vector2(0.18, 0.025), Vector2(0, 0.015)], 7, Tile.CLAY_DARK)
	var rng := _rng(53)
	for i in 5:
		var a := rng.randf() * PI
		var c := Vector3(rng.randf_range(-0.08, 0.08), 0.035, rng.randf_range(-0.06, 0.06))
		b.box(c, Vector3(0.022, 0.022, 0.16), Tile.LINEN, Basis(Vector3.UP, a))
		b.box(c + Basis(Vector3.UP, a) * Vector3(0, 0, 0.08), Vector3(0.035, 0.03, 0.03), Tile.LINEN)
	return b.commit()


# ─── Гончар ──────────────────────────────────────────────────────────────────

## Печь для обжига: высокий глиняный купол, топка внизу (смотрит в −Z, там светятся угли), дым — из KINDS.
static func _make_kiln() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0.85, 0), Vector2(0.88, 0.6), Vector2(0.75, 1.2), Vector2(0.45, 1.6), Vector2(0.25, 1.75), Vector2(0.2, 1.8),
		Vector2(0.15, 1.6)], 9, Tile.CLAY_DARK)
	# Топка — тёмный проём с каменной рамкой
	b.box(Vector3(0, 0.35, -0.84), Vector3(0.5, 0.45, 0.06), Tile.SOOT)
	b.box(Vector3(0, 0.62, -0.86), Vector3(0.66, 0.09, 0.1), Tile.STONE)
	for x in [-0.29, 0.29]:
		b.box(Vector3(x, 0.32, -0.86), Vector3(0.09, 0.62, 0.1), Tile.STONE)
	# Поленья у топки
	for i in 3:
		b.box(Vector3(-0.6 + i * 0.12, 0.06 + (i % 2) * 0.1, -1.0), Vector3(0.1, 0.1, 0.7), Tile.BARK, Basis(Vector3.UP, 0.4))
	return b.commit()


## Гончарный круг: нижний маховик, ось, верхний круг с недоделанным горшком.
static func _make_potters_wheel() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0.02), Vector2(0.33, 0.02), Vector2(0.33, 0.1), Vector2(0, 0.1)], 9, Tile.WOOD_DARK)
	b.box(Vector3(0, 0.3, 0), Vector3(0.05, 0.42, 0.05), Tile.WOOD)
	b.lathe([Vector2(0, 0.5), Vector2(0.2, 0.5), Vector2(0.2, 0.55), Vector2(0, 0.55)], 8, Tile.WOOD)
	b.lathe([Vector2(0, 0.55), Vector2(0.08, 0.55), Vector2(0.1, 0.62), Vector2(0.07, 0.7), Vector2(0.05, 0.69), Vector2(0, 0.6)], 6, Tile.CLAY)
	b.box(Vector3(0.45, 0.22, 0), Vector3(0.3, 0.44, 0.3), Tile.WOOD)
	return b.commit()


## Полки у стены с горшками (точка — у стены, полки смотрят в −Z).
static func _make_pot_shelf() -> Mesh:
	var b := PB.new()
	b.xf = Transform3D(Basis(), Vector3(0, 0, -0.23))
	for x in [-0.78, 0.78]:
		b.box(Vector3(x, 0.9, 0), Vector3(0.06, 1.8, 0.42), Tile.WOOD_DARK)
	var rng := _rng(55)
	for k in 3:
		var y := 0.35 + k * 0.6
		b.box(Vector3(0, y, 0), Vector3(1.6, 0.04, 0.42), Tile.WOOD)
		var x := -0.6
		while x < 0.65:
			var h := rng.randf_range(0.14, 0.3)
			var r := rng.randf_range(0.07, 0.12)
			b.lathe([Vector2(0, 0), Vector2(r * 0.6, 0), Vector2(r, h * 0.45), Vector2(r * 0.55, h), Vector2(0, h)], 6,
				Tile.CLAY if rng.randf() < 0.6 else Tile.CLAY_DARK, Vector3(x, y + 0.02, rng.randf_range(-0.06, 0.06)))
			x += r * 2.0 + 0.06
	return b.commit()


## Груда черепков у мастерской (брак обжига).
static func _make_shard_heap() -> Mesh:
	var b := PB.new()
	var rng := _rng(57)
	b.lathe([Vector2(0, 0), Vector2(0.7, 0), Vector2(0.45, 0.2), Vector2(0, 0.32)], 7, Tile.CLAY_DARK)
	for i in 18:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.75)
		var y := maxf(0.02, 0.32 * (1.0 - d / 0.75)) + 0.01
		var s := rng.randf_range(0.05, 0.11)
		var c := Vector3(cos(a) * d, y, sin(a) * d)
		b.quad(c + Vector3(-s, 0.0, -s * 0.5), c + Vector3(s, 0.03, -s * 0.4), c + Vector3(s * 0.8, 0.0, s * 0.5),
			c + Vector3(-s * 0.7, 0.02, s * 0.4), Tile.CLAY, true)
	return b.commit()


# ─── Ужас ────────────────────────────────────────────────────────────────────

## Неровное плоское пятно на земле (лужа крови, пыль): веер треугольников с рваным краем.
static func _blob(b: PB, center: Vector3, rx: float, rz: float, tile: int, seed: int, points: int = 9) -> void:
	var rng := _rng(seed)
	var ring := []
	for i in points:
		var a := TAU * i / points
		var k := rng.randf_range(0.65, 1.15)
		ring.append(center + Vector3(cos(a) * rx * k, 0.0, sin(a) * rz * k))
	for i in points:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % points]
		b.quad(center, p0, p1, center, tile)


## Полоса волочения: тело тащили к двери (по −Z): цепочка перекрывающихся мягких пятен, сужается и рвётся,
## по краям — короткие следы пальцев.
static func _make_blood_drag() -> Mesh:
	var d := DB.new()
	var rng := _rng(65)
	var z := 1.4
	var x := 0.0
	var w := 0.32
	while z > -1.4:
		var z1 := z - rng.randf_range(0.18, 0.3)
		var x1 := x + rng.randf_range(-0.05, 0.05)
		var w1 := clampf(w + rng.randf_range(-0.06, 0.03), 0.12, 0.34)
		d.floor_spot(Vector3((x + x1) * 0.5, 0.013, (z + z1) * 0.5), (w + w1) * 0.5 * 1.1, (z - z1) * 1.9, 0.0,
			rng.randf_range(0.65, 0.95), rng.randf() < 0.5)
		x = x1
		z = z1
		w = w1
	d.floor_spot(Vector3(0.0, 0.012, 1.55), 0.55, 0.4, 0.8)
	for i in 4:
		d.floor_spot(Vector3(-0.15 + i * 0.1, 0.013, -1.2 - rng.randf() * 0.15), 0.035, 0.22, 0.0, 0.85)
	return d.commit()


## Кровавые следы: цепочка отпечатков подошв (пятка и носок — мягкие пятна) уходит по −Z и бледнеет.
static func _make_blood_steps() -> Mesh:
	var d := DB.new()
	for i in 8:
		var side := -1.0 if i % 2 else 1.0
		var c := Vector3(side * 0.12, 0.013, 1.6 - i * 0.45)
		var fade := 1.0 - 0.6 * float(i) / 7.0
		d.floor_spot(c, 0.11, 0.18, side * 0.1, fade)
		d.floor_spot(c + Vector3(0.0, 0.0, -0.14), 0.09, 0.08, side * 0.1, fade)
	return d.commit()


## Стол 0,7 м, опрокинутый ножками вверх.
static func _make_table_overturned() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.025, 0), Vector3(1.1, 0.05, 0.65), Tile.WOOD, Basis(Vector3.UP, 0.1))
	for p in [Vector2(-0.48, -0.26), Vector2(0.48, -0.26), Vector2(0.48, 0.26)]:
		b.box(Vector3(p.x, 0.38, p.y), Vector3(0.06, 0.66, 0.06), Tile.WOOD_DARK)
	b.box(Vector3(-0.7, 0.03, 0.4), Vector3(0.06, 0.06, 0.66), Tile.WOOD_DARK, Basis(Vector3.UP, 0.9))
	return b.commit()


# ─── Фасады и двери ──────────────────────────────────────────────────────────

## Занавесь вместо двери (у бедных): ткань в проёме, край отогнут — за ним темно. Точка — середина проёма, ткань в плоскости XY.
static func _make_curtain() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 2.05, 0), Vector3(1.05, 0.04, 0.04), Tile.WOOD_DARK)
	b.quad(Vector3(-0.5, 2.03, 0.0), Vector3(0.3, 2.03, 0.0), Vector3(0.22, 0.02, -0.04), Vector3(-0.5, 0.02, 0.0), Tile.SACK, true)
	b.quad(Vector3(0.3, 2.03, 0.0), Vector3(0.5, 2.03, 0.0), Vector3(0.48, 0.3, 0.06), Vector3(0.36, 0.25, 0.1), Tile.SACK, true)
	return b.commit()


## Деревянная горница-балкон на втором этаже: выступ на консолях, решётчатые стенки, навес.
static func _make_balcony() -> Mesh:
	var b := PB.new()
	var y := 3.4
	b.box(Vector3(0, y, -0.45), Vector3(2.0, 0.08, 0.9), Tile.WOOD_DARK)
	for x in [-0.8, 0.8]:
		b.box(Vector3(x, y - 0.3, -0.2), Vector3(0.1, 0.1, 0.5), Tile.WOOD_DARK, Basis(Vector3.RIGHT, -0.6))
	b.box(Vector3(0, y + 0.55, -0.88), Vector3(2.0, 1.0, 0.05), Tile.WOOD)
	for x in [-0.98, 0.98]:
		b.box(Vector3(x, y + 0.55, -0.45), Vector3(0.05, 1.0, 0.86), Tile.WOOD)
	for i in 7:
		b.box(Vector3(-0.75 + i * 0.25, y + 0.55, -0.91), Vector3(0.03, 0.95, 0.02), Tile.WOOD_DARK)
	b.box(Vector3(0, y + 0.85, -0.92), Vector3(2.0, 0.03, 0.02), Tile.WOOD_DARK)
	b.quad(Vector3(-1.1, y + 1.5, 0.0), Vector3(1.1, y + 1.5, 0.0), Vector3(1.1, y + 1.15, -1.05), Vector3(-1.1, y + 1.15, -1.05),
		Tile.WOOD_DARK, true)
	return b.commit()


static func _make_awning_ochre() -> Mesh:
	return _awning(Tile.CLOTH_OCHRE)


static func _make_awning_blue() -> Mesh:
	return _awning(Tile.CLOTH_BLUE)


static func _make_awning_red() -> Mesh:
	return _awning(Tile.CLOTH_RED)


## Тканевый навес над дверью или окном на двух жердях, под ним — пучки трав.
static func _awning(tile: int) -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 2.55, -0.03), Vector3(1.6, 0.05, 0.05), Tile.WOOD_DARK)
	for x in [-0.75, 0.75]:
		b.box(Vector3(x, 2.4, -0.45), Vector3(0.04, 0.04, 0.9), Tile.WOOD_DARK, Basis(Vector3.RIGHT, 0.3))
	b.quad(Vector3(-0.8, 2.56, -0.02), Vector3(0.8, 2.56, -0.02), Vector3(0.8, 2.25, -0.9), Vector3(-0.8, 2.25, -0.9), tile, true)
	# Провис кромки
	b.quad(Vector3(-0.8, 2.25, -0.9), Vector3(0.8, 2.25, -0.9), Vector3(0.8, 2.1, -0.92), Vector3(-0.8, 2.1, -0.92), tile, true)
	return b.commit()


## Деревянная решётка на окне второго этажа.
static func _make_window_grille() -> Mesh:
	var b := PB.new()
	var y := 3.9
	b.box(Vector3(0, y, -0.005), Vector3(0.6, 0.7, 0.02), Tile.SOOT)
	b.box(Vector3(0, y - 0.38, -0.05), Vector3(0.8, 0.06, 0.1), Tile.STONE)
	for i in 4:
		b.box(Vector3(-0.21 + i * 0.14, y, -0.03), Vector3(0.03, 0.7, 0.03), Tile.WOOD)
	for j in 3:
		b.box(Vector3(0, y - 0.22 + j * 0.22, -0.035), Vector3(0.6, 0.03, 0.03), Tile.WOOD)
	return b.commit()


## Наружная каменная лестница вдоль стены к закрытой двери горницы (точка у стены, лестница идёт по +X, от стены в −Z).
static func _make_stair_ext() -> Mesh:
	var b := PB.new()
	var n := 10
	var rise := 0.33
	for i in n:
		b.box(Vector3(-1.5 + i * 0.3, (i + 1) * rise * 0.5, -0.45), Vector3(0.3, (i + 1) * rise, 0.9), Tile.STONE)
	b.box(Vector3(1.85, n * rise * 0.5, -0.45), Vector3(0.8, n * rise, 0.9), Tile.STONE)
	# Закрытая дверь горницы над площадкой
	b.box(Vector3(1.85, n * rise + 1.0, -0.03), Vector3(0.85, 1.9, 0.06), Tile.WOOD_DARK)
	b.box(Vector3(1.85, n * rise + 2.05, -0.06), Vector3(1.2, 0.2, 0.12), Tile.STONE)
	return b.commit()


## Балка перекрытия, рухнувшая наискось над проходом: нижний конец на завале (−X), верхний упёрся в стену (+X) выше головы.
static func _make_beam_leaning() -> Mesh:
	var b := PB.new()
	var a := Vector3(-1.4, 1.3, 0.0)
	var c := Vector3(0.5, 2.55, 0.0)
	var d := c - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	b.box((a + c) * 0.5, Vector3(0.2, 0.18, d.length()), Tile.WOOD_DARK, basis)
	b.box(Vector3(-1.2, 1.15, 0.25), Vector3(0.9, 0.12, 0.6), Tile.STONE, Basis(Vector3.BACK, 0.3))
	return b.commit()


# ─── Люди: фигуры в позах (тела, сидящий солдат) ─────────────────────────────

## Звено тела (рука, нога, шея): брусок от a до c сечением r×r, чуть заходит в суставы.
static func _limb(b: PB, a: Vector3, c: Vector3, r: float, tile: int) -> void:
	var d := c - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD
	b.box((a + c) * 0.5, Vector3(r, r, d.length() + r * 0.4), tile, Basis.looking_at(d.normalized(), up))


## Шар (голова, кулак): тело вращения из 5 колец.
static func _ball(b: PB, c: Vector3, r: float, tile: int, scale_xz := Vector2.ONE) -> void:
	b.lathe([Vector2(0, -r), Vector2(r * 0.7, -r * 0.7), Vector2(r, 0), Vector2(r * 0.7, r * 0.7), Vector2(0, r)], 6, tile,
		c, Basis(), scale_xz)


## Полотно, которым накрыли убитого (тело — модель Corpses "corpse_laid": таз в точке, голова в −Z).
## Ткань лежит по телу — бугор головы, грудь, колени — и складками на земле вокруг; ступни торчат наружу (+Z).
static func _make_cover_cloth() -> Mesh:
	var b := PB.new()
	var rng := _rng(127)
	# Сечения вдоль тела: [z, высота по оси тела, полуширина на земле]
	var secs := [[-1.72, 0.0, 0.34], [-1.5, 0.27, 0.44], [-1.1, 0.34, 0.52], [-0.75, 0.37, 0.66], [-0.4, 0.37, 0.72],
		[-0.05, 0.34, 0.72], [0.3, 0.28, 0.6], [0.62, 0.23, 0.48], [0.76, 0.0, 0.4]]
	var across := [-1.0, -0.62, -0.25, 0.25, 0.62, 1.0]
	var rows := []
	for sec: Array in secs:
		var row := []
		for k: float in across:
			var edge := absf(k) > 0.99
			var w: float = sec[2] * (rng.randf_range(0.88, 1.12) if edge else 1.0)
			var h: float = 0.0 if edge else float(sec[1]) * pow(1.0 - k * k, 0.55) * rng.randf_range(0.9, 1.08)
			row.append(Vector3(k * w, 0.012 + h, float(sec[0]) + (rng.randf_range(-0.04, 0.04) if edge else 0.0)))
		rows.append(row)
	for i in rows.size() - 1:
		for k in across.size() - 1:
			b.quad(rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k], Tile.LINEN)
	# Кровь проступила сквозь ткань у груди
	_blob(b, Vector3(0.06, 0.0, -0.4), 0.12, 0.16, Tile.BLOOD_DARK, 128, 7)
	return b.commit()


# ─── Комья ткани и пепла, сандалии ────────────────────────────────────────────

## Смятый ком ткани: неровные кольца с разным радиусом по сторонам (складки), сверху — веер.
static func _lump(b: PB, c: Vector3, rx: float, rz: float, h: float, tile: int, seed: int, sides: int = 8) -> void:
	var rng := _rng(seed)
	var rings := [[0.0, 1.0], [0.45, 0.85], [0.85, 0.45], [1.0, 0.0]]
	var pts := []
	for ring in rings:
		var row := []
		for i in sides:
			var a := TAU * i / sides
			var k: float = ring[1] * rng.randf_range(0.7, 1.15)
			var y: float = c.y + h * ring[0] * rng.randf_range(0.85, 1.1)
			row.append(Vector3(c.x + cos(a) * rx * k, y, c.z + sin(a) * rz * k))
		pts.append(row)
	for k in rings.size() - 1:
		for i in sides:
			var a0: Vector3 = pts[k][i]
			var a1: Vector3 = pts[k][(i + 1) % sides]
			var b0: Vector3 = pts[k + 1][i]
			var b1: Vector3 = pts[k + 1][(i + 1) % sides]
			b.quad(b1, b0, a0, a1, tile)


## Сандалия, стоящая на подошве, с ремешками вокруг пустого места, где была стопа.
static func _sandal(b: PB, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	b.box(at + basis * Vector3(0, 0.01, 0), Vector3(0.09, 0.02, 0.24), Tile.WOOD_DARK, basis)
	# Ремешки — тонкие дуги поперёк, задник у пятки
	b.box(at + basis * Vector3(0, 0.035, -0.05), Vector3(0.095, 0.01, 0.025), Tile.SACK, basis)
	b.box(at + basis * Vector3(0, 0.04, 0.04), Vector3(0.095, 0.01, 0.025), Tile.SACK, basis)
	b.box(at + basis * Vector3(0, 0.04, 0.11), Vector3(0.08, 0.04, 0.012), Tile.SACK, basis)


# ─── Тела унесли, забили, сожгли (этап 4в) ───────────────────────────────────

## Размер куска следа волочения, м (ширина × длина), и его текстуры, пикселей на кусок.
const TRAIL_SIZE := Vector2(0.6, 2.4)
const TRAIL_TEX := Vector2i(32, 128)
const TRAIL_VARIANTS := 4

static var _trail_mat: ShaderMaterial


## Материал следов волочения: шейдер крови (мягкий край, альфа-смешивание), текстура 128×128 с четырьмя рисунками
## (по столбцу 32×128 на кусок), без дизеринга.
static func trail_material() -> ShaderMaterial:
	if _trail_mat == null:
		_trail_mat = PsxMaterial.make_blood(_trail_texture())
	return _trail_mat


static var _blood_mat: ShaderMaterial


## Материал крови на полу и стенах (лужи, брызги, полосы волочения, следы): одно пятно 32×32 с мягким краем.
static func blood_material() -> ShaderMaterial:
	if _blood_mat == null:
		_blood_mat = PsxMaterial.make_blood(_blood_spot_texture())
	return _blood_mat


## Пятно крови 32×32: неровный контур (несколько гармоник по углу), мягкий край шириной ~4 пикселя (плавная альфа),
## к середине темнее и гуще; без зерна, дизера и сетки. Цвет — тёмно-красный.
static func _blood_spot_texture() -> ImageTexture:
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var rng := _rng(401)
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.07
	noise.seed = 7
	var edge := Color(0.46, 0.058, 0.064)
	var core := Color(0.3, 0.03, 0.04)
	for y in n:
		for x in n:
			var p := (Vector2(x + 0.5, y + 0.5) / n - Vector2(0.5, 0.5)) * 2.0
			var d := p.length()
			var ang := atan2(p.y, p.x)
			var r := 0.6 + 0.09 * sin(2.0 * ang + ph[0]) + 0.07 * sin(3.0 * ang + ph[1]) + 0.04 * sin(5.0 * ang + ph[2])
			var a := (1.0 - smoothstep(r - 0.24, r + 0.04, d)) * 0.94
			var inner := smoothstep(r * 0.85, 0.05, d)
			var shade := 0.93 + 0.14 * noise.get_noise_2d(x, y)
			var c := edge.lerp(core, inner) * shade
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


## Плавный шум по одной оси (значения 0…1 в узлах через 1, сглаженная интерполяция).
static func _noise1(x: float, seed: int) -> float:
	var i := floori(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	var a := float(hash(Vector2i(i, seed)) % 1000) / 999.0
	var c := float(hash(Vector2i(i + 1, seed)) % 1000) / 999.0
	return lerpf(a, c, f)


## Рисунок следа: тело тащили по плитам (вдоль v, сверху вниз). Не лента, а след: середина темнее и плотнее,
## к краям — реже (дизер), ширина и сила гуляют, есть сухие разрывы и смазы, борозды от пяток; на втором куске —
## отпечаток ладони сбоку, на четвёртом — отпечатки ступней.
static func _trail_texture() -> ImageTexture:
	# Рисуем вдвое крупнее и сжимаем до TRAIL_TEX: край получается мягким, без дизера
	var w := TRAIL_TEX.x * 2
	var h := TRAIL_TEX.y * 2
	var img := Image.create_empty(w * TRAIL_VARIANTS, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.05, 0.055, 0.0))
	var edge := Color(0.42, 0.052, 0.058)
	var core := Color(0.28, 0.03, 0.04)
	for k in TRAIL_VARIANTS:
		var seed := 300 + k * 17
		var rng := _rng(seed)
		# Разрывы: [середина v, полудлина v] — там след почти пропадает
		var gaps := []
		for g in [1, 2, 0, 1][k]:
			gaps.append([rng.randf_range(0.2, 0.8), rng.randf_range(0.03, 0.08)])
		var smear := k == 2
		var heels := 0.9 if k == 3 else (0.0 if smear else 0.45)
		var a_map := PackedFloat32Array()
		a_map.resize(w * h)
		for y in h:
			var v := float(y) / (h - 1)
			# К концам куска след возвращается к середине и обычной ширине — куски стыкуются
			var ends := sin(PI * v)
			var cx := 0.5 + (_noise1(v * 3.0, seed) - 0.5) * 0.22 * ends
			var hw := lerpf(0.13, 0.27, _noise1(v * 4.5, seed + 1)) * (1.35 if smear else 1.0)
			var strength := lerpf(0.75, 1.15, _noise1(v * 7.0, seed + 2)) * (0.5 if smear else 1.0)
			for g: Array in gaps:
				strength *= smoothstep(0.0, 1.0, absf(v - float(g[0])) / float(g[1]) - 0.3)
			var heel_on := heels * smoothstep(0.25, 0.5, _noise1(v * 9.0, seed + 3))
			for x in w:
				var u := (float(x) + 0.5) / w
				var d := absf(u - cx) / hw
				# Продольные волокна: полосы вдоль хода, медленно меняются
				var fib := 0.55 + 0.45 * _noise1(u * 26.0 + _noise1(v * 2.0, seed + 5) * 3.0, seed + 4)
				var a := clampf(1.0 - pow(d, 1.6), 0.0, 1.0) * strength * fib
				for side: float in [-1.0, 1.0]:
					var hd := absf(u - (cx + side * 0.1 + (_noise1(v * 5.0, seed + 6) - 0.5) * 0.04)) / 0.022
					a = maxf(a, clampf(1.0 - hd * hd, 0.0, 1.0) * heel_on)
				a_map[y * w + x] = a
		# Отпечатки: ладонь сбоку от следа (кусок 2), ступни (кусок 4), капли у края (все)
		if k == 1:
			_stamp_hand(a_map, w, h, Vector2(51.0, 96.0), 0.35)
		if k == 3:
			_stamp_ellipse(a_map, w, h, Vector2(13.0, 70.0), Vector2(3.2, 7.0), 0.2, 0.8)
			_stamp_ellipse(a_map, w, h, Vector2(52.0, 168.0), Vector2(3.2, 7.0), -0.25, 0.8)
		for i in 7:
			var at := Vector2(rng.randf_range(4.0, w - 4.0), rng.randf_range(6.0, h - 6.0))
			_stamp_ellipse(a_map, w, h, at, Vector2(rng.randf_range(0.8, 1.8), rng.randf_range(1.0, 3.0)), 0.0, 0.9)
		for y in h:
			for x in w:
				var a: float = a_map[y * w + x]
				var tone := 0.9 + 0.2 * _noise1(float(x) * 0.15 + float(y) * 0.05, seed + 9)
				var col := edge.lerp(core, smoothstep(0.3, 0.95, a * 1.25)) * tone
				img.set_pixel(k * w + x, y, Color(col.r, col.g, col.b, clampf(a * 1.5, 0.0, 1.0) * 0.94))
	img.resize(TRAIL_TEX.x * TRAIL_VARIANTS, TRAIL_TEX.y, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


## Пятно-эллипс в карту плотности (center и radius — в пикселях, rot — рад).
static func _stamp_ellipse(a_map: PackedFloat32Array, w: int, h: int, center: Vector2, radius: Vector2, rot: float,
		amount: float) -> void:
	var r := ceili(maxf(radius.x, radius.y)) + 1
	for y in range(maxi(0, int(center.y) - r), mini(h, int(center.y) + r + 1)):
		for x in range(maxi(0, int(center.x) - r), mini(w, int(center.x) + r + 1)):
			var p := (Vector2(x + 0.5, y + 0.5) - center).rotated(-rot) / radius
			var a := clampf(1.0 - p.length_squared(), 0.0, 1.0) * amount
			a_map[y * w + x] = maxf(a_map[y * w + x], a)


## Отпечаток ладони: пятно, четыре пальца веером и большой палец (опёрся, пока тащили).
static func _stamp_hand(a_map: PackedFloat32Array, w: int, h: int, at: Vector2, rot: float) -> void:
	_stamp_ellipse(a_map, w, h, at, Vector2(4.2, 4.8), rot, 0.75)
	for i in 4:
		var ang := rot + (i - 1.5) * 0.24
		var tip := at + Vector2(sin(ang), -cos(ang)) * 9.5
		_stamp_ellipse(a_map, w, h, tip, Vector2(1.3, 3.6), ang, 0.7)
	var th := rot - 1.15
	_stamp_ellipse(a_map, w, h, at + Vector2(sin(th), -cos(th)) * 6.5, Vector2(1.4, 3.0), th, 0.7)


## Кусок следа волочения: лента 0,6 × 2,4 м на плитах, длинной стороной вдоль Z, резана на клетки по 0,6 м
## (чтобы текстура не плыла); variant — какой из четырёх рисунков.
static func _trail_mesh(variant: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := TRAIL_SIZE.x * 0.5
	var hl := TRAIL_SIZE.y * 0.5
	var u0 := (variant + 0.5 / TRAIL_TEX.x) / TRAIL_VARIANTS
	var u1 := (variant + 1.0 - 0.5 / TRAIL_TEX.x) / TRAIL_VARIANTS
	var n := 4
	for i in n:
		var v0 := float(i) / n
		var v1 := float(i + 1) / n
		var z0 := lerpf(-hl, hl, v0)
		var z1 := lerpf(-hl, hl, v1)
		var quad := [[Vector3(-hw, 0.012, z0), Vector2(u0, v0)], [Vector3(hw, 0.012, z0), Vector2(u1, v0)],
			[Vector3(hw, 0.012, z1), Vector2(u1, v1)], [Vector3(-hw, 0.012, z1), Vector2(u0, v1)]]
		for j: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[j][1])
			st.add_vertex(quad[j][0])
	return st.commit()


static func _make_blood_trail_1() -> Mesh:
	return _trail_mesh(0)


static func _make_blood_trail_2() -> Mesh:
	return _trail_mesh(1)


static func _make_blood_trail_3() -> Mesh:
	return _trail_mesh(2)


static func _make_blood_trail_4() -> Mesh:
	return _trail_mesh(3)


## Окровавленный камень с кулак-два: им били. Тёмное пятно под ним и на нём.
static func _make_stone_bloody() -> Mesh:
	var b := PB.new()
	_blob(b, Vector3(0.02, 0.011, 0.0), 0.2, 0.16, Tile.BLOOD_DARK, 151, 8)
	_lump(b, Vector3(0, 0, 0), 0.11, 0.09, 0.12, Tile.STONE, 152, 6)
	_lump(b, Vector3(0.02, 0.07, 0.01), 0.075, 0.06, 0.06, Tile.BLOOD_DARK, 153, 5)
	return b.commit()


## Окровавленный обожжённый кирпич: лежит углом, один конец тёмный.
static func _make_brick_bloody() -> Mesh:
	var b := PB.new()
	var rot := Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, 0.12)
	_blob(b, Vector3(0.05, 0.011, 0.02), 0.17, 0.12, Tile.BLOOD_DARK, 154, 7)
	b.box(Vector3(0, 0.045, 0), Vector3(0.12, 0.075, 0.24), Tile.CLAY_DARK, rot)
	b.box(rot * Vector3(0, 0.0, -0.085) + Vector3(0, 0.047, 0), Vector3(0.124, 0.079, 0.08), Tile.BLOOD_DARK, rot)
	return b.commit()


## Кучка серого пепла — всё, что осталось от человека; в пепле — пряжка римского пояса и обрывок ремня.
static func _make_ash_pile() -> Mesh:
	var b := PB.new()
	_blob(b, Vector3(0, 0.011, 0), 0.62, 0.5, Tile.DUST, 155, 11)
	_blob(b, Vector3(0.05, 0.013, -0.05), 0.4, 0.3, Tile.SOOT, 156, 9)
	_lump(b, Vector3(0, 0, 0), 0.36, 0.3, 0.15, Tile.DUST, 157, 9)
	_lump(b, Vector3(0.08, 0.05, 0.04), 0.18, 0.15, 0.12, Tile.SOOT, 158, 6)
	# Ремень торчит из пепла, на конце — бронзовая пряжка-рамка
	b.box(Vector3(-0.24, 0.07, 0.16), Vector3(0.3, 0.012, 0.045), Tile.WOOD_DARK, Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, 0.25))
	var at := Vector3(-0.4, 0.035, 0.25)
	var rot := Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, 0.15)
	for e in [[Vector3(0, 0, -0.03), Vector3(0.075, 0.012, 0.014)], [Vector3(0, 0, 0.03), Vector3(0.075, 0.012, 0.014)],
			[Vector3(-0.031, 0, 0), Vector3(0.014, 0.012, 0.06)], [Vector3(0.031, 0, 0), Vector3(0.014, 0.012, 0.06)],
			[Vector3(0.0, 0.004, 0), Vector3(0.07, 0.006, 0.008)]]:
		b.box(at + rot * (e[0] as Vector3), e[1], Tile.METAL, rot)
	return b.commit()


## Выжженный силуэт на стене (точка у стены, смотрит в −Z): тёмная тень человека, который закрывал лицо руками, —
## как тень, выжженная светом. Ниже — копоть до земли.
static func _make_scorch_silhouette() -> Mesh:
	var b := PB.new()
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var z := 0.006
	_blob_v(b, Vector2(0.0, 1.52), 0.115, 0.13, z, Tile.SOOT, 160, 8)
	_blob_v(b, Vector2(0.0, 1.08), 0.23, 0.36, z, Tile.SOOT, 161, 10)
	_blob_v(b, Vector2(-0.1, 0.42), 0.1, 0.44, z, Tile.SOOT, 162, 8)
	_blob_v(b, Vector2(0.11, 0.4), 0.1, 0.42, z, Tile.SOOT, 163, 8)
	# Руки подняты к лицу
	_blob_v(b, Vector2(-0.24, 1.36), 0.075, 0.2, z, Tile.SOOT, 164, 7)
	_blob_v(b, Vector2(-0.14, 1.6), 0.07, 0.12, z, Tile.SOOT, 165, 6)
	_blob_v(b, Vector2(0.25, 1.38), 0.075, 0.2, z, Tile.SOOT, 166, 7)
	_blob_v(b, Vector2(0.15, 1.62), 0.07, 0.12, z, Tile.SOOT, 167, 6)
	return b.commit()


## Рука свисает с края плоской крыши одноэтажного дома (парапет на 4,5 м): тот, кто успел залезть, лежит наверху.
static func _make_hand_hanging() -> Mesh:
	var b := PB.new()
	var top := 4.52
	_limb(b, Vector3(0.0, top + 0.02, 0.3), Vector3(0.02, top, -0.07), 0.11, Tile.LINEN)
	_limb(b, Vector3(0.02, top, -0.08), Vector3(0.04, top - 0.3, -0.13), 0.08, Tile.SKIN)
	_limb(b, Vector3(0.04, top - 0.3, -0.13), Vector3(0.03, top - 0.55, -0.12), 0.07, Tile.SKIN)
	_ball(b, Vector3(0.03, top - 0.62, -0.12), 0.05, Tile.SKIN)
	# Потёк по стене под рукой
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	b.quad(Vector3(-0.045, top - 0.9, 0.007), Vector3(-0.02, top - 0.9, 0.007), Vector3(-0.028, top - 1.7, 0.007),
		Vector3(-0.04, top - 1.7, 0.007), Tile.BLOOD_DARK)
	return b.commit()


## Растоптанная корзина: модель корзины, сплющенная и перекошенная.
static func _make_basket_crushed() -> Mesh:
	var squash := Basis(Vector3.BACK, 0.12) * Basis(Vector3.UP, 0.4) * Basis.from_scale(Vector3(1.2, 0.3, 1.05))
	return _model("prop_basket", Transform3D(squash, Vector3(0.0, 0.01, 0.0)))


# ─── Римское ─────────────────────────────────────────────────────────────────

## Щит лежит лицом вверх, чуть перекошен (модель prop_shield: 1,10 × 0,48, длинная ось — X, лицо — +Y).
static func _make_shield() -> Mesh:
	return _model("prop_shield", Transform3D(Basis(Vector3.RIGHT, 0.04), Vector3(0.0, 0.01, 0.0)))


## Щит прислонён к стене (точка у стены, лицо щита — в −Z), низ на земле: длинная ось модели — вверх, к стене.
static func _make_shield_leaning() -> Mesh:
	var front := Vector3(0, 0.26, -1).normalized()
	var up := Vector3(0.0, -front.z, front.y)
	return _model("prop_shield", Transform3D(Basis(up, front, up.cross(front)), Vector3(0, 0.55 * up.y + 0.01, -0.2)))


## Сломанное копьё: древко переломлено (модель, разрезанная по X на 0,2 м), обломок с наконечником лежит отдельно.
static func _make_spear_broken() -> Mesh:
	var lie := Basis(Vector3.UP, PI * 0.5)
	return _model_parts("prop_spear", [
		[Transform3D(Basis(Vector3.UP, 0.1) * lie, Vector3(0.0, 0.002, -0.1)), Vector2(-INF, 0.15)],
		[Transform3D(Basis(Vector3.UP, -0.7) * lie, Vector3(0.05, 0.002, -0.12)), Vector2(0.2, INF)],
	])


## Жаровня опрокинута: тренога на боку, чаша лежит рядом, угли и зола рассыпаны веером (тлеющие — огоньки из KINDS).
static func _make_brazier_overturned() -> Mesh:
	var b := PB.new()
	# Тренога на боку: три ножки и кольцо
	var tip := Basis(Vector3.BACK, PI * 0.5)
	for i in 3:
		var a := TAU * i / 3.0
		var foot := Vector3(-0.85, 0.2 + sin(a) * 0.17, cos(a) * 0.42)
		_limb(b, foot, Vector3(-0.1, 0.2 + sin(a) * 0.12, cos(a) * 0.12), 0.035, Tile.IRON)
	b.lathe([Vector2(0.12, -0.02), Vector2(0.15, -0.02), Vector2(0.15, 0.02), Vector2(0.12, 0.02)], 8, Tile.IRON,
		Vector3(-0.1, 0.2, 0.0), tip)
	# Чаша на боку, отверстием к углям
	b.lathe([Vector2(0.06, 0.0), Vector2(0.26, 0.06), Vector2(0.3, 0.17), Vector2(0.27, 0.17), Vector2(0, 0.12)], 9, Tile.IRON,
		Vector3(0.15, 0.28, -0.05), Basis(Vector3.BACK, -PI * 0.5 + 0.25))
	# Зола и угли веером
	_blob(b, Vector3(0.55, 0.008, 0.0), 0.45, 0.32, Tile.BASALT, 105, 9)
	var rng := _rng(106)
	for i in 12:
		b.box(Vector3(rng.randf_range(0.3, 0.9), 0.02, rng.randf_range(-0.3, 0.3)), Vector3(0.045, 0.03, 0.04),
			Tile.SOOT if i % 3 else Tile.CLAY_DARK, Basis(Vector3.UP, rng.randf() * PI))
	return b.commit()


## Тлеющая жаровня (брошенный пост): та же тренога, вместо пламени угли — огоньки поменьше.
static func _make_brazier_smoldering() -> Mesh:
	return _make_brazier()


# ─── Кровь ───────────────────────────────────────────────────────────────────

## Лужа крови: плоские неровные пятна с мягким краем (децали blood_material, текстура 32×32): большое, поверх него
## поменьше, брызги вокруг и короткие подтёки по швам плит. Цвет — тёмно-красный.
static func _make_blood_pool() -> Mesh:
	var d := DB.new()
	var rng := _rng(61)
	d.floor_spot(Vector3(0.0, 0.011, 0.0), 1.05, 0.78, 0.35)
	d.floor_spot(Vector3(0.05, 0.012, 0.03), 0.66, 0.5, 2.0, 0.8, true)
	d.floor_spot(Vector3(0.4, 0.011, 0.2), 0.3, 0.24, 0.6)
	# Брызги вокруг: мелкие пятна разного размера
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.5, 0.85)
		var sz := rng.randf_range(0.035, 0.11)
		d.floor_spot(Vector3(cos(a) * r * 1.15, 0.011, sin(a) * r * 0.85), sz, sz * rng.randf_range(0.7, 1.3), rng.randf() * TAU,
			rng.randf_range(0.7, 1.0), i % 2 == 0)
	# Подтёки по швам плит: короткие узкие языки вдоль осей, от края лужи наружу
	for i in 5:
		var along_x := i % 2 == 0
		var sgn := 1.0 if i < 3 else -1.0
		var len := rng.randf_range(0.16, 0.3)
		var edge := Vector3(0.45 * sgn, 0.0, rng.randf_range(-0.15, 0.15)) if along_x else Vector3(rng.randf_range(-0.25, 0.25), 0.0, 0.32 * sgn)
		var c := edge + (Vector3(len * 0.5 * sgn, 0.012, 0.0) if along_x else Vector3(0.0, 0.012, len * 0.5 * sgn))
		d.floor_spot(c, len if along_x else 0.05, 0.05 if along_x else len, 0.0, 0.85)
	return d.commit()


## Брызги на стене (точка у стены, смотрит в −Z): пятно удара, россыпь мелких капель вокруг и короткие подтёки вниз
## (децали с мягким краем, не длинные линии).
static func _make_blood_splatter() -> Mesh:
	var d := DB.new()
	d.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var rng := _rng(67)
	var hit := Vector2(0.0, 1.3)
	d.wall_spot(hit, 0.16, 0.13, 0.006, 0.4)
	d.wall_spot(hit + Vector2(0.03, -0.02), 0.1, 0.09, 0.007, 1.9, 0.85)
	for i in 30:
		var a := rng.randf_range(-PI * 0.3, PI * 1.3)
		var dist := rng.randf_range(0.07, 0.5) * rng.randf_range(0.5, 1.0)
		var c := hit + Vector2(cos(a) * dist * 1.3, sin(a) * dist * 0.8)
		var sz := maxf(rng.randf_range(0.02, 0.06) * (1.0 - dist), 0.012)
		d.wall_spot(c, sz, sz * rng.randf_range(0.7, 1.4), 0.006, rng.randf() * TAU, rng.randf_range(0.7, 1.0))
	# Подтёки: короткие, вытянутые вниз пятна от места удара и самых крупных капель
	for i in 5:
		var x := hit.x + rng.randf_range(-0.12, 0.12)
		var top := hit.y + rng.randf_range(-0.05, 0.02)
		var len := rng.randf_range(0.09, 0.2)
		var w := rng.randf_range(0.025, 0.045)
		d.wall_spot(Vector2(x, top - len * 0.5), w, len, 0.007, 0.0, 0.9)
	return d.commit()


# ─── Паника и святые ─────────────────────────────────────────────────────────

## Брошенные носилки: две жерди, провисшее полотно, один конец упал на землю.
static func _make_litter() -> Mesh:
	var b := PB.new()
	var tilt := Basis(Vector3.RIGHT, 0.12)
	for x in [-0.3, 0.3]:
		b.box(Vector3(x, 0.17, 0), Vector3(0.05, 0.05, 2.2), Tile.WOOD, tilt)
	for z in [-0.55, 0.55]:
		b.box(tilt * Vector3(0, 0.19, z), Vector3(0.62, 0.04, 0.04), Tile.WOOD_DARK, tilt)
	b.quad(tilt * Vector3(-0.28, 0.17, -0.7), tilt * Vector3(0.28, 0.17, -0.7), tilt * Vector3(0.28, 0.12, 0.7),
		tilt * Vector3(-0.28, 0.12, 0.7), Tile.LINEN, true)
	_lump(b, tilt * Vector3(0.05, 0.12, 0.2), 0.22, 0.3, 0.07, Tile.LINEN, 107, 7)
	return b.commit()


## Опрокинутый лоток: столешница на боку, ножки торчат, навес сорван и лежит, фрукты раскатились.
static func _make_stall_overturned() -> Mesh:
	var b := PB.new()
	var tip := Basis(Vector3.RIGHT, PI * 0.5)
	b.box(Vector3(0, 0.5, 0.0), Vector3(2.0, 0.06, 1.0), Tile.WOOD, tip)
	for x in [-0.92, 0.92]:
		for y in [0.1, 0.9]:
			b.box(Vector3(x, y, -0.4), Vector3(0.07, 0.07, 0.8), Tile.WOOD_DARK)
	b.quad(Vector3(-1.0, 0.03, -0.9), Vector3(1.1, 0.12, -0.8), Vector3(1.2, 0.02, -1.9), Vector3(-0.9, 0.04, -1.8), Tile.CLOTH_BLUE, true)
	var rng := _rng(108)
	for i in 10:
		_ball(b, Vector3(rng.randf_range(-1.2, 1.2), 0.04, rng.randf_range(-1.6, -0.2)), 0.045,
			Tile.CLOTH_RED if i % 2 else Tile.FOOD)
	return b.commit()


## Погребальная пелена: длинная льняная лента зацепилась за гвоздь на углу (~1 м) и тянется по улице
## (по −Z) на 3 м, перекручиваясь.
static func _make_shroud_strip() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 1.08, 0.0), Vector3(0.02, 0.02, 0.08), Tile.IRON)
	var pts := [Vector3(0.0, 1.07, -0.02), Vector3(0.02, 0.75, -0.08), Vector3(0.04, 0.35, -0.2), Vector3(0.06, 0.03, -0.5),
		Vector3(0.0, 0.015, -0.9), Vector3(-0.12, 0.015, -1.4), Vector3(-0.08, 0.015, -1.9), Vector3(0.08, 0.015, -2.4),
		Vector3(0.14, 0.015, -2.8), Vector3(0.05, 0.015, -3.1)]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		var wa := 0.07 + 0.03 * sin(i * 1.7)
		var wc := 0.07 + 0.03 * sin((i + 1) * 1.7)
		b.quad(Vector3(a.x - wa, a.y, a.z), Vector3(a.x + wa, a.y, a.z), Vector3(c.x + wc, c.y, c.z), Vector3(c.x - wc, c.y, c.z),
			Tile.SHROUD, true)
	return b.commit()


## Погребальная пыль: россыпь серо-белых пятен и цепочка босых следов из неё (по −Z), бледнеющих.
static func _make_burial_dust() -> Mesh:
	var b := PB.new()
	var rng := _rng(71)
	for i in 6:
		_blob(b, Vector3(rng.randf_range(-0.4, 0.4), 0.011, 0.6 + rng.randf_range(-0.3, 0.3)), rng.randf_range(0.12, 0.3),
			rng.randf_range(0.1, 0.22), Tile.DUST, 72 + i, 7)
	# Дорожка рассыпанной пыли вдоль следов
	for i in 12:
		_blob(b, Vector3(rng.randf_range(-0.08, 0.15) + i * 0.015, 0.01, 0.2 - i * 0.32), rng.randf_range(0.1, 0.18),
			rng.randf_range(0.12, 0.2), Tile.DUST, 140 + i, 6)
	for i in 7:
		var side := -1.0 if i % 2 else 1.0
		var c := Vector3(side * 0.12 + i * 0.03, 0.013, 0.1 - i * 0.55)
		# Босая ступня: пятка, свод и пальцы
		_blob(b, c, 0.04, 0.06, Tile.DUST, 80 + i, 6)
		_blob(b, c + Vector3(side * 0.01, 0, -0.11), 0.045, 0.05, Tile.DUST, 90 + i, 6)
		for t in 4:
			b.box(c + Vector3(-0.03 + t * 0.02, 0, -0.18), Vector3(0.014, 0.002, 0.02), Tile.DUST)
	return b.commit()


## Сброшенные погребальные пелены: длинные льняные ленты кольцами и комом на полу.
static func _make_shroud_pile() -> Mesh:
	var b := PB.new()
	_lump(b, Vector3(0.0, 0.0, 0.0), 0.32, 0.25, 0.12, Tile.SHROUD, 111)
	var rng := _rng(112)
	for k in 3:
		var prev := Vector3(rng.randf_range(-0.2, 0.2), 0.02, rng.randf_range(-0.1, 0.1))
		var a := rng.randf() * TAU
		for i in 8:
			a += rng.randf_range(0.4, 0.9)
			var next := prev + Vector3(cos(a), 0.0, sin(a)) * 0.22
			next.y = 0.015 + (0.04 if i < 2 else 0.0)
			b.quad(Vector3(prev.x - 0.05, prev.y, prev.z), Vector3(prev.x + 0.05, prev.y, prev.z),
				Vector3(next.x + 0.05, next.y, next.z), Vector3(next.x - 0.05, next.y, next.z), Tile.SHROUD, true)
			prev = next
	return b.commit()


## Надпись, процарапанная на штукатурке по-гречески: ΟΥΚ ΗΓΕΡΘΗ — «не воскрес» (переиначенное «Он воскрес»,
## Мф 28:6). Светлые царапины, рядом следы пальцев и кровь. Точка у стены, смотрит в −Z.
static func _make_graffiti_greek() -> Mesh:
	var b := PB.new()
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var oct := []
	for i in 9:
		var a := TAU * i / 8.0 + PI / 8.0
		oct.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
	var ring := []
	for i in 8:
		ring.append([oct[i], oct[i + 1]])
	var letters := {
		"Ο": ring,
		"Υ": [[Vector2(0, 1), Vector2(0.5, 0.5)], [Vector2(1, 1), Vector2(0.5, 0.5)], [Vector2(0.5, 0.5), Vector2(0.5, 0)]],
		"Κ": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0.9, 1), Vector2(0, 0.5)], [Vector2(0, 0.5), Vector2(0.9, 0)]],
		"Η": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0.9, 0), Vector2(0.9, 1)], [Vector2(0, 0.5), Vector2(0.9, 0.5)]],
		"Γ": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0, 1), Vector2(0.8, 1)]],
		"Ε": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0, 1), Vector2(0.85, 1)], [Vector2(0, 0.5), Vector2(0.65, 0.5)],
			[Vector2(0, 0), Vector2(0.85, 0)]],
		"Ρ": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0, 1), Vector2(0.7, 1)], [Vector2(0.7, 1), Vector2(0.85, 0.82)],
			[Vector2(0.85, 0.82), Vector2(0.85, 0.68)], [Vector2(0.85, 0.68), Vector2(0.7, 0.5)], [Vector2(0.7, 0.5), Vector2(0, 0.5)]],
		"Θ": ring + [[Vector2(0.25, 0.5), Vector2(0.75, 0.5)]],
	}
	var rng := _rng(113)
	var text := "ΟΥΚ ΗΓΕΡΘΗ"
	var size := Vector2(0.13, 0.18)
	var x := -0.72
	var y := 1.42
	for ch in text:
		if ch == " ":
			x += 0.1
			continue
		var tilt := rng.randf_range(-0.04, 0.04)
		for seg: Array in letters[ch]:
			var p0: Vector2 = seg[0]
			var p1: Vector2 = seg[1]
			var a := Vector2(x + p0.x * size.x, y + p0.y * size.y + p0.x * tilt)
			var c := Vector2(x + p1.x * size.x, y + p1.y * size.y + p1.x * tilt)
			_scratch(b, a, c, 0.018, Tile.DUST)
		x += size.x + 0.045
	# Царапины ногтями и кровь под надписью
	for i in 4:
		var sx := -0.2 + i * 0.035
		_scratch(b, Vector2(sx, 1.3), Vector2(sx + 0.03, 0.85 + rng.randf() * 0.1), 0.006, Tile.BLOOD_DARK)
	_hand(b, Vector2(0.38, 1.05), 0.3, 0.007, Tile.BLOOD_DARK)
	return b.commit()


## Царапина на вертикальной плоскости от a до c (лицом в +Z до разворота b.xf).
static func _scratch(b: PB, a: Vector2, c: Vector2, w: float, tile: int) -> void:
	var d := (c - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	var z := 0.006
	# Порядок вершин — лицом в +Z при любом направлении штриха
	var p := [a + n, c + n, c - n, a - n]
	if (p[1] - p[0]).cross(p[3] - p[0]) > 0.0:
		p = [a - n, c - n, c + n, a + n]
	b.quad(Vector3(p[0].x, p[0].y, z), Vector3(p[1].x, p[1].y, z), Vector3(p[2].x, p[2].y, z), Vector3(p[3].x, p[3].y, z), tile, true)


# ─── Маленькие истории: двор, очаг, игрушки, лестница ────────────────────────

## Цистерна брошена: крышка сброшена, над устьем рама с перерезанной верёвкой; устье — тёмная дыра.
## Ставится поверх цистерны (cistern).
static func _make_rope_cut() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0.455), Vector2(0.37, 0.455), Vector2(0, 0.456)], 8, Tile.SOOT)
	for x in [-0.62, 0.62]:
		b.box(Vector3(x, 0.8, 0), Vector3(0.08, 1.6, 0.08), Tile.WOOD_DARK)
	b.box(Vector3(0, 1.6, 0), Vector3(1.4, 0.08, 0.08), Tile.WOOD_DARK)
	# Обрезок верёвки на перекладине с размочаленным концом
	b.box(Vector3(0.05, 1.32, 0), Vector3(0.02, 0.5, 0.02), Tile.SACK)
	b.box(Vector3(0.05, 1.06, 0), Vector3(0.035, 0.04, 0.035), Tile.SACK, Basis(Vector3.UP, 0.4))
	# Крышка лежит на земле у цистерны
	b.lathe([Vector2(0, 0.0), Vector2(0.4, 0.0), Vector2(0.4, 0.04), Vector2(0, 0.045)], 8, Tile.WOOD, Vector3(0.9, 0, 0.5))
	return b.commit()


## Опрокинутое ведро: кожаное ведро на боку, дужка, обрывок верёвки, мокрое тёмное пятно.
static func _make_bucket() -> Mesh:
	var b := PB.new()
	_blob(b, Vector3(-0.25, 0.008, 0.0), 0.45, 0.3, Tile.SOOT, 115, 9)
	b.lathe([Vector2(0, 0), Vector2(0.13, 0), Vector2(0.16, 0.3), Vector2(0.14, 0.3), Vector2(0.11, 0.03)], 8, Tile.WOOD_DARK,
		Vector3(0.0, 0.15, 0.0), Basis(Vector3.BACK, PI * 0.5 - 0.1))
	b.box(Vector3(0.28, 0.16, 0), Vector3(0.02, 0.02, 0.32), Tile.IRON)
	b.box(Vector3(0.6, 0.012, 0.1), Vector3(0.5, 0.02, 0.02), Tile.SACK, Basis(Vector3.UP, 0.3))
	return b.commit()


## Детская глиняная свистулька-птичка.
static func _make_toy_bird() -> Mesh:
	var b := PB.new()
	_ball(b, Vector3(0, 0.04, 0), 0.04, Tile.CLAY, Vector2(0.8, 1.5))
	_ball(b, Vector3(0, 0.08, -0.05), 0.025, Tile.CLAY)
	b.box(Vector3(0, 0.085, -0.08), Vector3(0.012, 0.01, 0.03), Tile.CLAY_DARK)
	b.box(Vector3(0, 0.055, 0.07), Vector3(0.05, 0.01, 0.05), Tile.CLAY, Basis(Vector3.RIGHT, -0.4))
	return b.commit()


## Детская глиняная повозочка на двух колёсах с верёвочкой.
static func _make_toy_cart() -> Mesh:
	var b := PB.new()
	b.box(Vector3(0, 0.07, 0), Vector3(0.12, 0.06, 0.2), Tile.CLAY)
	for x in [-0.075, 0.075]:
		b.lathe([Vector2(0, -0.01), Vector2(0.045, -0.01), Vector2(0.045, 0.01), Vector2(0, 0.01)], 7, Tile.CLAY_DARK,
			Vector3(x, 0.045, 0.02), Basis(Vector3.BACK, PI * 0.5))
	b.box(Vector3(0.02, 0.006, -0.25), Vector3(0.008, 0.008, 0.32), Tile.SACK, Basis(Vector3.UP, 0.2))
	return b.commit()


## Очаг: кольцо камней, зола, угли ещё тлеют (огоньки из KINDS); над ним вертел на рогатинах — жарили ягнёнка.
static func _make_hearth_embers() -> Mesh:
	var b := PB.new()
	_blob(b, Vector3(0, 0.01, 0), 0.32, 0.32, Tile.BASALT, 117, 9)
	for i in 9:
		var a := TAU * i / 9.0
		b.box(Vector3(cos(a) * 0.38, 0.06, sin(a) * 0.38), Vector3(0.16, 0.12, 0.13), Tile.STONE, Basis(Vector3.UP, a))
	var rng := _rng(118)
	for i in 8:
		b.box(Vector3(rng.randf_range(-0.2, 0.2), 0.035, rng.randf_range(-0.2, 0.2)), Vector3(0.07, 0.05, 0.05),
			Tile.SOOT if i % 2 else Tile.CLAY_DARK, Basis(Vector3.UP, rng.randf() * PI))
	for x in [-0.55, 0.55]:
		b.box(Vector3(x, 0.35, 0), Vector3(0.04, 0.7, 0.04), Tile.WOOD_DARK)
		b.box(Vector3(x, 0.72, 0), Vector3(0.03, 0.12, 0.03), Tile.WOOD_DARK, Basis(Vector3.BACK, 0.5))
	b.box(Vector3(0, 0.7, 0), Vector3(1.3, 0.025, 0.025), Tile.WOOD_DARK)
	return b.commit()


## Миска с недоеденной едой: глиняная миска, похлёбка, кусок лепёшки на краю.
static func _make_bowl_food() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.11, 0.05), Vector2(0.12, 0.07), Vector2(0.1, 0.065)], 8, Tile.CLAY)
	b.lathe([Vector2(0, 0.045), Vector2(0.1, 0.045), Vector2(0, 0.05)], 8, Tile.FOOD)
	b.lathe([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.065, 0.01), Vector2(0, 0.015)], 6, Tile.FOOD, Vector3(0.14, 0.0, 0.05),
		Basis(Vector3.FORWARD, 0.2))
	return b.commit()


## Упавшая лестница: деревянная приставная лестница лежит от стены (точка у стены) по −Z, 3,6 м.
static func _make_ladder_fallen() -> Mesh:
	var b := PB.new()
	for x in [-0.22, 0.22]:
		b.box(Vector3(x, 0.04, -1.85), Vector3(0.06, 0.06, 3.6), Tile.WOOD)
	for i in 10:
		b.box(Vector3(0, 0.05, -0.2 - i * 0.36), Vector3(0.44, 0.035, 0.04), Tile.WOOD_DARK)
	return b.commit()


# ─── Зелень ──────────────────────────────────────────────────────────────────

## Пучок сухой травы в щели у стены или между плит.
static func _make_grass_tuft() -> Mesh:
	var b := PB.new()
	var rng := _rng(121)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		var h := rng.randf_range(0.12, 0.26)
		var tip := Vector3(cos(a) * 0.08, h, sin(a) * 0.08)
		b.quad(Vector3(-0.015, 0, 0), Vector3(0.015, 0, 0), tip + Vector3(0.005, 0, 0), tip - Vector3(0.005, 0, 0),
			Tile.GRASS if i % 3 else Tile.LEAF, true)
	return b.commit()


## Кустик у стены: несколько комков листвы и сухие стебли.
static func _make_bush_small() -> Mesh:
	var b := PB.new()
	_lump(b, Vector3(0, 0, 0), 0.3, 0.25, 0.35, Tile.LEAF, 123, 7)
	_lump(b, Vector3(0.18, 0.15, 0.05), 0.18, 0.16, 0.25, Tile.LEAF, 124, 6)
	for i in 4:
		var a := TAU * i / 4.0
		b.quad(Vector3(cos(a) * 0.1 - 0.01, 0, sin(a) * 0.1), Vector3(cos(a) * 0.1 + 0.01, 0, sin(a) * 0.1),
			Vector3(cos(a) * 0.35, 0.55, sin(a) * 0.35), Vector3(cos(a) * 0.34, 0.55, sin(a) * 0.35), Tile.GRASS, true)
	return b.commit()


## Горшок с травами на крыше.
static func _make_herb_pot() -> Mesh:
	var b := PB.new()
	b.lathe([Vector2(0, 0), Vector2(0.12, 0), Vector2(0.16, 0.2), Vector2(0.18, 0.24), Vector2(0.15, 0.24), Vector2(0, 0.2)], 7, Tile.CLAY)
	_lump(b, Vector3(0, 0.2, 0), 0.17, 0.17, 0.22, Tile.LEAF, 125, 6)
	return b.commit()


# ─── Предметы с физикой (этап 5) ────────────────────────────────────────────

## Один черепок: выгнутый кусок стенки кувшина (~12 см), с двух сторон. Точка — середина.
static func _make_shard_piece() -> Mesh:
	var b := PB.new()
	var bend := 0.018
	var pts := [Vector3(-0.065, 0.0, -0.04), Vector3(0.0, bend, -0.055), Vector3(0.06, 0.0, -0.035),
		Vector3(0.07, 0.0, 0.03), Vector3(0.0, bend, 0.05), Vector3(-0.055, 0.0, 0.04)]
	b.quad(pts[0], pts[1], pts[4], pts[5], Tile.CLAY, true)
	b.quad(pts[1], pts[2], pts[3], pts[4], Tile.CLAY, true)
	return b.commit()


## Камень с кулак — чтобы кинуть. Точка — середина.
static func _make_stone_throw() -> Mesh:
	var b := PB.new()
	_lump(b, Vector3(0, -0.04, 0), 0.07, 0.06, 0.08, Tile.STONE, 161, 6)
	_lump(b, Vector3(0, 0.0, 0), 0.06, 0.055, -0.04, Tile.STONE, 162, 6)
	return b.commit()


## Окровавленный камень в руке первого святого. Точка — середина.
static func _make_stone_held() -> Mesh:
	var b := PB.new()
	_lump(b, Vector3(0, -0.05, 0), 0.09, 0.075, 0.1, Tile.STONE, 163, 6)
	_lump(b, Vector3(0.01, -0.01, 0), 0.07, 0.06, 0.07, Tile.BLOOD_DARK, 164, 5)
	return b.commit()
