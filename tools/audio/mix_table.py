"""Баланс «у слушателя» (доделка 5-5): что получается из файла + db реестра + затухания по расстоянию.
python3 tools/audio/mix_table.py      — из корня проекта; печатает таблицу (она же попадает в docs/audio_levels.md).

Уровень у слушателя, дБFS = громкость файла + db из data/sounds.gd + затухание 3D:
  затухание = min(+3, 20·lg(unit / d)) + 20·lg(1 − d / range)      (так считает AudioStreamPlayer3D:
  обратное расстояние с потолком max_db = +3 дБ и плавный уход в ноль к max_distance).
Громкость файла: разовый звук — самый громкий кусок 120 мс (медиана по вариантам); петля — обычный уровень
(медиана окон 0,4 с) и «громкие места» (95-й процентиль) — в таблице «обычно…громко»; у напева святого
«громко» — это сама фраза, «обычно» — с паузами между фразами. Добавки из кода (шаг на бегу +1, напев в погоне +4,
за стеной −12…) сюда не входят — они в комментариях реестра и в скриптах.
Заглушки (synth) из Python не посчитать: их громкость замерена разово выгрузкой из Godot — SYNTH ниже.
"""
import sys, os, re
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_levels import AUDIO, REG, registry, decode, loud120

DIST = [1.5, 3.0, 6.0, 12.0, 15.0, 25.0]
## Заглушки: громкость самого громкого куска 120 мс, дБFS (SoundSynth, замер 5-5).
SYNTH = {'dogs': -13.4, 'distant_singing': -14.0, 'voice_messenger': -12.0, 'angel_chord': -11.7, 'angel_wings': -14.7,
         'tinnitus': -8.6, 'saint_chant': -13.4, 'whisper': -13.7, 'step_earth': -13.2, 'step_wood': -12.0, 'heartbeat': -9.6,
         'shard_break': -12.1, 'alarm_stone_fall': -14.9, 'alarm_door_creak': -17.2, 'alarm_distant_thud': -6.5,
         'alarm_shuffle': -11.8}


def att(d, unit, rng):
    if d >= rng:
        return None
    return min(3.0, 20 * np.log10(unit / d)) + 20 * np.log10(1 - d / rng)


def loop_levels(x, sr):
    p = (x ** 2).mean(1)
    n = int(0.4 * sr)
    c = np.concatenate([[0.0], np.cumsum(p)])
    m = 10 * np.log10((c[n:] - c[:-n])[::n // 4] / n + 1e-12)
    return float(np.percentile(m, 50)), float(np.percentile(m, 95))


def all_entries():
    """Все звуки реестра, включая заглушки: имя → {bus, db, unit, range, loop, files | synth}."""
    out = registry()
    src = open(REG, encoding='utf-8').read().split('const SOUNDS := {')[1].split('\n}\n')[0]
    for m in re.finditer(r'^\t"(\w+)": \{(.*?)\},?$', src, re.S | re.M):
        name, e = m.group(1), m.group(2)
        if name in out or '"synth"' not in e:
            continue
        num = lambda k: (float(re.search(r'"%s": (-?[\d.]+)' % k, e).group(1)) if re.search(r'"%s": (-?[\d.]+)' % k, e) else None)
        out[name] = {'synth': True, 'loop': '"loop": true' in e, 'db': num('db'), 'unit': num('unit'), 'range': num('range'),
                     'bus': re.search(r'"bus": "(\w+)"', e).group(1)}
    return out


def rows():
    out = []
    for name, e in all_entries().items():
        if e.get('synth'):
            typ, hi = SYNTH.get(name), None
        elif e['loop'] or name == 'ambient_drone':
            typ, hi = loop_levels(*decode(os.path.join(AUDIO, e['files'][0])))
        else:
            typ, hi = float(np.median([loud120(*decode(os.path.join(AUDIO, f))) for f in e['files']])), None
        out.append((name, e, typ, hi))
    return out


def fmt(v):
    return '—' if v is None else f'{v:.0f}'.replace('-', '−')


def table():
    L = ['| Звук | Шина | Файл: обычно / громко | db | unit / range | Не из точки | ' + ' | '.join(f'{d:g} м'.replace('.', ',') for d in DIST) + ' |',
         '|---|---|---|---|---|---|' + '---|' * len(DIST)]
    for name, e, typ, hi in rows():
        base = None if typ is None else typ + e['db']
        if e['unit'] is None:
            cells = [fmt(base) + (f' (до {fmt(hi + e["db"])})' if hi is not None else '')] + [''] * len(DIST)
            ur = '—'
        else:
            cells = ['']
            for d in DIST:
                a = att(d, e['unit'], e['range'])
                cells.append('·' if a is None or base is None else
                             fmt(base + a) + ('' if hi is None else '…' + fmt(hi + e['db'] + a)))
            ur = f'{e["unit"]:g} / {e["range"]:g}'
        L.append(f'| {name}{" *(заглушка)*" if e.get("synth") else ""} | {e["bus"]} | {fmt(typ)}{"" if hi is None else " / " + fmt(hi)} | '
                 f'{e["db"]:g} | {ur} | ' + ' | '.join(cells) + ' |')
    return L


if __name__ == '__main__':
    print('\n'.join(table()))
