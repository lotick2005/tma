"""Выравнивание записей по группам (доделка 5-5): варианты одного звука — к одной громкости, пик не выше −1 дБ,
тишина в начале разовых звуков срезана. Работает прямо по audio/*.ogg (исходников в репозитории нет):
декодирует, правит, кодирует обратно тем же кодеком, что pack2/pack3 (libvorbis, -q:a 4), частота и число каналов те же.
python3 tools/audio/level_groups.py [--dry]      — из корня проекта; нужны numpy и ffmpeg.

Правила:
  • группа — файлы имя_01…NN.ogg; мерило громкости — самый громкий кусок 120 мс (measure_levels.loud120);
  • цель группы — медиана её вариантов; если после этого чей-то пик выше PEAK_DB — вся группа тише целиком
    (без ограничителя: щелчок остаётся щелчком, как в pack2/pack3). Насколько группа сдвинулась — печатается:
    на столько же поправлен db в data/sounds.gd;
  • тишина в начале: до первого отсчёта громче −40 дБ от пика оставляем PRE_MS и короткий фейд;
  • петли и длинный фон не трогаем (щелчков на стыках замер не нашёл) — список LOOPS;
  • группа, в которой править нечего (разброс меньше SPREAD_OK, пик и начало в норме), не перекодируется:
    каждое перекодирование ogg — потеря качества; повторный запуск ничего не меняет;
  • особое: hammer_nail — три подгруппы (07–09 записаны «далёкими» нарочно); saint_chant_02 — всплески громче
    остального напева на 5–6 дБ прижаты (см. tame_bursts), сам напев не тронут.
"""
import sys, os, re, subprocess, tempfile
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_levels import AUDIO, decode, loud120, lead_ms, db

PEAK_DB = -1.5      # потолок пика до кодирования (vorbis добавляет до ~0,4 дБ)
PEAK_MAX = -1.0     # потолок после кодирования
SPREAD_OK = 1.0     # группа с разбросом меньше — уже ровная
MIN_GAIN = 0.3      # дБ: меньше — не трогаем
BURST_DB = -12.0    # saint_chant_02: всплески громче этого (120 мс) прижимаем
LEAD_MAX = 10.0     # мс
PRE_MS = 4.0
FADE_MS = 3.0
LOOPS = {'ambient_drone', 'wind_drone', 'market_crowd', 'dark_ambience', 'industrial_loop', 'birds_morning_mono',
         'crowd_panic', 'crowd_stampede', 'prayer_choir', 'prayer_choir_mono', 'saint_chant_01', 'saint_chant_02',
         'saint_mumble_01', 'saint_drone_01', 'ritual_far_01'}
SUBGROUPS = {'hammer_nail': [range(1, 7), range(7, 10), range(10, 16)]}


def group_key(name):
    m = re.match(r'(.+)_(\d\d)$', name)
    if not m:
        return name
    for k, rs in enumerate(SUBGROUPS.get(m.group(1), [])):
        if int(m.group(2)) in rs:
            return f'{m.group(1)}#{k + 1}'
    return m.group(1)


def trim(x, sr):
    if lead_ms(x, sr) <= LEAD_MAX:
        return x, False
    e = np.abs(x).max(1)
    i = int(np.argmax(e > e.max() * 10 ** (-40 / 20)))
    y = x[max(0, i - int(PRE_MS * sr / 1000)):].copy()
    n = int(FADE_MS * sr / 1000)
    y[:n] *= np.linspace(0, 1, n)[:, None]
    return y, True


def tame_bursts(x, sr, thr_db=-20.0, ratio=3.0, win=0.4):
    """Мягко прижать куски, где громкость (окно 0,4 с, по кругу — это петля) выше порога: выше порога — 3:1."""
    n = int(win * sr)
    p = (x ** 2).mean(1)
    pp = np.concatenate([p[-n:], p, p[:n]])
    c = np.concatenate([[0.0], np.cumsum(pp)])
    env = 10 * np.log10((c[n:] - c[:-n]) / n + 1e-12)[n // 2:n // 2 + len(p)]
    g = -np.maximum(env - thr_db, 0.0) * (1 - 1 / ratio)
    k = np.hanning(n // 2)
    gp = np.concatenate([g[-n:], g, g[:n]])
    g = np.convolve(gp, k / k.sum(), 'same')[n:n + len(p)]
    return x * (10 ** (g / 20))[:, None]


def encode(x, sr, path):
    with tempfile.NamedTemporaryFile(suffix='.raw') as t:
        t.write(x.astype(np.float32).tobytes())
        t.flush()
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(sr), '-ac', str(x.shape[1]), '-i', t.name,
                        '-c:a', 'libvorbis', '-q:a', '4', path], check=True)


