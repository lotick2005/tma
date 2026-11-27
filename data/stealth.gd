extends RefCounted
## Стелс (этап 5, CLAUDE.md §4, §8): шум и предметы с физикой — все числа в одном месте.
## Читают NoiseSystem (scripts/noise_system.gd), PhysProp (scripts/phys_prop.gd), Player, HeroHands.
## Параметры святых (слух, зрение, скорости, времена) — @export в scripts/saint.gd и в сцене scenes/actors/saint.tscn.
##
## Шумовое событие — {позиция, радиус, источник}. Святой слышит событие, если стоит ближе радиуса.
## За стеной (луч от точки шума до святого упирается в стену) радиус умножается на WALL_FACTOR.

## Шаги героя — радиус шума одного шага, м (по режиму движения, сигнал Player.footstep).
const STEP_RADIUS := {
	"crouch": 1.0,
	"walk": 4.0,
	"run": 10.0,
}
## Выглядывание (Q / E, полировка демо 5): наклонился или выпрямился стоя — переступил на месте, радиус шума, м
## (тише шага: шаг — 4 м); в приседе — как шаг в приседе.
const LEAN_RADIUS := 2.0
## Встал из приседа (полировка демо 3): первые шаги не сразу громкие — радиус шага нарастает от STAND_RISE_FROM м
## до обычного за STAND_RISE_TIME с. Святой ближе STAND_RISE_FROM слышит сразу, дальше — с задержкой.
const STAND_RISE_FROM := 3.0
const STAND_RISE_TIME := 0.8
## Шум за стеной слышно хуже: радиус × это.
const WALL_FACTOR := 0.5

## ─── Удары предметов ────────────────────────────────────────────────────────
## Шум — от удара, а не от вида предмета: скорость удара (м/с) × вес (кг) × громкость материала = радиус, м,
## не больше max_radius предмета. Удары слабее MIN_SPEED м/с не звучат (катится, лежит).
## Глина при ударе сильнее break_speed разбивается: шум — break_radius, меш сменяется 2–4 черепками.
const MIN_SPEED := 0.6
## Летел и коснулся: удар — скорость поперёк поверхности × GLANCE + полная скорость × GLANCE_ALONG
## (скользящий удар тоже звенит, но тише прямого).
const GLANCE := 0.8
const GLANCE_ALONG := 0.3
## Громкость материала: во сколько раз радиус больше, чем «скорость × вес».
const LOUDNESS := {"clay": 5.0, "stone": 1.7, "wood": 1.6}
## Звук удара по материалу (реестр data/sounds.gd): глина качнулась / покатилась, камень, дерево.
const HIT_SOUND := {"clay": "pot_wobble", "stone": "stone_drop", "wood": "wood_fall"}
## Звук, когда глина разбилась: большой сосуд — pot_break, черепок — shard_break.
const BREAK_SOUND := {"shard_piece": "shard_break"}
## Громкость звука удара: от radius = 0 до max_radius — от QUIET_DB до 0 дБ (добавка к реестру).
const QUIET_DB := -16.0
## Сколько секунд после появления предмет молчит (встаёт на землю при загрузке уровня).
const SPAWN_QUIET := 1.0
## Сколько секунд после удара предмет молчит (чтобы дребезг не сыпал события каждый кадр).
const HIT_COOLDOWN := 0.35

## Виды предметов с физикой. mesh — меш PropLibrary; mass — кг; material — clay / stone / wood;
## shape — "cyl" [радиус, высота] (низ — в точке предмета), "box" [x, y, z] (низ в точке), "lump" [x, y, z] (середина в точке);
## max_radius — самый громкий удар, м; break_speed — глина бьётся при такой скорости удара (0 — не бьётся);
## break_radius — шум, когда разбилась, м; shards — сколько черепков (от–до);
## pick — можно взять в левую руку (сколько в руке: черепков до 3, остального по одному);
## neck — кувшин в руке держат за горло: [высота горла над дном, радиус горла], м (без него — лежит в ладони);
## bump — во сколько раз сильнее его толкает герой (большой кувшин высокий и шаткий: бегом опрокидывается).
const KINDS := {
	"shard_piece": {"mesh": "shard_piece", "mass": 0.15, "material": "clay", "shape": "lump", "size": [0.13, 0.03, 0.1],
		"max_radius": 6.0, "break_speed": 2.5, "break_radius": 12.0, "shards": [0, 0], "pick": 3},
	"stone_throw": {"mesh": "stone_throw", "mass": 0.8, "material": "stone", "shape": "lump", "size": [0.13, 0.1, 0.12],
		"max_radius": 8.0, "break_speed": 0.0, "pick": 1},
	"jar_small": {"mesh": "jar_small", "mass": 1.2, "material": "clay", "shape": "cyl", "size": [0.12, 0.37],
		"max_radius": 6.0, "break_speed": 3.2, "break_radius": 14.0, "shards": [2, 3], "pick": 1, "neck": [0.33, 0.05]},
	"jug": {"mesh": "jug", "mass": 1.0, "material": "clay", "shape": "cyl", "size": [0.1, 0.32],
		"max_radius": 6.0, "break_speed": 3.2, "break_radius": 14.0, "shards": [2, 3], "pick": 1, "neck": [0.27, 0.045]},
	"jar_large": {"mesh": "jar_large", "mass": 9.0, "material": "clay", "shape": "cyl", "size": [0.24, 0.8],
		"max_radius": 8.0, "break_speed": 2.4, "break_radius": 16.0, "shards": [3, 4], "pick": 0, "bump": 1.7},
	"stool": {"mesh": "stool", "mass": 2.5, "material": "wood", "shape": "box", "size": [0.36, 0.45, 0.3],
		"max_radius": 6.0, "break_speed": 0.0, "pick": 0},
}

