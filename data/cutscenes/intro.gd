extends RefCounted
## Катсцена вступления (уровень 1, CLAUDE.md §2), снята кадрами (§2 «Язык камеры»):
## верхний план площади → вестник бежит сквозь толпу (через плечо героя) → его слова (крупно, наезд) →
## паника (верхний план, вставки, дрожь; солнце начинает тускнеть) → героя сбивают (из его глаз: толчок, падение,
## ноги мимо, удар) → чернота со звуками, которые он пропустил → очнулся на мостовой во тьме → «Выбраться из города».
## Играет scripts/intro.gd. Формат шагов — в шапке scripts/cutscene_player.gd.
##
## Актёры: "messenger" — вестник, "double" — дублёр героя для кадра со стороны.
## Точки (считает intro.gd): "plaza" — середина площади; "m_path", "m_corner", "m_stop" — путь вестника к герою,
## "m_flee" — куда он бежит потом; "jar", "stall" — кувшин и лоток, которые опрокидывают; "sun" — чёрное солнце;
## "crowd" — середина толпы; "fall_cam", "fall_look" — где лежит голова героя и куда он смотрит вдоль мостовой;
## "wake_look" — куда смотрит, вставая; "goal" — на север, к кварталу и маяку.
## Методы (ctx.target = Intro): panic(), panic_sound(), tip(имя), hero_body(видно), blackout(), blackout_sound(),
## aftermath(), double(показать), lamp_out().
##
## Единственное прямое объяснение в игре — слова вестника (§1 «Недосказанность»). Больше ничего не объяснять.
## Вестник говорит по-арамейски (пока заглушка-бормотание), русский — только субтитры (§5 «Языки голосов»).

