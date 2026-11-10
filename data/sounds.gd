extends RefCounted
## Реестр звуков (CLAUDE.md §5) — все звуки игры по именам, в одном месте. Читает AudioManager.
##
## Каждая строка — один звук. У звука ЛИБО файл ("file"), ЛИБО процедурная заглушка ("synth" —
## имя функции в scripts/sound_synth.gd, генерируется при старте).
## Заменить заглушку записью — одна строка: вместо "synth": "birds" пишешь "file": "res://audio/birds.ogg"
## (несколько вариантов — массив: "file": ["res://audio/step_stone_1.ogg", "res://audio/step_stone_2.ogg"]).
## Для браузера — только .ogg; всё, что звучит из точки в мире, — моно. Автора и лицензию — в audio/CREDITS.md.
##
## Поля:
##   bus      — шина: Ambience, SFX, Voices, Angel, Music;
##   db       — громкость, дБ;
##   loop     — зациклен (у файлов включается при загрузке; длинный фон зацикливает слой с кроссфейдом);
##   variants — сколько вариантов сгенерировать заглушкой (при каждом проигрывании берётся случайный);
##   unit     — расстояние, м, на котором 3D-звук звучит в полную силу (дальше тише);
##   range    — дальше этого, м, 3D-звук не слышен;
##   pitch    — случайный разброс высоты при проигрывании (0,05 = ±5 %);
##   db_rand  — случайный разброс громкости, ±дБ.
## Варианты берутся случайно, но один и тот же не звучит дважды подряд.

const _STEPS_STONE := [
	"res://audio/steps_stone_01.ogg", "res://audio/steps_stone_02.ogg", "res://audio/steps_stone_03.ogg",
	"res://audio/steps_stone_04.ogg", "res://audio/steps_stone_05.ogg", "res://audio/steps_stone_06.ogg",
	"res://audio/steps_stone_07.ogg", "res://audio/steps_stone_08.ogg", "res://audio/steps_stone_09.ogg",
	"res://audio/steps_stone_10.ogg", "res://audio/steps_stone_11.ogg", "res://audio/steps_stone_12.ogg",
]
const _STEPS_STONE_RUN := [
	"res://audio/steps_stone_run_01.ogg", "res://audio/steps_stone_run_02.ogg", "res://audio/steps_stone_run_03.ogg",
	"res://audio/steps_stone_run_04.ogg", "res://audio/steps_stone_run_05.ogg", "res://audio/steps_stone_run_06.ogg",
]
const _STEPS_STAIRS := [
	"res://audio/steps_stairs_01.ogg", "res://audio/steps_stairs_02.ogg", "res://audio/steps_stairs_03.ogg",
	"res://audio/steps_stairs_04.ogg", "res://audio/steps_stairs_05.ogg", "res://audio/steps_stairs_06.ogg",
	"res://audio/steps_stairs_07.ogg", "res://audio/steps_stairs_08.ogg", "res://audio/steps_stairs_09.ogg",
	"res://audio/steps_stairs_10.ogg",
]
const _BREATH_RUN := [
	"res://audio/breath_run_01.ogg", "res://audio/breath_run_02.ogg", "res://audio/breath_run_03.ogg",
	"res://audio/breath_run_04.ogg", "res://audio/breath_run_05.ogg",
]
const _BREATH_TIRED := [
	"res://audio/breath_tired_01.ogg", "res://audio/breath_tired_02.ogg", "res://audio/breath_tired_03.ogg",
	"res://audio/breath_tired_04.ogg", "res://audio/breath_tired_05.ogg", "res://audio/breath_tired_06.ogg",
	"res://audio/breath_tired_07.ogg",
]
const _BREATH_CALM := ["res://audio/breath_calm_01.ogg", "res://audio/breath_calm_02.ogg"]

