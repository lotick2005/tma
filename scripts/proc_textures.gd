class_name ProcTextures
extends RefCounted
## Процедурные текстуры-заглушки. Без мипмапов; фильтр nearest задаёт сам материал.


## Шашечка size×size пикселей из cells×cells клеток, с лёгким шумом «под камень».
static func checker(size: int, cells: int, a: Color, b: Color, grain: float = 0.06, seed: int = 1) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cell := maxi(1, size / cells)
	for y in size:
		for x in size:
			var c := a if ((x / cell) + (y / cell)) % 2 == 0 else b
			var n := rng.randf_range(-grain, grain)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	return ImageTexture.create_from_image(img)


## Однотонная текстура с шумом и пятнами (глина, ткань, кожа).
static func mottled(size: int, base: Color, grain: float = 0.05, blotch: float = 0.08, seed: int = 1) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 4.0 / size
	for y in size:
		for x in size:
			var n := rng.randf_range(-grain, grain) + noise.get_noise_2d(x, y) * blotch
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n))
	return ImageTexture.create_from_image(img)


## Кольчуга: ряды колечек со сдвигом через ряд.
static func chainmail(size: int, ring: int, metal: Color, gap: Color, seed: int = 1) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := ring * 0.5
	for y in size:
		for x in size:
			var row := y / ring
			var sx := fposmod(x + (r if row % 2 == 1 else 0.0), ring) - r + 0.5
			var sy := fposmod(y, ring) - r + 0.5
			var d := sqrt(sx * sx + sy * sy) / r
			var c := metal if d > 0.35 and d < 1.0 else gap
			# Блик на верхней половине кольца
			if d > 0.35 and d < 1.0 and sy < 0.0:
				c = c.lightened(0.15)
			var n := rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	return ImageTexture.create_from_image(img)


## Полосы поперёк V: ремни калиг поверх кожи ноги.
static func stripes(size: int, bands: int, a: Color, b: Color, seed: int = 1) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var band := maxi(1, size / bands)
	for y in size:
		for x in size:
			var c := a if (y / band) % 3 != 2 else b
			var n := rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	return ImageTexture.create_from_image(img)


## Язычок пламени с альфой: белое ядро, жёлтый и оранжевый край.
static func flame(w: int, h: int) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := 1.0 - (y + 0.5) / h  # 0 внизу, 1 наверху
		# Капля: широкая внизу, острая сверху
		var half := 0.5 * sin(PI * pow(clampf(t * 1.1, 0.0, 1.0), 0.6)) * (1.0 - t * 0.3)
		for x in w:
			var dx := absf((x + 0.5) / w - 0.5)
			if half <= 0.0 or dx > half:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var k := dx / half
			var c := Color(1.0, 0.95, 0.75) if k < 0.4 and t < 0.6 else (Color(1.0, 0.75, 0.25) if k < 0.75 else Color(0.95, 0.4, 0.1))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Ткань с тёмной каймой внизу (последние hem строк): подол и рукава туники.
static func hemmed_cloth(size: int, base: Color, hem: int, seed: int = 1) -> ImageTexture:
	var img := mottled(size, base, 0.035, 0.08, seed).get_image()
	for y in range(size - hem, size):
		for x in size:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35))
	return ImageTexture.create_from_image(img)


## Кладка: ряды блоков (courses рядов на текстуру), длины блоков случайные от min_len до max_len
## (в долях ширины текстуры), каждый ряд со своим сдвигом. Бесшовная по обеим осям.
## margin — ширина плоской каймы (пиксели); boss — чуть выступающая середина с тенью снизу
## и бликом сверху (иродианская рустовка). joint — насколько темнее швы.
static func ashlar(size: int, courses: int, base: Color, seed: int = 1, margin: int = 3, boss: bool = true,
		min_len: float = 0.3, max_len: float = 0.8, joint: float = 0.45, tint: float = 0.06) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 8.0 / size
	var course_h := size / courses
	for r in courses:
		# Разрезы ряда: сумма длин ровно size, чтобы текстура стыковалась
		var cuts: Array[int] = []
		var total := 0
		while total < size:
			var piece := rng.randi_range(int(size * min_len), int(size * max_len))
			if size - total - piece < int(size * min_len):
				piece = size - total
			cuts.append(piece)
			total += piece
		var offset := rng.randi_range(0, size - 1)
		var tints: Array[Color] = []
		for c in cuts:
			var t := rng.randf_range(-tint, tint)
			# Известняк гуляет от кремового к золотисто-розоватому
			var warm := rng.randf_range(0.0, tint)
			tints.append(Color(base.r + t + warm * 0.5, base.g + t, base.b + t - warm * 0.5))
		for x in size:
			var px := posmod(x - offset, size)
			var bi := 0
			var bx := px
			while bx >= cuts[bi]:
				bx -= cuts[bi]
				bi += 1
			var blen: int = cuts[bi]
			for yy in course_h:
				var y := r * course_h + yy
				var c: Color = tints[bi]
				var d := mini(mini(bx, blen - 1 - bx), mini(yy, course_h - 1 - yy))
				var n := rng.randf_range(-0.025, 0.025)
				if d == 0:
					c = c.darkened(joint)
				elif boss and d > margin:
					# Середина блока: грубее и чуть темнее; верхний край — блик, нижний — тень
					n += noise.get_noise_2d(x, y) * 0.06 - 0.03
					if yy == margin + 1:
						n += 0.08
					elif yy == course_h - 2 - margin:
						n -= 0.12
					elif bx == margin + 1:
						n += 0.04
					elif bx == blen - 2 - margin:
						n -= 0.06
				else:
					n += noise.get_noise_2d(x, y) * 0.02
				img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	return ImageTexture.create_from_image(img)


