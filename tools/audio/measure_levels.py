"""Замер громкости всех звуков игры (доделка 5-5). Слушать нельзя — меряем.
python3 tools/audio/measure_levels.py [--json out.json] [--md docs/audio_levels.md] [--before before.json]
Запускать из корня проекта. Нужны numpy и ffmpeg.

Для каждого ogg из audio/ (помечено, есть ли он в реестре data/sounds.gd):
  loud  — громкость самого громкого куска 120 мс, дБFS (то же мерило, что в pack2/pack3: годится и для щелчка в 50 мс);
  lufs  — интегральная громкость по EBU R128 (только если файл длиннее 1 с; у коротких она не определена);
  rms   — среднеквадратичная по всему файлу, дБFS;
  peak  — пик отсчёта, дБFS;
  lead  — тишина в начале, мс (до первого отсчёта громче −40 дБ от пика);
  seam  — у петель: скачок на стыке конец → начало, во сколько раз он больше обычного шага сигнала рядом
          (больше ~3 и сам скачок громче −50 дБFS — щелчок), и разница громкости 100 мс до и после стыка, дБ.
"""
import sys, os, re, json, subprocess, argparse
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO = os.path.join(ROOT, 'audio')
REG = os.path.join(ROOT, 'data', 'sounds.gd')
LEAD_THR_DB = -40.0
SEAM_RATIO = 3.0
SEAM_MIN_DB = -50.0


def db(v):
    return 20 * np.log10(max(float(v), 1e-9))


def decode(path):
    """ogg → (float64 [n, каналов], частота)."""
    info = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=sample_rate,channels',
                           '-of', 'csv=p=0', path], capture_output=True, text=True).stdout.strip().split(',')
    sr, ch = int(info[0]), int(info[1])
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-'], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, ch).astype(np.float64), sr


def loud120(x, sr):
    """Громкость самого громкого куска 120 мс, дБFS (каналы — по мощности в среднем)."""
    p = (x ** 2).mean(1)
    n = min(len(p), int(0.12 * sr))
    c = np.concatenate([[0.0], np.cumsum(p)])
    return 10 * np.log10(((c[n:] - c[:-n]) / n).max() + 1e-12)


