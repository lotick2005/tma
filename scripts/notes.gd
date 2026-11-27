class_name Notes
extends Node3D
## Записки в мире (этап 5б, CLAUDE.md §6): свиток, восковая табличка или черепок с надписью — лоуполи, без значков
## и контура. Слегка видны в темноте (полировка демо 5): тёплый слабый блик (собственная подсветка материала) медленно
## пульсирует (PULSE_PERIOD), заметен ближе GLOW_FAR, во всю силу — ближе GLOW_NEAR; не ярче огонька светильника.
## Пока светильник в руке и записка ближе GLINT_RANGE, блик чуть сильнее (с мерцанием огня).
## Читать — ПКМ (HeroHands зовёт readable(), экран — NotesUI).
## Тексты — data/notes/notes.gd, места — NOTES в данных уровня.

const T := preload("res://data/notes/notes.gd")

## Дальше этого, м, записку не прочитать; и только если она в конусе взгляда (угол, градусы).
const READ_DISTANCE := 2.3
const READ_ANGLE := 22.0
## Блик в свете светильника: с какого расстояния, м, и сколько максимум (собственная подсветка 0..1).
const GLINT_RANGE := 3.5
const GLINT_MAX := 0.22
## Пульс в темноте: период, с; подсветка в минимуме и максимуме пульса; во всю силу ближе GLOW_NEAR м, дальше
## гаснет и к GLOW_FAR м пропадает.
const PULSE_PERIOD := 3.5
const GLOW_MIN := 0.22
const GLOW_MAX := 0.55
const GLOW_NEAR := 4.5
const GLOW_FAR := 6.0
## Подсветка умножается на цвет поверхности (тёмный воск таблички светился бы впятеро слабее свитка): яркость блика
## в пике пульса — GLOW_LUMA независимо от материала (цвет подсветки усиливается по яркости поверхности).
const GLOW_LUMA := 0.42
const GLOW_TINT := Color(1.0, 0.78, 0.5)

## [id, Node3D, материал с «бликом», усиление цвета подсветки]
var _items: Array = []
var _t := 0.0


## Текст и поля записки по id ({} — нет такой).
static func info(id: String) -> Dictionary:
	return T.NOTES.get(id, {})


## Положить записку id в точку pos (на пол / на стол), поворот yaw. indoor — внутри дома (слой без небесного света).
func spawn(id: String, pos: Vector3, yaw: float, indoor := false) -> void:
	var inf := info(id)
	if inf.is_empty():
		push_warning("Notes: нет записки «%s» в data/notes/notes.gd" % id)
		return
	var form: String = inf.get("form", "scroll")
	var node := Node3D.new()
	node.name = "Note_" + id
	add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var glint: ShaderMaterial
	match form:
		"tablet":
			glint = _build_tablet(node)
		"shard":
			glint = _build_shard(node)
		_:
			glint = _build_scroll(node)
	if indoor:
		for mi in node.get_children():
			(mi as VisualInstance3D).layers = 1 << (LevelBuilder.INTERIOR_LAYER - 1)
	PropRegistry.add_box("note_" + form, node.global_transform, AABB(Vector3(-0.2, 0.0, -0.12), Vector3(0.4, 0.06, 0.24)))
	# Яркость поверхности (средняя по текстуре письма) → во сколько раз усилить цвет подсветки
	var tex := glint.get_shader_parameter("albedo_texture") as Texture2D
	var luma := 0.5
	if tex:
		var img := tex.get_image()
		var sum := 0.0
		for y in img.get_height():
			for x in img.get_width():
				sum += img.get_pixel(x, y).get_luminance()
		luma = sum / (img.get_width() * img.get_height())
	var gain := GLOW_LUMA / maxf(luma * GLOW_MAX, 0.02)
	glint.set_shader_parameter("self_illum_color", GLOW_TINT * gain)
	_items.append([id, node, glint, gain])


