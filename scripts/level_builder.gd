class_name LevelBuilder
extends RefCounted
## Сборка статичной геометрии уровня из кода (данные — в res://data/).
## Меши с одним материалом сливаются в один и режутся на квадраты CHUNK метров:
## так на весь уровень несколько десятков вызовов отрисовки (важно для браузера),
## а куски за спиной камера всё равно отсекает. Все коллизии — в одном StaticBody3D.
## Координаты здесь уже в метрах Godot: карту в них переводит WorldCoords.
## Два вида пакетов: «ориентиры» (стены Храма, Антония — видны издалека, куски по CHUNK м) и
## «местные» (квартал, предметы — куски по LOCAL_CHUNK м, дальше detail_range не рисуются:
## туман их всё равно скрывает). Какой вид и слой у следующих мешей — переменные local и layer.

const CHUNK := 40.0
const LOCAL_CHUNK := 24.0
## Слой «внутри домов»: небесный свет (солнце, чёрное солнце, луна) его не освещает.
const INTERIOR_LAYER := 4

## Узел, куда кладутся меши и коллизии.
var root: Node3D
var body: StaticBody3D
## Размер ячейки, на которую режутся грани, м (CLAUDE.md §7: ~1 м, как на PS1).
var cell := 1.0
## Слой отрисовки следующих мешей (1 — обычный, INTERIOR_LAYER — внутри домов).
var layer := 1
## true — следующие меши «местные» (см. выше).
var local := false
## Дальше этого расстояния местные куски не рисуются, м.
var detail_range := 45.0
## Созданные местные MeshInstance3D: им уровень меняет дальность при смене света.
var local_instances: Array[GeometryInstance3D] = []

var _batches := {}
var _batch_info := {}
## Повторяющиеся мелочи: ключ -> [меш, материал, слой, центр куска, PackedFloat32Array трансформов]
var _instances := {}
## Куски для MultiMesh крупнее: меньше вызовов отрисовки.
const INSTANCE_CHUNK := 32.0
var _inflate_counter := 0
## Формы коллизии по мешу: одинаковые лавки делят одну форму.
var _trimesh_cache := {}

## ─── Запечённый свет в вершинах (VertexLight) и тени-пятна (BlobShadows) ───
## false — следующие коллизии и коробки не заслоняют свет (невидимые границы уровня).
var occlude := true
## Запекать ли свет в вершины при commit().
var bake_light := true
## Тёплые пятна: [позиция, радиус, сила] (огоньки в нишах и жаровни — Glows.light_spots()).
var warm_spots: Array = []
## Сколько миллисекунд заняло запекание в последнем commit() (для отчёта / отладки).
var bake_ms := 0
## Заслонители: [Transform3D центра, размер] и треугольники в мировых координатах.
var _occ_boxes: Array = []
var _occ_faces := PackedVector3Array()
## Тени-пятна под неподвижным (тела): один меш на строитель.
var blobs := BlobShadows.new()


func _init(parent: Node3D) -> void:
	root = parent
	body = StaticBody3D.new()
	body.name = "Collision"
	root.add_child(body)


## Меш с трансформом в общий пакет материала (с текущими layer и local).
func add_mesh(mesh: Mesh, xform: Transform3D, mat: Material) -> void:
	var center := xform * mesh.get_aabb().get_center()
	var size := LOCAL_CHUNK if local else CHUNK
	var cx := floori(center.x / size)
	var cz := floori(center.z / size)
	var key := "%d:%d:%d:%d:%d" % [mat.get_instance_id(), layer, int(local), cx, cz]
	var st: SurfaceTool = _batches.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
		# Узел ставится в середину куска: дальность видимости считается от него
		_batch_info[key] = [mat, layer, local, Vector3((cx + 0.5) * size, 0.0, (cz + 0.5) * size)]
	var origin: Vector3 = _batch_info[key][3]
	st.append_from(mesh, 0, Transform3D(Basis(), -origin) * xform)


