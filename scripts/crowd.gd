class_name Crowd
extends Node3D
## Толпа вступления (уровень 1, площадь A): 40–50 горожан на моделях Meshy со скелетом Mixamo (CharacterModel),
## живые мокап-анимации. Поведение:
##  • stand — стоит (idle, иногда idle_old), иногда поворачивается;
##  • wander — бродит вокруг своего места (радиус wander_radius), останавливается (walk_calm / walk);
##  • trade — торгуется у лотка: стоит и время от времени жестикулирует (point, look_around);
##  • молятся лицом к Храму (поворот — в данных): sing — стоя (pray_stand), bow — склонившись (pray_bow),
##    kneel — на коленях (pray_kneel).
## set_wailing(true) — «песни в плач» (Ам 8:10): все в ужасе (terrified), часть опускается на колени.
## play_person(i, анимация) — любая анимация человеку (для катсцен: shoved, fall_flat, run…).
## alert() — вестник бежит и кричит: часть людей оглядывается (look_around, look_around_back).
## flee(i, путь, скорость, задержка, конец, opts) — паника (вступление, этап 4в): кто срывается сразу — в ужасе
## (terrified), кто не побежал сразу — нервно озирается (look_nervous), сжимается (scared_cower) или играет
## opts.wait_anim (shoved — его толкнули, cover_peek — прижался и выглядывает, idle_defeated — оцепенел,
## kneel_stand_up — встаёт с колен);
## потом бежит по точкам (run / run_fast). В давке (opts.crush — у выходов с площади) — толкается и идёт
## (walk_shoved / push_walk); opts.stumble_at — на этом метре пути спотыкается (opts.stumble_anim: stumble или
## shoved_spin — толкнули, развернуло). В конце — "hide" (убежал, пропал из виду), "fall" (падает анимацией
## opts.fall_anim и остаётся лежать — затоптан), "bang" (добежал до двери и бьётся в неё; opts.bang_anim —
## что делает у двери: terrified, scared_cower, cover_peek).
## Разнообразие паники (полировка демо 4): opts.pause_at / pause_anim / pause_time — через столько метров бега замирает
## на pause_time с и снова бежит (оглянулся, закричал, оцепенел); opts.run_style — «пробежка» (run, медленно),
## «бег» (run) или «быстрый бег» (run_fast), у каждого свой темп и фаза; end "pray" — падает на колени и молится
## (pray_kneel_down, остаётся); opts.no_sep — не расталкивается с соседями (те, кто должен пройти точно по маршруту).
## Бегущие расталкиваются (SEP_*): толпа не сливается в одну кучу, хотя коллизии у бегущих нет.
## Падение opts.fall_anim == "stumble_fall": споткнулся (stumble) и через STUMBLE_FALL_CUT секунд — в fall_flat.
## Коллизия — цилиндр на каждого (герой не проходит сквозь людей), двигается вместе с ним.
## Дальние обновляют анимацию реже (LOD_*): каждый человек — 1 вызов отрисовки, скиннинг — главная цена.

## Человек упал в панике (затоптан) — точка у ног: звук падения тела.
signal fell(at: Vector3, anim: String)

@export var wander_radius := 1.8
@export var wander_speed := 0.7

## Дальше этих расстояний от камеры (м) анимация обновляется раз в LOD_INTERVALS секунд.
const LOD_DISTANCES := [14.0, 28.0]
const LOD_INTERVALS := [1.0 / 15.0, 0.2]
## Давка: скорость, м/с (walk_shoved записан на 1,07 м/с, push_walk — на 0,67).
const CRUSH_SPEED := {"walk_shoved": 1.15, "push_walk": 0.85}
## Оглядываются на крик вестника: доля стоящих и бродящих (поющие молятся дальше), задержка, с.
const ALERT_SHARE := 0.6
const ALERT_DELAY := Vector2(0.6, 4.0)
## Расталкивание бегущих: ближе SEP_RADIUS м друг к другу — расходятся со скоростью SEP_SPEED м/с.
const SEP_RADIUS := 0.8
const SEP_SPEED := 1.6
## «Споткнулся и упал»: через сколько секунд stumble (1,15×) переходит в fall_flat; root motion всего падения —
## Intro.FALL_MOTION["stumble_fall"] (замерено).
const STUMBLE_FALL_CUT := 0.7
const STUMBLE_FALL_SPEED := 1.15
## Паника: кто ждёт дольше этого (с), не в ужасе на месте, а озирается или сжимается.
const WAIT_CALM := 0.6
## Кто молится (их крик вестника не отвлекает) и чем: поведение → анимация.
const PRAY := {"sing": "pray_stand", "bow": "pray_bow", "kneel": "pray_kneel"}
## Торгуется: раз в столько секунд — жест (point или look_around) на столько секунд.
const TRADE_GAP := Vector2(3.0, 8.0)
const TRADE_GESTURE := Vector2(2.2, 3.4)

