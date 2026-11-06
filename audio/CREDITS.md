# Авторы звуков

Все сторонние звуки в игре и их лицензии. При добавлении нового файла — допиши строку сюда и в титры игры.

| Файл | Источник | Автор | Лицензия | Что изменено |
|---|---|---|---|---|
| `prayer_choir.ogg` | [Horror Prayer Roman Catholic 02](https://freesound.org/people/klankbeeld/sounds/234122/) (freesound.org) | klankbeeld (по идее toiletrolltube) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Срезаны низкие частоты ниже ~140 Гц (убрано сердцебиение), перекодировано в OGG Vorbis |
| `prayer_choir_mono.ogg` | то же, что `prayer_choir.ogg` | klankbeeld (по идее toiletrolltube) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Моно-копия `prayer_choir.ogg` для 3D-источника (32 кГц, OGG Vorbis q3) |
| `ambient_drone.ogg` | [HORROR Cetti's Warbler -4 -2 oct -170x speed](https://freesound.org/people/klankbeeld/sounds/795877/) (freesound.org) | klankbeeld | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Пересэмплировано в 22 кГц (в записи нет ничего выше ~1,5 кГц), перекодировано в OGG Vorbis |
| `steps_stone_01…12.ogg` | [footsteps](https://freesound.org/s/651516/) (freesound.org) | 1bob | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Нарезано на 12 отдельных шагов (сухие, по камню), моно 44,1 кГц, срез ниже 60 Гц, выровнена громкость |
| `steps_stone_run_01…06.ogg` | [Footsteps stone floor](https://freesound.org/s/757207/) (freesound.org) | HenKonen | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Нарезано на 6 тяжёлых шагов (для бега), хвост эха комнаты срезан на 0,22 с, моно, выровнена громкость |
| `steps_stairs_01…10.ogg` | [250607_06h43 Albi - Walking up stone staircase](https://freesound.org/s/811375/) (freesound.org) | Sadiquecat | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Нарезано на 10 шагов по каменной лестнице, моно 44,1 кГц (было 192 кГц), выровнена громкость |
| `breath_run_01…05.ogg` | [Male_Breath_Fast_Loop_Stereo](https://freesound.org/s/554907/) (freesound.org) | Nox_Sound | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Нарезано на 5 циклов «выдох + вдох» (~1 с), моно, срез ниже 80 Гц, выровнена громкость |
| `breath_tired_01…07.ogg` | [Male Heavy Breathing](https://freesound.org/s/410969/) (freesound.org) | MihirFreeSound | [CC BY-NC 3.0](https://creativecommons.org/licenses/by-nc/3.0/) ⚠️ | Нарезано на 7 циклов одышки (~1,1–1,3 с), моно, срез ниже 80 Гц, выровнена громкость |
| `breath_calm_01…02.ogg` | [male breathing](https://freesound.org/s/408735/) (freesound.org) | FALCONS_SHADOW | [CC BY-NC 3.0](https://creativecommons.org/licenses/by-nc/3.0/) ⚠️ | Два отдельных спокойных вдоха-выдоха; взят только правый канал (левый в противофазе), моно, плавные края |

| `market_crowd.ogg` | [Ukrainian city farmers market1](https://freesound.org/s/592433/) (freesound.org) | Vital_Sounds | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Срезано ниже 70 Гц, приглушены приметные всплески (лязг, выкрики), три копии со сдвигом по времени и сменой высоты (0,955 / 1 / 1,045) сведены в 74-секундную бесшовную петлю, 32 кГц |
| `birds_morning_mono.ogg` | [Morning Birds](https://freesound.org/s/876938/) (freesound.org) | solarpsychedelic | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Взят кусок 78–180 с, моно, срезано всё ниже 1,6 кГц (машины, самолёт) и выше 11 кГц, бесшовная петля 100 с, 32 кГц |
| `wind_drone.ogg` | [Drone-Horror Wind](https://freesound.org/s/876947/) (freesound.org) | cat-fox_alex | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Обрезаны фейды, бесшовная петля 24 с, 22 кГц |
| `dark_ambience.ogg` | [Dark horror ambience](https://freesound.org/s/876811/) (freesound.org) | Daniel_Brooks | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Обрезаны фейды (взято 5–62,5 с), бесшовная петля 54,5 с, 22 кГц |
| `industrial_loop.ogg` | [107 BPM Industrial Ambient Loop](https://freesound.org/s/877426/) (freesound.org) | looplicator | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Ровно 32 доли, стык сглажен (12 мс), 22 кГц |

Громкость всех фонов выровнена по LUFS (базар −24, тёмный гул −25, птицы −26, ветер −27, индастриал −24). Скрипт — `tools/audio/ambience_loops.py`.

⚠️ **NC — только некоммерческое использование.** Пока игра бесплатная в браузере — можно. Если когда-нибудь игра станет платной, `breath_tired_*` и `breath_calm_*` надо заменить (на CC0 / CC BY или свою запись).

Строка для титров (автор просит указывать всех троих, без косвенных ссылок):
«Horror Prayer Roman Catholic 02» — klankbeeld, toiletrolltube, freesound.org — CC BY 4.0
«HORROR Cetti's Warbler» — klankbeeld, freesound.org — CC BY 4.0
«Male Heavy Breathing» — MihirFreeSound, freesound.org — CC BY-NC 3.0
«male breathing» — FALCONS_SHADOW, freesound.org — CC BY-NC 3.0
«Ukrainian city farmers market1» — Vital_Sounds, freesound.org — CC BY 3.0
«Dark horror ambience» — Daniel_Brooks, freesound.org — CC BY 4.0

Необязательно (CC0), но приятно авторам — в титрах «Шаги и дыхание»:
«footsteps» — 1bob; «Footsteps stone floor» — HenKonen; «Walking up stone staircase» — Sadiquecat (просит формат: «… sound by Sadiquecat on Freesound.org in CC0 licence»); «Male_Breath_Fast_Loop_Stereo» — Nox_Sound. Фоны: «Morning Birds» — solarpsychedelic; «Drone-Horror Wind» — cat-fox_alex; «107 BPM Industrial Ambient Loop» — looplicator. Все — freesound.org, CC0.

Просьбы автора klankbeeld (сверх лицензии): не использовать его звуки в стоковых библиотеках и не выкладывать «сырые» файлы отдельно (например, на YouTube). В игре — можно.
