class_name DarkSky
extends Node3D
## Небесное тело во тьме (CLAUDE.md §7): «чёрное солнце» — вечное полное затмение.
## Плоский диск всегда смотрит на камеру и висит на DISTANCE метров в нужном направлении,
## поэтому кажется бесконечно далёким. Дома и стены ближе — они его закрывают.
## Какое тело и где — в пресете освещения (LightingPreset.sky_body), его вызывает apply().

const DISTANCE := 120.0

var _disc: MeshInstance3D
var _halo: MeshInstance3D
var _dir := Vector3.UP
## Текстуры чёрного солнца: halo — ореол, disc — диск.
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
	_dir = LightingPreset.direction(preset.black_sun_elevation, preset.black_sun_azimuth)
	var size := 2.0 * DISTANCE * tan(deg_to_rad(preset.black_sun_size) * 0.5)
	if _textures.is_empty():
		_textures = _black_sun_textures(preset.black_sun_corona)
	(_halo.mesh as QuadMesh).size = Vector2.ONE * size * 2.6
	(_disc.mesh as QuadMesh).size = Vector2.ONE * size
	(_halo.material_override as StandardMaterial3D).albedo_texture = _textures.halo
	(_disc.material_override as StandardMaterial3D).albedo_texture = _textures.disc


## Насколько проявилось тело, 0…1 (вступление: чёрный диск наползает на дневное небо).
func set_fade(alpha: float) -> void:
	for mi in [_disc, _halo]:
		(mi.material_override as StandardMaterial3D).albedo_color.a = alpha


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


## {halo, disc}: чёрный диск, тонкое бледное кольцо и рваная корона с лучами.
static func _black_sun_textures(corona: Color) -> Dictionary:
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
	return {"halo": ImageTexture.create_from_image(halo), "disc": ImageTexture.create_from_image(disc)}