## Плач: 0 — нет, 1 — в полную силу (плавно).
var wailing := 0.0

var _people: Array[Dictionary] = []
var _body: StaticBody3D
var _wail_target := 0.0
var _rng := RandomNumberGenerator.new()
var _lod_timer := 0.0


func _ready() -> void:
	_rng.seed = 33


## Добавить человека: точка у ног, поворот (рад, лицом в −Z при 0), поведение "stand" / "wander" / "sing",
## вариант (чётные — горожанин, нечётные — горожанка).
func add_person(pos: Vector3, yaw: float, behavior: String, variant: int) -> void:
	_people.append({
		"home": pos, "pos": pos, "yaw": yaw, "do": behavior, "variant": variant,
		"target": pos, "wait": _rng.randf_range(0.5, 4.0),
		"kneels": _rng.randf() < 0.4, "turn": yaw, "forced": "",
	})


## Создать модели и коллизию. Вызвать один раз после всех add_person.
func commit() -> void:
	_body = StaticBody3D.new()
	_body.name = "CrowdCollision"
	add_child(_body)
	for i in _people.size():
		var p := _people[i]
		var m := CharacterModel.new()
		m.name = "Person%d" % i
		m.model = CutsceneActor.model_for_variant(p.variant)
		add_child(m)
		m.build()
		m.position = p.pos
		m.rotation.y = p.yaw
		p.model = m
		p.anim = ""
		_set_anim(p, _idle_anim(p), 0.0)
		m.randomize_phase(_rng)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25
		shape.height = 1.7
		cs.shape = shape
		_body.add_child(cs)
		p.shape = cs
	_update(0.0)


## Где сейчас люди (точки у ног).
func positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in _people:
		out.append(p.pos)
	return out


## Середина толпы (для звука).
func center() -> Vector3:
	var c := Vector3.ZERO
	for p in _people:
		c += p.pos
	return c / maxf(_people.size(), 1)


func count() -> int:
	return _people.size()


## Вестник бежит и кричит: часть стоящих и бродящих (не поющие) через ALERT_DELAY секунд начинает оглядываться.
func alert() -> void:
	for p in _people:
		if not PRAY.has(p.do) and _rng.randf() < ALERT_SHARE:
			p.alert_in = _rng.randf_range(ALERT_DELAY.x, ALERT_DELAY.y)


func set_wailing(on: bool) -> void:
	_wail_target = 1.0 if on else 0.0


## Человеку i — анимация (поверх поведения, пока не вызвать с пустым именем).
func play_person(i: int, anim_name: String, blend := 0.25) -> void:
	var p := _people[i]
	p.forced = anim_name
	if anim_name != "":
		_set_anim(p, anim_name, blend)


