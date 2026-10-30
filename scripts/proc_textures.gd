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
