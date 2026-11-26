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
##   db_rand  — случайный разброс громкости, ±дБ;
##   occl_db  — насколько тише за стеной, дБ (по умолчанию SoundEmitter.OCCLUDED_DB, −12).
## Варианты берутся случайно, но один и тот же не звучит дважды подряд.
##
## Баланс (доделка 5-5) — по замерам, а не на слух: docs/audio_levels.md (громкость файлов) и
## tools/audio/mix_table.py (что получается у слушателя: файл + db + затухание по расстоянию).
## Лестница от тихого к громкому, дБFS у слушателя: ветер −43 · фон тьмы −38 (волны до −22) · дыхание −36…−34 ·
## свои шаги −33 (ходьба) / −32 (бег): не выше фона больше чем на 6 дБ (доделка 6, пункт 7) · напев святого (фраза) вплотную −16, 2,5 м −20, 6 м −28, 12–15 м −35…−38 (полировка демо 3) · шарканье святого с 8 м −42 · базар днём −37 · паника −27 ·
## удары, кувшин, крик вблизи −21…−17 · удар по голове −12. Меняешь файл — пересчитай db на ту же разницу.

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
const _HAMMER_FAR := [
	"res://audio/hammer_nail_07.ogg", "res://audio/hammer_nail_08.ogg", "res://audio/hammer_nail_09.ogg",
]
const _SCREAM_PAIN := ["res://audio/scream_pain_01.ogg", "res://audio/scream_pain_02.ogg"]
const _GROAN_PAIN := ["res://audio/groan_pain_01.ogg", "res://audio/groan_pain_02.ogg"]
const _GATE_RATTLE := [
	"res://audio/gate_rattle_01.ogg", "res://audio/gate_rattle_02.ogg", "res://audio/gate_rattle_03.ogg", "res://audio/gate_rattle_04.ogg",
]
const _PARCHMENT := [
	"res://audio/parchment_01.ogg", "res://audio/parchment_02.ogg", "res://audio/parchment_03.ogg", "res://audio/parchment_04.ogg",
]
const _WOOD_CLACK := [
	"res://audio/wood_clack_01.ogg", "res://audio/wood_clack_02.ogg", "res://audio/wood_clack_03.ogg", "res://audio/wood_clack_04.ogg", "res://audio/wood_clack_05.ogg",
]

