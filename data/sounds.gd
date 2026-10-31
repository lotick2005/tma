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
##   pitch    — случайный разброс высоты при проигрывании (0,05 = ±5 %).

const SOUNDS := {
	# ─── Фон (не 3D, слой с плавным фейдом) ───────────────────────────────────────
	## Фон тьмы: 10 мин, стерео. Паузы почти тишины — фича, не трогать.
	"ambient_drone": {"file": "res://audio/ambient_drone.ogg", "bus": "Ambience", "db": -3.0},
	## Дневной фон площади: гомон толпы (вступление; пока — «день» в панели 0).
	"ambience_day_crowd": {"synth": "day_crowd", "bus": "Ambience", "db": -10.0, "loop": true},

	# ─── Дневные 3D-источники на площади (вступление, этап 4) ─────────────────────
	"birds": {"synth": "birds", "bus": "Ambience", "db": -8.0, "loop": true, "unit": 6.0, "range": 60.0},
	"dogs": {"synth": "dogs", "bus": "Ambience", "db": -6.0, "loop": true, "unit": 8.0, "range": 70.0},
	"distant_singing": {"synth": "distant_singing", "bus": "Ambience", "db": -4.0, "loop": true, "unit": 10.0, "range": 90.0},

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
	"whisper": {"synth": "whisper", "bus": "Voices", "db": -8.0, "variants": 3, "unit": 2.0, "range": 25.0, "pitch": 0.05},

	# ─── Герой ────────────────────────────────────────────────────────────────────
	## Шаги по поверхностям: мостовая, утоптанная земля дворов и комнат, дерево мостков и лестниц.
	"step_stone": {"synth": "step_stone", "bus": "SFX", "db": -10.0, "variants": 5, "unit": 1.5, "range": 18.0, "pitch": 0.06},
	"step_earth": {"synth": "step_earth", "bus": "SFX", "db": -10.0, "variants": 5, "unit": 1.5, "range": 18.0, "pitch": 0.06},
	"step_wood": {"synth": "step_wood", "bus": "SFX", "db": -8.0, "variants": 4, "unit": 1.5, "range": 18.0, "pitch": 0.05},
	## Дыхание: спокойное, тяжёлое после бега, частое при угрозе (петли, их громкость смешивает HeroAudio).
	"breath_calm": {"synth": "breath_calm", "bus": "SFX", "db": -22.0, "loop": true},
	"breath_heavy": {"synth": "breath_heavy", "bus": "SFX", "db": -10.0, "loop": true},
	"breath_fast": {"synth": "breath_fast", "bus": "SFX", "db": -12.0, "loop": true},
	## Один удар сердца («тук-тук»); частоту задаёт HeroAudio.
	"heartbeat": {"synth": "heartbeat", "bus": "SFX", "db": -4.0},

	# ─── Предметы ─────────────────────────────────────────────────────────────────
	"shard_break": {"synth": "shard_break", "bus": "SFX", "db": -4.0, "variants": 3, "unit": 3.0, "range": 40.0, "pitch": 0.08},

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
