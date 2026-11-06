class_name Anims
extends RefCounted
## Общая библиотека мокап-анимаций Mixamo (res://animations/*.glb, CLAUDE.md §2 «Анимации людей»).
## Каждый файл импортируется как AnimationLibrary с ретаргетом через models/mixamo_bone_map.tres —
## дорожки вида "%GeneralSkeleton:Hips", поэтому любая анимация подходит любой модели из res://models/.
## Здесь все 42 собраны в одну библиотеку (имя анимации = имя файла), плюс скорость записи для speed_scale.
## Таблица — animations/README.md.

const DIR := "res://animations/"

## Имя → [тип, скорость записи м/с (0 — на месте)]. Тип: loop — цикл на месте, once — разово
## (смещение в кости Root, root motion), pose — один кадр.
const LIST := {
	"idle": ["loop", 0.0], "idle_old": ["loop", 0.0], "idle_sway": ["loop", 0.0], "idle_sway_2": ["loop", 0.0],
	"idle_defeated": ["loop", 0.0],
	"walk": ["loop", 1.66], "walk_slow": ["loop", 0.53], "walk_calm": ["loop", 0.92], "walk_sad": ["loop", 0.76],
	"walk_injured": ["loop", 0.74], "walk_injured_fast": ["loop", 1.66], "walk_carry": ["loop", 1.16],
	"carry_idle": ["loop", 0.0], "walk_back": ["loop", 1.05], "strafe_left": ["loop", 1.61],
	"strafe_right": ["loop", 1.61], "run": ["loop", 4.11], "run_fast": ["loop", 5.5], "run_back": ["loop", 2.95],
	"crouch_walk": ["loop", 1.32], "crouch_pose": ["pose", 0.0], "crawl": ["loop", 0.47],
	"crawl_back": ["loop", 0.73],
	"walk_start": ["once", 0.0], "walk_stop": ["once", 0.0], "terrified": ["once", 0.0], "shoved": ["once", 0.0],
	"shoved_spin": ["once", 0.0], "fall_flat": ["once", 0.0], "walk_collapse": ["once", 0.0],
	"get_up": ["once", 0.0], "get_up_slow": ["once", 0.0], "kneel_down": ["once", 0.0],
	"kneel_stand_up": ["once", 0.0],
	"pray_stand": ["loop", 0.0], "pray_bow": ["loop", 0.0], "pray_kneel": ["loop", 0.0],
	"pray_kneel_down": ["once", 0.0], "pray_stand_up": ["once", 0.0],
	"dying": ["loop", 0.0], "lying_idle": ["loop", 0.0], "lying_pose": ["pose", 0.0],
}

## Дорожка кости Root — для AnimationMixer.root_motion_track.
const ROOT_TRACK := ^"%GeneralSkeleton:Root"

static var _lib: AnimationLibrary


## Все анимации одной библиотекой (грузится один раз, ~40 небольших файлов).
static func library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	for n: String in LIST:
		var src: AnimationLibrary = load(DIR + n + ".glb")
		if src == null or src.get_animation_list().is_empty():
			push_warning("Anims: нет анимации %s" % n)
			continue
		_lib.add_animation(n, src.get_animation(src.get_animation_list()[0]))
	return _lib


static func is_loop(anim_name: String) -> bool:
	return LIST.has(anim_name) and LIST[anim_name][0] == "loop"


## С какой скоростью шли в записи, м/с (0 — анимация на месте).
static func speed(anim_name: String) -> float:
	return float(LIST[anim_name][1]) if LIST.has(anim_name) else 0.0


## speed_scale, чтобы ноги не скользили при движении со скоростью v (для анимаций на месте — 1).
static func scale_for(anim_name: String, v: float) -> float:
	var s := speed(anim_name)
	return v / s if s > 0.0 else 1.0
