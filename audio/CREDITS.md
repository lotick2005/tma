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

## Второй набор (ноябрь): разовые звуки, напевы святых, паника

Нарезка и сведение — `tools/audio/pack2_sfx.py`. Все файлы — моно 44,1 кГц (петли толпы — стерео 32 кГц, напевы — моно 22 кГц), OGG Vorbis q4.

| Файл | Источник (freesound.org) | Автор | Лицензия | Что изменено |
|---|---|---|---|---|
| `pot_break_01…06.ogg` | [clay jar break](https://freesound.org/s/540336/); [clay jar break](https://freesound.org/s/540337/); [pot smash](https://freesound.org/s/540339/); [breaking pot short](https://freesound.org/s/810043/); [breaking pot long](https://freesound.org/s/810041/); [breaking pot low](https://freesound.org/s/810042/) | clearwavsound, anna_bliss | ⏳ уточняется; [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Обрезана тишина, длинные укорочены до ~2,5 с, срез ниже 90 Гц, выровнена громкость, моно |
| `pot_wobble_01…03.ogg` | [PLASTIC WOBBLING 004](https://freesound.org/s/101549/); [boardgame piece wobble 5](https://freesound.org/s/732124/) | sandyrb, aidan_walker | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); ⏳ уточняется | Вырезано качание; пластик опущен на 4–5 полутонов и приглушён сверху (ближе к глине), моно |
| `stone_drop_01…05.ogg` | [brick being dropped](https://freesound.org/s/655350/); [stone throwing pebbles](https://freesound.org/s/734669/) | jadevelloza, vrymaa | ⏳ уточняется | Нарезано на отдельные удары камня, срез ниже 70 Гц, моно |
| `rubble_fall_01…07.ogg` | [brick debris fall 06](https://freesound.org/s/437602/); [Foley_Impact_Stones_Strong_Debris](https://freesound.org/s/554148/); [Foley_Stones_Falls_Debris](https://freesound.org/s/550342/) | debsound, nox_sound | ⏳ уточняется | Нарезано на отдельные осыпи 1,2–2,5 с, моно |
| `wood_clack_01…05.ogg` | [woodblock 3](https://freesound.org/s/870350/); [wood block clacking](https://freesound.org/s/543705/) | geoff-bremner-audio, 200221-weanbekker | ⏳ уточняется | Отдельные стуки дерева, моно |
| `wood_fall_01…03.ogg` | [woodblock 3](https://freesound.org/s/870350/); [wood block clacking](https://freesound.org/s/543705/) | geoff-bremner-audio, 200221-weanbekker | ⏳ уточняется | Собрано из трёх стуков, опущенных на 6–11 полутонов (упал, подпрыгнул, лёг) |
| `wood_drag_01.ogg` | [chair stool wooden dragged 13](https://freesound.org/s/147009/) | dwoboyle | ⏳ уточняется | Вырезано 1,1 с, выровнена громкость |
| `hammer_nail_01…06.ogg` | [nailing](https://freesound.org/s/850175/) | mihacappy | ⏳ уточняется | Нарезано на 6 ударов, опущено на 3 полутона (тяжелее), срез ниже 70 Гц, моно |
| `scream_man_01…06.ogg` | [man screaming](https://freesound.org/s/325548/) | archeos | ⏳ уточняется | Нарезано на 6 криков, срез ниже 90 Гц |
| `scream_pain_01…02.ogg`, `groan_pain_01…02.ogg` | [man in excruciating pain](https://freesound.org/s/876075/); [Man screams in pain - in a big hall](https://freesound.org/s/401211/) | sebasteks, stuxer | ⏳ уточняется; [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Нарезано: долгий крик, крик в гулком зале (моно), два коротких стона |
| `gate_rattle_01…04.ogg` | [metal gate rattle handle swing clang](https://freesound.org/s/330522/) | widds | ⏳ уточняется | Нарезано на 4 куска, срез выше 7,5 кГц (меньше звона), моно |
| `parchment_01…04.ogg` | [Paper_Parchment_Rustling](https://freesound.org/s/204046/) | duckduckpony | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Нарезано на 4 шороха 1–2 с, срез ниже 150 Гц, моно |
| `cloth_rustle_01…06.ogg` | [fabric movement in a fight](https://freesound.org/s/852785/) | wigglesworth | ⏳ уточняется | Нарезано на 6 коротких шорохов, срез ниже 120 Гц |
| `steps_barefoot_01…10.ogg` | [01969 walking barefoot stone](https://freesound.org/s/101755/) | robinhood76 | ⏳ уточняется | Нарезано на 10 босых шагов, срез ниже 80 Гц, моно |
| `hit_wet_01…04.ogg` | [wet_plastic_hit](https://freesound.org/s/532139/); [wet_plastic_slap](https://freesound.org/s/532140/); [punches](https://freesound.org/s/96486/) | j1987, velvorn | ⏳ уточняется; [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Мокрый шлепок + приглушённый удар кулаком, опущенный на 3–6 полутонов |
| `hit_head.ogg`, `body_fall_01…03.ogg` | [punches](https://freesound.org/s/96486/); [fabric movement in a fight](https://freesound.org/s/852785/) | velvorn, wigglesworth | ⏳ уточняется | Удар кулаком, опущенный и приглушённый, + синтезированный низкий толчок; для падения тела — ещё шорох ткани |
| `choke_01…04.ogg`, `struggle_01.ogg` | [chokingthingmix](https://freesound.org/s/573900/); [choking](https://freesound.org/s/869797/); [real choking cough](https://freesound.org/s/252242/); [man struggle](https://freesound.org/s/682137/) | mcbyname, daniel8766, reitanna, henkonen | ⏳ уточняется | Нарезано на отдельные хрипы и рывок, срез ниже 90 Гц, моно |
| `gasp_wake_01…04.ogg` | [wake up scared](https://freesound.org/s/588666/); [gasp01](https://freesound.org/s/218410/) | thepig01, kokopetiyot | ⏳ уточняется | Нарезано на отдельные судорожные вдохи, моно |
| `saint_chant_01.ogg`, `saint_chant_phrase_01.ogg` | [Low chant](https://freesound.org/s/319253/) | adharca | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | Одна фраза без слов (10 с); петля 48 с — та же фраза на четырёх высотах (0, −2, +1,5, −3,5 полутона) с паузами; 22 кГц, моно |
| `saint_mumble_01.ogg` | [rapid male chanting in temple in japan](https://freesound.org/s/686617/) | calebjay | ⏳ уточняется | Срез ниже 120 Гц и выше 3,5 кГц, бесшовная петля 27 с, 22 кГц, моно |
| `saint_drone_01.ogg` | [singers dominance](https://freesound.org/s/876338/) | delzana | ⏳ уточняется | Бесшовная петля 3,8 с из ровной низкой ноты, 22 кГц, моно |
| `crowd_panic.ogg` | [man screaming](https://freesound.org/s/325548/); [man in excruciating pain](https://freesound.org/s/876075/); [wilhelm scream alternative 1](https://freesound.org/s/813303/); [wilhelm scream alternative 5](https://freesound.org/s/813307/); [wake up scared](https://freesound.org/s/588666/); [man struggle](https://freesound.org/s/682137/); [gasp01](https://freesound.org/s/218410/) | archeos, sebasteks, qubodup, thepig01, henkonen, kokopetiyot | ⏳ уточняется | Сборная петля 40 с: 70 криков из этих записей на разной высоте, громкости и удалении + ускоренный гомон из `market_crowd.ogg` (Vital_Sounds, CC BY 3.0) |
| `crowd_stampede.ogg` | [01969 walking barefoot stone](https://freesound.org/s/101755/) | robinhood76 | ⏳ уточняется | Сборная петля 30 с: ~780 шагов (эти босые + `steps_stone_run_*`, HenKonen, CC0) на разной высоте + синтезированный низкий гул |

⏳ **Лицензии этой таблицы сверены не все**: страницы freesound в день обработки не открывались. У freesound бывают только CC0, CC BY, CC BY-NC и (у старых записей) Sampling+ — для бесплатной игры с указанием авторов подходят все четыре. Перед платным релизом сверить каждую строку и заменить записи с NC.

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
