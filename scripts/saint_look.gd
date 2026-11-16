class_name SaintLook
extends RefCounted
## Вид святого (CLAUDE.md §4): белые погребальные одежды, чёрная повязка — это модель saint_a;
## кровь рисуется здесь, поверх текстуры модели: подол (снизу гуще, кверху сходит на нет, край неровный — потёками),
## кисти, при blood > 0,4 — предплечья. blood 0…1 — сколько крови (первый святой — самый окровавленный).
## Красится по пикселям, а не целыми треугольниками: высота над землёй и вес костей руки считаются в каждой точке
## текстуры, поэтому край мягкий и на швах развёртки нет тёмных заплат. Сама модель не меняется.
## Материал кешируется по (модель, кровь).

## Цвет крови: тёмно-бордовый, в середине почти чёрный (CLAUDE.md §7).
const BLOOD := Color(0.26, 0.035, 0.03)
const BLOOD_DARK := Color(0.1, 0.012, 0.012)

static var _mats := {}


static func material(model_name: String, blood: float) -> ShaderMaterial:
	var key := "%s:%.2f" % [model_name, blood]
	if _mats.has(key):
		return _mats[key]
	var base := CharacterModel.material(model_name)
	var tex: Texture2D = base.get_shader_parameter("albedo_texture")
	var mat := base
	if tex and blood > 0.01:
		var painted := _paint(model_name, tex, blood)
		if painted:
			mat = PsxMaterial.make(painted)
	_mats[key] = mat
	return mat


