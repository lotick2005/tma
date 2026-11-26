"""Звуки «очнулся» по замерам (доделка 6, пункт 4) и баланс шагов героя (пункт 7).
python3 tools/audio/wake_levels.py      — из корня проекта.

«Было» — всё разом: вдох сразу, кряхтение через 1,6 с, гул и ветер сразу (так было в Awaken).
«Стало» — data/sounds.gd WAKE: вдох сразу (gasp_db), кряхтение через groan_delay с с нарастанием groan_rise с (groan_db),
гул и ветер — через drone_delay с с нарастанием drone_rise с.
Считается по смеси файлов (22 кГц, моно) за первые 6 с, гул берётся с 40 случайных мест 10-минутного файла;
берём медиану: пик смеси, дБFS, и громкость самого громкого куска 120 мс у каждого из трёх звуков (вдох, кряхтение,
гул с ветром). «Выше двух других вместе» — разница в дБ между звуком и суммой мощностей двух других (должна быть < 0).
Шаги: уровень у слушателя на 1,5 м от ног (файл + db реестра + затухание + добавка режима из hero_audio.gd)
против фона тьмы (ambient_drone, обычный уровень, дБFS из tools/audio/mix_table.py).
"""
import sys, os, re, subprocess
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_levels import AUDIO, REG, registry, loud120, decode
from mix_table import loop_levels, att

SR = 22050
WINDOW = 6.0
reg = registry()
src = open(REG, encoding='utf-8').read()
WAKE = {k: float(v) for k, v in re.findall(r'"(\w+)": (-?[\d.]+),', src.split('const WAKE := {')[1].split('}')[0])}


def load(name, which=0):
    f = reg[name]['files'][which]
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(AUDIO, f), '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64), reg[name]['db']


def place(sig, t0, db, rise=0.0, fade=0.0, n=int(14 * SR)):
    out = np.zeros(n)
    i0 = int(t0 * SR)
    seg = sig[:max(0, n - i0)]
    g = np.full(len(seg), 10 ** (db / 20))
    t = np.arange(len(seg)) / SR
    if rise > 0:      # AudioManager.play_2d "rise": с −30 дБ до полной по синусу
        g = g * 10 ** (-30 * (1 - np.sin(np.minimum(t / rise, 1.0) * np.pi / 2)) / 20)
    if fade > 0:      # слой фона: линейный рост 0 → 1
        g = g * np.minimum(t / fade, 1.0)
    out[i0:i0 + len(seg)] = seg * g
    return out


def d(x):
    return 20 * np.log10(max(x, 1e-12))


def l120(x):
    n = int(0.12 * SR)
    c = np.concatenate([[0], np.cumsum(x ** 2)])
    return 10 * np.log10(((c[n:] - c[:-n]) / n).max() + 1e-12)


def run(kind):
    gasp, gdb = load('gasp_wake')
    groan, rdb = load('wake_groan', 1)
    amb, adb = load('ambient_drone')
    wind, wdb = load('wind_drone')
    wind = np.tile(wind, 4)
    rng = np.random.default_rng(5)
    peaks, levels = [], []
    for _ in range(40):
        off = rng.uniform(0, len(amb) / SR - 40)
        a = amb[int(off * SR):]
        if kind == 'before':
            parts = [place(gasp, 0, gdb), place(groan, 1.6, rdb), place(a, 0, adb) + place(wind, 0, wdb)]
        else:
            parts = [place(gasp, 0, gdb + WAKE['gasp_db']),
                     place(groan, WAKE['groan_delay'], rdb + WAKE['groan_db'], rise=WAKE['groan_rise']),
                     place(a, WAKE['drone_delay'], adb, fade=WAKE['drone_rise']) + place(wind, WAKE['drone_delay'], wdb, fade=WAKE['drone_rise'])]
        win = slice(0, int(WINDOW * SR))
        peaks.append(d(np.abs(sum(parts)[win]).max()))
        levels.append([l120(p[win]) for p in parts])
    return np.median(peaks), np.median(levels, axis=0)


def dominance(lv):
    p = 10 ** (np.array(lv) / 10)
    return [10 * np.log10(p[i] / (p.sum() - p[i])) for i in range(3)]


def wake():
    print('«Очнулся»: окно %.0f с от момента, когда чернота уходит; медиана по 40 местам гула' % WINDOW)
    print('WAKE:', WAKE)
    out = {}
    for kind in ('before', 'after'):
        pk, lv = run(kind)
        out[kind] = pk
        dm = dominance(lv)
        print('  %-6s пик смеси %6.1f дБFS | вдох %6.1f, кряхтение %6.1f, гул+ветер %6.1f | выше двух других вместе: %s'
              % ('было' if kind == 'before' else 'стало', pk, lv[0], lv[1], lv[2], ', '.join('%+.1f' % x for x in dm)))
    print('  общий пик: %+.1f дБ к прежнему' % (out['after'] - out['before']))


def steps():
    print('Шаги героя и дыхание у слушателя (1,5 м от ног), дБFS; фон тьмы — обычный уровень ambient_drone')
    amb, _ = decode(os.path.join(AUDIO, reg['ambient_drone']['files'][0]))
    bg, _hi = loop_levels(amb, _)
    bg += reg['ambient_drone']['db']
    adds = {'step_stone': {'ходьба': 0.0, 'присед': -7.0}, 'step_stone_run': {'бег': 1.0}, 'step_stairs': {'ступени (ходьба)': 0.0, 'ступени (бег)': 1.0}}
    print('  фон тьмы %.1f; шаги не выше %.1f' % (bg, bg + 6))
    worst = -99
    for name, modes in adds.items():
        e = reg[name]
        file_db = float(np.median([loud120(*decode(os.path.join(AUDIO, f))) for f in e['files']]))
        for mode, add in modes.items():
            lv = file_db + e['db'] + att(1.5, e['unit'], e['range']) + add
            worst = max(worst, lv)
            print('  %-16s %-18s %6.1f  (над фоном %+.1f)' % (name, mode, lv, lv - bg))
    for name in ('breath_run', 'breath_tired', 'breath_calm'):
        e = reg[name]
        file_db = float(np.median([loud120(*decode(os.path.join(AUDIO, f))) for f in e['files']]))
        print('  %-16s %-18s %6.1f  (тише самых громких шагов на %.1f)' % (name, 'дыхание', file_db + e['db'], worst - (file_db + e['db'])))


if __name__ == '__main__':
    wake()
    steps()
