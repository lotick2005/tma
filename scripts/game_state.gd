extends Node
## Глобальное состояние игры (autoload GameState).
## Пока только данные, без логики: её добавят следующие этапы.

## Текущий уровень (путь к сцене или id уровня).
var current_level: String = ""
## Текущий чекпойнт внутри уровня (id точки возрождения).
var current_checkpoint: String = ""
## id прочитанных записок, в порядке прочтения.
var read_notes: Array[String] = []
## Сюжетные флаги: имя флага -> значение.
var story_flags: Dictionary = {}
## Есть ли у героя ключ от калитки южных ворот (уровень 2, Антония).
var has_key: bool = false
## Светильник в руке (true) или убран (false). Клавиша F, см. scripts/hero_arms.gd.
var lamp_out: bool = true
## Вступление (уровень 1: день на площади, вестник, тьма) пройдено — уровень сразу начинается во тьме.
var intro_done: bool = false