const SOUNDS := {
	# ─── Фон (не 3D, слой с плавным фейдом) ───────────────────────────────────────
	## Фон тьмы: 10 мин, стерео. Паузы почти тишины — фича, не трогать.
	"ambient_drone": {"file": "res://audio/ambient_drone.ogg", "bus": "Ambience", "db": -8.0},
	## Ветер во тьме: 24 с, стерео, бесшовная петля — второй, тихий слой под ambient_drone (слой "wind").
	## Гаснет вместе с фоном перед ангелом (шина Ambience). Тише гула: ровная подложка под его волнами.
	"wind_drone": {"file": "res://audio/wind_drone.ogg", "bus": "Ambience", "db": -13.0, "loop": true},
	## Дневной фон площади: гомон базара (вступление; «день» в панели 0). 74 с, бесшовная петля.
	## Не громче пения святого с 6 м. Заглушка (synth "day_crowd") оставлена в sound_synth.gd.
	"ambience_day_crowd": {"file": "res://audio/market_crowd.ogg", "bus": "Ambience", "db": -10.0, "loop": true},
	## Тёмный гул с тихим пульсом (54,5 с, петля): только закрытые страшные места — подвал с мёртвыми, канал.
	## Включается зоной поверх фона тьмы: уровень 1 — подвал, куда сложили мёртвых (DEAD_CELLAR, слой "cellar").
	"dark_ambience": {"file": "res://audio/dark_ambience.ogg", "bus": "Ambience", "db": -8.0, "loop": true},

	# ─── Музыка ──────────────────────────────────────────────────────────────────
	## Индастриал-петля 107 уд/мин (17,9 с = 32 доли). ПОКА НЕ ИСПОЛЬЗУЕТСЯ (кандидат — погоня ангела или меню).
	"industrial_loop": {"file": "res://audio/industrial_loop.ogg", "bus": "Music", "db": -10.0, "loop": true},

	# ─── Дневные 3D-источники на площади (вступление, этап 4) ─────────────────────
	## Птицы утром: 100 с, моно, петля; у каждого источника — свой случайный старт (SoundEmitter.resume).
	"birds": {"file": "res://audio/birds_morning_mono.ogg", "bus": "Ambience", "db": -6.0, "loop": true, "unit": 6.0, "range": 60.0},
	"dogs": {"synth": "dogs", "bus": "Ambience", "db": -18.0, "loop": true, "unit": 8.0, "range": 70.0},
	"distant_singing": {"synth": "distant_singing", "bus": "Ambience", "db": -20.0, "loop": true, "unit": 10.0, "range": 90.0},

	# ─── Вступление (этап 4) ──────────────────────────────────────────────────────
	## Паника (доработка 4в): записи второго набора (audio/CREDITS.md). Обе петли — стерео, поэтому не из точки:
	## слои фона на шине Ambience (AudioManager.set_layer), в черноте глохнут через ФНЧ шины (set_bus_muffled).
	## Паника на 10 дБ громче базара; топот — под ней. Перегруз ловит лимитер на Master.
	"crowd_panic": {"file": "res://audio/crowd_panic.ogg", "bus": "Ambience", "db": -4.0, "loop": true},
	"crowd_stampede": {"file": "res://audio/crowd_stampede.ogg", "bus": "Ambience", "db": -7.0, "loop": true},
	## Отдельные крики, моно: ближние — у бегущих людей во время паники (3D), далёкие — в черноте (глухо, за стеной).
	"scream_man": {"file": _SCREAM_MAN, "bus": "Voices", "db": -6.0, "db_rand": 2.0, "unit": 3.0,
		"range": 60.0, "pitch": 0.06},
	## Героя толкнули (захват, ткань) — потом он падает (body_fall).
	"shove": {"file": _GRAB, "bus": "SFX", "db": -5.0, "pitch": 0.04},
	## Удар перед чернотой — и сразу звон в ушах (7 с, затихает в черноте: Intro.head_blow).
	"hit_head": {"file": "res://audio/hit_head.ogg", "bus": "SFX", "db": -3.0},
	"ring_ears": {"file": "res://audio/ring_ears_01.ogg", "bus": "SFX", "db": -6.0},
	## Тело падает на камень (герой; затоптанные в панике — 3D).
	"body_fall": {"file": _BODY_FALL, "bus": "SFX", "db": -6.0, "db_rand": 1.0, "unit": 2.5,
		"range": 35.0, "pitch": 0.05},
	## Глухой удар вдалеке (двери) — в черноте вступления; потом — ложные тревоги.
	"thud_far": {"file": _THUD_FAR, "bus": "SFX", "db": -4.0, "unit": 6.0, "range": 60.0, "pitch": 0.05},
	## Очнулся: судорожный вдох, потом кряхтит и встаёт (wake_groan 07–08 — зевки, не берём).
	"gasp_wake": {"file": _GASP_WAKE, "bus": "SFX", "db": -8.0},
	"wake_groan": {"file": _WAKE_GROAN, "bus": "SFX", "db": -10.0, "pitch": 0.03},
	## Сбивчивая речь вестника — по-арамейски (§5 «Языки голосов»); пока заглушка — невнятные слоги,
	## русский — субтитрами. Потом — запись голоса. Звучит из его головы.
	"voice_messenger": {"synth": "voice_babble", "bus": "Voices", "db": -14.0, "variants": 4, "unit": 2.0, "range": 25.0,
		"pitch": 0.04},

	# ─── Хор (только главное меню и молельная комната уровня 1) ──────────────────
	## Стерео — для главного меню (этап 10).
	"prayer_choir": {"file": "res://audio/prayer_choir.ogg", "bus": "Music", "db": -6.0, "loop": true},
	## Моно-копия того же хора — 3D-источник в молельной комнате.
	"prayer_choir_3d": {"file": "res://audio/prayer_choir_mono.ogg", "bus": "Voices", "db": -2.0, "loop": true,
		"unit": 2.5, "range": 32.0},

	# ─── Ангел (этап 6) ───────────────────────────────────────────────────────────
	## Чистый мажорный аккорд, который по мере звучания расстраивается.
	"angel_chord": {"synth": "angel_chord", "bus": "Angel", "db": -6.0, "unit": 4.0, "range": 60.0},
	## Крылья: медленные волны шума, как огромный парус на ветру.
	"angel_wings": {"synth": "angel_wings", "bus": "Angel", "db": -6.0, "loop": true, "unit": 5.0, "range": 50.0},
	## Звон в ушах: высокий синус с биением.
	"tinnitus": {"synth": "tinnitus", "bus": "Angel", "db": -18.0, "loop": true},

	# ─── Святые (этап 5) ──────────────────────────────────────────────────────────
	"saint_chant": {"synth": "saint_chant", "bus": "Voices", "db": -20.0, "loop": true, "unit": 6.0, "range": 40.0},
	## Напев без слов (записи второго набора, моно-петли): у каждого святого свой — 01 (48 с) или 02 (глухой, 56 с),
	## свой случайный старт и своя высота (Saint). Позиционный 3D: по нему игрок понимает, где святой.
	## Полировка демо 3: плавная кривая по расстоянию — unit 2,5 м (обратное расстояние, −6 дБ на удвоение),
	## range 50 м (уход в ноль далеко, без отсечки на 12–15 м). Фраза у слушателя: 15 м −38, 12 м −35 (тихо, на фоне тьмы),
	## 6 м −28 (ясно), 2,5 м −20, вплотную −16 (громко; в погоне +2; пик −3 дБFS — ниже лимитера).
	## За стеной — "occl_db" −7 (а не общие −12): святого за углом слышно, но глухо.
	"saint_chant_01": {"file": "res://audio/saint_chant_01.ogg", "bus": "Voices", "db": 0.0, "loop": true,
		"unit": 2.5, "range": 50.0, "occl_db": -7.0},
	"saint_chant_02": {"file": "res://audio/saint_chant_02.ogg", "bus": "Voices", "db": 0.0, "loop": true,
		"unit": 2.5, "range": 50.0, "occl_db": -7.0},
	## Ищет: быстрый монотонный речитатив обрывками; принюхивается.
	"saint_mumble": {"file": "res://audio/saint_mumble_01.ogg", "bus": "Voices", "db": -2.0, "loop": true,
		"unit": 2.5, "range": 40.0, "occl_db": -7.0},
	"saint_sniff": {"file": _SAINT_SNIFF, "bus": "Voices", "db": -10.0, "unit": 2.5, "range": 24.0, "pitch": 0.05,
		"occl_db": -7.0},
	## Погоня: низкая ровная нота под напевом; хрип-рык раз в 3–6 с (и когда схватил).
	"saint_drone": {"file": "res://audio/saint_drone_01.ogg", "bus": "Voices", "db": -8.0, "loop": true,
		"unit": 2.5, "range": 40.0, "occl_db": -7.0},
	"saint_growl": {"file": _SAINT_GROWL, "bus": "Voices", "db": -7.0, "db_rand": 2.0, "unit": 2.0, "range": 30.0,
		"pitch": 0.05, "occl_db": -7.0},
	## Шаги босиком и шорох погребальной ткани (на каждом 2–3-м шаге, тихо). Шарканье слышно с 8 м (−42),
	## на 3 м −31, вплотную −27 (полировка демо 3; было: с 6 м уже −47 — не слышно).
	"steps_barefoot": {"file": _STEPS_BAREFOOT, "bus": "SFX", "db": 0.0, "db_rand": 2.0, "unit": 3.0, "range": 24.0,
		"pitch": 0.05, "occl_db": -7.0},
	"cloth_rustle": {"file": _CLOTH_RUSTLE, "bus": "SFX", "db": -11.0, "db_rand": 2.0, "unit": 2.0, "range": 12.0,
		"pitch": 0.05},
	## Первый святой бьёт камнем мёртвого: мокрые тупые удары (слышно издалека — ведёт к переулку).
	"hit_wet": {"file": _HIT_WET, "bus": "SFX", "db": -2.0, "db_rand": 1.5, "unit": 3.0, "range": 40.0, "pitch": 0.06},
	## Схватил: захват, борьба, дыхание героя, удушье (не из точки — это сам герой).
	"grab": {"file": _GRAB, "bus": "SFX", "db": -6.0, "unit": 2.0, "range": 20.0, "pitch": 0.04},
	"struggle": {"file": "res://audio/struggle_01.ogg", "bus": "SFX", "db": -6.0},
	"breath_struggle": {"file": "res://audio/breath_struggle_01.ogg", "bus": "SFX", "db": -6.0},
	"choke": {"file": _CHOKE, "bus": "SFX", "db": -5.0, "pitch": 0.04},
	"whisper": {"synth": "whisper", "bus": "Voices", "db": -4.0, "variants": 3, "unit": 2.0, "range": 25.0, "pitch": 0.05},

	# ─── Герой ────────────────────────────────────────────────────────────────────
	## Шаги (записи, авторы — audio/CREDITS.md). Пока только камень: ходьба и присед, бег, ступени и лестницы.
	## Свои шаги почти сухие (доля эха — HeroAudio.step_reverb) и чуть выше фона тьмы; дыхание — тише шагов.
	"step_stone": {"file": _STEPS_STONE, "bus": "SFX", "db": -12.0, "db_rand": 2.0, "unit": 1.5, "range": 18.0, "pitch": 0.04},
	"step_stone_run": {"file": _STEPS_STONE_RUN, "bus": "SFX", "db": -11.5, "db_rand": 2.0, "unit": 1.5, "range": 18.0, "pitch": 0.04},
	"step_stairs": {"file": _STEPS_STAIRS, "bus": "SFX", "db": -8.5, "db_rand": 2.0, "unit": 1.5, "range": 18.0, "pitch": 0.04},
	## Заглушки других поверхностей — на потом (AudioManager.surfaces_enabled).
	"step_earth": {"synth": "step_earth", "bus": "SFX", "db": -16.0, "variants": 5, "unit": 1.5, "range": 18.0, "pitch": 0.06},
	"step_wood": {"synth": "step_wood", "bus": "SFX", "db": -17.0, "variants": 4, "unit": 1.5, "range": 18.0, "pitch": 0.05},
	## Дыхание — отдельные циклы, HeroAudio ставит их подряд (не петли): бег и угроза, одышка после бега,
	## «затаился» (присел, стоит, угроза > 0,3).
	"breath_run": {"file": _BREATH_RUN, "bus": "SFX", "db": -19.0},
	"breath_tired": {"file": _BREATH_TIRED, "bus": "SFX", "db": -18.0},
	"breath_calm": {"file": _BREATH_CALM, "bus": "SFX", "db": -22.0},
	## Один удар сердца («тук-тук»); частоту задаёт HeroAudio.
	"heartbeat": {"synth": "heartbeat", "bus": "SFX", "db": -12.0},

	# ─── Предметы ─────────────────────────────────────────────────────────────────
	"shard_break": {"synth": "shard_break", "bus": "SFX", "db": -10.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.08},
	## Глина бьётся (кувшин, горшок), дерево падает (табурет, лоток) — записи второго набора.
	"pot_break": {"file": _POT_BREAK, "bus": "SFX", "db": -1.0, "db_rand": 1.5, "unit": 3.0, "range": 40.0,
		"pitch": 0.06},
	"wood_fall": {"file": _WOOD_FALL, "bus": "SFX", "db": -3.0, "db_rand": 1.5, "unit": 3.0, "range": 40.0,
		"pitch": 0.06},
	## Предметы с физикой (этап 5): глина качнулась / покатилась, камень упал, стук дерева.
	## Громкость по силе удара и высоту ±5 % задаёт PhysProp.
	"pot_wobble": {"file": _POT_WOBBLE, "bus": "SFX", "db": -3.0, "unit": 2.5, "range": 30.0},
	"stone_drop": {"file": _STONE_DROP, "bus": "SFX", "db": -1.0, "unit": 2.5, "range": 35.0},
	"wood_clack": {"file": _WOOD_CLACK, "bus": "SFX", "db": -4.0, "unit": 2.5, "range": 30.0},
	## Записки (этап 5б): шорох свитка при чтении — не из точки (экран записки, play_2d); табличка — wood_clack.
	"parchment": {"file": _PARCHMENT, "bus": "SFX", "db": -4.0},

	# ─── Конец демо (этап 5б): ворота Антонии заперты, за скалой распинают ─────────
	## Створку дёргают (герой, вплотную). Из-за скалы (≈15 м, за камнем — окклюзия −12 дБ): далёкие удары молотка
	## по одному (07–09 — уличные, далёкие), крик и стон, обряд (пение и стук, петля 30 с) + напевы святых.
	## Цель у слушателя за скалой: молоток ≈ −36, крик ≈ −32, обряд ≈ −40 дБFS — тише фона, но различимо.
	"gate_rattle": {"file": _GATE_RATTLE, "bus": "SFX", "db": -6.0, "unit": 3.0, "range": 30.0, "pitch": 0.04},
	"hammer_far": {"file": _HAMMER_FAR, "bus": "SFX", "db": 2.0, "unit": 8.0, "range": 70.0, "pitch": 0.04},
	"scream_pain": {"file": _SCREAM_PAIN, "bus": "Voices", "db": -2.0, "unit": 6.0, "range": 70.0, "pitch": 0.03},
	"groan_pain": {"file": _GROAN_PAIN, "bus": "Voices", "db": 0.0, "unit": 6.0, "range": 60.0, "pitch": 0.03},
	"ritual_far": {"file": "res://audio/ritual_far_01.ogg", "bus": "Voices", "db": 0.0, "loop": true,
		"unit": 8.0, "range": 70.0},

	# ─── Ложные тревоги ───────────────────────────────────────────────────────────
	"alarm_stone_fall": {"synth": "stone_fall", "bus": "SFX", "db": -6.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.1},
	"alarm_door_creak": {"synth": "door_creak", "bus": "SFX", "db": -5.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.08},
	"alarm_distant_thud": {"synth": "distant_thud", "bus": "SFX", "db": -18.0, "variants": 2, "unit": 6.0, "range": 60.0, "pitch": 0.1},
	"alarm_shuffle": {"synth": "shuffle", "bus": "SFX", "db": -8.0, "variants": 3, "unit": 2.5, "range": 30.0, "pitch": 0.06},
}

## «Очнулся» (вступление и Awaken): три звука не разом, а по очереди; отсчёт — от момента, когда чернота уходит.
## 1) вдох gasp_wake — сразу (резкий, как удар), на gasp_db дБ тише, чем в реестре;
## 2) дыхание wake_groan — через groan_delay с, нарастает groan_rise с (groan_db — добавка к реестру: рост съедает начало);
## 3) фон: гул ambient_drone и ветер wind_drone возвращаются через drone_delay с, нарастают drone_rise с;
## хор молельни (3D, «dark») — ещё позже, через choir_delay с.
## Числа подобраны по замерам (tools/audio/wake_levels.py): общий пик на 8 дБ ниже прежнего «всё разом»,
## ни один из трёх не громче двух других вместе.
const WAKE := {
	"gasp_db": -9.0,
	"groan_delay": 1.25,
	"groan_rise": 1.0,
	"groan_db": 3.0,
	"drone_delay": 2.5,
	"drone_rise": 2.0,
	"choir_delay": 4.0,
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
