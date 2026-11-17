class_name Settings
extends RefCounted
## Настройки игрока (этап 5б): чувствительность мыши и общая громкость. Хранятся в user://settings.cfg
## (в браузере — в IndexedDB страницы), читаются при старте (ClickToStart), меняются ползунками в паузе.

const PATH := "user://settings.cfg"
## Чувствительность — множитель к Player.mouse_sensitivity.
const MOUSE_MIN := 0.25
const MOUSE_MAX := 3.0

## Множитель чувствительности мыши (1 — как задумано).
static var mouse := 1.0
## Общая громкость 0..1 (шина Master).
static var volume := 1.0
static var _loaded := false


## Прочитать из файла (один раз за запуск) и применить.
static func load_and_apply() -> void:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(PATH) == OK:
			mouse = clampf(float(cfg.get_value("input", "mouse", 1.0)), MOUSE_MIN, MOUSE_MAX)
			volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	apply()


static func apply() -> void:
	AudioManager.set_bus_volume("Master", linear_to_db(maxf(volume, 0.0001)))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse", mouse)
	cfg.set_value("audio", "volume", volume)
	cfg.save(PATH)
