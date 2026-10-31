extends RefCounted
## Катсцена вступления (уровень 1, CLAUDE.md §2): вестник → солнце тускнеет → звуки уходят по одному →
## пение превращается в крик и плач → чернота и тишина → «глаза привыкают»: людей нет → «Выбраться из города».
## Играет scripts/intro.gd после свободной ходьбы. Формат шагов — в шапке scripts/cutscene_player.gd.
##
## Актёры: "messenger" — вестник. Точки (считает intro.gd): "m_path" — по главной дороге к арке,
## "m_corner" — угол у Южной стены (или та же арка, если герой под аркой), "m_stop" — перед героем,
## "m_side" — шаг в сторону от героя, "m_flee" — куда убегает, "sun" — чёрное солнце, "crowd" — середина толпы,
## "goal" — на север, к кварталу и маяку.
## Методы (ctx.target = Intro): silence(звук, с), voices_off(с), wail(), silence_all(), aftermath(), stand(), lamp_out().
##
## Единственное прямое объяснение в игре — слова вестника (§1 «Недосказанность»). Больше ничего не объяснять.

const STEPS := [
	# Вестник выбегает из квартала и бежит к герою; герой поворачивается на крик
	{"actor": "messenger", "show": true, "anim": "idle"},
	{"parallel": [
		{"actor": "messenger", "walk": ["m_path", "m_corner", "m_stop"], "speed": 4.2},
		{"camera": "look", "at": "messenger", "follow": true, "background": true},
		{"say": "Солдат!.. Солдат!", "who": "messenger", "sound": "voice_messenger", "time": 2.2},
	]},
	{"actor": "messenger", "anim": "panic"},
	{"parallel": [
		{"actor": "messenger", "turn_to": "hero_feet", "time": 0.3},
		{"camera": "look", "at": "messenger", "time": 0.5},
	]},
	{"say": "Гробы… гробы открылись…", "who": "messenger", "sound": "voice_messenger", "time": 3.0},
	{"say": "Мёртвые ходят. Я сам видел — ходят…", "who": "messenger", "sound": "voice_messenger", "time": 3.2},
	{"say": "Святые… они встали. Они идут в город.", "who": "messenger", "sound": "voice_messenger", "time": 3.6},
	{"say": "Беги… слышишь? Беги!", "who": "messenger", "sound": "voice_messenger", "time": 2.2},

	# Убегает; солнце начинает тускнеть, как при затмении
	{"actor": "messenger", "anim": "idle"},
	{"parallel": [
		{"actor": "messenger", "walk": ["m_side", "m_flee"], "speed": 4.6},
		{"camera": "look", "at": "messenger", "follow": true, "background": true},
	]},
	{"parallel": [
		{"effect": "lighting", "from": "day", "to": "darkness", "time": 18.0},
		# Взгляд: вверх, на солнце, потом — на людей
		{"steps": [
			{"pause": 0.8},
			{"camera": "look", "at": "sun", "time": 3.0},
			{"pause": 5.0},
			{"camera": "look", "at": "crowd", "time": 3.5},
		]},
		# Звуки пропадают по одному: птицы → собаки → голоса торговцев
		{"steps": [
			{"pause": 2.5},
			{"call": "silence", "args": ["birds", 3.0]},
			{"pause": 4.0},
			{"call": "silence", "args": ["dogs", 2.5]},
			{"pause": 4.0},
			{"call": "voices_off", "args": [4.0]},
		]},
	]},
	# Тихо — остаётся только пение. Потом пение превращается в крик и плач
	{"pause": 2.5},
	{"call": "wail", "skip": true},
	{"camera": "look", "at": "crowd", "follow": true, "time": 7.0},

	# Обрыв: полная чернота и тишина
	{"parallel": [
		{"effect": "fade", "to": 1.0, "time": 0.25, "ease": "linear"},
		{"call": "silence_all"},
	]},
	{"pause": 4.5},
	# В черноте: людей больше нет. Герой на коленях, смотрит в землю
	{"call": "aftermath"},
	{"pause": 1.5},
	# «Глаза привыкают»: медленно проступают мостовая, туман, брошенное
	{"parallel": [
		{"effect": "fade", "to": 0.0, "time": 8.0, "ease": "in"},
		{"effect": "global", "name": "psx_fog_end", "from": 2.5, "to": 13.5, "time": 9.0, "ease": "out"},
	]},
	{"pause": 1.0},
	{"call": "stand"},
	{"camera": "look", "at": "goal", "time": 3.0},
	{"call": "lamp_out"},
	{"pause": 1.2},
	{"title": "Выбраться из города"},
]
