class_name HeroAudio
extends Node
## Звуки героя (узел Player/Audio):
##  • шаги — по поверхности (мостовая, земля, дерево — AudioManager.surface_at), тише в приседе, громче на бегу;
##    3D-звук у ног: в переулке отдаётся эхом, в подвале гулко;
##  • дыхание — три петли, смешиваются по громкости: спокойное → тяжёлое после бега (выносливость) →
##    частое при угрозе (ThreatDirector);
##  • сердцебиение — только при угрозе, частота и громкость растут с ней.

## Громкость шагов по режиму, дБ.
@export var step_db_crouch := -12.0
@export var step_db_walk := 0.0
@export var step_db_run := 5.0
## Высота «ног» под центром игрока, м (точка звука шага).
@export var step_height := 0.05

@export_group("Дыхание")
## Как быстро набирается «запыхался» на бегу и как медленно проходит, единиц в секунду.
@export var exertion_rise := 0.3
@export var exertion_fall := 0.07
## Угроза, с которой дыхание становится частым.
@export var fast_breath_from := 0.2

@export_group("Сердце")
## Сердце вступает с этой угрозы.
@export var heart_from := 0.15
## Удары в минуту при слабой и при полной угрозе.
@export var heart_bpm_min := 62.0
@export var heart_bpm_max := 128.0
## Громкость при слабой и при полной угрозе, дБ.
@export var heart_db_min := -26.0
@export var heart_db_max := -2.0

## «Запыхался», 0…1.
var exertion := 0.0

var _player: Player
var _breath := {}
var _heart: AudioStreamPlayer
var _heart_timer := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	if _player:
		_player.footstep.connect(_on_footstep)


func _process(delta: float) -> void:
	if not AudioManager.unlocked or _player == null:
		return
	if _breath.is_empty():
		_start_loops()
	var threat: float = ThreatDirector.threat
	# Запыхался: растёт на бегу и пока выносливость низкая, проходит медленно
	var tired := 1.0 - _player.stamina / maxf(_player.stamina_max, 0.01)
	var running := _player.move_mode == Player.MoveMode.RUN
	var goal := maxf(tired, 1.0 if running else 0.0)
	exertion = move_toward(exertion, goal, (exertion_rise if goal > exertion else exertion_fall) * delta)
	var heavy := smoothstep(0.2, 0.7, exertion)
	var fast := smoothstep(fast_breath_from, 0.8, threat)
	var calm := clampf(1.0 - maxf(heavy, fast), 0.0, 1.0)
	_set_breath("breath_calm", calm)
	_set_breath("breath_heavy", heavy * (1.0 - fast * 0.7))
	_set_breath("breath_fast", fast)
	# Сердце
	if threat >= heart_from:
		var k := inverse_lerp(heart_from, 1.0, threat)
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = 60.0 / lerpf(heart_bpm_min, heart_bpm_max, k)
			_heart.volume_db = AudioManager.entry("heartbeat").get("db", 0.0) + lerpf(heart_db_min, heart_db_max, k)
			_heart.pitch_scale = randf_range(0.97, 1.03)
			_heart.play()
	else:
		_heart_timer = 0.0


func _start_loops() -> void:
	for sound_name in ["breath_calm", "breath_heavy", "breath_fast"]:
		var p := AudioStreamPlayer.new()
		p.bus = AudioManager.entry(sound_name).get("bus", "SFX")
		p.stream = AudioManager.get_stream(sound_name)
		p.volume_db = -80.0
		add_child(p)
		if p.stream:
			p.play(randf() * p.stream.get_length())
		_breath[sound_name] = p
	_heart = AudioStreamPlayer.new()
	_heart.bus = AudioManager.entry("heartbeat").get("bus", "SFX")
	_heart.stream = AudioManager.get_stream("heartbeat")
	add_child(_heart)


func _set_breath(sound_name: String, weight: float) -> void:
	var p: AudioStreamPlayer = _breath[sound_name]
	var base: float = AudioManager.entry(sound_name).get("db", 0.0)
	p.volume_db = base + linear_to_db(maxf(weight, 1e-4))


func _on_footstep(mode: Player.MoveMode) -> void:
	var db := step_db_walk
	match mode:
		Player.MoveMode.CROUCH:
			db = step_db_crouch
		Player.MoveMode.RUN:
			db = step_db_run
	var feet := _player.global_position + Vector3.UP * step_height
	var surface := AudioManager.surface_at(feet)
	AudioManager.play_3d("step_" + surface, feet, {"db": db, "occlude": false})
