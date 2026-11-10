class_name SaintLook
extends RefCounted
## Вид святого (CLAUDE.md §4): белые погребальные одежды, чёрная повязка — это модели saint_a / saint_b;
## кровь рисуется здесь, поверх текстуры модели, по геометрии: подол снизу вверх, кисти и предплечья,
## при сильной крови — брызги на груди. blood 0…1 — сколько крови (первый святой — самый окровавленный).
## Треугольники меша выбираются по высоте вершин и весам костей рук, их UV закрашиваются в копии текстуры.
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
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(model_name) + int(blood * 100.0)
	# Насколько высоко кровь по подолу (доля роста): от 6 % до ~35 %
	var hem := 0.06 + 0.3 * blood
	for t in idx.size() / 3:
		var ia := idx[t * 3]
		var ib := idx[t * 3 + 1]
		var ic := idx[t * 3 + 2]
		var c := (v[ia] + v[ib] + v[ic]) / 3.0
		var y := (c.y - lo) / height
		# Рваный край: порог гуляет по окружности
		var edge := hem + 0.05 * sin(c.x * 23.0 + c.z * 7.0) + 0.04 * cos(c.z * 31.0)
		var amount := 0.0
		if y < edge:
			amount = clampf((edge - y) / 0.08, 0.35, 1.0)
		var hand := 0.0
		var arm := 0.0
		for k in per:
			var w := bw[ia * per + k]
			var b := bi[ia * per + k]
			if hand_bones.has(b):
				hand += w
			elif arm_bones.has(b):
				arm += w
		if hand > 0.4:
			amount = maxf(amount, 0.9)
		elif arm > 0.4 and blood > 0.4:
			amount = maxf(amount, clampf((blood - 0.4) * 2.0, 0.4, 0.9))
		# Брызги на груди и рукавах
		if blood > 0.55 and y > 0.5 and y < 0.8 and rng.randf() < (blood - 0.55) * 0.35:
			amount = maxf(amount, 0.7)
		if amount <= 0.0:
			continue
		_fill(img, uv[ia], uv[ib], uv[ic], amount, rng.randi())
	inst.free()
	return ImageTexture.create_from_image(img)


## Закрасить треугольник UV кровью (amount — насколько густо).
static func _fill(img: Image, a: Vector2, b: Vector2, c: Vector2, amount: float, seed: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var pa := a * Vector2(w, h)
	var pb := b * Vector2(w, h)
	var pc := c * Vector2(w, h)
	var x0 := clampi(floori(minf(pa.x, minf(pb.x, pc.x))) - 1, 0, w - 1)
	var x1 := clampi(ceili(maxf(pa.x, maxf(pb.x, pc.x))) + 1, 0, w - 1)
	var y0 := clampi(floori(minf(pa.y, minf(pb.y, pc.y))) - 1, 0, h - 1)
	var y1 := clampi(ceili(maxf(pa.y, maxf(pb.y, pc.y))) + 1, 0, h - 1)
	var area := (pb - pa).cross(pc - pa)
	if absf(area) < 1e-6:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var w0 := (pb - p).cross(pc - p) / area
			var w1 := (pc - p).cross(pa - p) / area
			var w2 := 1.0 - w0 - w1
			# Чуть шире треугольника — чтобы на швах UV не оставалось белых щелей
			if w0 < -0.15 or w1 < -0.15 or w2 < -0.15:
				continue
			var col := BLOOD.lerp(BLOOD_DARK, rng.randf() * amount)
			var src := img.get_pixel(x, y)
			var k := amount * rng.randf_range(0.75, 1.0)
			img.set_pixel(x, y, src.lerp(col * Color(src.get_luminance() + 0.4, src.get_luminance() + 0.4, src.get_luminance() + 0.4), k))