## ─── Герой задевает предметы ────────────────────────────────────────────────
## CharacterBody3D сам тела не толкает: герой проходит сквозь них, а предмету даётся толчок по скорости героя.
## Толчок, Н·с = BUMP_IMPULSE × (скорость героя, м/с)^BUMP_SPEED_POWER × (вес, кг)^BUMP_MASS_POWER; точка толчка —
## на доле высоты предмета: шагом — BUMP_HEIGHT_WALK (низко: сдвинулся, качнулся), бегом — BUMP_HEIGHT_RUN (высоко:
## опрокинулся). Шагом (2,2 м/с) кувшин качнётся, бегом (4,6 м/с) — опрокинется.
const BUMP_IMPULSE := 0.075
const BUMP_SPEED_POWER := 1.6
const BUMP_MASS_POWER := 1.0
const BUMP_HEIGHT_WALK := 0.3
const BUMP_HEIGHT_RUN := 0.85
## В приседе толчок слабее (герой идёт осторожно).
const BUMP_CROUCH := 0.35
## Один и тот же предмет толкается не чаще, с.
const BUMP_COOLDOWN := 0.5
## Насколько ближе своего радиуса коллизии герой задевает предмет, м (запас).
const BUMP_REACH := 0.08

## ─── Бросок ─────────────────────────────────────────────────────────────────
## Скорость броска, м/с: быстро щёлкнул ЛКМ — min (падает в ~3 м), держал THROW_HOLD_FULL с и дольше — max (~15 м,
## если смотреть прямо; выше взгляд — дальше). Дуга — чуть вверх от взгляда (THROW_LIFT).
const THROW_SPEED_MIN := 4.0
const THROW_SPEED_MAX := 17.0
const THROW_HOLD_FULL := 1.0
const THROW_LIFT := 0.18
## Откуда вылетает предмет — от глаз, в осях взгляда, м: слева внизу, где рука (x — вправо, y — вверх, z — назад).
const THROW_ORIGIN := Vector3(-0.22, -0.2, -0.45)
## Дуга-подсказка, пока зажата ЛКМ: считается той же формулой, что полёт (шаг физики, тяжесть, linear_damp предмета),
## до первой стены или пола. Точки пунктира — через ARC_DOT_STEP м, первая — в ARC_DOT_FROM м от руки;
## размер точки и метки места падения; полёт считается не дольше ARC_MAX_TIME с.
const THROW_DAMP := 0.2
const ARC_DOT_STEP := 0.45
const ARC_DOT_FROM := 0.6
const ARC_DOT_SIZE := 0.012
const ARC_MARK_RADIUS := 0.16
const ARC_MAX_TIME := 4.0
const ARC_COLOR := Color(0.95, 0.86, 0.66)
## Как далеко тянется рука, чтобы взять предмет (E), м, и в каком угле от взгляда, градусы.
const PICK_DISTANCE := 1.9
const PICK_ANGLE := 22.0

## ─── Предметы на уровне ─────────────────────────────────────────────────────
## Не больше стольких тел с физикой на уровне (черепки от разбитых считаются; лишние черепки не появляются).
const MAX_BODIES := 48
## Дальше этого от героя предметы заморожены, м; проверка раз в FREEZE_CHECK с.
const FREEZE_DISTANCE := 30.0
const FREEZE_CHECK := 0.5