## Паника: человек i ждёт delay секунд, потом бежит по route со скоростью speed; end — что в конце пути:
## "hide" — пропал из виду, "fall" — падает (opts.fall_anim, по умолчанию fall_flat; повёрнут на opts.fall_yaw)
## и остаётся лежать, "bang" — бьётся в дверь.
## opts: "crush" — [[точка, радиус], …]: внутри — давка (opts.crush_anim: walk_shoved или push_walk, медленно);
## "stumble_at" — через столько метров бега спотыкается (stumble) и бежит дальше.
## Пока ждёт: delay < WAIT_CALM — в ужасе (terrified), дольше — нервно озирается (look_nervous) или,
## opts.cower — сжимается (scared_cower). Коллизия с бегущих снимается (герой в это время не управляется).
func flee(i: int, route: PackedVector3Array, speed: float, delay: float, end := "hide", opts := {}) -> void:
	var p := _people[i]
	p.flee = {"route": route, "at": 0, "speed": speed, "delay": delay, "end": end, "done": false,
		"crush": opts.get("crush", []), "crush_anim": opts.get("crush_anim", "walk_shoved"),
		"stumble_at": float(opts.get("stumble_at", -1.0)), "ran": 0.0, "stumble": 0.0,
		"stumble_anim": opts.get("stumble_anim", "stumble"), "bang_anim": opts.get("bang_anim", "terrified"),
		"fall_anim": opts.get("fall_anim", "fall_flat"), "fall_yaw": opts.get("fall_yaw", null),
		"pause_at": float(opts.get("pause_at", -1.0)), "pause_anim": opts.get("pause_anim", "look_around_back"),
		"pause_time": float(opts.get("pause_time", 1.2)), "pause": 0.0, "run_style": int(opts.get("run_style", 1)),
		"no_sep": bool(opts.get("no_sep", false)), "fall_cut": -1.0}
	p.forced = ""
	p.erase("alert_in")
	if p.has("shape"):
		(p.shape as CollisionShape3D).disabled = true
	var m: CharacterModel = p.model
	var wait_anim: String = opts.get("wait_anim", "")
	if wait_anim != "" and delay >= WAIT_CALM:
		# Разовые (встаёт с колен, толкнули) — с начала; циклы — со случайного места
		var once := wait_anim in ["kneel_stand_up", "shoved", "yell_out"]
		m.play(wait_anim, 0.3, float(opts.get("wait_speed", 1.0)), once)
		p.anim = wait_anim
		if not once:
			m.randomize_phase(_rng)
		elif wait_anim != "kneel_stand_up" and m.anim:
			# Разовые начинаются не все разом: кого-то уже толкнули, кто-то только кричит
			m.anim.seek(_rng.randf_range(0.0, 0.3) * m.anim.current_animation_length, true)
	elif delay < WAIT_CALM:
		_set_anim(p, "terrified", 0.3, _rng.randf_range(1.0, 1.4))
		m.randomize_phase(_rng)
	elif opts.get("cower", false):
		# Сжался — и через delay вскакивает и бежит (с начала цикла: сначала сидит)
		_set_anim(p, "scared_cower", 0.35)
	else:
		_set_anim(p, "look_nervous", 0.3, _rng.randf_range(1.0, 1.3))
		m.randomize_phase(_rng)


## Убрать толпу (и её коллизию) — людей на площади больше нет.
func vanish() -> void:
	visible = false
	set_process(false)
	for p in _people:
		(p.model as CharacterModel).process_mode = Node.PROCESS_MODE_DISABLED
	if _body:
		_body.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_update(delta)


func _idle_anim(p: Dictionary) -> String:
	if PRAY.has(p.do):
		return PRAY[p.do]
	return "idle_old" if int(p.variant) == 3 else "idle"


func _set_anim(p: Dictionary, anim_name: String, blend: float, speed := 1.0) -> void:
	(p.model as CharacterModel).play(anim_name, blend, speed)
	p.anim = anim_name


