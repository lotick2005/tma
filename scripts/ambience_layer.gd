class_name AmbienceLayer
extends Node
## Слой фона (не 3D): один звук, плавное появление и исчезание. Создаёт AudioManager.set_layer().
## Короткую петлю (WAV с loop) просто зацикливает. Длинный файл без петли (фон тьмы, 10 мин) играет
## двумя плеерами по очереди: за crossfade секунд до конца вступает второй с начала — шва не слышно.
## Старт — со случайного места, чтобы каждый заход звучал по-разному.

## Длина кроссфейда на стыке петли, с.
var crossfade := 6.0
## Громкость звука из реестра, дБ.
var base_db := 0.0
## Имя звука в реестре (чтобы не перезапускать то же самое).
var sound_name := ""

var _players: Array[AudioStreamPlayer] = []
var _active := 0
## Текущая и целевая громкость слоя (линейно, 0…1) и скорость фейда (в секунду).
var _gain := 0.0
var _target := 0.0
var _rate := 1.0
## Ход кроссфейда на стыке: 0 — нет, иначе — прошло секунд.
var _xfade := 0.0
var _stream: AudioStream
var _manual_loop := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start(stream: AudioStream, bus: String, fade: float, random_start := true) -> void:
	_stream = stream
	_manual_loop = not _is_looped(stream)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.stream = stream
		add_child(p)
		_players.append(p)
	var length := stream.get_length()
	var from := 0.0
	if random_start and length > crossfade * 3.0:
		from = randf() * (length - crossfade * 2.0)
	_players[0].play(from)
	_gain = 0.0
	_target = 1.0
	_rate = 1.0 / maxf(fade, 0.01)
	_apply()


## Плавно убрать слой и удалить его.
func stop(fade: float) -> void:
	_target = 0.0
	_rate = 1.0 / maxf(fade, 0.01)


func _is_looped(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


func _process(delta: float) -> void:
	if _players.is_empty():
		return
	_gain = move_toward(_gain, _target, _rate * delta)
	if _target == 0.0 and _gain <= 0.0:
		queue_free()
		return
	if _manual_loop:
		var cur := _players[_active]
		var length := _stream.get_length()
		if _xfade == 0.0 and cur.playing and cur.get_playback_position() >= length - crossfade:
			_active = 1 - _active
			_players[_active].play(0.0)
			_xfade = 0.0001
		elif _xfade > 0.0:
			_xfade += delta
			if _xfade >= crossfade:
				_xfade = 0.0
				_players[1 - _active].stop()
		elif not cur.playing:
			# Доиграл, не дождавшись кроссфейда (пауза дерева и т. п.) — продолжаем с начала
			cur.play(0.0)
	_apply()


func _apply() -> void:
	var k := clampf(_xfade / crossfade, 0.0, 1.0) if _xfade > 0.0 else 1.0
	# Равная мощность: sin/cos
	var g_new := sin(k * PI * 0.5)
	var g_old := cos(k * PI * 0.5)
	_players[_active].volume_db = base_db + linear_to_db(maxf(_gain * g_new, 1e-5))
	_players[1 - _active].volume_db = base_db + linear_to_db(maxf(_gain * g_old, 1e-5))
