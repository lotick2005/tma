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
## Ходит плавно, как живой (поза — каждый кадр); жуть — в редком резком рывке головы и плеч (twitch, раз в 5–12 с).
## Предметы с физикой не толкает (с ними нет коллизии).
## Не застревает: путь — по навмешу без срезания углов, вдоль стены скользит; не продвинулся за stuck_time —
## перестраивает путь, не помогло — бросает цель и возвращается на ближайшую точку патруля (_give_up).

enum State { PRAY, WANDER, ALERT, INVESTIGATE, SEARCH, CHASE, CATCH, SCENE }

const STATE_NAMES := ["PRAY", "WANDER", "ALERT", "INVESTIGATE", "SEARCH", "CHASE", "CATCH", "SCENE"]
## Слой физики святых (4-й бит). Стены видят, героя и предметы — нет.
const LAYER := 4

## Схватил героя.
signal caught_player(saint: Saint)
## Сменилось состояние.
signal state_changed(saint: Saint, state: State)

@export_group("Вид")
## Модель: saint_a — в белом с повязкой. (saint_b ниже на 24 см и не по скелету анимаций — не использовать.)
@export var model := "saint_a"
## Рост — только общий масштаб модели, 0,95…1,05 (CLAUDE.md §4: модели не искажать).
@export_range(0.95, 1.05) var height_scale := 1.0
## Сколько крови на одежде и руках, 0…1.
@export_range(0.0, 1.0) var blood := 0.5
## Напев: saint_chant_01 или saint_chant_02 (у каждого свой).
@export var chant := "saint_chant_01"
## Сколько раз в секунду обновляется поза: 30 и больше — каждый кадр, плавно (так и надо);
## меньше — рвано (пробовали: выглядит как лаг). Ползунок — в панели (0).
@export var anim_fps := 30.0
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
## Стоит на посту и не сходит с места на стук предметов (святой у молельни, полировка демо 5): упал или разбился
## предмет — резко поворачивает голову на звук и замолкает на startle_min…startle_max с, потом снова поёт.
## Шаги слышит как обычно (hearing). Слух на стук — object_hearing (множитель радиуса шума предмета).
@export var hold_ground := false
@export var object_hearing := 1.0
@export var startle_min := 2.0
@export var startle_max := 3.0

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
## Погоня (полировка демо 3): чуть ниже бега героя (4,6) — за 5 с бега (выносливость) отрываешься на ~5 м;
## дальше спасает укрытие без света (hide_time).
@export var chase_speed := 3.6
## Поворот, градусов в секунду.
@export var turn_speed := 150.0
## Столько секунд идёт, но почти не продвинулся — перестраивает путь; ещё столько же — бросает цель
## и возвращается на ближайшую точку патруля.
@export var stuck_time := 1.2

@export_group("Время")
## Тишина после того, как услышал, с.
@export var alert_min := 1.5
@export var alert_max := 2.5
## Сколько ищет на месте шума (или у последней точки, где слышал героя в погоне), с: случайно от min до этого.
@export var search_time := 8.0
@export var search_time_min := 6.0
## Погоня кончается, если столько секунд ничего не слышно и не видно.
@export var chase_lose_time := 3.0
## Укрылся (полировка демо 3): светильник убран, святой не видит героя (стена, проём, ящик между головой святого
## и героем) столько секунд — погоня прерывается: замирает и слушает (alert_min…alert_max), потом идёт к последней
## точке, где слышал, ищет search_time и уходит. Шаг, услышанный в погоне, сбрасывает счёт.
@export var hide_time := 0.8
## Пауза на точке патруля, с.
@export var wander_pause_min := 2.0
@export var wander_pause_max := 6.0
## Рывок головы и плеч: раз в столько секунд (в погоне — вдвое чаще).
@export var twitch_min := 5.0
@export var twitch_max := 12.0

