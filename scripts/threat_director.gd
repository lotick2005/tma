extends Node
## «Режиссёр угрозы» (autoload ThreatDirector): одно число threat 0…1 — насколько герою сейчас страшно.
## Растёт → фон уходит в тишину, дыхание учащается, вступает сердце (AudioManager, HeroAudio).
## Падает → всё плавно возвращается.
## Кто поднимает угрозу:
##  • пока врагов нет — ползунок «Угроза» в отладочной панели (0): manual_threat;
##  • святые и ангел (этапы 5–6) — report_threat() из своей точки, каждый кадр, пока они рядом / ищут / гонятся.

signal threat_changed(value: float)

## Скорость роста и спада угрозы, единиц в секунду (растёт быстро, отпускает медленно).
const RISE_RATE := 0.8
const FALL_RATE := 0.12
## Сколько секунд держится сообщённая угроза, если её не повторили.
const REPORT_HOLD := 0.6

## Текущая угроза (сглаженная), 0…1. Только читать.
var threat := 0.0
## Угроза с ползунка отладочной панели, 0…1.
var manual_threat := 0.0

## Сообщённые угрозы: id источника → [величина, сколько ещё держится].
var _reports := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Сообщить угрозу из точки мира. amount — сила вплотную (0…1), radius — дальше этого, м, не страшно
## (между ними — линейно). source — кто сообщает (узел врага), чтобы его угроза обновлялась, а не копилась.
func report_threat(from: Vector3, amount: float, radius := 20.0, source: Object = null) -> void:
	var d := from.distance_to(listener_position())
	var value := clampf(amount, 0.0, 1.0) * clampf(1.0 - d / maxf(radius, 0.01), 0.0, 1.0)
	var key: Variant = source.get_instance_id() if source else _reports.size() + 100000
	var old: Array = _reports.get(key, [0.0, 0.0])
	_reports[key] = [maxf(value, old[0] if old[1] > 0.0 else 0.0), REPORT_HOLD]


## Где слушатель (камера), для расстояний.
func listener_position() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _process(delta: float) -> void:
	var target := manual_threat
	for key in _reports.keys():
		var r: Array = _reports[key]
		r[1] -= delta
		if r[1] <= 0.0:
			_reports.erase(key)
		else:
			target = maxf(target, r[0])
	var rate := RISE_RATE if target > threat else FALL_RATE
	var next := move_toward(threat, target, rate * delta)
	if next != threat:
		threat = next
		threat_changed.emit(threat)
