# Quaternius — Universal Animation Library (Standard, бесплатная версия)

- Источник: https://quaternius.com/packs/universalanimationlibrary.html (itch.io: https://quaternius.itch.io/universal-animation-library)
- Лицензия: **CC0 1.0** (общественное достояние) — можно всё, указывать автора не обязательно (в титрах всё равно пишем «Quaternius»). Текст — `License.txt`.
- Файл: `UAL1_Standard.glb` (версия Unreal-Godot, без root motion). Свой скелет Quaternius (не Mixamo) — для ретаргета нужен отдельный `BoneMap`.
- Исключение из правила «исходники в репозиторий не кладём»: файл CC0 и небольшой (7,6 МБ), лежит в `tools/` (Godot его не видит, в браузерную сборку не попадает), чтобы облачные сессии могли его взять.

43 анимации: A_TPose, Crouch_Fwd_Loop, Crouch_Idle_Loop, Dance_Loop, Death01, Driving_Loop, Fixing_Kneeling, Hit_Chest, Hit_Head, Idle_Loop, Idle_Talking_Loop, Idle_Torch_Loop, Interact, Jog_Fwd_Loop, Jump_Land, Jump_Loop, Jump_Start, PickUp_Table, Pistol_Aim_Down, Pistol_Aim_Neutral, Pistol_Aim_Up, Pistol_Idle_Loop, Pistol_Reload, Pistol_Shoot, Punch_Cross, Punch_Jab, Push_Loop, Roll, Sitting_Enter, Sitting_Exit, Sitting_Idle_Loop, Sitting_Talking_Loop, Spell_Simple_Enter, Spell_Simple_Exit, Spell_Simple_Idle_Loop, Spell_Simple_Shoot, Sprint_Loop, Swim_Fwd_Loop, Swim_Idle_Loop, Sword_Attack, Sword_Idle, Walk_Formal_Loop, Walk_Loop.

Полезные для игры: `Fixing_Kneeling` (на коленях, руки работают у земли — основа для старика с камнем), `Death01` (ещё одно падение), `Hit_Head`, `Hit_Chest` (реакции в давке), `Push_Loop` (давка), `Sword_Attack` (удар сверху — можно взять руку для удара камнем), `Sitting_*` (горожане сидят), `Interact`, `PickUp_Table`.
