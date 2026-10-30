class_name WorldCoords
extends RefCounted
## Перевод координат карты (CLAUDE.md §3) в координаты Godot.
## Карта: x — на восток, y — на север, h — высота относительно платформы Храмовой горы, в реальных метрах.
## Начало (0, 0) — юго-западный угол Храмовой горы у арки Робинсона.
## Godot: position = Vector3(x * K, h * K, -y * K), ось −Z смотрит на север.
## Длины и перепады рельефа сжимаются на K, а сами постройки (их высоты и размеры) — нет.

## Масштаб k: единственное место, где он задан.
const K := 0.4


## Точка карты → точка Godot.
static func point(x: float, y: float, h: float = 0.0) -> Vector3:
	return Vector3(x * K, h * K, -y * K)


## x карты → X Godot.
static func gx(x: float) -> float:
	return x * K


## y карты (север) → Z Godot.
static func gz(y: float) -> float:
	return -y * K


## h карты (рельеф) → Y Godot.
static func gy(h: float) -> float:
	return h * K