@export_group("Звук")
## Громкость напева: обычно, когда ищет, в погоне (дБ, добавка к реестру).
@export var chant_db := 0.0
@export var chant_search_db := -7.0
@export var chant_chase_db := 2.0
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
var _stuck_from := Vector3.ZERO
var _stuck_count := 0
var _repath := false
## Стена, в которую упёрся (нормаль), сколько её ещё помнить, и в какую сторону обходить, если упёрся лбом.
var _wall_n := Vector3.ZERO
var _wall_t := 0.0
var _side := 1.0
## Когда последний раз слышал шаги героя (в погоне идёт прямо на него, пока слышит), с.
var _step_heard := -100.0
var _patrol_i := 0
var _returning := false
var _heard_times: Array[float] = []
var _lose := 0.0
var _hidden := 0.0
## Погоня прервана укрытием: после тишины (ALERT) — к последней точке (INVESTIGATE), а не снова в погоню.
var _lost_hidden := false
var _vision_timer := 0.0
var _lamp_seen_cool := 0.0
var _twitch_timer := 5.0
var _twitch := 0.0
var _twitch_rot := Vector3.ZERO
var _twitch_w := 0.0
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
## Удар: доля IK руки поверх анимации (0 — рука из анимации), сколько ударов до паузы (−1 — без пауз: катсцена),
## толчок корпуса вперёд в момент удара (затухает).
var _strike_w := 0.0
var _strike_left := 3
var _strike_steady := false
var _strike_jolt := 0.0
## Катсцена: повернуть голову к точке (доля 0…1).
var _scene_look := Vector3.ZERO
var _scene_look_on := false
var _scene_look_w := 0.0
var _head_fwd_l := Vector3.BACK
var _bones := {}
var _scene_anim := ""
## Вздрогнул на стук (hold_ground): сколько ещё молчит и смотрит, куда повернул голову (мир), доля поворота 0…1.
var _startle := 0.0
var _startle_at := Vector3.ZERO
var _startle_w := 0.0


## Модификатор скелета: удар камнем правой рукой поверх анимации kneel_inspect (готовой анимации нет).
class _Strike:
	extends SkeletonModifier3D
	var saint: Node

	func _process_modification_with_delta(_delta: float) -> void:
		saint._apply_pose()


func _ready() -> void:
	add_to_group("saints")
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1
	_agent = $NavigationAgent3D
	# Точку пути считает пройденной только вплотную: иначе срезает угол и упирается в стену
	# (запас навмеша до стены — 0,25 м, а раньше поворачивал за 0,5 м до угла)
	_agent.path_desired_distance = 0.2
	_agent.target_desired_distance = 0.5
	height_scale = clampf(height_scale, 0.95, 1.05)
	_agent.avoidance_enabled = false
	character = CharacterModel.new()
	character.name = "Model"
	character.model = model
	add_child(character)
	character.build()
	character.scale = Vector3.ONE * height_scale
	character.mesh_instance.material_override = SaintLook.material(model, blood)
	BlobShadow.attach(self, Vector2(0.6, 0.5) * height_scale)
	set_anim_fps(anim_fps)
	var skel := character.skeleton
	_head = skel.find_bone("Head")
	for b in ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "RightIndexProximal", "Spine", "Neck", "UpperChest"]:
		_bones[b] = skel.find_bone(b)
	# Лицо модели — +Z скелета
	_head_fwd_l = (skel.get_bone_global_rest(_head).basis.inverse() * Vector3.BACK).normalized()
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


## Полностью вернуть к началу: место, состояние, слух, зрение, таймеры, цель, поза, звук.
func reset() -> void:
	global_position = home
	rotation.y = home_yaw
	velocity = Vector3.ZERO
	_heard_times.clear()
	_step_heard = -100.0
	_target = home
	_timer = 0.0
	_search_left = 0.0
	_search_center = home
	_lose = 0.0
	_hidden = 0.0
	_lost_hidden = false
	_stuck = 0.0
	_stuck_from = home
	_stuck_count = 0
	_repath = true
	_wall_n = Vector3.ZERO
	_wall_t = 0.0
	_patrol_i = 0
	_returning = false
	_vision_timer = 0.0
	_lamp_seen_cool = 0.0
	_twitch = 0.0
	_twitch_w = 0.0
	_twitch_timer = randf_range(twitch_min, twitch_max)
	_walked = 0.0
	_growl_timer = 4.0
	_sniff_timer = 3.0
	_moving = false
	_speed = 0.0
	_strike = false
	_strike_w = 0.0
	_strike_angle = 0.0
	_strike_jolt = 0.0
	_scene_look_on = false
	_scene_look_w = 0.0
	_scene_anim = ""
	_startle = 0.0
	_startle_w = 0.0
	if not is_inside_tree():
		state = start_state
		return
	# Поза: после «схватил» (hold_down) модель сдвинута root motion и сидит на корточках — вернуть сразу
	state = start_state
	character.rotation = Vector3.ZERO
	set_anim_fps(anim_fps)
	character.play("idle_old", 0.0, 1.0, true)
	character.reset_motion()
	_agent.target_position = home
	_enter(start_state, true)


## Точка головы в мире (катсцены, слух, зрение).
func head_point() -> Vector3:
	if character and _head >= 0:
		var sk := character.skeleton
		return sk.global_transform * sk.get_bone_global_pose(_head).origin
	return global_position + Vector3.UP * 1.55 * height_scale