## Экземпляр повторяющегося предмета (MultiMeshInstance3D по кускам INSTANCE_CHUNK м, «местный»).
func add_instance(mesh: Mesh, xform: Transform3D, mat: Material) -> void:
	var cx := floori(xform.origin.x / INSTANCE_CHUNK)
	var cz := floori(xform.origin.z / INSTANCE_CHUNK)
	var key := "%d:%d:%d:%d" % [mesh.get_instance_id(), layer, cx, cz]
	if not _instances.has(key):
		_instances[key] = [mesh, mat, layer, Vector3((cx + 0.5) * INSTANCE_CHUNK, 0.0, (cz + 0.5) * INSTANCE_CHUNK), []]
	var entry: Array = _instances[key]
	(entry[4] as Array).append(Transform3D(xform.basis, xform.origin - entry[3]))


## Ящик: base — центр нижней грани, size — размер, yaw — поворот вокруг Y (рад).
## collide = false — только картинка (дальний фон, мелочь).
## Картинка чуть больше коллизии (на _inflate() с каждой стороны): у соседних коробок грани
## не совпадают, одна перекрывает шов другой — на стыках не мелькают щели.
func box(base: Vector3, size: Vector3, mat: Material, tile: float = 1.0, collide: bool = true,
		yaw: float = 0.0, skip_faces: int = 0, cell_override: float = 0.0) -> void:
	var xform := Transform3D(Basis(Vector3.UP, yaw), base + Vector3.UP * size.y * 0.5)
	var c := cell_override if cell_override > 0.0 else cell
	var e := minf(_inflate(), size[size.min_axis_index()] * 0.1)
	add_mesh(PsxMesh.box(size + Vector3.ONE * e * 2.0, tile, c, skip_faces), xform, mat)
	if collide:
		collision_box(xform, size)
	elif occlude:
		# Видимая коробка без коллизии (парапет, перемычка) тоже заслоняет; жерди и брусья (два размера < 0,4 м) — нет
		var dims := [size.x, size.y, size.z]
		dims.sort()
		if dims[1] >= 0.4:
			_occ_boxes.append([xform, size])


## Ящик по двум углам (min, max).
func box_between(a: Vector3, b: Vector3, mat: Material, tile: float = 1.0, collide: bool = true,
		skip_faces: int = 0, cell_override: float = 0.0) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	var size := hi - lo
	box(Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5), size, mat, tile, collide, 0.0, skip_faces, cell_override)


## Колонна (8–12-угольная призма), base — центр основания.
func column(base: Vector3, radius: float, height: float, mat: Material, sides: int = 8, tile: float = 1.0,
		collide: bool = true) -> void:
	add_mesh(PsxMesh.column(radius, height, sides, tile, cell), Transform3D(Basis(), base), mat)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision_shape(shape, Transform3D(Basis(), base + Vector3.UP * height * 0.5))


## Произвольный меш с точной коллизией по треугольникам. Картинка, как у box(), чуть раздута.
## Меш должен стоять в своём начале координат (рельеф и меши в мировых координатах — с inflate = false).
func mesh_with_trimesh(mesh: Mesh, xform: Transform3D, mat: Material, inflate: bool = true) -> void:
	var size := mesh.get_aabb().size
	var e := _inflate() if inflate else 0.0
	var k := Vector3.ONE + Vector3.ONE * e * 2.0 / size.max(Vector3.ONE * 0.01)
	add_mesh(mesh, Transform3D(xform.basis * Basis.from_scale(k), xform.origin), mat)
	var id := mesh.get_instance_id()
	if not _trimesh_cache.has(id):
		_trimesh_cache[id] = mesh.create_trimesh_shape()
	collision_shape(_trimesh_cache[id], xform)


