class_name PropRegistry
extends RefCounted
## Где какой предмет стоит — для отладочных подписей (панель 0 → «Подписи предметов»): луч из камеры
## находит предмет под прицелом и показывает его kind. Предметы слиты в общие меши, поэтому
## отдельных узлов у них нет — здесь хранятся вид, положение и границы каждого.
## Уровень очищает реестр перед сборкой (clear) — в нём только предметы текущего уровня.

## [kind, Transform3D, AABB в координатах предмета].
static var _items: Array = []


static func clear() -> void:
	_items.clear()


static func add(kind: String, xf: Transform3D) -> void:
	var aabb := PropLibrary.mesh(kind).get_aabb().grow(0.04)
	_items.append([kind, xf, aabb])


## Ближайший предмет на луче from → dir не дальше max_dist; блокирует то, что ближе стены (hit_limit). "" — ничего.
static func pick(from: Vector3, dir: Vector3, max_dist: float, hit_limit: float = INF) -> String:
	var best := ""
	var best_d := minf(max_dist, hit_limit + 0.3)
	for it: Array in _items:
		var xf: Transform3D = it[1]
		if xf.origin.distance_to(from) > max_dist + 4.0:
			continue
		var inv := xf.affine_inverse()
		var hit: Variant = (it[2] as AABB).intersects_ray(inv * from, inv.basis * dir)
		if hit == null:
			continue
		var d := from.distance_to(xf * (hit as Vector3))
		if d < best_d:
			best_d = d
			best = it[0]
	return best
