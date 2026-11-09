# Фото-текстуры (Poly Haven, CC0)

`textures/photo/*.png` — 24 текстуры с [Poly Haven](https://polyhaven.com) (лицензия [CC0](https://creativecommons.org/publicdomain/zero/1.0/): можно всё, указывать автора не обязательно). Взят только цвет (`diff`, 1K), уменьшен до 128×128 усреднением блоков, все бесшовные (тайлятся). Фильтр в игре — nearest, без мипмапов, наш psx-шейдер.

Одна текстура на исходнике — это примерно 1–3 м поверхности; масштаб UV подбирать на глаз по кадру (камни в стене ≈ 0,3–1 м, доски ≈ 0,15–0,2 м шириной).

## Что куда (предложение — проверять в браузере)

| Поверхность в игре | Текстура |
|---|---|
| Стены Храмовой горы, Антония, тёсаный камень | `sandstone_blocks_04`, `white_sandstone_bricks_03`, `yellow_stone_wall` |
| Белые оштукатуренные дома (богатые) | `white_stucco_02`; облупленные — `white_rough_plaster` |
| Простая штукатурка | `rough_plaster_03` |
| Охряная обмазка (бедные дома) | `clay_block_wall` |
| Бут, рваный камень (бедные дома, задние стены, подвалы) | `rock_wall_04`, `rustic_stone_wall_02`, `rock_wall_03`, `worn_brick_wall` |
| Переулки, мелкая мостовая | `rock_wall_06` |
| Земля, дворы, сады | `dirt_floor`, `gravelly_sand`, `dry_ground_rocks` |
| Скала Антонии, рельеф, канал | `rock_face_03`, `medieval_blocks_06` |
| Двор с травой | `rocky_terrain_03` |
| Пол богатого дома | `terrazzo_tiles` |
| Дерево (двери, балки, леса, лотки) | `old_wood_floor`, `dark_wooden_planks` |
| Ткань: мешки, навесы, циновки | `hessian_230`, `hessian_380` |
| Лён: пелены, полотно на телах, одежда | `jogging_melange` |

Главная мостовая (крупные светлые плиты с водостоком) и иродианская рустовка (кайма и выступ у каждого блока) — фирменные формы, их рисует процедурная текстура. Фото можно подмешать как зерно камня, но рисунок плит и рустовку оставить.

## Что стоит сейчас (уровень 1)

Яркость и оттенок каждого фото подогнаны цветом материала к прежнему цвету поверхности (`ProcTextures.photo_tint`), саму картинку не перерисовываем. «м» — сколько метров стены или пола на один повтор текстуры (`QuarterBuilder._tile`).

| Материал (`_m.*` в `western_street.gd`) | Текстура | м |
|---|---|---|
| `white` — белые богатые дома, колонны стои (`column`) | `white_stucco_02` | 2,5 |
| `plaster_a` — простая штукатурка; `plaster_in` — стены комнат; `roof` — крыши | `rough_plaster_03` | 2,5 / 2,5 / 3 |
| `plaster_b` — облупленная штукатурка | `white_rough_plaster` | 2,5 |
| `ochre` — охряная обмазка | `clay_block_wall` | 2,5 |
| `rubble` — бут бедных домов и цоколей | `rock_wall_04` | 3 |
| `rubble_in` — подвалы | `rustic_stone_wall_02` | 2,5 |
| `paving_dark` — боковые переулки | `rock_wall_06` | 2 |
| `earth` — дворы | `gravelly_sand` | 2 |
| `floor` — полы комнат | `dirt_floor` | 2 |
| `ceiling`, `cedar` — балки потолков, кедр стои | `dark_wooden_planks` | 2 |
| `wood` — леса, мостки, лотки; `door` — двери (+ процедурные полосы) | `old_wood_floor` | 3 / 1 |
| `gate` — ворота (+ бронзовые полосы) | `dark_wooden_planks` | 2,25 |
| `ashlar` (рустовка), `paving_main`, `gutter`, `lintel` — процедурные + зерно | `sandstone_blocks_04` | 4 / 2 |
| `slab` (гладкие плиты скалы Антонии) — процедурные + зерно | `rock_face_03` | 4 |
| `paving` (мостовая площади, подступенки) — процедурные + зерно | `rock_wall_03` | 4 |

Атлас предметов (`PropLibrary._atlas`, 64×64 на плитку — кусок фото в родном разрешении, ≈0,5–1,5 м): WOOD — `old_wood_floor`, WOOD_DARK — `dark_wooden_planks` (доски повёрнуты вдоль V), LINEN — `jogging_melange`, SHROUD — полосы + зерно `jogging_melange`, CLOTH_RED и CLOTH_OCHRE — `hessian_380` с каймой, CLOTH_BLUE — полосы + зерно `hessian_380`, STRAW и SACK — `hessian_230`, STONE — `sandstone_blocks_04`. Остальные плитки (глина, кровь, металл, зелень…) — процедурные.

Пока не использованы: `dry_ground_rocks`, `medieval_blocks_06`, `rock_wall_03` (только зерно), `rocky_terrain_03`, `terrazzo_tiles`, `white_sandstone_bricks_03`, `worn_brick_wall`, `yellow_stone_wall`, `hessian` в ткани навесов — по месту на следующих уровнях.

## Авторы (по желанию, CC0)

Все — Poly Haven: Rob Tuytel, Dimitrios Savva, Charlotte Baglioni, Amal Kumar и др. (автор каждой текстуры — на её странице polyhaven.com/a/<имя>).
