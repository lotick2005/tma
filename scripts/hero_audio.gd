class_name HeroAudio
extends Node
## Звуки героя (узел Player/Audio). Звуки — в реестре data/sounds.gd, записи — audio/ (авторы — audio/CREDITS.md).
##
##  • Шаги. Пока одна поверхность — камень (AudioManager.surfaces_enabled = false): ходьба и присед — step_stone,
##    бег — step_stone_run, ступени и лестницы (вверх и вниз) — step_stairs. На ступенях ли герой — по перепаду высоты
##    между двумя шагами. Вариант случайный без повтора подряд, высота ±4 %, громкость ±2 дБ (реестр).
##    Свои шаги почти сухие: в эхо зон идёт только доля step_reverb (эхо — для звуков мира).
##  • Дыхание — не петля, а отдельные циклы подряд (следующий — когда кончился предыдущий, с паузой):
##      бег — breath_run вступает через 1–2 с бега и нарастает;
##      угроза > threat_breath_from — тоже breath_run, но тише, чем на бегу;
##      после бега (выносливость ниже tired_below) — одышка breath_tired: громкость и паузы по выносливости,
##        за 4–6 с затихает до нуля;
##      «затаился» (присел, стоит, угроза > hide_threat) — один тихий breath_calm раз в 6–10 с.
##    В покое, при ходьбе и в приседе без угрозы дыхания нет.
##  • Сердце — только при угрозе, частота и громкость растут с ней.

enum Breath { NONE, RUN, TIRED, CALM }

@export_group("Шаги")
## Добавка громкости по режиму, дБ (основная громкость — в реестре).
@export var step_db_crouch := -7.0
@export var step_db_walk := 0.0
@export var step_db_run := 1.0
## Доля своих шагов в эхе зоны (0 — совсем сухо, 1 — как звуки мира).
@export var step_reverb := 0.12
## Перепад высоты между двумя шагами, м, с которого шаг считается шагом по ступеням.
@export var stairs_rise := 0.08
## Высота «ног» над центром игрока, м (точка звука шага).
@export var step_height := 0.05

@export_group("Дыхание")
## Через сколько секунд бега вступает дыхание (случайно в пределах) и за сколько нарастает до полной громкости.
@export var run_breath_delay_min := 1.0
@export var run_breath_delay_max := 2.0
@export var run_breath_rise := 2.5
## С какой громкости (доля полной) вступает дыхание на бегу.
@export var run_breath_start := 0.3
## Пауза между циклами на бегу, с.
@export var run_breath_gap := Vector2(0.03, 0.12)
## Одышка после бега: если выносливость ниже этой доли; затихает за столько секунд (случайно в пределах).
@export var tired_below := 0.4
@export var tired_fade_min := 4.0
@export var tired_fade_max := 6.0
## Пауза между циклами одышки: при сильной усталости и почти отдышавшись, с.
@export var tired_gap_heavy := 0.05
@export var tired_gap_light := 1.2
## Угроза, с которой слышно частое дыхание, и его громкость относительно бега, дБ.
@export var threat_breath_from := 0.5
@export var threat_breath_db := -7.0
## «Затаился»: угроза больше этой; пауза между вдохами, с.
@export var hide_threat := 0.3
@export var hide_gap_min := 6.0
@export var hide_gap_max := 10.0

@export_group("Сердце")
## Сердце вступает с этой угрозы.
@export var heart_from := 0.15
## Удары в минуту при слабой и при полной угрозе.
@export var heart_bpm_min := 62.0
@export var heart_bpm_max := 120.0
## Громкость при слабой и при полной угрозе, дБ (добавка к реестру).
@export var heart_db_min := -24.0
@export var heart_db_max := -6.0

## Сколько секунд герой бежит без перерыва.
var run_time := 0.0
## Одышка, 1 — только что остановился выдохшимся, 0 — отдышался.
var tired := 0.0

var _player: Player
var _breath: AudioStreamPlayer
var _breath_mode := Breath.NONE
var _breath_wait := 0.0
var _run_delay := 1.5
var _tired_rate := 0.2
var _was_running := false
var _heart: AudioStreamPlayer
var _heart_timer := 0.0
var _last_step_pos := Vector3.INF


func _ready() -> void:
	_player = get_parent() as Player
	if _player:
		_player.footstep.connect(_on_footstep)


func _process(delta: float) -> void:
	if not AudioManager.unlocked or _player == null:
		return
	if _breath == null:
		_make_players()
	var threat: float = ThreatDirector.threat
	_update_exertion(delta)
	_update_breath(delta, threat)
	_update_heart(delta, threat)


func _make_players() -> void:
	_breath = AudioStreamPlayer.new()
	_breath.bus = "SFX"
	add_child(_breath)
	_heart = AudioStreamPlayer.new()
	_heart.bus = AudioManager.entry("heartbeat").get("bus", "SFX")
	_heart.stream = AudioManager.get_stream("heartbeat")
	add_child(_heart)


# ─── Бег и одышка ────────────────────────────────────────────────────────────