static func _paint(model_name: String, tex: Texture2D, blood: float) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var scene: PackedScene = load(CharacterModel.MODEL_DIR + model_name + ".glb")
	var inst := scene.instantiate()
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	var mi: MeshInstance3D = null
	for c in skel.get_children():
		if c is MeshInstance3D:
			mi = c
	if mi == null:
		inst.free()
		return null
	# Кости рук: кисти — кровь всегда, предплечья — при blood > 0,4
	var hand_bones := {}
	var arm_bones := {}
	var skin := mi.skin
	for b in skin.get_bind_count():
		var bname := skin.get_bind_name(b)
		if bname == "" and skin.get_bind_bone(b) >= 0:
			bname = skel.get_bone_name(skin.get_bind_bone(b))
		if bname.ends_with("Hand") or bname.contains("Index") or bname.contains("Thumb") or bname.contains("Middle"):
			hand_bones[b] = true
		elif bname.ends_with("LowerArm"):
			arm_bones[b] = true
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var per := bi.size() / v.size()
	var lo := INF
	var hi := -INF
	for p in v:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var height := maxf(hi - lo, 0.1)
	# По вершинам: высота (доля роста), вес костей кисти и предплечья
	var vy := PackedFloat32Array()
	var vhand := PackedFloat32Array()
	var varm := PackedFloat32Array()
	vy.resize(v.size())
	vhand.resize(v.size())
	varm.resize(v.size())
	for i in v.size():
		vy[i] = (v[i].y - lo) / height
		var hand := 0.0
		var arm := 0.0
		for k in per:
			var b := bi[i * per + k]
			if hand_bones.has(b):
				hand += bw[i * per + k]
			elif arm_bones.has(b):
				arm += bw[i * per + k]
		vhand[i] = hand
		varm[i] = arm
	# Насколько высоко кровь по подолу (доля роста; сам подол — на ~12 %, ниже — босые ноги): от 16 % до 30 %
	var hem := 0.12 + 0.18 * blood
	var arm_k := clampf((blood - 0.4) * 1.5, 0.0, 0.8)
	var size := Vector2(img.get_width(), img.get_height())
	var src := img.duplicate() as Image
	for t in idx.size() / 3:
		var ia := idx[t * 3]
		var ib := idx[t * 3 + 1]
		var ic := idx[t * 3 + 2]
		var low := minf(vy[ia], minf(vy[ib], vy[ic]))
		var touched := low < hem * 1.5 or vhand[ia] + vhand[ib] + vhand[ic] > 0.05 \
			or (arm_k > 0.0 and varm[ia] + varm[ib] + varm[ic] > 0.05)
		if not touched:
			continue
		var pa := uv[ia] * size
		var pb := uv[ib] * size
		var pc := uv[ic] * size
		var area := (pb - pa).cross(pc - pa)
		if absf(area) < 1e-6:
			continue
		var x0 := clampi(floori(minf(pa.x, minf(pb.x, pc.x))), 0, int(size.x) - 1)
		var x1 := clampi(ceili(maxf(pa.x, maxf(pb.x, pc.x))), 0, int(size.x) - 1)
		var y0 := clampi(floori(minf(pa.y, minf(pb.y, pc.y))), 0, int(size.y) - 1)
		var y1 := clampi(ceili(maxf(pa.y, maxf(pb.y, pc.y))), 0, int(size.y) - 1)
		for py in range(y0, y1 + 1):
			for px in range(x0, x1 + 1):
				var p := Vector2(px + 0.5, py + 0.5)
				var w0 := (pb - p).cross(pc - p) / area
				var w1 := (pc - p).cross(pa - p) / area
				var w2 := 1.0 - w0 - w1
				# Только пиксели самого треугольника (с запасом в полпикселя на шов), без захода на соседние куски развёртки
				var m := minf(w0, minf(w1, w2))
				if m < -0.5 / maxf(sqrt(absf(area)), 1.0):
					continue
				w0 = clampf(w0, 0.0, 1.0)
				w1 = clampf(w1, 0.0, 1.0)
				w2 = clampf(w2, 0.0, 1.0)
				var ws := maxf(w0 + w1 + w2, 1e-4)
				var pos := (v[ia] * w0 + v[ib] * w1 + v[ic] * w2) / (ws * height)
				var y := (vy[ia] * w0 + vy[ib] * w1 + vy[ic] * w2) / ws
				var hand := (vhand[ia] * w0 + vhand[ib] * w1 + vhand[ic] * w2) / ws
				var arm := (varm[ia] * w0 + varm[ib] * w1 + varm[ic] * w2) / ws
				# Подол: край гуляет вокруг тела (потёки вверх и вниз), по месту в пространстве — на швах сходится
				var wave := 0.5 + 0.3 * sin(pos.x * 41.0 + pos.z * 17.0) + 0.2 * sin(pos.z * 67.0 - pos.x * 29.0)
				var edge := hem * (0.55 + 0.6 * wave)
				var amount := smoothstep(edge, edge * 0.55, y) * 0.85
				# Кисти — густо, предплечья — слабее и сходит к локтю
				amount = maxf(amount, smoothstep(0.25, 0.8, hand) * 0.8)
				amount = maxf(amount, smoothstep(0.3, 0.9, arm) * arm_k)
				if amount <= 0.01:
					continue
				# Мелкая неровность, чтобы не было ровной заливки
				var grain := 0.85 + 0.15 * sin(pos.x * 311.0 + pos.y * 173.0) * sin(pos.z * 257.0 - pos.y * 97.0)
				var k := clampf(amount * grain, 0.0, 0.9)
				var base := src.get_pixel(px, py)
				var lum := base.get_luminance()
				# Ткань проступает сквозь кровь: складки и тени текстуры остаются
				var col := BLOOD.lerp(BLOOD_DARK, k * 0.7) * (0.55 + 0.6 * lum)
				col.a = base.a
				var old := img.get_pixel(px, py)
				var mixed := base.lerp(col, k)
				# Пиксель на шве двух треугольников — берём более тёмный, без двойного наложения
				if old != base and old.get_luminance() < mixed.get_luminance():
					continue
				img.set_pixel(px, py, mixed)
	inst.free()
	return ImageTexture.create_from_image(img)