## Второй набор записей (доработка 4в): варианты одного звука, имя_01…NN.ogg.
const _SCREAM_MAN := [
	"res://audio/scream_man_01.ogg", "res://audio/scream_man_02.ogg", "res://audio/scream_man_03.ogg",
	"res://audio/scream_man_04.ogg", "res://audio/scream_man_05.ogg", "res://audio/scream_man_06.ogg",
]
const _GRAB := [
	"res://audio/grab_01.ogg", "res://audio/grab_02.ogg",
]
const _BODY_FALL := [
	"res://audio/body_fall_01.ogg", "res://audio/body_fall_02.ogg", "res://audio/body_fall_03.ogg",
]
const _THUD_FAR := [
	"res://audio/thud_far_01.ogg", "res://audio/thud_far_02.ogg",
]
const _GASP_WAKE := [
	"res://audio/gasp_wake_01.ogg", "res://audio/gasp_wake_02.ogg", "res://audio/gasp_wake_03.ogg",
	"res://audio/gasp_wake_04.ogg",
]
const _WAKE_GROAN := [
	"res://audio/wake_groan_01.ogg", "res://audio/wake_groan_02.ogg", "res://audio/wake_groan_03.ogg",
	"res://audio/wake_groan_04.ogg", "res://audio/wake_groan_05.ogg", "res://audio/wake_groan_06.ogg",
]
const _POT_BREAK := [
	"res://audio/pot_break_01.ogg", "res://audio/pot_break_02.ogg", "res://audio/pot_break_03.ogg",
	"res://audio/pot_break_04.ogg", "res://audio/pot_break_05.ogg", "res://audio/pot_break_06.ogg",
]
const _WOOD_FALL := [
	"res://audio/wood_fall_01.ogg", "res://audio/wood_fall_02.ogg", "res://audio/wood_fall_03.ogg",
]

## Этап 5: святые, схватка, предметы с физикой.
const _SAINT_GROWL := [
	"res://audio/saint_growl_01.ogg", "res://audio/saint_growl_02.ogg", "res://audio/saint_growl_03.ogg", "res://audio/saint_growl_04.ogg", "res://audio/saint_growl_05.ogg", "res://audio/saint_growl_06.ogg", "res://audio/saint_growl_07.ogg", "res://audio/saint_growl_08.ogg",
]
const _SAINT_SNIFF := [
	"res://audio/saint_sniff_01.ogg", "res://audio/saint_sniff_02.ogg",
]
const _STEPS_BAREFOOT := [
	"res://audio/steps_barefoot_01.ogg", "res://audio/steps_barefoot_02.ogg", "res://audio/steps_barefoot_03.ogg", "res://audio/steps_barefoot_04.ogg", "res://audio/steps_barefoot_05.ogg", "res://audio/steps_barefoot_06.ogg", "res://audio/steps_barefoot_07.ogg", "res://audio/steps_barefoot_08.ogg", "res://audio/steps_barefoot_09.ogg", "res://audio/steps_barefoot_10.ogg",
]
const _CLOTH_RUSTLE := [
	"res://audio/cloth_rustle_01.ogg", "res://audio/cloth_rustle_02.ogg", "res://audio/cloth_rustle_03.ogg", "res://audio/cloth_rustle_04.ogg", "res://audio/cloth_rustle_05.ogg", "res://audio/cloth_rustle_06.ogg", "res://audio/cloth_rustle_07.ogg", "res://audio/cloth_rustle_08.ogg", "res://audio/cloth_rustle_09.ogg", "res://audio/cloth_rustle_10.ogg", "res://audio/cloth_rustle_11.ogg", "res://audio/cloth_rustle_12.ogg", "res://audio/cloth_rustle_13.ogg", "res://audio/cloth_rustle_14.ogg",
]
const _HIT_WET := [
	"res://audio/hit_wet_01.ogg", "res://audio/hit_wet_02.ogg", "res://audio/hit_wet_03.ogg", "res://audio/hit_wet_04.ogg",
]
const _CHOKE := [
	"res://audio/choke_01.ogg", "res://audio/choke_02.ogg", "res://audio/choke_03.ogg", "res://audio/choke_04.ogg", "res://audio/choke_05.ogg", "res://audio/choke_06.ogg", "res://audio/choke_07.ogg", "res://audio/choke_08.ogg",
]
const _POT_WOBBLE := [
	"res://audio/pot_wobble_01.ogg", "res://audio/pot_wobble_02.ogg", "res://audio/pot_wobble_03.ogg",
]
const _STONE_DROP := [
	"res://audio/stone_drop_01.ogg", "res://audio/stone_drop_02.ogg", "res://audio/stone_drop_03.ogg", "res://audio/stone_drop_04.ogg", "res://audio/stone_drop_05.ogg",
]
const _WOOD_CLACK := [
	"res://audio/wood_clack_01.ogg", "res://audio/wood_clack_02.ogg", "res://audio/wood_clack_03.ogg", "res://audio/wood_clack_04.ogg", "res://audio/wood_clack_05.ogg",
]