## Сколько раз в секунду обновляется поза (панель 0: сравнить 10 / 15 / 30).
func set_anim_fps(v: float) -> void:
	anim_fps = v
	if character:
		character.set_update_interval(1.0 / maxf(anim_fps, 1.0) if anim_fps < 29.5 else 0.0)


func state_name() -> String:
	return STATE_NAMES[state]


# ─── Слух и зрение ───────────────────────────────────────────────────────────

func _on_noise(pos: Vector3, radius: float, source: String, maker: Object) -> void:
	if maker == self or state == State.CATCH or state == State.SCENE or not is_inside_tree():
		return
	if hold_ground and source != "step" and state == State.PRAY:
		if _hears(pos, radius * object_hearing):
			_startle_on(pos)
		return
	if not _hears(pos, radius * hearing):
		return
	if source == "step":
		_step_heard = Time.get_ticks_msec() / 1000.0
	hear(pos)


## Слышно ли: по земле ближе радиуса (высота не в счёт — шаг в 4 м слышен всегда), а за стеной — ближе
## радиус × WALL_FACTOR (шаг — 2 м). Стена — луч на высоте пояса: кувшин или стол между ними не глушат.
func _hears(pos: Vector3, radius: float) -> bool:
	var ear := head_point()
	var d := Vector2(pos.x - ear.x, pos.z - ear.z).length()
	if d > radius or absf(pos.y - global_position.y) > maxf(radius, 3.0):
		return false
	if d <= radius * NoiseSystem.S.WALL_FACTOR:
		return true
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, ear, NoiseSystem.WALL_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Стук предмета, а он на посту: голова — рывком к звуку, напев обрывается; с места не сходит.
func _startle_on(pos: Vector3) -> void:
	if _startle <= 0.0:
		_voice("silent")
		AudioManager.play_3d("cloth_rustle", global_position + Vector3.UP * 1.0, {"db": 2.0})
	_startle = randf_range(startle_min, startle_max)
	_startle_at = pos + Vector3.UP * 0.3


func _update_startle(delta: float) -> void:
	if _startle <= 0.0:
		_startle_w = move_toward(_startle_w, 0.0, delta / 0.6)
		return
	# Рывок — за 0,1 с (жуть в резкости), назад — медленно
	_startle_w = move_toward(_startle_w, 1.0, delta / 0.1)
	_startle -= delta
	if _startle <= 0.0 or state != State.PRAY:
		_startle = 0.0
		if state == State.PRAY:
			_voice("normal")


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
			# Услышал — значит, не затаился: укрытие считается заново
			_hidden = 0.0


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
	if d < catch_distance and absf(_player.global_position.y - global_position.y) < 1.2 and not Awaken.busy \
			and (state == State.CHASE or ang < 100.0):
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


## Укрылся: светильник убран и между головой святого и героем (на высоте груди: стоя или в приседе) — стена,
## край проёма или ящик (один луч за кадр, только в погоне).
func _player_hidden() -> bool:
	if _player == null or GameState.lamp_out:
		return false
	var chest := _player.global_position + Vector3.UP * (0.9 if _player.is_crouched() else 1.3)
	return not _clear_to(chest)


