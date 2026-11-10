class_name Saint
extends CharacterBody3D
## Восставший святой (этап 5, CLAUDE.md §4). Сцена — res://scenes/actors/saint.tscn.
##
## Почти слепой: повязка на глазах. Ищет по звуку (NoiseSystem), видит смутно — силуэт вплотную спереди
## и горящий светильник дальше. Все дистанции, скорости и времена — @export ниже.
## Состояния:
##   PRAY        — стоит и молится (или на коленях), напевает;
##   WANDER      — бродит по точкам патруля, напевает;
##   ALERT       — услышал: пение обрывается на полуслове, 1,5–2,5 с тишины (только шарканье и ткань) —
##                 главный сигнал игроку «тебя услышали», без значков на экране;
##   INVESTIGATE — идёт к последнему услышанному шуму; пение тихое, обрывками, бормочет;
##   SEARCH      — на месте шума: озирается, принюхивается, обходит рядом search_time секунд, потом назад;
##   CHASE       — шум близко и повторяется (или увидел): идёт быстро, пение громче и сбивается, низкая нота, рык;
##   CATCH       — схватил (уровень показывает «очнулся», scripts/awaken.gd);
##   SCENE       — в катсцене (первый святой бьёт камнем мёртвого).
## Анимация рваная: поза обновляется anim_fps раз в секунду, а сам он движется плавно — как кукла.
## Изредка резко дёргается (twitch). Предметы с физикой не толкает (с ними нет коллизии).

enum State { PRAY, WANDER, ALERT, INVESTIGATE, SEARCH, CHASE, CATCH, SCENE }

const STATE_NAMES := ["PRAY", "WANDER", "ALERT", "INVESTIGATE", "SEARCH", "CHASE", "CATCH", "SCENE"]
## Слой физики святых (4-й бит). Стены видят, героя и предметы — нет.
const LAYER := 4

## Схватил героя.
signal caught_player(saint: Saint)
## Сменилось состояние.
signal state_changed(saint: Saint, state: State)

@export_group("Вид")
## Модель: saint_a — в белом, saint_b — в покрывале, сутулый, ниже.
@export var model := "saint_a"
## Рост (масштаб модели).
@export var height_scale := 1.0
## Сколько крови на одежде и руках, 0…1.
@export_range(0.0, 1.0) var blood := 0.5
## Напев: saint_chant_01 или saint_chant_02 (у каждого свой).
@export var chant := "saint_chant_01"
## Сколько раз в секунду обновляется поза (8–12 — рвано, как кукла; 30 — плавно).
@export var anim_fps := 10.0
## Анимация, когда молится (pray_stand, pray_kneel, kneel_idle…).
@export var pray_anim := "pray_stand"

@export_group("Слух")
## Множитель радиуса шума (1 — как в data/stealth.gd; больше — чутче).
@export var hearing := 1.0
## Шум ближе этого, м, и повторный (за repeat_window с) — погоня.
@export var chase_distance := 7.0
@export var repeat_window := 5.0
## Шум совсем рядом (ближе этого, м) — сразу погоня.
@export var chase_instant := 2.5

@export_group("Зрение")
## Силуэт вплотную спереди, м, и угол от лица, градусы.
@export var sight_close := 1.8
@export var sight_close_angle := 60.0
## Горящий светильник: дальше, м, и угол.
@export var lamp_sight := 6.0
@export var lamp_angle := 70.0
## Схватил, если ближе, м.
@export var catch_distance := 0.85

@export_group("Скорость")
## Бродит, идёт на шум, гонится, м/с. Герой: шаг 2,2, бег 4,6, присед 1,0.
@export var wander_speed := 0.55
@export var investigate_speed := 0.95
@export var chase_speed := 2.7
## Поворот, градусов в секунду.
@export var turn_speed := 150.0
## Если столько секунд почти не двигается, хотя идёт, — бросает цель (застрял в углу).
@export var stuck_time := 2.0