## Невидимая стена или коробка коллизии. xform — центр коробки.
func collision_box(xform: Transform3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape(shape, xform)


func collision_shape(shape: Shape3D, xform: Transform3D) -> void:
	if occlude:
		if shape is BoxShape3D:
			_occ_boxes.append([xform, (shape as BoxShape3D).size])
		elif shape is CylinderShape3D:
			var cyl := shape as CylinderShape3D
			_occ_boxes.append([Transform3D(Basis(), xform.origin), Vector3(cyl.radius * 1.6, cyl.height, cyl.radius * 1.6)])
		elif shape is ConcavePolygonShape3D:
			var f := (shape as ConcavePolygonShape3D).get_faces()
			for k in f.size():
				f[k] = xform * f[k]
			_occ_faces.append_array(f)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	body.add_child(cs)


## Раздутие картинки, м: от 1 до 4,6 см, у идущих подряд построек — разное.
func _inflate() -> float:
	_inflate_counter += 1
	return 0.01 + 0.006 * (_inflate_counter % 7)


## Создаёт MeshInstance3D из накопленных пакетов. Вызвать один раз в конце сборки.
func commit() -> void:
	var t0 := Time.get_ticks_msec()
	var light := _make_vertex_light()
	var i := 0
	for key in _batches:
		var st: SurfaceTool = _batches[key]
		var info: Array = _batch_info[key]
		var mi := MeshInstance3D.new()
		mi.name = "Geo%d" % i
		if light and info[0] is ShaderMaterial and (info[0] as ShaderMaterial).shader == PsxMaterial.SHADER:
			# Общие вершины сливаются (их в ~2,5 раза меньше: и запекать быстрее, и видеокарте легче)
			st.index()
			var arrays := st.commit_to_arrays()
			arrays[Mesh.ARRAY_COLOR] = light.colors(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], info[3])
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mi.mesh = am
		else:
			mi.mesh = st.commit()
		mi.material_override = info[0]
		mi.layers = 1 << (int(info[1]) - 1)
		mi.position = info[3]
		if info[2]:
			mi.visibility_range_end = detail_range
			local_instances.append(mi)
		root.add_child(mi)
		i += 1
	_batches.clear()
	_batch_info.clear()
	_occ_boxes.clear()
	_occ_faces.clear()
	bake_ms = Time.get_ticks_msec() - t0
	blobs.commit(root)
	for key in _instances:
		var entry: Array = _instances[key]
		var xforms: Array = entry[4]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry[0]
		mm.instance_count = xforms.size()
		for j in xforms.size():
			mm.set_instance_transform(j, xforms[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Many%d" % i
		mmi.multimesh = mm
		mmi.material_override = entry[1]
		mmi.layers = 1 << (int(entry[2]) - 1)
		mmi.position = entry[3]
		mmi.visibility_range_end = detail_range
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		local_instances.append(mmi)
		root.add_child(mmi)
		i += 1
	_instances.clear()


## Сетка заслонителей для запекания, если есть что запекать (null — запекание выключено).
func _make_vertex_light() -> VertexLight:
	if not bake_light or _batches.is_empty():
		return null
	var bounds := AABB()
	var first := true
	for key in _batches:
		var info: Array = _batch_info[key]
		if not (info[0] is ShaderMaterial and (info[0] as ShaderMaterial).shader == PsxMaterial.SHADER):
			continue
		# Границы куска: по XZ — сам кусок, по высоте — заслонители решат; берём середину и размер куска
		var size := LOCAL_CHUNK if info[2] else CHUNK
		var c: Vector3 = info[3]
		var ab := AABB(c - Vector3(size * 0.5, 0.0, size * 0.5), Vector3(size, 0.0, size))
		bounds = ab if first else bounds.merge(ab)
		first = false
	if first:
		return null
	# По высоте — от низа до верха заслонителей и тёплых пятен
	var y0 := INF
	var y1 := -INF
	for b: Array in _occ_boxes:
		var xf: Transform3D = b[0]
		var hy: float = (b[1] as Vector3).y * 0.5
		y0 = minf(y0, xf.origin.y - hy)
		y1 = maxf(y1, xf.origin.y + hy)
	for p in _occ_faces:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	if y0 > y1:
		return null
	bounds.position.y = y0
	bounds.size.y = y1 - y0
	var vl := VertexLight.new()
	vl.build(bounds, _occ_boxes, _occ_faces, warm_spots)
	return vl if vl.ok else null


## Дальность местных кусков (днём видно далеко, во тьме — нет смысла рисовать дальше тумана).
func set_detail_range(range_m: float) -> void:
	detail_range = range_m
	for mi in local_instances:
		mi.visibility_range_end = range_m