def lufs(path):
    out = subprocess.run(['ffmpeg', '-v', 'info', '-nostats', '-i', path, '-af', 'ebur128', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    try:
        return float(out.split('Integrated loudness:')[1].split('I:')[1].split('LUFS')[0])
    except (IndexError, ValueError):
        return None


def lead_ms(x, sr):
    e = np.abs(x).max(1)
    return 1000.0 * int(np.argmax(e > e.max() * 10 ** (LEAD_THR_DB / 20))) / sr


def seam(x, sr):
    """Стык петли: (скачок / обычный шаг рядом, скачок дБFS, разница громкости до и после стыка дБ)."""
    n = int(0.02 * sr)
    jump = float(np.abs(x[0] - x[-1]).max())
    near = np.concatenate([np.abs(np.diff(x[:n], axis=0)), np.abs(np.diff(x[-n:], axis=0))]).max()
    m = int(0.1 * sr)
    lv = 10 * np.log10((x[:m] ** 2).mean() + 1e-12) - 10 * np.log10((x[-m:] ** 2).mean() + 1e-12)
    return jump / max(float(near), 1e-9), db(jump), float(lv)


def registry():
    """data/sounds.gd → {имя звука: {"files": [...], "loop": bool, "db":, "unit":, "range":, "bus":}}; заглушки пропускаем."""
    src = open(REG, encoding='utf-8').read()
    consts = {m.group(1): re.findall(r'res://audio/([\w.]+)', m.group(2))
              for m in re.finditer(r'const (_\w+) := \[(.*?)\]', src, re.S)}
    body = src.split('const SOUNDS := {')[1].split('\n}\n')[0]
    out = {}
    for m in re.finditer(r'^\t"(\w+)": \{(.*?)\},?$', body, re.S | re.M):
        name, e = m.group(1), m.group(2)
        f = re.search(r'"file": (_\w+|"res://audio/[\w.]+")', e)
        if not f:
            continue
        files = consts[f.group(1)] if f.group(1).startswith('_') else [f.group(1).strip('"').split('/')[-1]]
        num = lambda k: (float(re.search(r'"%s": (-?[\d.]+)' % k, e).group(1)) if re.search(r'"%s": (-?[\d.]+)' % k, e) else None)
        out[name] = {'files': files, 'loop': '"loop": true' in e, 'db': num('db'), 'unit': num('unit'), 'range': num('range'),
                     'bus': re.search(r'"bus": "(\w+)"', e).group(1)}
    return out


def group_of(fname):
    """steps_stone_07.ogg → steps_stone; файл без номера — сам себе группа."""
    m = re.match(r'hammer_nail_(\d\d)', fname)
    if m:  # три подгруппы: 07–09 записаны «далёкими» нарочно (level_groups.SUBGROUPS)
        return 'hammer_nail ' + ('01–06' if int(m.group(1)) <= 6 else '07–09' if int(m.group(1)) <= 9 else '10–15')
    return re.sub(r'_\d\d$', '', fname[:-4])


def measure_all():
    reg = registry()
    used = {}
    for name, e in reg.items():
        for f in e['files']:
            used.setdefault(f, []).append(name)
    loops = {f for e in reg.values() if e['loop'] for f in e['files']}
    rows = {}
    for f in sorted(os.listdir(AUDIO)):
        if not f.endswith('.ogg'):
            continue
        p = os.path.join(AUDIO, f)
        x, sr = decode(p)
        r = {'group': group_of(f), 'sounds': used.get(f, []), 'ch': x.shape[1], 'sr': sr, 'len': len(x) / sr,
             'loud': float(loud120(x, sr)), 'rms': float(10 * np.log10((x ** 2).mean() + 1e-12)), 'peak': db(np.abs(x).max()),
             'lufs': lufs(p) if len(x) / sr >= 1.0 else None, 'loop': f in loops, 'lead': lead_ms(x, sr)}
        if r['loop']:
            ratio, jdb, lv = seam(x, sr)
            r.update(seam_ratio=ratio, seam_db=jdb, seam_level=lv, click=bool(ratio > SEAM_RATIO and jdb > SEAM_MIN_DB))
        rows[f] = r
    return rows


def groups(rows):
    g = {}
    for f, r in rows.items():
        g.setdefault(group_of(f), []).append(f)
    return g


def summary(rows):
    """По группам: число файлов, медиана и разброс loud, макс. пик, макс. тишина в начале, щелчки."""
    out = {}
    for g, files in groups(rows).items():
        l = [rows[f]['loud'] for f in files]
        out[g] = {'n': len(files), 'loud': float(np.median(l)), 'spread': float(max(l) - min(l)),
                  'peak': max(rows[f]['peak'] for f in files), 'lead': max(rows[f]['lead'] for f in files),
                  'loop': any(rows[f]['loop'] for f in files), 'clicks': sum(1 for f in files if rows[f].get('click')),
                  'used': any(rows[f]['sounds'] for f in files), 'len': float(np.mean([rows[f]['len'] for f in files]))}
    return out


def fmt(v, nd=1):
    return '—' if v is None else f'{v:.{nd}f}'.replace('.', ',')


def write_md(path, rows, before=None):
    s = summary(rows)
    L = ['# Громкость звуков: замер', '',
         'Собрано `python3 tools/audio/measure_levels.py --md docs/audio_levels.md` (не править руками).',
         'Выравнивание файлов — `tools/audio/level_groups.py`. Баланс между звуками — `db`, `unit`, `range` в `data/sounds.gd`.', '',
         '- **громк.** — самый громкий кусок 120 мс, дБFS; у группы — медиана по вариантам, **разброс** — от самого тихого до самого громкого варианта;',
         '- **LUFS** — интегральная громкость (только файлы длиннее 1 с);',
         '- **начало** — тишина перед звуком, мс; **стык** — у петель: скачок на стыке относительно обычного шага сигнала (×) и перепад громкости через стык, дБ. Щелчок — скачок больше ×3 и громче −50 дБFS.',
         '- «нет в реестре» — файл лежит в `audio/`, но в `data/sounds.gd` пока не вписан (звуки будущих этапов).', '']
    if before:
        b = summary(before)
        L += ['## Было → стало (по группам)', '',
              '| Группа | Файлов | Громк. было → стало | Разброс было → стало | Пик было → стало | Начало, мс было → стало | Щелчков на стыке |',
              '|---|---|---|---|---|---|---|']
        for g in sorted(s):
            if g not in b:
                continue
            x, y = b[g], s[g]
            ch = lambda k, nd=1: (fmt(x[k], nd) if abs(x[k] - y[k]) < 0.05 else f'{fmt(x[k], nd)} → **{fmt(y[k], nd)}**')
            click = f'{x["clicks"]} → {y["clicks"]}' if y['loop'] else '—'
            L.append(f'| {g}{"" if y["used"] else " *(нет в реестре)*"} | {y["n"]} | {ch("loud")} | {ch("spread")} | {ch("peak")} | {ch("lead", 0)} | {click} |')
        L.append('')
    L += ['## Все файлы', '',
          '| Файл | Звук в реестре | Кан. | Длина, с | Громк. | LUFS | RMS | Пик | Начало, мс | Петля: стык |',
          '|---|---|---|---|---|---|---|---|---|---|']
    for f, r in rows.items():
        sm = '—'
        if r['loop']:
            sm = f'×{fmt(r["seam_ratio"])}, {fmt(r["seam_level"])} дБ' + (' **щелчок**' if r['click'] else '')
        L.append(f'| {f} | {", ".join(r["sounds"]) or "*нет*"} | {r["ch"]} | {fmt(r["len"], 2)} | {fmt(r["loud"])} | {fmt(r["lufs"])} | '
                 f'{fmt(r["rms"])} | {fmt(r["peak"])} | {fmt(r["lead"], 0)} | {sm} |')
    import mix_table
    L += ['', '## Баланс у слушателя', '',
          'Что получается из файла + `db` реестра + затухания по расстоянию (`tools/audio/mix_table.py`), дБFS. '
          'У петель — «обычно…громко» (у напева «громко» — сама фраза). Добавки из кода (бег +1, присед −7, напев в погоне +4, '
          'ищет −7, за стеной −12) сюда не входят. «·» — дальше дальности, не слышно.', ''] + mix_table.table()
    open(path, 'w', encoding='utf-8').write('\n'.join(L) + '\n')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--json')
    ap.add_argument('--md')
    ap.add_argument('--before')
    a = ap.parse_args()
    rows = measure_all()
    if a.json:
        json.dump(rows, open(a.json, 'w'), indent=1)
    if a.md:
        write_md(a.md, rows, json.load(open(a.before)) if a.before else None)
    for g, v in sorted(summary(rows).items()):
        print(f'{g:24s} n={v["n"]:2d} loud={v["loud"]:6.1f} spread={v["spread"]:4.1f} peak={v["peak"]:6.1f} lead={v["lead"]:5.0f} '
              f'len={v["len"]:6.2f} {"LOOP" if v["loop"] else ""} {"CLICK" if v["clicks"] else ""} {"" if v["used"] else "(unused)"}')
