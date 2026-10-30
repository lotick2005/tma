@tool
extends Node3D
## Каталог всех предметов PropLibrary в сетке с подписями — посмотреть библиотеку в редакторе
## (scenes/props/catalog.tscn) или запустить сцену (F6 в редакторе): свет ровный, без тумана.

const STEP := 3.0
const COLUMNS := 7


func _ready() -> void:
	for c in get_children():
		c.queue_free()
	var i := 0
	for kind in PropLibrary.KINDS:
		var mi := MeshInstance3D.new()
		mi.mesh = PropLibrary.mesh(kind)
		mi.material_override = PropLibrary.material()
		mi.position = Vector3((i % COLUMNS) * STEP, 0.0, (i / COLUMNS) * STEP)
		add_child(mi)
		var label := Label3D.new()
		label.text = kind
		label.pixel_size = 0.004
		label.position = mi.position + Vector3(0, -0.05, 1.0)
		label.rotation_degrees.x = -60.0
		add_child(label)
		i += 1
