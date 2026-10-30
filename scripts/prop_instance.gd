@tool
extends MeshInstance3D
## Один предмет из библиотеки PropLibrary — для ручной расстановки в редакторе.
## Брось res://scenes/props/prop.tscn в сцену и выбери kind. Уровни из кода ставят предметы сами (QuarterProps).

@export var kind := "jar_large":
	set(value):
		kind = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	if property.name == "kind":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PropLibrary.KINDS.keys())


func _rebuild() -> void:
	if not PropLibrary.KINDS.has(kind):
		mesh = null
		return
	mesh = PropLibrary.mesh(kind)
	material_override = PropLibrary.material()