## Записка, которую можно прочитать: в луче взгляда, ближе READ_DISTANCE, не за стеной.
## {"id", "dist"} или {} — нет (dist — чтобы сравнить с предметом, который можно взять).
func readable(from: Vector3, dir: Vector3, exclude: Array = []) -> Dictionary:
	var ex: Array[RID] = []
	ex.assign(exclude)
	var best := {}
	var best_score := INF
	var cos_max := cos(deg_to_rad(READ_ANGLE))
	for it: Array in _items:
		var to: Vector3 = (it[1] as Node3D).global_position + Vector3.UP * 0.04 - from
		var d := to.length()
		if d > READ_DISTANCE or d < 0.01:
			continue
		var c := to.dot(dir) / d
		if c < cos_max:
			continue
		var score := d * (2.0 - c)
		if score >= best_score:
			continue
		# Не сквозь стену: луч до записки не упирается в геометрию раньше неё
		var q := PhysicsRayQueryParameters3D.create(from, from + to * maxf(0.0, 1.0 - 0.12 / d))
		q.collision_mask = 1
		q.exclude = ex
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		best_score = score
		best = {"id": it[0], "dist": d}
	return best


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var lamp := GameState.lamp_out
	# Мерцание огня — общее для всех записок
	var flicker := 0.8 + 0.2 * sin(_t * 9.3) * sin(_t * 3.7 + 1.0)
	for i in _items.size():
		var it: Array = _items[i]
		var d := cam.global_position.distance_to((it[1] as Node3D).global_position)
		# Медленный пульс (у каждой записки своя фаза)
		var pulse := 0.5 + 0.5 * sin(_t * TAU / PULSE_PERIOD + i * 1.7)
		var k := lerpf(GLOW_MIN, GLOW_MAX, pulse * pulse) * (1.0 - smoothstep(GLOW_NEAR, GLOW_FAR, d))
		if lamp and d < GLINT_RANGE:
			k += GLINT_MAX * (1.0 - d / GLINT_RANGE) * flicker
		(it[2] as ShaderMaterial).set_shader_parameter("self_illum", minf(k, 0.75))


# ─── Меши ────────────────────────────────────────────────────────────────────

## Свиток: развёрнутый лист с письмом и две скалки по краям (одна закатана толще).
func _build_scroll(node: Node3D) -> ShaderMaterial:
	var sheet := PsxMaterial.make(_writing_texture(Color(0.80, 0.70, 0.50), Color(0.20, 0.12, 0.07), 11), Color.WHITE)
	sheet.set_shader_parameter("self_illum_color", Color(1.0, 0.85, 0.6))
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.17, 0.2)
	_mesh(node, plane, sheet, Vector3(0.0, 0.012, 0.0))
	var roll_mat := PsxMaterial.make(null, Color(0.66, 0.55, 0.36))
	for r: Array in [[-0.115, 0.024], [0.11, 0.016]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = r[1]
		cyl.bottom_radius = r[1]
		cyl.height = 0.21
		cyl.radial_segments = 6
		cyl.rings = 1
		var mi := _mesh(node, cyl, roll_mat, Vector3(0.0, r[1], r[0]))
		mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
	return sheet


## Восковая табличка: две створки (диптих) — деревянная рамка, в ней тёмный воск с процарапанными строками.
func _build_tablet(node: Node3D) -> ShaderMaterial:
	var wax := PsxMaterial.make(_writing_texture(Color(0.20, 0.15, 0.09), Color(0.62, 0.52, 0.34), 7), Color.WHITE)
	wax.set_shader_parameter("self_illum_color", Color(1.0, 0.8, 0.55))
	var wood := PsxMaterial.make(null, Color(0.45, 0.30, 0.17))
	for side: float in [-0.105, 0.105]:
		var frame := BoxMesh.new()
		frame.size = Vector3(0.19, 0.016, 0.15)
		_mesh(node, frame, wood, Vector3(side, 0.008, 0.0))
		var face := PlaneMesh.new()
		face.size = Vector2(0.16, 0.12)
		_mesh(node, face, wax, Vector3(side, 0.0165, 0.0))
	return wax


## Черепок с надписью чернилами (остракон).
func _build_shard(node: Node3D) -> ShaderMaterial:
	var clay := PsxMaterial.make(_writing_texture(Color(0.62, 0.36, 0.22), Color(0.12, 0.07, 0.05), 5), Color.WHITE)
	clay.set_shader_parameter("self_illum_color", Color(1.0, 0.8, 0.55))
	var body := BoxMesh.new()
	body.size = Vector3(0.2, 0.014, 0.15)
	_mesh(node, body, PsxMaterial.make(null, Color(0.55, 0.31, 0.19)), Vector3(0.0, 0.007, 0.0))
	var face := PlaneMesh.new()
	face.size = Vector2(0.18, 0.13)
	_mesh(node, face, clay, Vector3(0.0, 0.0145, 0.0))
	return clay


func _mesh(node: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	node.add_child(mi)
	return mi


## Поверхность с письмом 32×32: фон с шумом и строки коротких штрихов (буквы не читаются — PS1).
func _writing_texture(base: Color, ink: Color, seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, base.darkened(rng.randf_range(-0.06, 0.1)))
	var y := 4
	while y < 29:
		var x := 3 + rng.randi_range(0, 1)
		var end := 28 - rng.randi_range(0, 6)
		while x < end:
			var w := rng.randi_range(1, 3)
			for i in w:
				if x + i < end:
					img.set_pixel(x + i, y, ink.lerp(base, rng.randf_range(0.0, 0.3)))
			x += w + rng.randi_range(1, 2)
		y += 3
	return ImageTexture.create_from_image(img)
