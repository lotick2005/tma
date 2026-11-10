extends Node
## Система шума (autoload NoiseSystem, этап 5, CLAUDE.md §4 «Слух»).
## Любое действие создаёт шумовое событие {позиция, радиус, источник}: шаг героя, упавший кувшин,
## брошенный черепок. Святые подписаны на сигнал noise и сами решают, слышат ли (расстояние, стены).
## Радиусы — data/stealth.gd.
## Отладка (tma/debug/keys): клавиша 5 — круги шума на земле и состояния святых над головами
## (святые слушают сигнал debug_changed).

const S := preload("res://data/stealth.gd")

## Шумовое событие. source — что шумит: "step" (шаги героя), "impact" (удар предмета), "throw"…;
## maker — кто (герой, предмет), может быть null.
signal noise(pos: Vector3, radius: float, source: String, maker: Object)
## Включили / выключили отладочный показ (клавиша 5).
signal debug_changed(on: bool)

## Слой физики со стенами (луч «за стеной ли» проверяет только его).
const WALL_MASK := 1
## Сколько секунд виден отладочный круг.
const DEBUG_LIFE := 1.4

var debug_visible := false
## Последнее событие (для тестов и отладки): [позиция, радиус, источник].
var last_event: Array = []

var _debug_keys := false
var _rings: Array = []  # [MeshInstance3D, сколько осталось]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_debug_keys = ProjectSettings.get_setting("tma/debug/keys", false)


## Шумнуть: pos — где, radius — дальше этого не слышно (м), source — что это.
func make_noise(pos: Vector3, radius: float, source: String, maker: Object = null) -> void:
	if radius <= 0.01:
		return
	last_event = [pos, radius, source]
	noise.emit(pos, radius, source, maker)
	if debug_visible:
		_add_ring(pos, radius, source)


## Слышно ли шум из точки pos радиуса radius в точке ear: ближе радиуса, а за стеной — ближе radius × WALL_FACTOR.
## Разница высот считается вполовину (шаг — у земли, ухо — на голове).
func audible(pos: Vector3, radius: float, ear: Vector3, world: World3D) -> bool:
	# Высоту учитываем вполовину: шаг у ног, ухо на голове — «4 м» значит 4 м по земле
	var off := ear - pos
	off.y *= 0.5
	var d := off.length()
	if d > radius:
		return false
	if d <= radius * S.WALL_FACTOR:
		return true
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, ear, WALL_MASK)
	return world.direct_space_state.intersect_ray(q).is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if _debug_keys and event.is_action_pressed("debug_5"):
		set_debug_visible(not debug_visible)


func set_debug_visible(on: bool) -> void:
	debug_visible = on
	debug_changed.emit(on)
	if not on:
		for r: Array in _rings:
			(r[0] as Node).queue_free()
		_rings.clear()


func _process(delta: float) -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var r: Array = _rings[i]
		r[1] -= delta
		var mi: MeshInstance3D = r[0]
		if r[1] <= 0.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_rings.remove_at(i)
		else:
			(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(r[1] / DEBUG_LIFE, 0.0, 1.0)


## Отладочный круг шума на земле: жёлтый — шаги, красный — удары и броски.
func _add_ring(pos: Vector3, radius: float, source: String) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := 40
	for i in n + 1:
		var a := TAU * i / n
		im.surface_add_vertex(Vector3(cos(a) * radius, 0.05, sin(a) * radius))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.9, 0.2) if source == "step" else Color(1.0, 0.3, 0.2)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	root.add_child(mi)
	mi.global_position = pos
	_rings.append([mi, DEBUG_LIFE])
