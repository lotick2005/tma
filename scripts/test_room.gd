extends Node3D
## Тестовый коридор этапа 1: 45 м, колонны через каждые 5 м, ящики с шашечкой —
## видно дрожание вершин, плывущие текстуры и как дальние колонны растворяются в тумане.
## Отладка (флаг tma/debug/keys): 1 — белый свет за спиной героя, чтобы увидеть тень тела.

## Ширина, высота, длина коридора, м.
const ROOM := Vector3(6.0, 5.0, 45.0)
## Коридор идёт от z = START_Z на север (−Z).
const START_Z := 4.0
const WALL := 0.5
## Пол и стены режутся на квадраты такого размера (м), чтобы текстуры меньше плыли.
const CELL := 1.0
const COLUMN_STEP := 5.0
const COLUMN_X := 2.0
const COLUMN_RADIUS := 0.35
## Ящики: центр основания и размер.
const CRATES := [
	[Vector3(-1.2, 0.0, -3.0), Vector3(1.0, 1.0, 1.0)],
	[Vector3(-1.2, 1.0, -3.0), Vector3(0.7, 0.7, 0.7)],
	[Vector3(1.0, 0.0, -9.0), Vector3(1.2, 0.8, 1.2)],
	[Vector3(-0.8, 0.0, -17.0), Vector3(1.5, 1.5, 1.5)],
	[Vector3(1.4, 0.0, -26.0), Vector3(1.0, 1.2, 2.5)],
]

var _test_light: OmniLight3D

@onready var _player: Node3D = $Player


func _ready() -> void:
	# Фон — цвет тумана, тогда даль сливается с дымкой
	var env: Environment = $WorldEnvironment.environment
	env.background_color = PsxMaterial.global_param("psx_fog_color")

	var stone := PsxMaterial.make(ProcTextures.checker(64, 4, Color(0.82, 0.75, 0.6), Color(0.55, 0.48, 0.38)))
	var wood := PsxMaterial.make(ProcTextures.checker(64, 4, Color(0.55, 0.38, 0.22), Color(0.35, 0.23, 0.13), 0.08, 2))
	var marble := PsxMaterial.make(ProcTextures.checker(64, 8, Color(0.92, 0.9, 0.84), Color(0.6, 0.6, 0.62), 0.04, 3))

	var w := ROOM.x
	var h := ROOM.y
	var l := ROOM.z
	var cz := START_Z - l * 0.5
	_add_box(Vector3(0.0, -WALL, cz), Vector3(w, WALL, l), stone, 2.0)  # пол
	_add_box(Vector3(0.0, h, cz), Vector3(w, WALL, l), stone, 2.0)  # потолок
	_add_box(Vector3(-w * 0.5 - WALL * 0.5, 0.0, cz), Vector3(WALL, h, l), stone, 2.0)
	_add_box(Vector3(w * 0.5 + WALL * 0.5, 0.0, cz), Vector3(WALL, h, l), stone, 2.0)
	_add_box(Vector3(0.0, 0.0, START_Z + WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), stone, 2.0)
	_add_box(Vector3(0.0, 0.0, START_Z - l - WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), stone, 2.0)
	for c in CRATES:
		_add_box(c[0], c[1], wood, 1.0)
	var z := 0.0
	while z > START_Z - l + 1.0:
		for x in [-COLUMN_X, COLUMN_X]:
			_add_column(Vector3(x, 0.0, z), COLUMN_RADIUS, h, marble)
		z -= COLUMN_STEP


func _unhandled_input(event: InputEvent) -> void:
	if ProjectSettings.get_setting("tma/debug/keys", false) and event.is_action_pressed("debug_1"):
		if _test_light:
			_test_light.queue_free()
			_test_light = null
		else:
			_test_light = OmniLight3D.new()
			_test_light.light_color = Color(0.85, 0.9, 1.0)
			_test_light.light_energy = 2.0
			_test_light.omni_range = 25.0
			_test_light.shadow_enabled = true
			add_child(_test_light)


func _process(_delta: float) -> void:
	if _test_light:
		# За спиной и чуть выше головы — как будет светить ангел
		_test_light.global_position = _player.global_position + _player.global_basis.z * 2.5 + Vector3.UP * 2.2


## Ящик по центру основания.
func _add_box(base: Vector3, size: Vector3, mat: Material, tile: float) -> void:
	var body := StaticBody3D.new()
	body.position = base + Vector3.UP * size.y * 0.5
	var mesh := MeshInstance3D.new()
	mesh.mesh = PsxMesh.box(size, tile, CELL)
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	add_child(body)


func _add_column(base: Vector3, radius: float, height: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = base
	var mesh := MeshInstance3D.new()
	mesh.mesh = PsxMesh.column(radius, height, 8, 1.0, CELL)
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = radius
	shape.shape.height = height
	shape.position.y = height * 0.5
	body.add_child(shape)
	add_child(body)