func _clear_to(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(head_point(), p, 1)
	# Сам герой — тоже тело на слое стен: без исключения луч всегда упирался в него, и святые не видели совсем
	if _player:
		q.exclude = [_player.get_rid()]
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
			_search_left = randf_range(minf(search_time_min, search_time), search_time)
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
	var direct := false
	match state:
		State.PRAY:
			if _returning or global_position.distance_to(home) > 1.0:
				_returning = true
				want = home
				speed = wander_speed
				if _arrived(home) or _nav_done(home):
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
				if _arrived(want) or _nav_done(want):
					_patrol_i = (_patrol_i + 1) % patrol.size()
					_timer = randf_range(wander_pause_min, wander_pause_max)
					want = Vector3.ZERO
		State.ALERT:
			_timer -= delta
			_turn_toward(_target, delta, 0.5)
			if _timer <= 0.0:
				var d := global_position.distance_to(_target)
				if _lost_hidden:
					_lost_hidden = false
					_enter(State.INVESTIGATE)
				elif d < chase_instant or (_heard_times.size() >= 2 and d < chase_distance):
					_enter(State.CHASE)
				else:
					_enter(State.INVESTIGATE)
		State.INVESTIGATE:
			want = _target
			speed = investigate_speed
			if _arrived(_target) or _nav_done(_target):
				# Дошёл (или ближе не подойти: шум за стеной, в запертом доме) — ищет здесь
				_target = global_position
				_enter(State.SEARCH)
		State.SEARCH:
			_search_left -= delta
			_timer -= delta
			if _timer <= 0.0:
				# Шаг-другой в сторону: обходит место шума
				_target = _random_near(_search_center, 3.0)
				_timer = randf_range(3.0, 5.0)
			if not _arrived(_target) and not _nav_done(_target):
				want = _target
				speed = investigate_speed * 0.7
			if _search_left <= 0.0:
				_go_back()
		State.CHASE:
			_lose -= delta
			var hid := _player_hidden()
			_hidden = _hidden + delta if hid else 0.0
			# Вплотную чует; пока слышит шаги — идёт прямо на героя, а не на место прошлого шага.
			# Укрывшегося без света «вплотную» не чует: только если услышал шаг
			if _player and not _player.locked and ((not hid and global_position.distance_to(_player.global_position) < sight_close * 1.4)
					or Time.get_ticks_msec() / 1000.0 - _step_heard < 1.0):
				_target = _player.global_position
			if not _arrived(_target):
				if not _nav_done(_target):
					want = _target
					speed = chase_speed
				elif _player and _target.distance_to(_player.global_position) < 0.3 \
						and global_position.distance_to(_target) < 5.0 and _clear_to(_target + Vector3.UP * 1.2):
					# Путь по навмешу кончился, а герой рядом и на виду (встал там, куда навмеш не достаёт) — прямо на него
					want = _target
					speed = chase_speed
					direct = true
			if _hidden >= hide_time:
				_hidden = 0.0
				_heard_times.clear()
				_lost_hidden = true
				_enter(State.ALERT)
			elif _lose <= 0.0:
				_enter(State.INVESTIGATE)
		State.CATCH, State.SCENE:
			velocity.x = 0.0
			velocity.z = 0.0
	_move(want, speed, delta, direct)
	_update_startle(delta)
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
	return d.length() < 0.7


## Путь к точке p кончился (дошёл до конца пути; сама точка может быть недостижима — за стеной).
func _nav_done(p: Vector3) -> bool:
	return _nav_ready() and _agent.target_position.distance_to(p) < 0.3 and _agent.is_navigation_finished()


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


## Идти к точке want по навмешу (direct — напрямик, мимо навмеша) со скоростью speed; 0 — стоять.
func _move(want: Vector3, speed: float, delta: float, direct := false) -> void:
	_moving = false
	_wall_t -= delta
	if speed <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		move_and_slide()
		_speed = Vector2(velocity.x, velocity.z).length()
		_stuck = 0.0
		_stuck_count = 0
		_stuck_from = global_position
		return
	if _repath or _agent.target_position.distance_to(want) > 0.3:
		_repath = false
		_agent.target_position = want
	var dir := Vector3.ZERO
	if direct or not _nav_ready():
		# Напрямик (или навмеш ещё не готов)
		dir = want - global_position
	elif not _agent.is_navigation_finished():
		dir = _agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() > 0.02:
		dir = dir.normalized()
		# Упёрся в стену или предмет, которого нет в навмеше: не давит в неё, а идёт вдоль — в ту сторону, куда ведёт путь
		if _wall_t > 0.0 and dir.dot(_wall_n) < -0.02:
			var along := dir.slide(_wall_n)
			if along.length() < 0.05:
				along = _wall_n.cross(Vector3.UP) * _side
			dir = along.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_turn_toward(global_position + dir, delta, 1.0)
		_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	var before := global_position
	move_and_slide()
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		if n.length() > 0.3:
			_wall_n = n.normalized()
			_wall_t = 0.3
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 1e-4)
	_speed = moved
	_walked += moved * delta
	# Застрял? Раз в stuck_time: прошёл меньше четверти того, что должен был, — сначала перестроить путь,
	# не помогло — бросить цель (_give_up)
	_stuck += delta
	if _stuck >= stuck_time:
		var gone := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
		if gone < speed * _stuck * 0.25:
			_stuck_count += 1
			if _stuck_count == 1:
				_repath = true
				_side = -_side
			else:
				_give_up()
		else:
			_stuck_count = 0
		_stuck = 0.0
		_stuck_from = global_position


## Путь перестроил — не помогло. Бросает цель: в патруле — на ближайшую другую точку, шёл на шум или гнался —
## ищет там, где стоит, потом вернётся; искал — другое место рядом. Совсем никак (третий раз подряд) —
## встаёт на ближайшее место навмеша, а если шёл домой и герой далеко — оказывается дома.
func _give_up() -> void:
	_repath = true
	_wall_t = 0.0
	if _stuck_count >= 3:
		var map := _agent.get_navigation_map()
		var c := NavigationServer3D.map_get_closest_point(map, global_position)
		if _nav_ready() and c.distance_to(global_position) < 1.5:
			global_position = c
		if state == State.PRAY and (_player == null or _player.global_position.distance_to(global_position) > 15.0):
			global_position = home
			_returning = false
		_stuck_count = 0
	match state:
		State.WANDER:
			_patrol_i = _nearest_patrol(_patrol_i)
		State.INVESTIGATE, State.CHASE:
			_target = global_position
			_enter(State.SEARCH)
		State.SEARCH:
			_search_center = global_position
			_target = global_position
			_timer = 0.0


