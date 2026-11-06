class_name CharacterModel
extends Node3D
## Персонаж на модели Meshy (res://models/<имя>.glb) и общем скелете Mixamo с мокап-анимациями (Anims).
## Модель повёрнута на 180°: в файлах персонажи смотрят по +Z, а в игре «вперёд» — −Z (как у Player и катсцен).
## Материал — наш psx_lit (дрожание, туман, аффинность) с текстурой модели, фильтр nearest.
##
## Анимации: play(имя, смешивание, скорость). Root motion разовых анимаций (fall_flat, shoved_spin…)
## не двигает кость Root, а копится в motion и сдвигает модель внутри узла — сам узел (и коллизия на нём) стоит.
## Дальних можно обновлять реже: set_update_interval(с).
##
## Статические помощники: material() — PS1-материал модели (или пепел), bake_pose() — поза в статичный меш (тела),
## split_mesh() / reweight() — для героя (голова отдельно, подол на тазу).

const MODEL_DIR := "res://models/"
## Все модели персонажей.
const MODELS := ["hero", "townsman", "townswoman", "saint_a", "saint_b"]
## Пепел: цвет сожжённых (CLAUDE.md §6) — серый, текстура модели почти не видна.
const ASH_COLOR := Color(0.42, 0.41, 0.4)

@export var model := "townsman"
## Тени: катсцена и толпа без теней (как на PS1); герой — отдельно.
@export var cast_shadows := false

var skeleton: Skeleton3D
var anim: AnimationPlayer
var mesh_instance: MeshInstance3D
## Накопленный root motion, м — в осях этого узла.
var motion := Vector3.ZERO
## Что играет сейчас.
var current := ""

var _inst: Node3D
var _interval := 0.0
var _acc := 0.0

static var _mats := {}


func _ready() -> void:
	if _inst == null:
		build()


## Собрать модель и плеер анимаций (вызывается сам в _ready; можно раньше, чтобы сразу ставить позу).
func build() -> void:
	if _inst:
		return
	var scene: PackedScene = load(MODEL_DIR + model + ".glb")
	_inst = scene.instantiate()
	_inst.rotation.y = PI
	add_child(_inst)
	skeleton = _inst.find_child("GeneralSkeleton", true, false)
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			mesh_instance = c
			c.material_override = material(model)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Меш двигается костями — запас, чтобы его не отсекало по рамке позы покоя
			c.extra_cull_margin = 1.5
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	_inst.add_child(anim)
	anim.root_node = ^".."
	anim.add_animation_library("", Anims.library())
	anim.root_motion_track = Anims.ROOT_TRACK
	anim.mixer_applied.connect(_on_applied)


## Играть анимацию: blend — смешивание с прошлой, с; speed — speed_scale (для циклов ходьбы — Anims.scale_for);
## restart — начать заново, даже если уже играет.
func play(anim_name: String, blend := 0.25, speed := 1.0, restart := false) -> void:
	if anim == null:
		build()
	if not Anims.LIST.has(anim_name):
		push_warning("CharacterModel: нет анимации %s" % anim_name)
		return
	anim.speed_scale = speed
	if anim_name == current and not restart and anim.is_playing():
		return
	current = anim_name
	anim.play(anim_name, blend)
	if restart:
		anim.seek(0.0, true)


## Начать цикл со случайного места (чтобы толпа не шагала в ногу).
func randomize_phase(rng: RandomNumberGenerator = null) -> void:
	if anim and anim.is_playing():
		var r := rng.randf() if rng else randf()
		anim.seek(r * anim.current_animation_length, true)


func set_speed(speed: float) -> void:
	if anim:
		anim.speed_scale = speed


## Разовая анимация доиграла (или играет цикл)?
func is_finished() -> bool:
	return anim == null or not anim.is_playing()


## Обновлять анимацию раз в interval секунд (0 — каждый кадр). Для дальних людей толпы.
func set_update_interval(interval: float) -> void:
	if anim == null:
		build()
	if is_equal_approx(interval, _interval):
		return
	_interval = interval
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if interval > 0.0 \
		else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	set_process(interval > 0.0)


## Сбросить накопленный root motion (модель снова в точке узла).
func reset_motion() -> void:
	motion = Vector3.ZERO
	if _inst:
		_inst.position = Vector3.ZERO


func _process(delta: float) -> void:
	if _interval <= 0.0:
		return
	_acc += delta
	if _acc >= _interval:
		anim.advance(_acc)
		_acc = 0.0


func _on_applied() -> void:
	var d := anim.get_root_motion_position()
	if d != Vector3.ZERO:
		motion += _inst.basis * d
		_inst.position = motion


# ─── Статические помощники ───────────────────────────────────────────────────

## PS1-материал модели с её же текстурой (кешируется). ashen — пепел: серый, текстура едва проступает.
static func material(model_name: String, ashen := false) -> ShaderMaterial:
	var key := model_name + (":ash" if ashen else "")
	if _mats.has(key):
		return _mats[key]
	var tex: Texture2D = null
	var scene: PackedScene = load(MODEL_DIR + model_name + ".glb")
	var inst := scene.instantiate()
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh.surface_get_material(0)
		if m is BaseMaterial3D:
			tex = (m as BaseMaterial3D).albedo_texture
			break
	inst.free()
	var mat: ShaderMaterial
	if ashen:
		mat = PsxMaterial.make(_ash_texture(tex), Color.WHITE)
	else:
		mat = PsxMaterial.make(tex)
	_mats[key] = mat
	return mat


