class_name Corpses
extends RefCounted
## Тела (CLAUDE.md §6): модели горожан и героя в позах мокап-анимаций, поза запечена в статичный меш
## (CharacterModel.bake_pose), без скелета — один вызов отрисовки на материал в куске уровня.
## Сожжённые ангелом — те же тела в сером пепле (material(..., ashen)).
## Ставятся как предметы: QuarterProps.place(вид, ...) — вид из KINDS, точка у таза, лицом (головой) в −Z.

## Вид → [модель, анимация, кадр (с; −1 — последний), пепел, сдвиг таза от точки (x, z), что это,
## (необязательно) кость над точкой: по умолчанию "Hips" — таз; "" — точка = кость Root (конец root motion падения)].
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
	"corpse_mother": ["townswoman", "walk_collapse", -1.0, false, Vector2(0.0, 0.0), "мать: упала на бегу"],
	# Сложенные в подвале: лежат ровно, рядами
	"corpse_laid": ["townsman", "lying_idle", 0.0, false, Vector2(0.0, 0.0), "сложен в подвале"],
	"corpse_laid_f": ["townswoman", "lying_idle", 1.6, false, Vector2(0.0, 0.0), "сложена в подвале"],
	"corpse_laid_soldier": ["hero", "lying_pose", -1.0, false, Vector2(0.0, 0.0), "солдат, сложен в подвале"],
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
	return CharacterModel.material(k[0], k[3])