## Ближайшая точка патруля (кроме skip — той, к которой не смог пройти).
func _nearest_patrol(skip := -1) -> int:
	var best := maxi(skip, 0)
	var best_d := INF
	for i in patrol.size():
		if i == skip and patrol.size() > 1:
			continue
		var d := global_position.distance_to(patrol[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Поискал — назад: молиться на место или в патруль с ближайшей точки.
func _go_back() -> void:
	_returning = true
	_heard_times.clear()
	if patrol.is_empty():
		_enter(start_state)
	else:
		_patrol_i = _nearest_patrol()
		_enter(State.WANDER)


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


## Рывок: голова и плечи резко дёргаются в сторону и возвращаются (кости, а не вся модель); идти не перестаёт.
func _update_twitch(delta: float) -> void:
	if state == State.CATCH or state == State.SCENE:
		_twitch = 0.0
		_twitch_w = 0.0
		return
	_twitch_timer -= delta * (2.0 if state == State.CHASE else 1.0)
	if _twitch > 0.0:
		_twitch -= delta
		_twitch_w = move_toward(_twitch_w, 1.0, delta / 0.05)
	else:
		_twitch_w = move_toward(_twitch_w, 0.0, delta / 0.14)
		if _twitch_timer <= 0.0:
			_twitch_timer = randf_range(twitch_min, twitch_max)
			_twitch = randf_range(0.12, 0.3)
			var side := -1.0 if randf() < 0.5 else 1.0
			_twitch_rot = Vector3(randf_range(-0.15, 0.1), side * randf_range(0.35, 0.7), -side * randf_range(0.1, 0.35))
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
			_set_em(_mumble, true, -14.0, _chant_pitch * 0.94)
			_set_em(_drone, false)


func _set_em(em: SoundEmitter, on: bool, db := 0.0, pitch := 1.0) -> void:
	if em == null:
		return
	if on:
		em.volume_db = db
		em.main.pitch_scale = pitch
		if em.twin:
			em.twin.pitch_scale = pitch
		em.apply()
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
							_chant.seek(randf() * 40.0)
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
					_chant.seek(randf() * 40.0)
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
	character.play("hold_down", 0.2, 1.0, true)


# ─── Первый святой: удар камнем (катсцена, CLAUDE.md §3) ──────────────────────

## Удар камнем — замах и падение руки, с: поднимает STRIKE_RAISE, держит наверху STRIKE_TOP, бьёт за STRIKE_FALL,
## рука лежит на теле до конца STRIKE_PERIOD (один удар в ~1,5 с). На каждый удар — hit_wet.
## Полировка демо 5: поза — kneel_fix (Quaternius «Fixing_Kneeling»: на коленях, руки у земли), отрезок, где он
## стоит на коленях (STRIKE_BASE_FROM…TO, туда-обратно); замах правой — кости руки из sword_attack (удар сверху):
## от начала до верха замаха SWING_TOP, падение — до SWING_HIT. Камень падает на голову лежащего (strike_target):
## на падении рука доводится IK до головы, корпус подаётся вперёд и вниз (STRIKE_REACH_LEAN).
const STRIKE_PERIOD := 1.5
const STRIKE_RAISE := 0.6
const STRIKE_TOP := 0.2
const STRIKE_FALL := 0.11
## Кисть с камнем от плеча (в осях святого: вправо, вверх, назад), м: наверху — над головой и чуть за ней,
## внизу — на теле перед коленями.
const STRIKE_HAND_TOP := Vector3(0.14, 0.5, 0.1)
const STRIKE_HAND_DOWN := Vector3(-0.05, -0.42, -0.5)
## Корпус откидывается назад на замахе и подаётся вперёд на ударе, град.
const STRIKE_LEAN_BACK := 12.0
const STRIKE_LEAN_HIT := 9.0
const STRIKE_BASE := "kneel_fix"
const STRIKE_BASE_FROM := 1.1
const STRIKE_BASE_TO := 3.7
const STRIKE_SWING := "sword_attack"
const SWING_TOP := 0.26
const SWING_HIT := 0.47
const SWING_BONES := ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
## Наклон корпуса вперёд, когда камень у головы лежащего, град.
const STRIKE_REACH_LEAN := 22.0
## Куда падает камень (голова жертвы, мир); ZERO — рука идёт по старой дуге (STRIKE_HAND_*).
var strike_target := Vector3.ZERO
## Фаза удара: 0 — замах, 1 — наверху, 2 — падает, 3 — лежит на голове; доля фазы 0…1.
var _strike_phase := 3
var _strike_k := 1.0
var _swing_tracks := {}
var _base_dir := 1.0
## Последнее смещение камня от кисти (мир) — чтобы к голове шёл камень, а не запястье.
var _stone_off := Vector3.ZERO

## Стоит на коленях над телом и бьёт его камнем, снова и снова: два-четыре удара, пауза, ещё.
func start_strikes() -> void:
	_enter(State.SCENE)
	_scene_anim = STRIKE_BASE
	character.play(STRIKE_BASE, 0.0)
	character.anim.seek(STRIKE_BASE_FROM, true)
	_base_dir = 1.0
	if _swing_tracks.is_empty():
		var sw := Anims.library().get_animation(STRIKE_SWING)
		for b: String in SWING_BONES:
			var ti := sw.find_track(NodePath("%GeneralSkeleton:" + b), Animation.TYPE_ROTATION_3D)
			if ti >= 0:
				_swing_tracks[b] = ti
	# Здесь поза всегда плавная (и при малом anim_fps из панели): рука с камнем идёт каждый кадр
	character.set_update_interval(0.0)
	_strike = true
	_strike_steady = false
	_strike_t = STRIKE_PERIOD
	_strike_pause = randf_range(0.3, 1.0)
	_strike_left = randi_range(2, 4)
	_strike_w = 1.0
	_scene_look_on = false
	_scene_look_w = 0.0
	if _stone == null:
		_stone = MeshInstance3D.new()
		_stone.mesh = PropLibrary.mesh("stone_held")
		_stone.material_override = PropLibrary.material()
		add_child(_stone)
		_stone.top_level = true


## Катсцена: бить ровно, без пауз (true) — удар раз в STRIKE_PERIOD.
func strike_steady(on: bool) -> void:
	_strike_steady = on
	if on:
		_strike_pause = 0.0


## Катсцена: замер — рука с камнем опускается и больше не поднимается.
func stop_strikes() -> void:
	_strike = false


## Катсцена: повернуть голову к точке (on = false — вернуть).
func scene_look(point: Vector3, on := true) -> void:
	_scene_look = point
	_scene_look_on = on


## Точка камня в руке (катсцена: вставка «камень в руке»).
func stone_point() -> Vector3:
	return _stone.global_position if _stone else head_point()


## Встать и уйти вглубь (после катсцены): встаёт, потом бродит по патрулю.
func stand_and_leave() -> void:
	_strike = false
	_scene_anim = "kneel_stand_up"
	character.play("kneel_stand_up", 0.15, 1.0, true)
	await get_tree().create_timer(2.2).timeout
	_scene_look_on = false
	if state != State.SCENE:
		return
	character.reset_motion()
	_scene_anim = ""
	start_state = State.WANDER
	set_anim_fps(anim_fps)
	_enter(State.WANDER, true)
	_timer = 0.0


func _process(delta: float) -> void:
	_strike_w = move_toward(_strike_w, 1.0 if _strike else 0.0, delta / 0.6)
	_scene_look_w = move_toward(_scene_look_w, 1.0 if _scene_look_on else 0.0, delta / 0.7)
	_strike_jolt = maxf(0.0, _strike_jolt - delta / 0.35)
	# Поза на коленях — отрезок kneel_fix туда-обратно (без скачка на стыке)
	if character.current == STRIKE_BASE and character.anim.is_playing():
		var pos := character.anim.current_animation_position
		if pos >= STRIKE_BASE_TO:
			_base_dir = -1.0
		elif pos <= STRIKE_BASE_FROM:
			_base_dir = 1.0
		character.anim.speed_scale = _base_dir
	if not _strike:
		# Замер: рука плавно опускается из того места, где была
		_strike_angle = move_toward(_strike_angle, 0.0, delta / 0.5)
		return
	_strike_t += delta
	if _strike_t >= STRIKE_PERIOD + _strike_pause:
		_strike_t = 0.0
		_strike_pause = 0.0
		if not _strike_steady:
			_strike_left -= 1
			if _strike_left <= 0:
				_strike_left = randi_range(2, 4)
				_strike_pause = randf_range(1.5, 3.5)
	var t := _strike_t
	var hit_at := STRIKE_RAISE + STRIKE_TOP + STRIKE_FALL
	var was := _strike_angle
	if t < STRIKE_RAISE:
		_strike_angle = smoothstep(0.0, 1.0, t / STRIKE_RAISE)
		_strike_phase = 0
		_strike_k = t / STRIKE_RAISE
	elif t < STRIKE_RAISE + STRIKE_TOP:
		_strike_angle = 1.0
		_strike_phase = 1
		_strike_k = (t - STRIKE_RAISE) / STRIKE_TOP
	elif t < hit_at:
		# Падает с разгоном
		var k := (t - STRIKE_RAISE - STRIKE_TOP) / STRIKE_FALL
		_strike_angle = 1.0 - k * k
		_strike_phase = 2
		_strike_k = k * k
	else:
		_strike_angle = 0.0
		_strike_phase = 3
		_strike_k = 1.0
	if was > 0.0 and _strike_angle <= 0.0:
		_strike_jolt = 1.0
		AudioManager.play_3d("hit_wet", stone_point(), {"db": 2.0})


## Из модификатора скелета, поверх анимации: рывок головы и плеч; удар камнем (катсцена).
func _apply_pose() -> void:
	if _twitch_w > 0.001:
		var e := _twitch_rot * _twitch_w
		var chest: int = _bones.UpperChest if _bones.UpperChest >= 0 else _bones.Spine
		_rotate_bone(chest, Basis.from_euler(e * 0.3))
		_rotate_bone(_bones.Neck, Basis.from_euler(e))
	_apply_strike()


## Корпус и правая рука с камнем — замах и удар (IK от плеча), голова — к точке катсцены, камень — в кисть.
func _apply_strike() -> void:
	var has_stone := _stone != null and _stone.visible
	if not has_stone and _scene_look_w <= 0.001 and _startle_w <= 0.001:
		return
	var skel := character.skeleton
	var to_skel := skel.global_transform.affine_inverse()
	var axes := (to_skel.basis * global_basis).orthonormalized()
	if not has_stone:
		pass
	elif _strike_w > 0.001 and strike_target != Vector3.ZERO:
		_apply_swing(skel, to_skel, axes)
	elif _strike_w > 0.001:
		# Корпус: назад на замахе, вперёд на ударе
		var lean := deg_to_rad(STRIKE_LEAN_BACK) * _strike_angle - deg_to_rad(STRIKE_LEAN_HIT) * _strike_jolt * _strike_jolt
		_rotate_bone(_bones.Spine, Basis(axes.x, lean * _strike_w))
		# Рука: кисть идёт по дуге от тела вверх за голову
		var shoulder := skel.get_bone_global_pose(_bones.RightUpperArm).origin
		var top := axes * STRIKE_HAND_TOP
		var down := axes * STRIKE_HAND_DOWN
		var dir := down.normalized().slerp(top.normalized(), _strike_angle)
		var hand := shoulder + dir * lerpf(down.length(), top.length(), _strike_angle)
		_solve_right_arm(hand, axes * Vector3(0.9, -0.2, 0.5), _strike_w)
	var look_w := maxf(_scene_look_w, _startle_w)
	if look_w > 0.001:
		var look_at := _scene_look if _scene_look_w >= _startle_w else _startle_at
		var want := (to_skel * look_at - skel.get_bone_global_pose(_head).origin).normalized()
		for i in 2:
			var hb := skel.get_bone_global_pose(_head).basis.orthonormalized()
			var q := Quaternion(hb * _head_fwd_l, want)
			var ang := q.get_angle()
			if ang < 0.001:
				break
			var share := (0.4 if i == 0 else 1.0) * look_w
			var lim := deg_to_rad(40.0 if i == 0 else 80.0)
			_rotate_bone(_bones.Neck if i == 0 else _head, Basis(Quaternion().slerp(q, minf(share, lim / ang))))
	if not has_stone:
		return
	var h := skel.get_bone_global_pose(_bones.RightHand)
	var f := skel.get_bone_global_pose(_bones.RightIndexProximal)
	var at := skel.global_transform * h.origin.lerp(f.origin, 0.8)
	_stone.global_transform = Transform3D(skel.global_basis.orthonormalized() * h.basis.orthonormalized(), at)


## Удар по голове лежащего: правая рука — из sword_attack (замах), на падении IK доводит камень до strike_target.
## Замер (stop_strikes): _strike_angle плавно уходит в 0 — рука остаётся на голове, IK гаснет вместе с _strike_w.
func _apply_swing(skel: Skeleton3D, to_skel: Transform3D, axes: Basis) -> void:
	var sw := Anims.library().get_animation(STRIKE_SWING)
	# Время в анимации меча и доля IK (0 — рука из анимации, 1 — камень на голове)
	var ts := SWING_HIT
	var ik := 1.0
	match _strike_phase:
		0:
			ts = lerpf(0.0, SWING_TOP, smoothstep(0.0, 1.0, _strike_k))
			ik = 1.0 - smoothstep(0.0, 0.45, _strike_k)
		1:
			ts = SWING_TOP
			ik = 0.0
		2:
			ts = lerpf(SWING_TOP, SWING_HIT, _strike_k)
			ik = _strike_k
	if not _strike:
		ik = 1.0
	for b: String in _swing_tracks:
		var bone: int = _bones.get(b, -1)
		if bone < 0:
			continue
		var cur := skel.get_bone_pose_rotation(bone)
		var want := sw.rotation_track_interpolate(_swing_tracks[b], ts)
		skel.set_bone_pose_rotation(bone, cur.slerp(want, _strike_w * (1.0 - ik * 0.6)))
	# Корпус: назад на замахе, вперёд и вниз к голове на ударе
	var lean := deg_to_rad(STRIKE_LEAN_BACK) * (1.0 - ik) * _strike_angle - deg_to_rad(STRIKE_REACH_LEAN) * ik \
		- deg_to_rad(STRIKE_LEAN_HIT) * _strike_jolt * _strike_jolt
	_rotate_bone(_bones.Spine, Basis(axes.x, lean * _strike_w))
	if ik > 0.001:
		var hand := to_skel * (strike_target - _stone_off)
		_solve_right_arm(hand, axes * Vector3(0.9, 0.2, 0.3), ik * _strike_w)
	var h := skel.get_bone_global_pose(_bones.RightHand)
	var f := skel.get_bone_global_pose(_bones.RightIndexProximal)
	_stone_off = skel.global_transform.basis * (h.origin.lerp(f.origin, 0.8) - h.origin)


## Повернуть кость в пространстве скелета (вокруг её начала), дети едут вместе с ней.
func _rotate_bone(bone: int, rot: Basis) -> void:
	var skel := character.skeleton
	var g := skel.get_bone_global_pose(bone).basis.orthonormalized()
	var parent := skel.get_bone_parent(bone)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skel.set_bone_pose_rotation(bone, (pb.inverse() * rot.orthonormalized() * g).get_rotation_quaternion())


## Двухзвенный IK правой руки в пространстве скелета (как у героя, hero_arms.gd): кисть — в точку hand,
## локоть — в сторону pole, weight — доля поверх анимации.
func _solve_right_arm(hand: Vector3, pole: Vector3, weight: float) -> void:
	var skel := character.skeleton
	var ua: int = _bones.RightUpperArm
	var fa: int = _bones.RightLowerArm
	var hb: int = _bones.RightHand
	var a := skel.get_bone_rest(fa).origin.length()
	var b := skel.get_bone_rest(hb).origin.length()
	var parent_g := skel.get_bone_global_pose(skel.get_bone_parent(ua)).basis.orthonormalized()
	var ua_g := skel.get_bone_global_pose(ua)
	var fa_g := skel.get_bone_global_pose(fa)
	var hb_g := skel.get_bone_global_pose(hb)
	var ua_b := ua_g.basis.orthonormalized()
	var fa_b := fa_g.basis.orthonormalized()
	var to_target := hand - ua_g.origin
	var d := clampf(to_target.length(), 0.05, (a + b) * 0.999)
	var dir := to_target.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var out := (pole - dir * pole.dot(dir)).normalized()
	var elbow := ua_g.origin + dir * a * cos_a + out * a * sqrt(1.0 - cos_a * cos_a)
	var wrist := ua_g.origin + dir * d
	var ua_new := _arc_turn(fa_g.origin - ua_g.origin, elbow - ua_g.origin) * ua_b
	var fa_cur := ua_new * ua_b.inverse() * fa_b
	var fa_new := _arc_turn(fa_cur * skel.get_bone_rest(hb).origin, wrist - elbow) * fa_cur
	ua_new = ua_b.slerp(ua_new, weight)
	fa_new = fa_b.slerp(fa_new, weight)
	skel.set_bone_pose_rotation(ua, (parent_g.inverse() * ua_new).get_rotation_quaternion())
	skel.set_bone_pose_rotation(fa, (ua_new.inverse() * fa_new).get_rotation_quaternion())


## Поворот по кратчайшей дуге от направления from к to.
func _arc_turn(from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	if f.dot(t) > 0.99999:
		return Basis()
	if f.dot(t) < -0.9999:
		return Basis(f.cross(Vector3.UP).normalized(), PI)
	return Basis(Quaternion(f, t))