func _update(delta: float) -> void:
	wailing = move_toward(wailing, _wail_target, delta * 0.5)
	for p in _people:
		var moving := false
		if p.has("flee"):
			_update_flee(p, delta)
			continue
		if p.has("alert_in"):
			p.alert_in -= delta
			if p.alert_in <= 0.0:
				p.erase("alert_in")
				p.forced = "look_around" if _rng.randf() < 0.5 else "look_around_back"
				_set_anim(p, p.forced, 0.5, _rng.randf_range(0.9, 1.15))
				(p.model as CharacterModel).randomize_phase(_rng)
		if p.forced != "":
			pass
		elif wailing > 0.1:
			# Плач: ужас; часть опускается на колени
			var a := "kneel_down" if p.kneels else "terrified"
			if p.anim != a:
				_set_anim(p, a, 0.6, _rng.randf_range(0.85, 1.1))
		else:
			match p.do:
				"wander":
					if p.wait > 0.0:
						p.wait -= delta
						if p.wait <= 0.0:
							var a := _rng.randf() * TAU
							var r := _rng.randf_range(0.6, wander_radius)
							p.target = p.home + Vector3(cos(a) * r, 0.0, sin(a) * r)
					else:
						var to: Vector3 = p.target - p.pos
						to.y = 0.0
						if to.length() < 0.1:
							p.wait = _rng.randf_range(2.0, 6.0)
						else:
							p.pos += to.normalized() * minf(wander_speed * delta, to.length())
							p.turn = atan2(-to.x, -to.z)
							moving = true
				"sing", "bow", "kneel":
					pass
				"trade":
					# Торгуется: жест — и снова стоит
					p.wait -= delta
					if p.wait <= 0.0:
						if p.get("gesture", "") == "":
							p.gesture = "point" if _rng.randf() < 0.6 else "look_around"
							p.wait = _rng.randf_range(TRADE_GESTURE.x, TRADE_GESTURE.y)
						else:
							p.gesture = ""
							p.wait = _rng.randf_range(TRADE_GAP.x, TRADE_GAP.y)
				_:
					p.wait -= delta
					if p.wait <= 0.0:
						p.wait = _rng.randf_range(4.0, 10.0)
						p.turn = p.yaw + _rng.randf_range(-0.8, 0.8)
			var want := "walk_calm" if moving else _idle_anim(p)
			if p.get("gesture", "") != "":
				want = p.gesture
			if p.anim != want:
				_set_anim(p, want, 0.35, Anims.scale_for(want, wander_speed) if moving else 1.0)
		p.yaw = lerp_angle(p.yaw, p.turn, 1.0 - exp(-3.0 * delta))
		var m: CharacterModel = p.model
		m.position = p.pos
		m.rotation.y = p.yaw
		if p.has("shape"):
			(p.shape as CollisionShape3D).position = (p.pos as Vector3) + Vector3.UP * 0.85
	_separate(delta)
	_update_lod(delta)


## Бегущие расталкиваются: два человека ближе SEP_RADIUS расходятся (коллизии у бегущих нет, но кучей не сливаются).
## Не трогает тех, кто упадёт в точку (end "fall"), стоит, ждёт или помечен no_sep.
func _separate(delta: float) -> void:
	var movers: Array[Dictionary] = []
	for p in _people:
		if not p.has("flee"):
			continue
		var f: Dictionary = p.flee
		if f.done or f.delay > 0.0 or f.pause > 0.0 or f.stumble > 0.0 or f.end == "fall" or f.no_sep:
			continue
		movers.append(p)
	for a in movers.size():
		for b in range(a + 1, movers.size()):
			var pa: Dictionary = movers[a]
			var pb: Dictionary = movers[b]
			var d: Vector3 = pa.pos - pb.pos
			d.y = 0.0
			var dist := d.length()
			if dist >= SEP_RADIUS:
				continue
			if dist < 0.01:
				d = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
				dist = 0.01
			var push := d / dist * SEP_SPEED * delta * (1.0 - dist / SEP_RADIUS)
			pa.pos += push
			pb.pos -= push
			(pa.model as CharacterModel).position = pa.pos
			(pb.model as CharacterModel).position = pb.pos


