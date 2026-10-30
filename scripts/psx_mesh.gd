class_name PsxMesh
extends RefCounted
## Генераторы лоуполи-мешей для блокаута.
## UV считаются в метрах (делённых на tile), поэтому плотность текселей одинакова на всех гранях
## и текстура соседних блоков стыкуется. Грани режутся на ячейки не больше cell метров:
## на больших треугольниках аффинные текстуры плывут слишком сильно (на PS1 делали так же).


## Ящик с центром в начале координат.
static func box(size: Vector3, tile: float = 1.0, cell: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	# Нормаль, «вправо» и «вверх» грани, если смотреть на неё снаружи.
	var faces := [
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hn := absf(h.dot(n))
		var hu := absf(h.dot(u))
		var hv := absf(h.dot(v))
		var nu := maxi(1, ceili(hu * 2.0 / cell))
		var nv := maxi(1, ceili(hv * 2.0 / cell))
		for i in nu:
			for j in nv:
				var u0 := lerpf(-hu, hu, float(i) / nu)
				var u1 := lerpf(-hu, hu, float(i + 1) / nu)
				var v0 := lerpf(-hv, hv, float(j) / nv)
				var v1 := lerpf(-hv, hv, float(j + 1) / nv)
				var tl := n * hn + u * u0 + v * v1
				var tr := n * hn + u * u1 + v * v1
				var br := n * hn + u * u1 + v * v0
				var bl := n * hn + u * u0 + v * v0
				# Godot: лицевая сторона — обход по часовой стрелке
				for p in [tl, tr, br, tl, br, bl]:
					st.set_normal(n)
					st.set_uv(Vector2(p.dot(u), -p.dot(v)) / tile)
					st.add_vertex(p)
	return st.commit()


## Колонна (n-угольная призма) с основанием в начале координат.
static func column(radius: float, height: float, sides: int = 8, tile: float = 1.0, cell: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(1, ceili(height / cell))
	var perimeter := TAU * radius
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var n := (d0 + d1).normalized()
		# Снаружи грани «вправо» — в сторону меньшего угла
		var s0 := perimeter * i / sides
		var s1 := perimeter * (i + 1) / sides
		for j in rows:
			var y0 := height * j / rows
			var y1 := height * (j + 1) / rows
			var tl := d1 * radius + Vector3.UP * y1
			var tr := d0 * radius + Vector3.UP * y1
			var br := d0 * radius + Vector3.UP * y0
			var bl := d1 * radius + Vector3.UP * y0
			var verts := [[tl, s1, y1], [tr, s0, y1], [br, s0, y0], [tl, s1, y1], [br, s0, y0], [bl, s1, y0]]
			for vert in verts:
				st.set_normal(n)
				st.set_uv(Vector2(-vert[1], -vert[2]) / tile)
				st.add_vertex(vert[0])
		# Торцы
		var top := Vector3.UP * height
		for tri in [[top, top + d0 * radius, top + d1 * radius, Vector3.UP], [Vector3.ZERO, d1 * radius, d0 * radius, Vector3.DOWN]]:
			for k in 3:
				var p: Vector3 = tri[k]
				st.set_normal(tri[3])
				st.set_uv(Vector2(p.x, p.z) / tile)
				st.add_vertex(p)
	return st.commit()


## Усечённая «коробка» вдоль +Y: снизу bottom (ширина по X, глубина по Z), сверху top.
## Основание в начале координат; top_shift сдвигает верхнюю грань.
static func frustum(bottom: Vector2, top: Vector2, height: float, tile: float = 1.0, top_shift: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var c := []
	for k in 2:
		var s: Vector2 = bottom if k == 0 else top
		var base := Vector3.ZERO if k == 0 else Vector3.UP * height + top_shift
		c.append_array([
			base + Vector3(-s.x, 0.0, -s.y) * 0.5, base + Vector3(s.x, 0.0, -s.y) * 0.5,
			base + Vector3(s.x, 0.0, s.y) * 0.5, base + Vector3(-s.x, 0.0, s.y) * 0.5,
		])
	return hexahedron(c, tile)


## Шестигранник по 8 углам: c[0..3] — нижний контур, c[4..7] — верхний, в том же порядке.
static func hexahedron(c: Array, tile: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for p: Vector3 in c:
		center += p
	center /= c.size()
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var q := [c[f[0]], c[f[1]], c[f[2]], c[f[3]]]
		var fc: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25
		_quad(st, q, fc - center, tile)
	return st.commit()


## Тело вращения вокруг Y. profile — точки (радиус, высота) снизу вверх.
static func lathe(profile: PackedVector2Array, sides: int, tile: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var mid := (d0 + d1).normalized()
		for j in profile.size() - 1:
			var p0 := profile[j]
			var p1 := profile[j + 1]
			var q := [
				d0 * p0.x + Vector3.UP * p0.y, d1 * p0.x + Vector3.UP * p0.y,
				d1 * p1.x + Vector3.UP * p1.y, d0 * p1.x + Vector3.UP * p1.y,
			]
			# Наружу — перпендикуляр к отрезку профиля
			var n2 := Vector2(p1.y - p0.y, -(p1.x - p0.x))
			_quad(st, q, mid * n2.x + Vector3.UP * n2.y, tile)
	return st.commit()


## Плоский четырёхугольник q[0..3] по контуру; outward — куда смотрит лицевая сторона.
## UV — проекция на ближайшую координатную плоскость, в метрах / tile.
static func _quad(st: SurfaceTool, q: Array, outward: Vector3, tile: float) -> void:
	# Нормаль по Ньюэллу: работает и для вырожденного четырёхугольника (треугольника)
	var n := Vector3.ZERO
	for i in 4:
		var a: Vector3 = q[i]
		var b: Vector3 = q[(i + 1) % 4]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if n.length_squared() < 1e-16:
		return
	n = n.normalized()
	# Ньюэлл даёт нормаль, из которой контур виден против часовой,
	# а лицевая сторона в Godot — по часовой
	var order := [0, 2, 1, 0, 3, 2]
	if n.dot(outward) < 0.0:
		n = -n
		order = [0, 1, 2, 0, 2, 3]
	var na := n.abs()
	for k in order:
		var p: Vector3 = q[k]
		var uv := Vector2(p.x, -p.y)
		if na.y >= na.x and na.y >= na.z:
			uv = Vector2(p.x, p.z)
		elif na.x >= na.z:
			uv = Vector2(p.z, -p.y)
		st.set_normal(n)
		st.set_uv(uv / tile)
		st.add_vertex(p)
