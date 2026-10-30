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