func _update_exertion(delta: float) -> void:
	var running := _player.move_mode == Player.MoveMode.RUN
	if running:
		if not _was_running:
			run_time = 0.0
			_run_delay = randf_range(run_breath_delay_min, run_breath_delay_max)
		run_time += delta
		tired = 0.0
	else:
		var ratio := _player.stamina / maxf(_player.stamina_max, 0.01)
		# Остановился (или выдохся) после бега с низкой выносливостью — одышка
		if _was_running and ratio < tired_below:
			tired = lerpf(0.6, 1.0, 1.0 - ratio / tired_below)
			_tired_rate = tired / randf_range(tired_fade_min, tired_fade_max)
		tired = maxf(0.0, tired - _tired_rate * delta)
		run_time = 0.0
	_was_running = running


## Сила дыхания на бегу, 0…1: вступает через _run_delay с и нарастает за run_breath_rise с.
func _run_strength() -> float:
	if run_time <= _run_delay:
		return 0.0
	return clampf((run_time - _run_delay) / run_breath_rise, 0.0, 1.0)


# ─── Дыхание: циклы подряд ───────────────────────────────────────────────────

func _update_breath(delta: float, threat: float) -> void:
	if _breath.playing:
		return
	_breath_wait -= delta
	var mode := Breath.NONE
	var gain := 0.0
	var run := _run_strength()
	var threat_k := smoothstep(threat_breath_from, 0.85, threat) if threat > threat_breath_from else 0.0
	var still := Vector2(_player.velocity.x, _player.velocity.z).length() < 0.1
	if run > 0.0 or threat_k > 0.0:
		mode = Breath.RUN
		# Вступает тихо (run_breath_start), нарастает до полной; при угрозе — тише, чем на бегу
		var run_gain := lerpf(run_breath_start, 1.0, run) if run > 0.0 else 0.0
		var threat_gain := lerpf(run_breath_start, 1.0, threat_k) * db_to_linear(threat_breath_db) if threat_k > 0.0 else 0.0
		gain = maxf(run_gain, threat_gain)
	elif tired > 0.02:
		mode = Breath.TIRED
		gain = tired
	elif _player.move_mode == Player.MoveMode.CROUCH and still and threat > hide_threat:
		mode = Breath.CALM
		gain = 1.0
	if mode != _breath_mode:
		# Смена режима: бег и одышка вступают сразу, «затаился» — после первой паузы
		_breath_wait = randf_range(hide_gap_min, hide_gap_max) * 0.5 if mode == Breath.CALM else 0.0
		_breath_mode = mode
	if mode == Breath.NONE or _breath_wait > 0.0:
		return
	var sound_name: String = {Breath.RUN: "breath_run", Breath.TIRED: "breath_tired", Breath.CALM: "breath_calm"}[mode]
	_breath.stream = AudioManager.get_stream(sound_name)
	_breath.volume_db = AudioManager.entry(sound_name).get("db", 0.0) + linear_to_db(maxf(gain, 1e-4)) + randf_range(-1.0, 1.0)
	_breath.pitch_scale = randf_range(0.97, 1.03)
	_breath.play()
	match mode:
		Breath.RUN:
			_breath_wait = randf_range(run_breath_gap.x, run_breath_gap.y)
		Breath.TIRED:
			_breath_wait = lerpf(tired_gap_light, tired_gap_heavy, tired) * randf_range(0.8, 1.2)
		Breath.CALM:
			_breath_wait = randf_range(hide_gap_min, hide_gap_max)


# ─── Сердце ──────────────────────────────────────────────────────────────────

func _update_heart(delta: float, threat: float) -> void:
	if threat < heart_from:
		_heart_timer = 0.0
		return
	var k := inverse_lerp(heart_from, 1.0, threat)
	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = 60.0 / lerpf(heart_bpm_min, heart_bpm_max, k)
		_heart.volume_db = AudioManager.entry("heartbeat").get("db", 0.0) + lerpf(heart_db_min, heart_db_max, k)
		_heart.pitch_scale = randf_range(0.97, 1.03)
		_heart.play()


# ─── Шаги ────────────────────────────────────────────────────────────────────

func _on_footstep(mode: Player.MoveMode) -> void:
	var feet := _player.global_position + Vector3.UP * step_height
	# Ступени: заметный перепад высоты с прошлого шага (недалеко — иначе это не соседний шаг)
	var on_stairs := false
	if _last_step_pos != Vector3.INF:
		var flat := Vector2(feet.x - _last_step_pos.x, feet.z - _last_step_pos.z).length()
		on_stairs = flat < 2.0 and absf(feet.y - _last_step_pos.y) >= stairs_rise
	_last_step_pos = feet
	var db := step_db_walk
	match mode:
		Player.MoveMode.CROUCH:
			db = step_db_crouch
		Player.MoveMode.RUN:
			db = step_db_run
	var sound_name := "step_" + AudioManager.surface_at(feet)
	if on_stairs:
		sound_name = "step_stairs"
	elif mode == Player.MoveMode.RUN and AudioManager.has_sound(sound_name + "_run"):
		sound_name += "_run"
	AudioManager.play_3d(sound_name, feet, {"db": db, "occlude": false, "reverb_gain": step_reverb})
