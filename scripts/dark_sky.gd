class_name DarkSky
extends Node3D
## Небесное тело во тьме (CLAUDE.md §7): «чёрное солнце» или «кровавая луна».
## Плоский диск всегда смотрит на камеру и висит на DISTANCE метров в нужном направлении,
## поэтому кажется бесконечно далёким. Дома и стены ближе — они его закрывают.
## Какое тело и где — в пресете освещения (LightingPreset.sky_body), его вызывает apply().

const DISTANCE := 120.0

var _disc: MeshInstance3D
var _halo: MeshInstance3D
var _dir := Vector3.UP
var _textures := {}


func _ready() -> void:
	_disc = _make_quad(1)
	_halo = _make_quad(0)
	visible = false


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and visible:
		global_position = cam.global_position + _dir * DISTANCE


func show_body(preset: LightingPreset) -> void:
	if preset.sky_body == LightingPreset.SkyBody.NONE:
		visible = false
		return
	visible = true
	var black := preset.sky_body == LightingPreset.SkyBody.BLACK_SUN
	var elevation := preset.black_sun_elevation if black else preset.blood_moon_elevation
	var azimuth := preset.black_sun_azimuth if black else preset.blood_moon_azimuth
	var size_deg := preset.black_sun_size if black else preset.blood_moon_size
	_dir = LightingPreset.direction(elevation, azimuth)
	var size := 2.0 * DISTANCE * tan(deg_to_rad(size_deg) * 0.5)
	var key := "black" if black else "moon"
	if not _textures.has(key):
		_textures[key] = _black_sun_textures(preset.black_sun_corona) if black else _blood_moon_textures(preset.blood_moon_color)
	var tex: Array = _textures[key]
	(_halo.mesh as QuadMesh).size = Vector2.ONE * size * (2.6 if black else 2.2)
	(_disc.mesh as QuadMesh).size = Vector2.ONE * size
	(_halo.material_override as StandardMaterial3D).albedo_texture = tex[0]
	(_disc.material_override as StandardMaterial3D).albedo_texture = tex[1]


## Квадрат-билборд без света и тумана. order — порядок отрисовки (ореол под диском).
func _make_quad(order: int) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.render_priority = order
	mat.no_depth_test = false
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## [ореол, диск]: чёрный диск, тонкое бледное кольцо и рваная корона с лучами.
static func _black_sun_textures(corona: Color) -> Array:
	var n := 64
	var halo := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var disc := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.9
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := p.length()
			# Ореол в 2,6 раза больше диска: край диска — на r = 1 / 2,6
			var rr := r * 2.6
			var rays := 0.5 + 0.5 * noise.get_noise_1d(atan2(p.y, p.x) * 6.0)
			var a := clampf(1.0 - (rr - 1.0) / (0.4 + 0.9 * rays), 0.0, 1.0)
			a = a * a * 0.55 if rr > 1.0 else 0.0
			halo.set_pixel(x, y, Color(corona.r, corona.g, corona.b, a))
			# Диск: чёрный круг, по краю тонкое светлое кольцо
			var c := Color(0, 0, 0, 0)
			if r < 0.9:
				c = Color(0.0, 0.0, 0.0, 1.0)
			elif r < 1.0:
				c = Color(corona.r, corona.g, corona.b, 1.0)
			disc.set_pixel(x, y, c)
	return [ImageTexture.create_from_image(halo), ImageTexture.create_from_image(disc)]


## [дымка, диск]: тёмно-красный диск с пятнами и красная дымка вокруг.
static func _blood_moon_textures(color: Color) -> Array:
	var n := 64
	var halo := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var disc := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.08
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := p.length()
			var rr := r * 2.2
			var a := clampf(1.0 - (rr - 0.9) / 1.3, 0.0, 1.0)
			halo.set_pixel(x, y, Color(color.r, color.g * 0.8, color.b * 0.8, a * a * 0.35))
			var c := Color(0, 0, 0, 0)
			if r < 1.0:
				var k := 0.75 + 0.25 * noise.get_noise_2d(x, y) - 0.25 * r * r
				c = Color(color.r * k, color.g * k, color.b * k, 1.0)
			disc.set_pixel(x, y, c)
	return [ImageTexture.create_from_image(halo), ImageTexture.create_from_image(disc)]
