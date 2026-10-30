extends Node3D
## Тестовая комната этапа 1: пол, стены, ящики и колонны с шашечкой,
## чтобы видеть дрожание вершин и плывущие текстуры.

const ROOM := Vector3(20.0, 5.0, 20.0)
const WALL := 0.5
## Ящики: центр основания и размер.
const CRATES := [
	[Vector3(-3.0, 0.0, -2.0), Vector3(1.0, 1.0, 1.0)],
	[Vector3(-3.0, 1.0, -2.0), Vector3(0.7, 0.7, 0.7)],
	[Vector3(-1.6, 0.0, -2.4), Vector3(1.2, 0.8, 1.2)],
	[Vector3(4.0, 0.0, 3.0), Vector3(1.5, 1.5, 1.5)],
	[Vector3(6.5, 0.0, -6.0), Vector3(3.0, 0.9, 1.0)],
	[Vector3(-6.0, 0.0, 5.0), Vector3(1.0, 1.2, 2.5)],
]
## Колонны: центр основания.
const COLUMNS := [
	Vector3(-4.0, 0.0, -6.0), Vector3(0.0, 0.0, -6.0), Vector3(4.0, 0.0, -6.0),
	Vector3(-4.0, 0.0, 0.0), Vector3(4.0, 0.0, -1.5),
]
const COLUMN_RADIUS := 0.4

var _stone: ShaderMaterial
var _wood: ShaderMaterial
var _marble: ShaderMaterial


func _ready() -> void:
	_stone = PsxMaterial.make(ProcTextures.checker(64, 4, Color(0.82, 0.75, 0.6), Color(0.55, 0.48, 0.38)))
	_wood = PsxMaterial.make(ProcTextures.checker(64, 4, Color(0.55, 0.38, 0.22), Color(0.35, 0.23, 0.13), 0.08, 2))
	_marble = PsxMaterial.make(ProcTextures.checker(64, 8, Color(0.92, 0.9, 0.84), Color(0.6, 0.6, 0.62), 0.04, 3))

	var w := ROOM.x
	var d := ROOM.z
	var h := ROOM.y
	_add_box(Vector3(0.0, -WALL, 0.0), Vector3(w, WALL, d), _stone, 2.0)  # пол
	_add_box(Vector3(0.0, h, 0.0), Vector3(w, WALL, d), _stone, 2.0)  # потолок
	_add_box(Vector3(0.0, 0.0, -d * 0.5 - WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), _stone, 2.0)
	_add_box(Vector3(0.0, 0.0, d * 0.5 + WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), _stone, 2.0)
	_add_box(Vector3(-w * 0.5 - WALL * 0.5, 0.0, 0.0), Vector3(WALL, h, d), _stone, 2.0)
	_add_box(Vector3(w * 0.5 + WALL * 0.5, 0.0, 0.0), Vector3(WALL, h, d), _stone, 2.0)
	for c in CRATES:
		_add_box(c[0], c[1], _wood, 1.0)
	for p in COLUMNS:
		_add_column(p, COLUMN_RADIUS, h, _marble)


## Ящик по центру основания.
func _add_box(base: Vector3, size: Vector3, mat: Material, tile: float) -> void:
	var body := StaticBody3D.new()
	body.position = base + Vector3.UP * size.y * 0.5
	var mesh := MeshInstance3D.new()
	mesh.mesh = PsxMesh.box(size, tile)
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
	mesh.mesh = PsxMesh.column(radius, height, 8, 1.0)
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = radius
	shape.shape.height = height
	shape.position.y = height * 0.5
	body.add_child(shape)
	add_child(body)
