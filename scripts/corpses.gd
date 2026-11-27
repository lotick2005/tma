class_name Corpses
extends RefCounted
## Тела (CLAUDE.md §6): модели горожан и героя в позах мокап-анимаций, поза запечена в статичный меш
## (CharacterModel.bake_pose), без скелета — один вызов отрисовки на материал в куске уровня.
## Сожжённые ангелом — те же тела в сером пепле (material(..., ashen)).
## Ставятся как предметы: QuarterProps.place(вид, ...) — вид из KINDS, точка у таза, лицом (головой) в −Z.

## Вид → [модель, анимация, кадр (с; −1 — последний), пепел, сдвиг таза от точки (x, z), что это,
## (необязательно) кость над точкой: по умолчанию "Hips" — таз; "" — точка = кость Root (конец root motion падения),
## (необязательно) краска — цвет, в который перекрашена яркая одежда модели (красное и синее), чтобы тела в груде
## не были одинаковыми].
const KINDS := {
	"corpse_trampled": ["townsman", "fall_flat", -1.0, false, Vector2(0.0, 0.0), "затоптан в давке: ничком, руки вперёд"],
	"corpse_trampled_f": ["townswoman", "fall_flat", -1.0, false, Vector2(0.0, 0.0), "затоптана в давке"],
	"corpse_doorway": ["townsman", "fall_flat", -1.0, false, Vector2(0.0, 0.45), "в дверях: голова на улице, ноги в доме"],
	"corpse_collapsed": ["townsman", "walk_collapse", -1.0, false, Vector2(0.0, 0.0), "шёл и упал"],
	"corpse_soldier": ["hero", "walk_collapse", -1.0, false, Vector2(0.0, 0.0), "солдат гарнизона (та же туника, что у героя)"],
	"corpse_lying": ["townsman", "lying_pose", -1.0, false, Vector2(0.0, 0.0), "лежит на спине"],
	"corpse_curled": ["townsman", "dying", 2.2, false, Vector2(0.0, 0.0), "свернулся у порога"],
	"corpse_beaten": ["townsman", "dying", 4.6, false, Vector2(0.0, 0.0), "забит камнем (жертва первого святого)"],
	# Затоптанные во вступлении: последний кадр той же анимации, что и падение (Intro, INTRO.falls), без сдвига к тазу —
	# точка тела = где кончился root motion падения, поэтому тело лежит ровно там и так, как человек упал.
	"corpse_fell_back": ["townsman", "fall_back", -1.0, false, Vector2(0.0, 0.0), "упал навзничь в давке", ""],
	"corpse_fell_collapse_f": ["townswoman", "hit_collapse", -1.0, false, Vector2(0.0, 0.0), "согнулась от удара и завалилась", ""],
	"corpse_fell_stumble_f": ["townswoman", "fall_flat", -1.0, false, Vector2(0.0, 0.0), "споткнулась на бегу и упала ничком", ""],
	"corpse_fell_hit": ["townsman", "hit_fall", -1.0, false, Vector2(0.0, 0.0), "сбит ударом в плечо, упал на спину", ""],
	# Солдат сидит у стены (точка у стены, лицом от неё): сполз спиной по стене, ноги согнуты, руки упёрты в землю —
	# первый кадр crawl_back (отползал от них, пока не упёрся в стену)
	"corpse_soldier_sitting": ["hero", "crawl_back", 0.0, false, Vector2(0.0, -0.62), "солдат сидит у стены, сполз по ней"],
	"corpse_mother": ["townswoman", "walk_collapse", -1.0, false, Vector2(0.0, 0.0), "мать: упала на бегу"],
	# Сложенные в подвале: лежат ровно, рядами
	"corpse_laid": ["townsman", "lying_idle", 0.0, false, Vector2(0.0, 0.0), "сложен в подвале"],
	"corpse_laid_f": ["townswoman", "lying_idle", 1.6, false, Vector2(0.0, 0.0), "сложена в подвале"],
	"corpse_laid_soldier": ["hero", "lying_pose", -1.0, false, Vector2(0.0, 0.0), "солдат, сложен в подвале"],
	# Груда в подвале: те же модели в других позах и в одежде других цветов (краска)
	"corpse_heap_ochre": ["townsman", "lying_idle", 1.9, false, Vector2(0.0, 0.0), "в груде: в охристом", "Hips", Color(0.62, 0.47, 0.24)],
	"corpse_heap_grey_f": ["townswoman", "fall_flat", -1.0, false, Vector2(0.0, 0.0), "в груде: ничком, в серо-зелёном", "Hips", Color(0.4, 0.44, 0.36)],
	"corpse_heap_brown": ["townsman", "dying", 3.3, false, Vector2(0.0, 0.0), "в груде: на боку, в буром", "Hips", Color(0.36, 0.27, 0.2)],
	"corpse_heap_linen_f": ["townswoman", "lying_idle", 0.4, false, Vector2(0.0, 0.0), "в груде: в некрашеном льне", "Hips", Color(0.74, 0.7, 0.6)],
	"corpse_heap_blue": ["townsman", "fall_flat", -1.0, false, Vector2(0.0, 0.0), "в груде: ничком, в тёмно-синем", "Hips", Color(0.2, 0.25, 0.38)],
	"corpse_ash": ["hero", "lying_pose", -1.0, true, Vector2(0.0, 0.0), "сожжён ангелом: серый пепел"],
	"corpse_ash_f": ["townswoman", "dying", 0.0, true, Vector2(0.0, 0.0), "сожжена ангелом"],
	"corpse_ash_kneel": ["townsman", "pray_kneel", 0.0, true, Vector2(0.0, 0.0), "сгорел на коленях"],
}

static var _meshes := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


## Статичный меш тела: таз в точке (плюс сдвиг из KINDS), голова в −Z.
static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var k: Array = KINDS[kind]
	var m := CharacterModel.bake_pose(k[0], k[1], k[2], k[6] if k.size() > 6 else "Hips", k[4])
	_meshes[kind] = m
	return m


static func material(kind: String) -> Material:
	var k: Array = KINDS[kind]
	if k.size() > 7:
		return _dyed(k[0], k[7])
	return CharacterModel.material(k[0], k[3])


static var _dyed_mats := {}


## Материал модели с перекрашенной одеждой: насыщенные красные и синие пиксели текстуры (плащи, туники, покрывала)
## получают оттенок краски, яркость и складки остаются; кожа, волосы, некрашеная ткань не меняются.
static func _dyed(model: String, dye: Color) -> Material:
	var key := "%s:%s" % [model, dye.to_html(false)]
	if _dyed_mats.has(key):
		return _dyed_mats[key]
	var base: ShaderMaterial = CharacterModel.material(model)
	var tex: Texture2D = base.get_shader_parameter("albedo_texture")
	var mat: ShaderMaterial = base
	if tex:
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				var red := c.h < 0.035 or c.h > 0.93
				var blue := c.h > 0.52 and c.h < 0.74
				if c.s > 0.38 and (red or blue):
					# Красное — в цвет краски, синее — в её тёмный оттенок: одежда остаётся двухцветной
					var l := c.get_luminance() / (0.2 if red else 0.16)
					var d := dye if red else dye.darkened(0.35)
					img.set_pixel(x, y, Color(minf(d.r * l, 1.0), minf(d.g * l, 1.0), minf(d.b * l, 1.0), c.a))
		mat = PsxMaterial.make(ImageTexture.create_from_image(img))
	_dyed_mats[key] = mat
	return mat
