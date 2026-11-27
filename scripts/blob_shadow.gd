class_name BlobShadow
extends MeshInstance3D
## Подвижная тень-пятно (CLAUDE.md §7): квадрат на полу под целью (святой, герой, предмет с физикой).
## Узел — ребёнок цели, но стоит в мире сам (top_level): не крутится, когда кувшин кувыркается.
## Пол ищет лучом вниз по слою мира (1); над пустотой или высоко над полом — тает.

## Половина размера пятна по X и Z, м.
var half := Vector2(0.35, 0.35)
## Луч вниз от точки цели (+UP_FROM м) до DOWN_TO м под ней.
const UP_FROM := 0.4
const DOWN_TO := 2.5
## Выше этого над полом пятно гаснет полностью, м.
const FADE_HEIGHT := 1.5
var _alpha := 1.0
var _target: Node3D
var _exclude: Array[RID] = []
## Предметы с физикой: пока спит, пол не ищем.
var _body: RigidBody3D
var _skip := 0


## Повесить пятно на цель: size — габарит по полу (x, z), м; alpha — прозрачность 0..1.
static func attach(target: Node3D, size: Vector2, alpha: float = 1.0) -> BlobShadow:
	var b := BlobShadow.new()
	b.name = "BlobShadow"
	b._target = target
	b.half = size * 0.5 * BlobShadows.GROW + Vector2(0.06, 0.06)
	if target is CollisionObject3D:
		b._exclude = [(target as CollisionObject3D).get_rid()]
	if target is RigidBody3D:
		b._body = target
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	b.mesh = quad
	b.material_override = BlobShadows.material()
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b._alpha = alpha
	target.add_child(b)
	return b



func _ready() -> void:
	top_level = true
	_update()


func _physics_process(_delta: float) -> void:
	if _body and _body.sleeping and _skip > 0:
		return
	_skip += 1
	_update()


func _update() -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		return
	var from := _target.global_position + Vector3.UP * UP_FROM
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (UP_FROM + DOWN_TO), 1, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		visible = false
		return
	var h := from.y - UP_FROM - (hit.position as Vector3).y
	var k := clampf(1.0 - h / FADE_HEIGHT, 0.0, 1.0)
	visible = k > 0.02 and _target.is_visible_in_tree()
	if not visible:
		return
	var n: Vector3 = hit.normal
	var fwd := _target.global_basis.z
	fwd = (fwd - n * fwd.dot(n))
	if fwd.length_squared() < 1e-6:
		fwd = Vector3.BACK
	fwd = fwd.normalized()
	var right := n.cross(fwd).normalized()
	global_transform = Transform3D(Basis(right * half.x, n, fwd * half.y), (hit.position as Vector3) + n * BlobShadows.LIFT)
	transparency = 1.0 - k * _alpha