def write_group(items, dry):
    """items: [(путь, сигнал, частота)]. Кодировать всю группу; если кодек поднял чей-то пик выше PEAK_MAX —
    вся группа чуть тише и ещё раз (от несжатого, не от ogg): варианты остаются ровными между собой."""
    extra = 0.0
    for _ in range(5):
        over = -99.0
        for path, x, sr in items:
            if dry:
                return extra
            encode(x * 10 ** (extra / 20), sr, path)
            over = max(over, db(np.abs(decode(path)[0]).max()) - PEAK_MAX)
        if over <= 0:
            return extra
        extra -= over + 0.15
    raise SystemExit(f'{items[0][0]}: пик не укладывается')


def main(dry):
    files = {}
    for f in sorted(os.listdir(AUDIO)):
        if f.endswith('.ogg'):
            files.setdefault(group_key(f[:-4]), []).append(f)
    for g, names in files.items():
        if 'saint_chant_02.ogg' in names:
            x, sr = decode(os.path.join(AUDIO, 'saint_chant_02.ogg'))
            y = tame_bursts(x, sr)
            if loud120(x, sr) > BURST_DB:
                print(f'saint_chant_02: всплески {loud120(x, sr):.1f} → {loud120(y, sr):.1f} дБ')
                write_group([(os.path.join(AUDIO, 'saint_chant_02.ogg'), y, sr)], dry)
        if any(f[:-4] in LOOPS for f in names):
            # Петли не трогаем; только если пик выше потолка — тише целиком (стык от этого не меняется)
            for f in names:
                x, sr = decode(os.path.join(AUDIO, f))
                pk = db(np.abs(x).max())
                if f[:-4] in LOOPS and pk > PEAK_MAX:
                    print(f'{f[:-4]}: пик {pk:.2f} дБ — тише на {pk - PEAK_DB:.1f} дБ')
                    write_group([(os.path.join(AUDIO, f), x * 10 ** ((PEAK_DB - pk) / 20), sr)], dry)
            continue
        items = []
        for f in names:
            x, sr = decode(os.path.join(AUDIO, f))
            y, cut = trim(x, sr)
            items.append([f, y, sr, cut, loud120(y, sr), db(np.abs(x).max())])
        l = [it[4] for it in items]
        spread = max(l) - min(l)
        target = float(np.median(l))
        gains = [(target - it[4]) if spread > SPREAD_OK else 0.0 for it in items]
        # Потолок пика: вся группа тише целиком
        over = max(db(np.abs(it[1]).max()) + gn for it, gn in zip(items, gains)) - PEAK_DB
        hot = max(it[5] for it in items) > PEAK_MAX
        shift = -over if over > 0 and (spread > SPREAD_OK or hot) else 0.0
        # Править нечего — группу не перекодируем; есть что — всю целиком (иначе поправка на пик кодека их разведёт)
        changed = sum(1 for it, gn in zip(items, gains) if abs(gn + shift) >= MIN_GAIN or it[3] or it[5] > PEAK_MAX)
        if changed:
            todo = [(os.path.join(AUDIO, it[0]), it[1] * 10 ** ((gn + shift) / 20), it[2]) for it, gn in zip(items, gains)
                    if len(items) > 1 and spread > SPREAD_OK or abs(gn + shift) >= MIN_GAIN or it[3] or it[5] > PEAK_MAX]
            shift += write_group(todo, dry)
            changed = len(todo)
            print(f'{g}: файлов {changed}/{len(items)}, разброс был {spread:.1f} дБ, громкость группы {target:.1f} → {target + shift:.1f} дБ '
                  f'(сдвиг {shift:+.1f}), срезано начало у {sum(1 for it in items if it[3])}')


if __name__ == '__main__':
    main('--dry' in sys.argv)
