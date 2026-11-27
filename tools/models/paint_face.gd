extends SceneTree
# Рисует брови, глаза и рот на текстуре лица: точка на лице (вид спереди, поза покоя) → тексель → красим его
# (и соседей по u). Лицо у Meshy грубое: тексель ≈ 1,5–2 см, поэтому глаз — 1–2 тёмных текселя.
# godot --headless --path . --script res://tools/models/paint_face.gd -- townsman   (затем --import: png в res:// перекодируется)
# Один раз для models/townsman_townsman.png (глаза и рот у вестника в крупном плане вступления); координаты — из вида спереди
# (поза покоя, лицо смотрит в +Z, метры): глаза — самые тёмные квадраты на лице модели, рот — по линии бороды. Повторный
# прогон по уже нарисованной текстуре даёт то же самое.
# Список: [x, y, цвет, [сдвиги в текселях по u]].
const EYE := Color(0.05, 0.03, 0.03)
const BROW := Color(0.11, 0.07, 0.05)
const MOUTH := Color(0.22, 0.07, 0.07)
const FEATURES := {
	"townsman": [
		[-0.036, 1.634, EYE, [0, 1]], [0.026, 1.619, EYE, [0, 1]],
		[-0.004, 1.553, MOUTH, [-1, 0]],
	],
}
func _init() -> void:
	var mname: String = OS.get_cmdline_user_args()[0]
	var inst: Node = load("res://models/%s.glb" % mname).instantiate()
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	var mi: MeshInstance3D
	for c in skel.get_children():
		if c is MeshInstance3D: mi = c
	var path := ProjectSettings.globalize_path("res://models/%s_%s.png" % [mname, mname])
	var timg := Image.load_from_file(path)
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tw := timg.get_width(); var th := timg.get_height()
	for f: Array in FEATURES[mname]:
		var bestz := -1e9
		var best := Vector2.ZERO
		for t in range(0, idx.size(), 3):
			var a := idx[t]; var b := idx[t + 1]; var c := idx[t + 2]
			var den := (v[b].y - v[c].y) * (v[a].x - v[c].x) + (v[c].x - v[b].x) * (v[a].y - v[c].y)
			if absf(den) < 1e-9: continue
			var w0: float = ((v[b].y - v[c].y) * (f[0] - v[c].x) + (v[c].x - v[b].x) * (f[1] - v[c].y)) / den
			var w1: float = ((v[c].y - v[a].y) * (f[0] - v[c].x) + (v[a].x - v[c].x) * (f[1] - v[c].y)) / den
			var w2 := 1.0 - w0 - w1
			if w0 < 0 or w1 < 0 or w2 < 0: continue
			var z := v[a].z * w0 + v[b].z * w1 + v[c].z * w2
			if z > bestz:
				bestz = z
				best = uv[a] * w0 + uv[b] * w1 + uv[c] * w2
		var tx := int(best.x * tw)
		var ty := int(best.y * th)
		print(mname, " ", f[0], ",", f[1], " z=", bestz, " texel ", tx, ",", ty)
		for d: int in f[3]:
			timg.set_pixel(clampi(tx + d, 0, tw - 1), clampi(ty, 0, th - 1), f[2])
	timg.save_png(path)
	inst.free()
	quit()