## Паника: ждёт, бежит по точкам (в давке — толкается и идёт, может споткнуться), в конце — пропадает,
## падает или бьётся в дверь.
func _update_flee(p: Dictionary, delta: float) -> void:
	var f: Dictionary = p.flee
	var m: CharacterModel = p.model
	if f.fall_cut >= 0.0:
		# Споткнулся и падает: через STUMBLE_FALL_CUT stumble переходит в fall_flat
		f.fall_cut -= delta
		if f.fall_cut < 0.0:
			m.play("fall_flat", 0.25, 1.0, true)
			p.anim = "fall_flat"
		return
	if f.done:
		return
	if f.delay > 0.0:
		f.delay -= delta
		return
	# Замер на бегу (оглянулся, закричал): стоит pause секунд и бежит дальше
	if f.pause > 0.0:
		f.pause -= delta
		if f.pause <= 0.0:
			p.anim = ""
		return
	# Споткнулся: стоит, пока не доиграет stumble, потом root motion — в его точку, бежит дальше
	if f.stumble > 0.0:
		f.stumble -= delta
		if f.stumble <= 0.0:
			p.pos += Basis(Vector3.UP, m.rotation.y) * m.motion
			m.reset_motion()
			m.position = p.pos
		return
	var route: PackedVector3Array = f.route
	var crush := ""
	for c: Array in f.crush:
		var d: Vector3 = (c[0] as Vector3) - p.pos
		d.y = 0.0
		if d.length() < float(c[1]):
			crush = f.crush_anim
	var speed: float = CRUSH_SPEED[crush] if crush != "" else f.speed
	var left: float = speed * delta
	f.ran += left
	while left > 0.0 and f.at < route.size():
		var to: Vector3 = route[f.at] - p.pos
		to.y = 0.0
		var d := to.length()
		if d <= left:
			p.pos = Vector3(route[f.at].x, p.pos.y, route[f.at].z)
			left -= d
			f.at += 1
		else:
			p.pos += to / d * left
			p.turn = atan2(-to.x, -to.z)
			left = 0.0
	p.yaw = lerp_angle(p.yaw, p.turn, 1.0 - exp(-(4.0 if crush != "" else 10.0) * delta))
	m.position = p.pos
	m.rotation.y = p.yaw
	if f.at < route.size():
		if f.stumble_at >= 0.0 and f.ran >= f.stumble_at and crush == "":
			f.stumble_at = -1.0
			m.reset_motion()
			var sa: String = f.stumble_anim
			m.play(sa, 0.15, 1.15, true)
			p.anim = sa
			f.stumble = Anims.library().get_animation(sa).length / 1.15 - 0.25
			return
		if f.pause_at >= 0.0 and f.ran >= f.pause_at and crush == "":
			f.pause_at = -1.0
			f.pause = f.pause_time
			var pa: String = f.pause_anim
			m.play(pa, 0.2, _rng.randf_range(0.9, 1.15), true)
			p.anim = pa
			return
		var a := crush
		if a == "":
			# Темп у каждого свой: пробежка, бег, быстрый бег
			a = "run_fast" if f.speed > 5.0 else "run"
		if p.anim != a:
			var sc := clampf(Anims.scale_for(a, speed) * [0.9, 1.0, 1.1][f.run_style % 3], 0.6, 1.7)
			_set_anim(p, a, 0.3 if crush != "" or p.anim == "walk_shoved" or p.anim == "push_walk" else 0.2, sc)
			m.randomize_phase(_rng)
		return
	f.done = true
	match f.end:
		"fall":
			m.rotation.y = p.turn if f.fall_yaw == null else float(f.fall_yaw)
			m.set_update_interval(0.0)
			m.reset_motion()
			if f.fall_anim == "stumble_fall":
				m.play("stumble", 0.2, STUMBLE_FALL_SPEED, true)
				f.fall_cut = STUMBLE_FALL_CUT
				p.anim = "stumble"
			else:
				m.play(f.fall_anim, 0.2, 1.0, true)
			fell.emit(m.global_position, f.fall_anim)
		"pray":
			# Упал на колени посреди бегущих и молится (Ам 8:10: «песни ваши в плач»)
			m.reset_motion()
			m.play("pray_kneel_down", 0.3, _rng.randf_range(0.9, 1.1), true)
			p.anim = "pray_kneel_down"
		"bang":
			_set_anim(p, f.bang_anim, 0.25, 1.5 if f.bang_anim == "terrified" else 1.0)
			m.randomize_phase(_rng)
		_:
			m.visible = false


## Дальние — реже обновлять анимацию (раз в 0,5 с проверять расстояния).
func _update_lod(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer > 0.0:
		return
	_lod_timer = 0.5
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var eye := cam.global_position
	for p in _people:
		if p.has("flee") and p.flee.done:
			continue
		var d := eye.distance_to(global_transform * (p.pos as Vector3))
		var interval := 0.0
		for k in LOD_DISTANCES.size():
			if d > LOD_DISTANCES[k]:
				interval = LOD_INTERVALS[k]
		(p.model as CharacterModel).set_update_interval(interval)
