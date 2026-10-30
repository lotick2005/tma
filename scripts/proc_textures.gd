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