const SOUNDS := {
	# ─── Фон (не 3D, слой с плавным фейдом) ───────────────────────────────────────
	## Фон тьмы: 10 мин, стерео. Паузы почти тишины — фича, не трогать.
	"ambient_drone": {"file": "res://audio/ambient_drone.ogg", "bus": "Ambience", "db": -3.0},
	## Ветер во тьме: 24 с, стерео, бесшовная петля — второй, тихий слой под ambient_drone (слой "wind").
	## Гаснет вместе с фоном перед ангелом (шина Ambience). Заметно тише гула.
	"wind_drone": {"file": "res://audio/wind_drone.ogg", "bus": "Ambience", "db": -13.0, "loop": true},
	## Дневной фон площади: гомон базара (вступление; «день» в панели 0). 74 с, бесшовная петля.
	## Чуть тише своих шагов вблизи. Заглушка (synth "day_crowd") оставлена в sound_synth.gd.
	"ambience_day_crowd": {"file": "res://audio/market_crowd.ogg", "bus": "Ambience", "db": -13.0, "loop": true},
	## Тёмный гул с тихим пульсом (54,5 с, петля): только закрытые страшные места — подвал с мёртвыми, канал.
	## Включается зоной поверх фона тьмы: уровень 1 — подвал, куда сложили мёртвых (DEAD_CELLAR, слой "cellar").
	"dark_ambience": {"file": "res://audio/dark_ambience.ogg", "bus": "Ambience", "db": -6.0, "loop": true},

	# ─── Музыка ──────────────────────────────────────────────────────────────────
	## Индастриал-петля 107 уд/мин (17,9 с = 32 доли). ПОКА НЕ ИСПОЛЬЗУЕТСЯ (кандидат — погоня ангела или меню).
	"industrial_loop": {"file": "res://audio/industrial_loop.ogg", "bus": "Music", "db": -10.0, "loop": true},

	# ─── Дневные 3D-источники на площади (вступление, этап 4) ─────────────────────
	## Птицы утром: 100 с, моно, петля; у каждого источника — свой случайный старт (SoundEmitter.resume).
	"birds": {"file": "res://audio/birds_morning_mono.ogg", "bus": "Ambience", "db": -6.0, "loop": true, "unit": 6.0, "range": 60.0},
	"dogs": {"synth": "dogs", "bus": "Ambience", "db": -6.0, "loop": true, "unit": 8.0, "range": 70.0},
	"distant_singing": {"synth": "distant_singing", "bus": "Ambience", "db": -4.0, "loop": true, "unit": 10.0, "range": 90.0},

	# ─── Вступление (этап 4) ──────────────────────────────────────────────────────
	## Паника (доработка 4в): записи второго набора (audio/CREDITS.md). Обе петли — стерео, поэтому не из точки:
	## слои фона на шине Ambience (AudioManager.set_layer), в черноте глохнут через ФНЧ шины (set_bus_muffled).
	## Паника громче базара (−13), но не режет; топот — под ней.
	"crowd_panic": {"file": "res://audio/crowd_panic.ogg", "bus": "Ambience", "db": -9.0, "loop": true},
	"crowd_stampede": {"file": "res://audio/crowd_stampede.ogg", "bus": "Ambience", "db": -11.0, "loop": true},
	## Отдельные крики, моно: ближние — у бегущих людей во время паники (3D), далёкие — в черноте (глухо, за стеной).
	"scream_man": {"file": _SCREAM_MAN, "bus": "Voices", "db": -8.0, "db_rand": 2.0, "unit": 3.0,
		"range": 60.0, "pitch": 0.06},
	## Героя толкнули (захват, ткань) — потом он падает (body_fall).
	"shove": {"file": _GRAB, "bus": "SFX", "db": -5.0, "pitch": 0.04},
	## Удар перед чернотой — и сразу звон в ушах (7 с, затихает в черноте: Intro.head_blow).
	"hit_head": {"file": "res://audio/hit_head.ogg", "bus": "SFX", "db": -3.0},
	"ring_ears": {"file": "res://audio/ring_ears_01.ogg", "bus": "SFX", "db": -12.0},
	## Тело падает на камень (герой; затоптанные в панике — 3D).
	"body_fall": {"file": _BODY_FALL, "bus": "SFX", "db": -3.0, "db_rand": 1.0, "unit": 2.5,
		"range": 35.0, "pitch": 0.05},
	## Глухой удар вдалеке (двери) — в черноте вступления; потом — ложные тревоги.
	"thud_far": {"file": _THUD_FAR, "bus": "SFX", "db": -4.0, "unit": 6.0, "range": 60.0, "pitch": 0.05},
	## Очнулся: судорожный вдох, потом кряхтит и встаёт (wake_groan 07–08 — зевки, не берём).
	"gasp_wake": {"file": _GASP_WAKE, "bus": "SFX", "db": -8.0},
	"wake_groan": {"file": _WAKE_GROAN, "bus": "SFX", "db": -10.0, "pitch": 0.03},
	## Сбивчивая речь вестника — по-арамейски (§5 «Языки голосов»); пока заглушка — невнятные слоги,
	## русский — субтитрами. Потом — запись голоса. Звучит из его головы.
	"voice_messenger": {"synth": "voice_babble", "bus": "Voices", "db": -4.0, "variants": 4, "unit": 2.0, "range": 25.0,
		"pitch": 0.04},

	# ─── Хор (только главное меню и молельная комната уровня 1) ──────────────────
	## Стерео — для главного меню (этап 10).
	"prayer_choir": {"file": "res://audio/prayer_choir.ogg", "bus": "Music", "db": -6.0, "loop": true},
	## Моно-копия того же хора — 3D-источник в молельной комнате.
	"prayer_choir_3d": {"file": "res://audio/prayer_choir_mono.ogg", "bus": "Voices", "db": -4.0, "loop": true,
		"unit": 2.5, "range": 32.0},

	# ─── Ангел (этап 6) ───────────────────────────────────────────────────────────
	## Чистый мажорный аккорд, который по мере звучания расстраивается.
	"angel_chord": {"synth": "angel_chord", "bus": "Angel", "db": -6.0, "unit": 4.0, "range": 60.0},
	## Крылья: медленные волны шума, как огромный парус на ветру.
	"angel_wings": {"synth": "angel_wings", "bus": "Angel", "db": -6.0, "loop": true, "unit": 5.0, "range": 50.0},
	## Звон в ушах: высокий синус с биением.
	"tinnitus": {"synth": "tinnitus", "bus": "Angel", "db": -18.0, "loop": true},

	# ─── Святые (этап 5) ──────────────────────────────────────────────────────────
	"saint_chant": {"synth": "saint_chant", "bus": "Voices", "db": -6.0, "loop": true, "unit": 2.0, "range": 25.0},
	## Напев без слов (записи второго набора, моно-петли): у каждого святого свой — 01 (48 с) или 02 (глухой, 56 с),
	## свой случайный старт и своя высота (Saint). Позиционный 3D: по нему игрок понимает, где святой.
	"saint_chant_01": {"file": "res://audio/saint_chant_01.ogg", "bus": "Voices", "db": -9.0, "loop": true,
		"unit": 2.0, "range": 26.0},
	"saint_chant_02": {"file": "res://audio/saint_chant_02.ogg", "bus": "Voices", "db": -8.0, "loop": true,
		"unit": 2.0, "range": 26.0},
	## Ищет: быстрый монотонный речитатив обрывками; принюхивается.
	"saint_mumble": {"file": "res://audio/saint_mumble_01.ogg", "bus": "Voices", "db": -10.0, "loop": true,
		"unit": 1.5, "range": 18.0},
	"saint_sniff": {"file": _SAINT_SNIFF, "bus": "Voices", "db": -10.0, "unit": 1.0, "range": 12.0, "pitch": 0.05},
	## Погоня: низкая ровная нота под напевом; хрип-рык раз в 3–6 с (и когда схватил).
	"saint_drone": {"file": "res://audio/saint_drone_01.ogg", "bus": "Voices", "db": -10.0, "loop": true,
		"unit": 2.0, "range": 22.0},
	"saint_growl": {"file": _SAINT_GROWL, "bus": "Voices", "db": -5.0, "db_rand": 2.0, "unit": 2.0, "range": 25.0,
		"pitch": 0.05},
	## Шаги босиком и шорох погребальной ткани (на каждом 2–3-м шаге, тихо).
	"steps_barefoot": {"file": _STEPS_BAREFOOT, "bus": "SFX", "db": -14.0, "db_rand": 2.0, "unit": 1.2, "range": 14.0,
		"pitch": 0.05},
	"cloth_rustle": {"file": _CLOTH_RUSTLE, "bus": "SFX", "db": -18.0, "db_rand": 2.0, "unit": 1.0, "range": 10.0,
		"pitch": 0.05},
	## Первый святой бьёт камнем мёртвого: мокрые тупые удары (слышно издалека — ведёт к переулку).
	"hit_wet": {"file": _HIT_WET, "bus": "SFX", "db": -3.0, "db_rand": 1.5, "unit": 3.0, "range": 40.0, "pitch": 0.06},
	## Схватил: захват, борьба, дыхание героя, удушье (не из точки — это сам герой).
	"grab": {"file": _GRAB, "bus": "SFX", "db": -3.0, "unit": 2.0, "range": 20.0, "pitch": 0.04},
	"struggle": {"file": "res://audio/struggle_01.ogg", "bus": "SFX", "db": -6.0},
	"breath_struggle": {"file": "res://audio/breath_struggle_01.ogg", "bus": "SFX", "db": -6.0},
	"choke": {"file": _CHOKE, "bus": "SFX", "db": -7.0, "pitch": 0.04},
	"whisper": {"synth": "whisper", "bus": "Voices", "db": -8.0, "variants": 3, "unit": 2.0, "range": 25.0, "pitch": 0.05},

	# ─── Герой ────────────────────────────────────────────────────────────────────
	## Шаги (записи, авторы — audio/CREDITS.md). Пока только камень: ходьба и присед, бег, ступени и лестницы.
	## Свои шаги почти сухие (доля эха — HeroAudio.step_reverb) и тише фона тьмы.
	"step_stone": {"file": _STEPS_STONE, "bus": "SFX", "db": -17.0, "db_rand": 2.0, "unit": 1.5, "range": 18.0, "pitch": 0.04},
	"step_stone_run": {"file": _STEPS_STONE_RUN, "bus": "SFX", "db": -16.0, "db_rand": 2.0, "unit": 1.5, "range": 18.0, "pitch": 0.04},
	"step_stairs": {"file": _STEPS_STAIRS, "bus": "SFX", "db": -16.0, "db_rand": 2.0, "unit": 1.5, "range": 18.0, "pitch": 0.04},
	## Заглушки других поверхностей — на потом (AudioManager.surfaces_enabled).
	"step_earth": {"synth": "step_earth", "bus": "SFX", "db": -10.0, "variants": 5, "unit": 1.5, "range": 18.0, "pitch": 0.06},
	"step_wood": {"synth": "step_wood", "bus": "SFX", "db": -8.0, "variants": 4, "unit": 1.5, "range": 18.0, "pitch": 0.05},
	## Дыхание — отдельные циклы, HeroAudio ставит их подряд (не петли): бег и угроза, одышка после бега,
	## «затаился» (присел, стоит, угроза > 0,3).
	"breath_run": {"file": _BREATH_RUN, "bus": "SFX", "db": -14.0},
	"breath_tired": {"file": _BREATH_TIRED, "bus": "SFX", "db": -13.0},
	"breath_calm": {"file": _BREATH_CALM, "bus": "SFX", "db": -22.0},
	## Один удар сердца («тук-тук»); частоту задаёт HeroAudio.
	"heartbeat": {"synth": "heartbeat", "bus": "SFX", "db": -10.0},

	# ─── Предметы ─────────────────────────────────────────────────────────────────
	"shard_break": {"synth": "shard_break", "bus": "SFX", "db": -4.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.08},
	## Глина бьётся (кувшин, горшок), дерево падает (табурет, лоток) — записи второго набора.
	"pot_break": {"file": _POT_BREAK, "bus": "SFX", "db": -4.0, "db_rand": 1.5, "unit": 3.0, "range": 40.0,
		"pitch": 0.06},
	"wood_fall": {"file": _WOOD_FALL, "bus": "SFX", "db": -4.0, "db_rand": 1.5, "unit": 3.0, "range": 40.0,
		"pitch": 0.06},
	## Предметы с физикой (этап 5): глина качнулась / покатилась, камень упал, стук дерева.
	## Громкость по силе удара и высоту ±5 % задаёт PhysProp.
	"pot_wobble": {"file": _POT_WOBBLE, "bus": "SFX", "db": -4.0, "unit": 2.5, "range": 30.0},
	"stone_drop": {"file": _STONE_DROP, "bus": "SFX", "db": -3.0, "unit": 2.5, "range": 35.0},
	"wood_clack": {"file": _WOOD_CLACK, "bus": "SFX", "db": -5.0, "unit": 2.5, "range": 30.0},

	# ─── Ложные тревоги ───────────────────────────────────────────────────────────
	"alarm_stone_fall": {"synth": "stone_fall", "bus": "SFX", "db": -6.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.1},
	"alarm_door_creak": {"synth": "door_creak", "bus": "SFX", "db": -8.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.08},
	"alarm_distant_thud": {"synth": "distant_thud", "bus": "SFX", "db": -4.0, "variants": 2, "unit": 6.0, "range": 60.0, "pitch": 0.1},
	"alarm_shuffle": {"synth": "shuffle", "bus": "SFX", "db": -8.0, "variants": 3, "unit": 2.5, "range": 30.0, "pitch": 0.06},
}

## Ложные тревоги: где-то в переулке вне поля зрения что-то звучит. Звуки — из SOUNDS.
const FALSE_ALARMS := {
	## Пауза между тревогами, с (случайно в этих пределах).
	"interval_min": 40.0,
	"interval_max": 120.0,
	## Не ближе и не дальше от героя, м.
	"distance_min": 8.0,
	"distance_max": 24.0,
	## При угрозе выше этой — не играть.
	"max_threat": 0.3,
	## [звук, где: "alley" — переулок / двор / площадка, "door" — у закрытой двери, вес].
	"sounds": [
		["alarm_stone_fall", "alley", 3.0],
		["alarm_door_creak", "door", 2.0],
		["alarm_distant_thud", "alley", 1.5],
		["whisper", "alley", 1.0],
		["alarm_shuffle", "alley", 2.0],
	],
}