const STEPS := [
	# ── Утро. Верхний общий план: площадь, толпа, герой — маленький ──
	{"shot": "high_wide", "of": "plaza", "side": -140.0, "dist": 10.0, "height": 10.0, "time": 3.2, "push": 1.5},

	# ── Вестник бежит сквозь толпу — через плечо героя ──
	{"actor": "messenger", "show": true, "anim": "idle"},
	{"camera": "face", "at": "m_corner"},
	{"parallel": [
		{"actor": "messenger", "walk": ["m_path", "m_corner", "m_stop"], "speed": 4.2},
		{"shot": "over_shoulder", "of": "messenger", "background": true},
		{"steps": [
			{"pause": 1.2},
			{"say": "Солдат!.. Солдат!", "who": "messenger", "sound": "voice_messenger", "time": 2.2},
		]},
	]},
	{"actor": "messenger", "anim": "terrified", "face": "hero_feet"},
	{"camera": "face", "at": "messenger"},

	# ── Его слова — крупно лицо, камера медленно наезжает; в середине — лицо героя ──
	{"parallel": [
		{"shot": "close", "of": "messenger", "side": 25.0, "dist": 1.1, "time": 6.6, "push": 0.4, "roll": 3.0},
		{"steps": [
			{"pause": 0.3},
			{"say": "Гробы… гробы открылись…", "who": "messenger", "sound": "voice_messenger", "time": 3.0},
			{"say": "Мёртвые ходят. Я сам видел — ходят…", "who": "messenger", "sound": "voice_messenger", "time": 3.2},
		]},
	]},
	{"shot": "close", "of": "hero", "side": -30.0, "dist": 1.0, "time": 1.4, "push": 0.1},
	{"parallel": [
		{"shot": "close", "of": "messenger", "side": -15.0, "dist": 0.75, "time": 5.6, "push": 0.2, "roll": -5.0},
		{"steps": [
			{"say": "Святые… они встали. Они идут в город.", "who": "messenger", "sound": "voice_messenger", "time": 3.5},
			{"say": "Беги… слышишь? Беги!", "who": "messenger", "sound": "voice_messenger", "time": 2.0},
		]},
	]},

	# ── Паника. Крик подхватывают, толпа срывается; солнце начинает тускнеть. От panic до удара — INTRO.knock_time (9 с) ──
	{"call": "panic"},
	{"call": "panic_sound", "skip": true},
	{"actor": "messenger", "anim": "idle"},
	{"parallel": [
		{"actor": "messenger", "walk": ["m_flee"], "speed": 4.8, "background": true},
		{"effect": "lighting", "from": "day", "to": "darkness", "time": 9.0, "amount": 0.5},
		{"steps": [
			# Верхний план: люди бегут к арке, к домам, к стройке
			{"shot": "high_wide", "of": "plaza", "side": -140.0, "dist": 9.0, "height": 9.0, "time": 2.6, "shake": 0.25,
				"roll": 4.0},
			# Вставки: кувшин падает и бьётся, лоток опрокидывают
			{"call": "tip", "args": ["jar"]},
			{"shot": "insert", "of": "jar", "side": 160.0, "dist": 1.5, "time": 1.1, "shake": 0.5, "track": false},
			{"call": "tip", "args": ["stall"]},
			{"shot": "insert", "of": "stall", "side": 60.0, "dist": 3.0, "height": 0.4, "time": 1.3, "shake": 0.5,
				"roll": -8.0, "track": false},
			# Из глаз героя: вокруг бегут; взгляд вверх — солнце гаснет
			{"camera": "eyes", "time": 0.0},
			{"effect": "shake", "amount": 0.2},
			{"camera": "look", "at": "sun", "time": 1.3},
			{"pause": 1.6},
			{"camera": "look", "at": "crowd", "time": 0.9, "ease": "in"},
			{"pause": 0.2},
		]},
	]},

	# ── Героя сбивают с ног — из его глаз: толчок, камера летит на мостовую, мимо бегут ноги, удар ──
	{"sound": "body_hit"},
	{"effect": "shake", "amount": 1.0},
	{"call": "hero_body", "args": [false]},
	{"camera": "move", "to": "fall_cam", "look": "fall_look", "roll": 82.0, "time": 0.5, "ease": "in"},
	{"sound": "body_fall"},
	{"effect": "shake", "amount": 1.0, "time": 0.7},
	{"pause": 0.7},
	{"effect": "shake", "amount": 0.3},
	{"pause": 2.1},
	{"sound": "body_hit"},
	{"effect": "fade", "to": 1.0, "time": 0.04, "ease": "linear"},

	# ── Без сознания: чернота; глухо, урывками — то, что он пропустил. Ничего не показываем ──
	{"call": "blackout"},
	{"effect": "shake", "amount": 0.0},
	{"pause": 1.2},
	{"call": "blackout_sound", "skip": true},
	{"pause": 13.2},

	# ── Очнулся: всё уже произошло. Щекой на мостовой, мутно; тьма и туман расходятся медленно ──
	{"call": "aftermath"},
	{"pause": 1.0},
	{"parallel": [
		{"effect": "fade", "to": 0.0, "time": 7.0, "ease": "in"},
		{"effect": "global", "name": "psx_fog_end", "from": 2.0, "to": 13.5, "time": 9.0, "ease": "out"},
		{"effect": "roll", "to": 74.0, "time": 9.0},
	]},
	# Со стороны, сверху: пустая площадь, тела; он один — тяжело встаёт
	{"call": "double", "args": [true]},
	{"shot": "high_wide", "of": "hero_feet", "side": 200.0, "dist": 4.5, "height": 4.2, "time": 5.2, "push": 0.7},
	{"call": "double", "args": [false]},
	# Снова из глаз: поднял голову, смотрит на север; достаёт светильник
	{"camera": "face", "at": "wake_look", "pitch": -0.45},
	{"camera": "eyes", "time": 0.0},
	{"call": "hero_body", "args": [true]},
	{"pause": 0.6},
	{"camera": "look", "at": "goal", "time": 3.0},
	{"call": "lamp_out"},
	{"pause": 1.2},
	{"title": "Выбраться из города"},
]