## Штукатурка: светлая, с пятнами и потёками сверху вниз.
static func plaster(size: int, base: Color, seed: int = 1) -> ImageTexture:
	var img := mottled(size, base, 0.03, 0.06, seed).get_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 100
	for i in size / 8:
		var x := rng.randi_range(0, size - 1)
		var y0 := rng.randi_range(0, size - 1)
		var piece := rng.randi_range(size / 8, size / 2)
		var dark := rng.randf_range(0.03, 0.08)
		for k in piece:
			var y := (y0 + k) % size
			var fade := 1.0 - float(k) / piece
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(dark * fade))
	return ImageTexture.create_from_image(img)


## Доски вдоль V: planks досок, у каждой свой тон, волокна вдоль доски и тёмные щели.
static func wood(size: int, planks: int, base: Color, seed: int = 1) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.0 / size
	var w := maxi(1, size / planks)
	var tints: Array[float] = []
	for p in planks + 1:
		tints.append(rng.randf_range(-0.07, 0.07))
	for y in size:
		for x in size:
			var p := x / w
			var n: float = tints[p] + noise.get_noise_2d(x * 12.0, y) * 0.08 + rng.randf_range(-0.03, 0.03)
			var c := Color(base.r + n, base.g + n * 0.8, base.b + n * 0.6)
			if x % w == 0:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Створка ворот: доски, поперёк — бронзовые полосы с заклёпками.
static func gate_door(size: int, wood_color: Color, bronze: Color, bands: int = 3, seed: int = 1) -> ImageTexture:
	var img := wood(size, 6, wood_color, seed).get_image()
	var step := size / bands
	var band_h := maxi(2, size / 16)
	for b in bands:
		var y0 := b * step + (step - band_h) / 2
		for yy in band_h:
			for x in size:
				var c := bronze.lightened(0.12) if yy == 0 else (bronze.darkened(0.3) if yy == band_h - 1 else bronze)
				img.set_pixel(x, y0 + yy, c)
		# Заклёпки над и под полосой
		for x in range(size / 12, size, size / 6):
			for y in [y0 - 2, y0 + band_h + 1]:
				if y >= 0 and y < size:
					img.set_pixel(x, y, bronze.lightened(0.2))
	return ImageTexture.create_from_image(img)


## Бутовая кладка жилых домов: неровные камни (ячейки Вороного) в светлом растворе. Бесшовная.
static func rubble(size: int, stones: int, base: Color, mortar: Color, seed: int = 1) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts: Array[Vector2] = []
	var tints: Array[float] = []
	for i in stones:
		pts.append(Vector2(rng.randf() * size, rng.randf() * size))
		tints.append(rng.randf_range(-0.08, 0.08))
	for y in size:
		for x in size:
			var d1 := INF
			var d2 := INF
			var best := 0
			for i in stones:
				# Расстояние с заворотом краёв — текстура стыкуется
				var dx := absf(x + 0.5 - pts[i].x)
				var dy := absf(y + 0.5 - pts[i].y)
				dx = minf(dx, size - dx)
				dy = minf(dy, size - dy)
				var d := dx * dx + dy * dy * 1.6
				if d < d1:
					d2 = d1
					d1 = d
					best = i
				elif d < d2:
					d2 = d
			var n := rng.randf_range(-0.03, 0.03)
			var c := mortar
			if sqrt(d2) - sqrt(d1) > 1.6:
				var t: float = tints[best]
				c = Color(base.r + t, base.g + t * 0.9, base.b + t * 0.8)
				# Тень по нижнему краю камня
				if sqrt(d2) - sqrt(d1) < 2.6:
					c = c.darkened(0.12)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	return ImageTexture.create_from_image(img)


# ─── Фото-текстуры (Poly Haven, CC0; textures/photo/, что куда — textures/README.md) ──────────────

const PHOTO_DIR := "res://textures/photo/"
static var _photo_cache := {}


## Фото-текстура 128×128 как есть (импорт без мипмапов; nearest и repeat задаёт psx-шейдер).
static func photo(name: String) -> Texture2D:
	if not _photo_cache.has(name):
		_photo_cache[name] = load(PHOTO_DIR + name + ".png")
	return _photo_cache[name]


