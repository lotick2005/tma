@tool
extends Node3D
## Каталог всех предметов PropLibrary в сетке с подписями — посмотреть библиотеку в редакторе
## (scenes/props/catalog.tscn) или запустить сцену (F6 в редакторе): свет ровный, без тумана.
## Рядом с каждым предметом стоит фигура героя (1,75 м) — проверка масштаба: стол 0,7 м, табурет 0,45 м,
## большой кувшин 0,8 м, дверь 2,1 м. Сетка на полу — 0,5 м.

const STEP := 3.5
const COLUMNS := 8
## Где фигура относительно предмета.
const HERO_OFFSET := Vector3(-1.1, 0.0, 0.3)


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Каталог смотрят без тумана psx-шейдера
		PsxMaterial.set_global("psx_fog_start", 500.0)
		PsxMaterial.set_global("psx_fog_end", 600.0)
	for c in get_children():
		c.queue_free()
	var hero_meshes := _hero_meshes()
	var i := 0
	for kind in PropLibrary.KINDS:
		var mi := MeshInstance3D.new()
		mi.mesh = PropLibrary.mesh(kind)
		mi.material_override = PropLibrary.material()
		mi.position = Vector3((i % COLUMNS) * STEP, 0.0, (i / COLUMNS) * STEP)
		add_child(mi)
		_add_hero(mi.position + HERO_OFFSET, hero_meshes)
		var label := Label3D.new()
		label.text = kind
		label.pixel_size = 0.004
		label.position = mi.position + Vector3(0, -0.05, 1.0)
		label.rotation_degrees.x = -60.0
		add_child(label)
		i += 1


## Фигура героя для масштаба — модель hero в позе idle, запечённая в статичный меш (один на весь каталог).
func _hero_meshes() -> Array:
	return [CharacterModel.bake_pose("hero", "idle", 0.0)]


func _add_hero(pos: Vector3, meshes: Array) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = meshes[0]
	mi.material_override = CharacterModel.material("hero")
	mi.position = pos
	add_child(mi)