@export_group("Время")
## Тишина после того, как услышал, с.
@export var alert_min := 1.5
@export var alert_max := 2.5
## Сколько ищет на месте шума, с.
@export var search_time := 9.0
## Погоня кончается, если столько секунд ничего не слышно и не видно.
@export var chase_lose_time := 4.0
## Пауза на точке патруля, с.
@export var wander_pause_min := 2.0
@export var wander_pause_max := 6.0
## Резкое дёрганье: раз в столько секунд (в погоне — вдвое чаще).
@export var twitch_min := 3.0
@export var twitch_max := 9.0

@export_group("Звук")
## Громкость напева: обычно, когда ищет, в погоне (дБ, добавка к реестру).
@export var chant_db := 0.0
@export var chant_search_db := -7.0
@export var chant_chase_db := 4.0
## Рык в погоне — раз в столько секунд.
@export var growl_min := 3.0
@export var growl_max := 6.0

var state := State.PRAY
## Где стоит / куда возвращается и куда смотрит; точки патруля (пусто — молится на месте).
var home := Vector3.ZERO
var home_yaw := 0.0
var patrol: Array[Vector3] = []
## С какого состояния начинает (PRAY или WANDER) — для сброса после «очнулся».
var start_state := State.PRAY

var character: CharacterModel
var _agent: NavigationAgent3D
var _target := Vector3.ZERO
var _timer := 0.0
var _search_left := 0.0
var _search_center := Vector3.ZERO
var _stuck := 0.0
var _patrol_i := 0
var _returning := false
var _heard_times: Array[float] = []
var _lose := 0.0
var _vision_timer := 0.0
var _lamp_seen_cool := 0.0
var _twitch_timer := 5.0
var _twitch := 0.0
var _twitch_rot := Vector3.ZERO
var _walked := 0.0
var _steps := 0
var _rustle_every := 2
var _growl_timer := 4.0
var _sniff_timer := 3.0
var _voice_timer := 0.0
var _voice_on := true
var _voice_mode := "normal"
var _chant_pitch := 1.0
var _chant: SoundEmitter
var _mumble: SoundEmitter
var _drone: SoundEmitter
var _label: Label3D
var _player: Player
var _head := -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _moving := false
var _speed := 0.0
# Удар камнем (SCENE)
var _strike := false
var _strike_t := 0.0
var _strike_pause := 0.0
var _strike_angle := 0.0
var _stone: MeshInstance3D
var _bones := {}
var _scene_anim := ""


## Модификатор скелета: удар камнем правой рукой поверх анимации kneel_inspect (готовой анимации нет).
class _Strike:
	extends SkeletonModifier3D
	var saint: Node

	func _process_modification_with_delta(_delta: float) -> void:
		saint._apply_strike()


func _ready() -> void:
	add_to_group("saints")
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1
	_agent = $NavigationAgent3D
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.6
	_agent.avoidance_enabled = false
	character = CharacterModel.new()
	character.name = "Model"
	character.model = model
	add_child(character)
	character.build()
	character.scale = Vector3.ONE * height_scale
	character.mesh_instance.material_override = SaintLook.material(model, blood)
	set_anim_fps(anim_fps)
	var skel := character.skeleton
	_head = skel.find_bone("Head")
	for b in ["RightUpperArm", "RightLowerArm", "RightHand", "RightIndexProximal"]:
		_bones[b] = skel.find_bone(b)
	var mod := _Strike.new()
	mod.saint = self
	skel.add_child(mod)
	_chant_pitch = randf_range(0.92, 1.08)
	_chant = AudioManager.add_emitter(chant, self, Vector3(0.0, 1.55 * height_scale, 0.0))
	_mumble = AudioManager.add_emitter("saint_mumble", self, Vector3(0.0, 1.55 * height_scale, 0.0), {"active": false})
	_drone = AudioManager.add_emitter("saint_drone", self, Vector3(0.0, 1.4 * height_scale, 0.0), {"active": false})
	for em in [_chant, _mumble, _drone]:
		if em:
			em.main.pitch_scale = _chant_pitch
			if em.twin:
				em.twin.pitch_scale = _chant_pitch
	_rustle_every = randi_range(2, 3)
	_twitch_timer = randf_range(twitch_min, twitch_max)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0025
	_label.font_size = 24
	_label.outline_size = 6
	_label.position = Vector3(0.0, 2.1 * height_scale, 0.0)
	_label.visible = NoiseSystem.debug_visible
	add_child(_label)
	NoiseSystem.noise.connect(_on_noise)
	NoiseSystem.debug_changed.connect(func(on: bool) -> void: _label.visible = on)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	_enter(state, true)