## Картинка фото в памяти (RGB8) или null, если текстуру не удалось прочитать обратно.
static func photo_image(name: String) -> Image:
	var tex := photo(name)
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		push_warning("Фото-текстура %s не читается — остаётся процедурная" % name)
		return null
	img.convert(Image.FORMAT_RGB8)
	return img


## Средний цвет картинки (уменьшение до 1×1 с усреднением — без цикла по пикселям).
static func image_mean(img: Image) -> Color:
	var m := img.duplicate() as Image
	m.resize(1, 1, Image.INTERPOLATE_TRILINEAR)
	return m.get_pixel(0, 0)


static func photo_mean(name: String) -> Color:
	var img := photo_image(name)
	return image_mean(img) if img else Color(0.5, 0.5, 0.5)


## Множитель цвета материала, чтобы средний цвет фото стал target (умножение в sRGB — то же, что в линейном).
## Так яркость фото подгоняется под освещение уровня без перерисовки картинки.
static func photo_tint(name: String, target: Color) -> Color:
	var m := photo_mean(name)
	return Color(target.r / maxf(m.r, 0.01), target.g / maxf(m.g, 0.01), target.b / maxf(m.b, 0.01))


## Кусок фото size×size пикселей в родном разрешении (для плитки атласа предметов), перекрашенный так,
## чтобы средний цвет стал target. contrast — 1 как есть, меньше — спокойнее. rotate — повернуть на 90°
## (доски и волокна вдоль V, как у процедурных). Без цикла по пикселям там, где можно.
static func photo_tile(name: String, size: int, target: Color, origin := Vector2i.ZERO, contrast := 1.0,
		rotate := false) -> ImageTexture:
	var src := photo_image(name)
	if src == null:
		return null
	if rotate:
		src.rotate_90(CLOCKWISE)
	var img := src.get_region(Rect2i(origin, Vector2i(size, size)))
	var m := image_mean(img)
	for y in size:
		for x in size:
			var c := img.get_pixel(x, y)
			c = Color(m.r + (c.r - m.r) * contrast, m.g + (c.g - m.g) * contrast, m.b + (c.b - m.b) * contrast)
			img.set_pixel(x, y, Color(c.r * target.r / maxf(m.r, 0.01), c.g * target.g / maxf(m.g, 0.01),
				c.b * target.b / maxf(m.b, 0.01)))
	return ImageTexture.create_from_image(img)


## Подмешать фото как зерно: процедурный рисунок (плиты, рустовка, полосы) остаётся, а внутри него —
## пятна и поры настоящего камня или ткани. Картинка увеличивается до размера фото (nearest), каждый
## пиксель умножается на яркость фото относительно её среднего; strength — сила зерна (0 — нет, 1 — полная).
## Фото бесшовное, поэтому и результат стыкуется, если процедурная текстура бесшовная.
## keep_size — не увеличивать картинку, а взять кусок фото её размера (плитки атласа 64×64).
static func with_grain(tex: ImageTexture, name: String, strength: float, keep_size := false) -> ImageTexture:
	var src := photo_image(name)
	if src == null:
		return tex
	var size := src.get_width()
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGB8)
	if keep_size:
		size = img.get_width()
		src = src.get_region(Rect2i(0, 0, size, size))
	elif img.get_width() != size:
		img.resize(size, size, Image.INTERPOLATE_NEAREST)
	var ml := maxf(image_mean(src).get_luminance(), 0.01)
	for y in size:
		for x in size:
			var k := 1.0 + strength * (src.get_pixel(x, y).get_luminance() / ml - 1.0)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k))
	return ImageTexture.create_from_image(img)


## Створка ворот и двери на фото-досках: доски вдоль V, поперёк — бронзовые или деревянные полосы с заклёпками.
static func photo_door(name: String, target: Color, bronze: Color, bands: int = 3) -> ImageTexture:
	var tile := photo_tile(name, 128, target, Vector2i.ZERO, 1.0, true)
	if tile == null:
		return gate_door(64, target, bronze, bands)
	var base := tile.get_image()
	_door_bands(base, bronze, bands)
	return ImageTexture.create_from_image(base)


static func _door_bands(img: Image, bronze: Color, bands: int) -> void:
	var size := img.get_width()
	var step := size / bands
	var band_h := maxi(2, size / 16)
	for b in bands:
		var y0 := b * step + (step - band_h) / 2
		for yy in band_h:
			for x in size:
				var c := bronze.lightened(0.12) if yy == 0 else (bronze.darkened(0.3) if yy == band_h - 1 else bronze)
				img.set_pixel(x, y0 + yy, c)
		for x in range(size / 12, size, size / 6):
			for y in [y0 - 2, y0 + band_h + 1]:
				if y >= 0 and y < size:
					img.set_pixel(x, y, bronze.lightened(0.2))