## Пепел: яркость текстуры модели, сжатая к серому (складки и черты читаются, цвета — нет).
static func _ash_texture(src: Texture2D) -> Texture2D:
	if src == null:
		return ProcTextures.mottled(64, ASH_COLOR, 0.06, 0.1, 7)
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			var g := lerpf(ASH_COLOR.r, l, 0.35) * rng.randf_range(0.82, 1.08)
			img.set_pixel(x, y, Color(g, g * 0.98, g * 0.96))
	return ImageTexture.create_from_image(img)


## Поза в статичный меш: модель в кадре time анимации (−1 — последний кадр), скиннинг посчитан на процессоре.
## Кость Root не двигается, модель повёрнута лицом в −Z, как в игре. center_bone — эта кость встаёт
## над точкой (по горизонтали), плюс сдвиг offset (x, z) в осях результата.
static func bake_pose(model_name: String, anim_name: String, time := -1.0, center_bone := "",
		offset := Vector2.ZERO) -> ArrayMesh:
	var scene: PackedScene = load(MODEL_DIR + model_name + ".glb")
	var inst := scene.instantiate()
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	var mi: MeshInstance3D = null
	for c in skel.get_children():
		if c is MeshInstance3D:
			mi = c
	var a: Animation = Anims.library().get_animation(anim_name)
	var t := a.length if time < 0.0 else minf(time, a.length)
	for i in a.get_track_count():
		var path := String(a.track_get_path(i))
		var bone := skel.find_bone(path.get_slice(":", 1))
		if bone < 0 or path.get_slice(":", 1) == "Root":
			continue
		match a.track_get_type(i):
			Animation.TYPE_POSITION_3D:
				skel.set_bone_pose_position(bone, a.position_track_interpolate(i, t))
			Animation.TYPE_ROTATION_3D:
				skel.set_bone_pose_rotation(bone, a.rotation_track_interpolate(i, t))
			Animation.TYPE_SCALE_3D:
				skel.set_bone_pose_scale(bone, a.scale_track_interpolate(i, t))
	var skin := mi.skin
	var bind := {}
	for b in skin.get_bind_count():
		var bone := skel.find_bone(skin.get_bind_name(b)) if skin.get_bind_bone(b) < 0 else skin.get_bind_bone(b)
		bind[b] = skel.get_bone_global_pose(bone) * skin.get_bind_pose(b)
	var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	if center_bone != "":
		var c := turn * skel.get_bone_global_pose(skel.find_bone(center_bone)).origin
		turn.origin = Vector3(offset.x - c.x, 0.0, offset.y - c.z)
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bi.size() / v.size()
		for i in v.size():
			var pv := Vector3.ZERO
			var pn := Vector3.ZERO
			for k in per:
				var w := bw[i * per + k]
				if w > 0.0:
					var bx: Transform3D = bind[bi[i * per + k]]
					pv += (bx * v[i]) * w
					pn += (bx.basis * n[i]) * w
			v[i] = turn * pv
			n[i] = (turn.basis * pn).normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_BONES] = null
		arr[Mesh.ARRAY_WEIGHTS] = null
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	inst.free()
	return out


## Разделить скиннинговый меш по костям: classify(веса_по_костям: Dictionary кость→вес) → номер группы
## для каждой вершины, треугольник уходит в группу с наибольшим номером среди своих вершин.
## Возвращает массив ArrayMesh (по группе), скиннинг сохраняется.
static func split_mesh(mesh: Mesh, groups: int, classify: Callable) -> Array[ArrayMesh]:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bi.size() / v.size()
	var vgroup := PackedInt32Array()
	vgroup.resize(v.size())
	for i in v.size():
		var w := {}
		for k in per:
			var b := bi[i * per + k]
			w[b] = w.get(b, 0.0) + bw[i * per + k]
		vgroup[i] = classify.call(w)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var lists := []
	for g in groups:
		lists.append(PackedInt32Array())
	for t in idx.size() / 3:
		var g := maxi(vgroup[idx[t * 3]], maxi(vgroup[idx[t * 3 + 1]], vgroup[idx[t * 3 + 2]]))
		var list: PackedInt32Array = lists[g]  # упакованный массив — значение: дописать и вернуть
		list.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		lists[g] = list
	var flags: int = mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var out: Array[ArrayMesh] = []
	for g in groups:
		var m := ArrayMesh.new()
		var a := arr.duplicate()
		a[Mesh.ARRAY_INDEX] = lists[g]
		if (lists[g] as PackedInt32Array).size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, flags)
			m.surface_set_material(0, mesh.surface_get_material(0))
		out.append(m)
	return out


## Перевесить вершины: fn(позиция, веса: Dictionary кость→вес) → новые веса (Dictionary) или null — не менять.
## Возвращает новый меш (до 4 костей на вершину, веса нормированы).
static func reweight(mesh: Mesh, fn: Callable) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bi.size() / v.size()
	for i in v.size():
		var w := {}
		for k in per:
			if bw[i * per + k] > 0.0:
				w[bi[i * per + k]] = w.get(bi[i * per + k], 0.0) + bw[i * per + k]
		var nw: Variant = fn.call(v[i], w)
		if nw == null:
			continue
		var pairs := []
		for b in nw:
			pairs.append([float(nw[b]), int(b)])
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var total := 0.0
		for k in mini(per, pairs.size()):
			total += pairs[k][0]
		for k in per:
			if k < pairs.size() and total > 0.0:
				bi[i * per + k] = pairs[k][1]
				bw[i * per + k] = pairs[k][0] / total
			else:
				bi[i * per + k] = 0
				bw[i * per + k] = 0.0
	arr[Mesh.ARRAY_BONES] = bi
	arr[Mesh.ARRAY_WEIGHTS] = bw
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	m.surface_set_material(0, mesh.surface_get_material(0))
	return m