## Поставить на место и начать заново (после «очнулся»).
func setup(at: Vector3, yaw: float, points: Array, first_state: State) -> void:
	home = at
	home_yaw = yaw
	patrol.clear()
	for p in points:
		patrol.append(p)
	start_state = first_state
	reset()


func reset() -> void:
	global_position = home
	rotation.y = home_yaw
	velocity = Vector3.ZERO
	_heard_times.clear()
	_patrol_i = 0
	_returning = false
	_strike = false
	if is_inside_tree():
		_enter(start_state, true)
	else:
		state = start_state


## Точка головы в мире (катсцены, слух, зрение).
func head_point() -> Vector3:
	if character and _head >= 0:
		var sk := character.skeleton
		return sk.global_transform * sk.get_bone_global_pose(_head).origin
	return global_position + Vector3.UP * 1.55 * height_scale


## Сколько раз в секунду обновляется поза (панель 0: сравнить 10 / 15 / 30).
func set_anim_fps(v: float) -> void:
	anim_fps = v
	if character and state != State.CATCH:
		character.set_update_interval(1.0 / maxf(anim_fps, 1.0) if anim_fps < 29.5 else 0.0)


func state_name() -> String:
	return STATE_NAMES[state]


# ─── Слух и зрение ───────────────────────────────────────────────────────────

func _on_noise(pos: Vector3, radius: float, _source: String, maker: Object) -> void:
	if maker == self or state == State.CATCH or state == State.SCENE or not is_inside_tree():
		return
	if not NoiseSystem.audible(pos, radius * hearing, head_point(), get_world_3d()):
		return
	hear(pos)


## Услышал шум в точке pos.
func hear(pos: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_heard_times.append(now)
	while not _heard_times.is_empty() and now - _heard_times[0] > repeat_window:
		_heard_times.pop_front()
	var d := global_position.distance_to(pos)
	match state:
		State.PRAY, State.WANDER:
			_target = pos
			_enter(State.ALERT)
		State.ALERT:
			_target = pos
		State.INVESTIGATE, State.SEARCH:
			_target = pos
			if d < chase_instant or (_heard_times.size() >= 2 and d < chase_distance):
				_enter(State.CHASE)
			else:
				_enter(State.INVESTIGATE)
		State.CHASE:
			_target = pos
			_lose = chase_lose_time


func _look(delta: float) -> void:
	_vision_timer -= delta
	_lamp_seen_cool -= delta
	if _vision_timer > 0.0 or _player == null or state == State.CATCH or state == State.SCENE:
		return
	_vision_timer = 0.15
	if _player.locked:
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var fwd := -global_basis.z
	var ang := rad_to_deg(fwd.angle_to(to.normalized())) if d > 0.01 else 0.0
	# Схватить
	if d < catch_distance and (state == State.CHASE or ang < 100.0):
		_enter(State.CATCH)
		return
	# Силуэт вплотную спереди
	if d < sight_close and (ang < sight_close_angle or state == State.CHASE) and _clear_to(_player.global_position + Vector3.UP * 1.2):
		_target = _player.global_position
		if state != State.CHASE:
			_enter(State.CHASE)
		_lose = chase_lose_time
		return
	# Горящий светильник
	if GameState.lamp_out and d < lamp_sight and (ang < lamp_angle or state == State.CHASE) and _lamp_seen_cool <= 0.0 \
			and _clear_to(_player.global_position + Vector3.UP * 1.3):
		_lamp_seen_cool = 1.2 if state != State.CHASE else 0.3
		hear(_player.global_position)


func _clear_to(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(head_point(), p, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ─── Состояния ───────────────────────────────────────────────────────────────

func _enter(s: State, force := false) -> void:
	if s == state and not force:
		return
	var was := state
	state = s
	match s:
		State.PRAY:
			_voice("normal")
		State.WANDER:
			_voice("normal")
			_timer = randf_range(0.5, 2.0)
		State.ALERT:
			# Обрыв на полуслове; в тишине — только шорох ткани и шарканье (повернулся на звук)
			_voice("silent")
			_timer = randf_range(alert_min, alert_max)
			AudioManager.play_3d("cloth_rustle", global_position + Vector3.UP * 1.0, {"db": 2.0})
			get_tree().create_timer(randf_range(0.4, 0.9), false).timeout.connect(func() -> void:
				if state == State.ALERT:
					AudioManager.play_3d("steps_barefoot", global_position + Vector3.UP * 0.05, {"db": -3.0}))
		State.INVESTIGATE:
			_voice("search")
			_agent.target_position = _target
		State.SEARCH:
			_voice("search")
			_search_left = search_time
			_search_center = _target
			_timer = randf_range(1.5, 3.0)
		State.CHASE:
			if was != State.CHASE:
				_voice("chase")
				_growl_timer = randf_range(0.3, 1.0)
			_lose = chase_lose_time
		State.CATCH:
			_voice("silent")
			velocity = Vector3.ZERO
			character.set_update_interval(1.0 / maxf(anim_fps, 1.0))
			character.play("reach_pose", 0.15)
			caught_player.emit(self)
		State.SCENE:
			_voice("scene")
	state_changed.emit(self, state)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	_look(delta)
	var want := Vector3.ZERO
	var speed := 0.0
	match state:
		State.PRAY:
			if _returning or global_position.distance_to(home) > 1.0:
				_returning = true
				want = home
				speed = wander_speed
				if _arrived(home):
					_returning = false
			else:
				_turn_to_yaw(home_yaw, delta)
		State.WANDER:
			if patrol.is_empty():
				_enter(State.PRAY)
			elif _timer > 0.0:
				_timer -= delta
			else:
				want = patrol[_patrol_i]
				speed = wander_speed
				if _arrived(want):
					_patrol_i = (_patrol_i + 1) % patrol.size()
					_timer = randf_range(wander_pause_min, wander_pause_max)
					want = Vector3.ZERO
		State.ALERT:
			_timer -= delta
			_turn_toward(_target, delta, 0.5)
			if _timer <= 0.0:
				var d := global_position.distance_to(_target)
				if d < chase_instant or (_heard_times.size() >= 2 and d < chase_distance):
					_enter(State.CHASE)
				else:
					_enter(State.INVESTIGATE)
		State.INVESTIGATE:
			want = _target
			speed = investigate_speed
			if _arrived(_target):
				_enter(State.SEARCH)
		State.SEARCH:
			_search_left -= delta
			_timer -= delta
			if _timer <= 0.0:
				# Шаг-другой в сторону: обходит место шума
				_target = _random_near(_search_center, 3.0)
				_timer = randf_range(3.0, 5.0)
			if global_position.distance_to(_target) > 0.8:
				want = _target
				speed = investigate_speed * 0.7
			if _search_left <= 0.0:
				_returning = true
				_enter(start_state if patrol.is_empty() else State.WANDER)
		State.CHASE:
			_lose -= delta
			if _player and global_position.distance_to(_player.global_position) < sight_close * 1.4:
				_target = _player.global_position
			want = _target
			speed = chase_speed
			if _lose <= 0.0:
				_enter(State.INVESTIGATE)
		State.CATCH, State.SCENE:
			velocity.x = 0.0
			velocity.z = 0.0
	_move(want, speed, delta)
	_update_twitch(delta)
	_update_anim(speed)
	_update_sounds(delta)
	_report_threat()
	if _label.visible:
		_label.text = STATE_NAMES[state]
		_label.modulate = [Color.WHITE, Color.WHITE, Color.YELLOW, Color.ORANGE, Color.ORANGE, Color.RED, Color.RED,
			Color.GRAY][state]


func _arrived(p: Vector3) -> bool:
	var d := global_position - p
	d.y = 0.0
	return d.length() < 0.7 or (_agent.is_navigation_finished() and _agent.target_position.distance_to(p) < 0.1
		and d.length() < 2.0)


func _move(want: Vector3, speed: float, delta: float) -> void:
	_moving = false
	if speed <= 0.0 or _twitch > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		move_and_slide()
		_speed = Vector2(velocity.x, velocity.z).length()
		return
	if _agent.target_position.distance_to(want) > 0.3:
		_agent.target_position = want
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		# Пути нет (навмеш ещё не готов или точка вне его) — прямо
		dir = want - global_position
		dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_turn_toward(global_position + dir, delta, 1.0)
		_moving = true
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 1e-4)
	_speed = moved
	_walked += moved * delta
	# Застрял (угол, предмет): через stuck_time — бросить эту цель
	if moved < speed * 0.2:
		_stuck += delta
		if _stuck > stuck_time:
			_stuck = 0.0
			_unstick()
	else:
		_stuck = 0.0


## Застрял: в патруле — к следующей точке, в поиске — новое место рядом, в погоне — подождать.
func _unstick() -> void:
	match state:
		State.WANDER:
			if not patrol.is_empty():
				_patrol_i = (_patrol_i + 1) % patrol.size()
		State.INVESTIGATE:
			_enter(State.SEARCH)
		State.SEARCH:
			_timer = 0.0
		State.PRAY:
			global_position = home
			_returning = false


func _turn_toward(p: Vector3, delta: float, k: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length_squared() < 1e-4:
		return
	_turn_to_yaw(atan2(-d.x, -d.z), delta * k)


func _turn_to_yaw(yaw: float, delta: float) -> void:
	var diff := wrapf(yaw - rotation.y, -PI, PI)
	var step := deg_to_rad(turn_speed) * delta
	rotation.y += clampf(diff, -step, step)


func _random_near(p: Vector3, r: float) -> Vector3:
	var a := randf() * TAU
	var q := p + Vector3(cos(a), 0.0, sin(a)) * randf_range(r * 0.4, r)
	var map := get_world_3d().navigation_map
	var c := NavigationServer3D.map_get_closest_point(map, q)
	return c if c != Vector3.ZERO else p


## Резкое дёрганье: на миг замер и дёрнулся (голова, корпус), потом снова как ни в чём не бывало.
func _update_twitch(delta: float) -> void:
	if state == State.CATCH:
		return
	_twitch_timer -= delta * (2.0 if state == State.CHASE else 1.0)
	if _twitch > 0.0:
		_twitch -= delta
		if _twitch <= 0.0:
			character.rotation = Vector3.ZERO
	elif _twitch_timer <= 0.0:
		_twitch_timer = randf_range(twitch_min, twitch_max)
		_twitch = randf_range(0.12, 0.3)
		character.rotation = Vector3(randf_range(-0.12, 0.12), randf_range(-0.45, 0.45), randf_range(-0.1, 0.1))
		AudioManager.play_3d("cloth_rustle", global_position + Vector3.UP, {"db": -2.0})


func _update_anim(speed: float) -> void:
	if state == State.CATCH:
		if character.current == "reach_pose" and _timer <= 0.0:
			pass
		return
	if state == State.SCENE:
		if _scene_anim != "":
			character.play(_scene_anim, 0.2)
		return
	if _moving:
		var a := "walk_slow"
		if state == State.CHASE:
			a = "walk_injured_fast"
		elif state == State.INVESTIGATE or state == State.SEARCH:
			a = "walk_calm"
		character.play(a, 0.25, clampf(Anims.scale_for(a, maxf(speed, 0.2)), 0.5, 2.2))
	else:
		var a := "idle_old"
		match state:
			State.PRAY:
				a = pray_anim
			State.SEARCH:
				a = "look_around"
			State.ALERT:
				a = "idle_old"
			State.WANDER:
				a = "pray_stand"
		character.play(a, 0.3)


# ─── Звук ────────────────────────────────────────────────────────────────────

## Голос по состоянию: normal — напев; silent — тишина; search — тихо, обрывками + бормотание;
## chase — громче, сбивается, низкая нота; scene — бормочет над телом.
func _voice(mode: String) -> void:
	_voice_mode = mode
	_voice_timer = 0.0
	match mode:
		"normal":
			_set_em(_chant, true, chant_db, _chant_pitch)
			_set_em(_mumble, false)
			_set_em(_drone, false)
		"silent":
			_set_em(_chant, false)
			_set_em(_mumble, false)
			_set_em(_drone, false)
		"search":
			_voice_on = false
			_voice_timer = randf_range(0.6, 1.5)
			_set_em(_chant, false)
			_set_em(_mumble, false)
			_set_em(_drone, false)
		"chase":
			_set_em(_chant, true, chant_chase_db, _chant_pitch)
			_set_em(_mumble, false)
			_set_em(_drone, true, 0.0, _chant_pitch)
		"scene":
			_set_em(_chant, false)
			_set_em(_mumble, true, -8.0, _chant_pitch * 0.94)
			_set_em(_drone, false)


func _set_em(em: SoundEmitter, on: bool, db := 0.0, pitch := 1.0) -> void:
	if em == null:
		return
	if on:
		em.volume_db = db
		em.main.pitch_scale = pitch
		if em.twin:
			em.twin.pitch_scale = pitch
		em._apply()
		if not em.is_active() or not em.is_playing():
			em.set_active(true)
	elif em.is_active():
		em.set_active(false)


func _update_sounds(delta: float) -> void:
	# Шаги и шорох ткани
	var step_len := 0.85 if state == State.CHASE else 0.6
	if _walked >= step_len:
		_walked -= step_len
		_steps += 1
		AudioManager.play_3d("steps_barefoot", global_position + Vector3.UP * 0.05,
			{"db": 2.0 if state == State.CHASE else 0.0})
		if _steps % _rustle_every == 0:
			_rustle_every = randi_range(2, 3)
			AudioManager.play_3d("cloth_rustle", global_position + Vector3.UP * 1.0)
	match _voice_mode:
		"search":
			# Тихо, обрывками: то напев, то бормотание, то тишина; изредка принюхивается
			_voice_timer -= delta
			if _voice_timer <= 0.0:
				_voice_on = not _voice_on
				if _voice_on:
					_voice_timer = randf_range(1.5, 3.5)
					if randf() < 0.55:
						_set_em(_chant, true, chant_search_db, _chant_pitch * randf_range(0.97, 1.0))
						if _chant and _chant.is_playing():
							_chant.main.seek(randf() * 40.0)
					else:
						_set_em(_mumble, true, -4.0, _chant_pitch)
				else:
					_voice_timer = randf_range(1.0, 3.0)
					_set_em(_chant, false)
					_set_em(_mumble, false)
			_sniff_timer -= delta
			if _sniff_timer <= 0.0:
				_sniff_timer = randf_range(4.0, 8.0)
				AudioManager.play_3d("saint_sniff", head_point())
		"chase":
			# Громче и сбивается: высота плывёт, напев срывается и начинается с другого места; рык
			if _chant:
				var p := _chant_pitch * (1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.0031) + 0.03 * sin(Time.get_ticks_msec() * 0.0117))
				_chant.main.pitch_scale = p
				if _chant.twin:
					_chant.twin.pitch_scale = p
			_voice_timer -= delta
			if _voice_timer <= 0.0:
				_voice_timer = randf_range(1.5, 3.5)
				if _chant and _chant.is_playing():
					var at := randf() * 40.0
					_chant.main.seek(at)
					if _chant.twin:
						_chant.twin.seek(at)
			_growl_timer -= delta
			if _growl_timer <= 0.0:
				_growl_timer = randf_range(growl_min, growl_max)
				AudioManager.play_3d("saint_growl", head_point())


func _report_threat() -> void:
	match state:
		State.PRAY, State.WANDER:
			ThreatDirector.report_threat(global_position, 0.3, 10.0, self)
		State.ALERT, State.INVESTIGATE, State.SEARCH:
			ThreatDirector.report_threat(global_position, 0.6, 16.0, self)
		State.CHASE, State.CATCH:
			ThreatDirector.report_threat(global_position, 1.0, 22.0, self)


# ─── Схватил ─────────────────────────────────────────────────────────────────

## Схватил: тянется (reach_pose), потом валит и держит (hold_down). Вызывает «очнулся» (scripts/awaken.gd).
func play_hold() -> void:
	character.set_update_interval(1.0 / maxf(anim_fps, 1.0))
	character.play("hold_down", 0.2, 1.0, true)


# ─── Первый святой: удар камнем (катсцена, CLAUDE.md §3) ──────────────────────

## Стоит на коленях над телом и бьёт его камнем, снова и снова. victim — куда бить.
func start_strikes() -> void:
	_enter(State.SCENE)
	_scene_anim = "kneel_inspect"
	character.play("kneel_inspect", 0.0)
	_strike = true
	_strike_t = 0.0
	_strike_pause = randf_range(0.3, 1.0)
	if _stone == null:
		_stone = MeshInstance3D.new()
		_stone.mesh = PropLibrary.mesh("stone_held")
		_stone.material_override = PropLibrary.material()
		add_child(_stone)
		_stone.top_level = true


## Точка камня в руке (катсцена: вставка «камень в руке»).
func stone_point() -> Vector3:
	return _stone.global_position if _stone else head_point()


## Встать и уйти вглубь (после катсцены): встаёт, потом бродит по патрулю.
func stand_and_leave() -> void:
	_strike = false
	_scene_anim = "kneel_stand_up"
	character.play("kneel_stand_up", 0.15, 1.0, true)
	await get_tree().create_timer(2.2).timeout
	if state != State.SCENE:
		return
	character.reset_motion()
	_scene_anim = ""
	start_state = State.WANDER
	_enter(State.WANDER, true)
	_timer = 0.0


func _process(delta: float) -> void:
	if not _strike:
		return
	_strike_t += delta
	var period := 0.45 + 0.1 + 0.09 + 0.35
	if _strike_t >= period + _strike_pause:
		_strike_t = 0.0
		_strike_pause = randf_range(1.5, 4.0) if randf() < 0.55 else randf_range(0.2, 0.6)
	var was := _strike_angle
	# Рывками: угол обновляется с частотой позы
	var t := snappedf(_strike_t, 1.0 / maxf(anim_fps, 1.0))
	if t < 0.45:
		_strike_angle = smoothstep(0.0, 0.45, t)
	elif t < 0.55:
		_strike_angle = 1.0
	elif t < 0.64:
		_strike_angle = 1.0 - (t - 0.55) / 0.09
	else:
		_strike_angle = 0.0
	if was > 0.2 and _strike_angle <= 0.0 and t < 0.7:
		AudioManager.play_3d("hit_wet", stone_point(), {"db": 2.0})


## Из модификатора скелета: поднять правую руку на угол и камень — в кисть.
func _apply_strike() -> void:
	if _stone == null or not _stone.visible:
		return
	var skel := character.skeleton
	if _strike and _strike_angle > 0.0:
		var right := skel.global_basis.inverse() * (global_basis * Vector3.RIGHT)
		right = right.normalized()
		var ua: int = _bones.RightUpperArm
		var g := skel.get_bone_global_pose(ua)
		var rot := Basis(right, deg_to_rad(125.0) * _strike_angle)
		var pg := skel.get_bone_global_pose(skel.get_bone_parent(ua))
		skel.set_bone_pose_rotation(ua, (pg.basis.orthonormalized().inverse() * rot * g.basis.orthonormalized()).get_rotation_quaternion())
		var fa: int = _bones.RightLowerArm
		skel.set_bone_pose_rotation(fa, skel.get_bone_pose_rotation(fa) * Quaternion(Vector3.RIGHT, deg_to_rad(-35.0) * _strike_angle))
	var h := skel.get_bone_global_pose(_bones.RightHand)
	var f := skel.get_bone_global_pose(_bones.RightIndexProximal)
	var at := skel.global_transform * h.origin.lerp(f.origin, 0.8)
	_stone.global_transform = Transform3D(skel.global_basis.orthonormalized() * h.basis.orthonormalized(), at)
