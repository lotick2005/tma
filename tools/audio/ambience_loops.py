"""Фоны для «Тьмы»: бесшовные петли, громкость по LUFS, wav -> out/ (в ogg кодирует ffmpeg)."""
import sys, os, io, subprocess
import numpy as np, soundfile as sf
from math import gcd
from scipy.signal import resample_poly, butter, sosfiltfilt

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
SR = 44100


def load(name):
    p = os.path.join(SRC, name)
    if p.endswith('.mp3'):
        raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'wav', '-'], capture_output=True).stdout
        x, r = sf.read(io.BytesIO(raw), always_2d=True)
    else:
        x, r = sf.read(p, always_2d=True)
    assert r == SR, r
    return x.astype(np.float64)


def filt(x, kind, f, order=4):
    return sosfiltfilt(butter(order, f, kind, fs=SR, output='sos'), x, axis=0)


def rate(x, r):
    """Сменить скорость (и высоту) в r раз."""
    n = 1000
    return resample_poly(x, n, int(round(n * r)), axis=0)


def seamless(x, xf):
    """Хвост плавно перетекает в начало: результат короче на xf секунд и зацикливается без шва."""
    n = int(xf * SR)
    head, body, tail = x[:n], x[n:-n] if n else x, x[-n:]
    t = np.linspace(0, 1, n)[:, None]
    # равномощный кроссфейд (сигналы некоррелированы)
    mix = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return np.concatenate([body, mix])


def circ(x, start, length):
    idx = (np.arange(length) + start) % len(x)
    return x[idx]


def save(name, x):
    pk = np.abs(x).max()
    if pk > 0.89:
        x = x * (0.89 / pk)
    sf.write(os.path.join(OUT, name + '.wav'), x.astype(np.float32), SR, subtype='FLOAT')
    print(f'  {name}: {len(x) / SR:.1f} s, {x.shape[1]} ch')


# --- базар: из 24 с делаем ~74 с непонятного гомона ---------------------------------------
print('базар (Vital_Sounds)')
m = load('market_592433.mp3')
m = filt(m, 'hp', 70)


def tame(x, win, over_db, band=None):
    """Срезать всплески громче медианы на over_db: приметные звуки (лязг, выкрик) не узнаются при повторе."""
    y = filt(x, 'hp', band) if band else x
    n = int(win * SR)
    e = np.sqrt(np.convolve((y ** 2).mean(1), np.ones(n) / n, 'same')) + 1e-9
    db = 20 * np.log10(e)
    lim = np.median(db) + over_db
    g = 10 ** (np.minimum(0, lim - db) / 20)
    g = np.convolve(g, np.ones(n) / n, 'same')[:, None]
    return x - y + y * g if band else x * g


m = tame(m, 0.05, 4.0, band=3000)   # лязг и звон в верхах
m = tame(m, 0.3, 5.0)               # громкие выкрики и удары
m = seamless(m, 1.5)                      # 23.1 с, зацикливается
L = int(74 * SR)
layers = []
for k, (r, off, lp) in enumerate([(1.0, 0.0, None), (0.955, 7.7, 3200), (1.045, 15.4, 3600)]):
    y = rate(m, r) if r != 1.0 else m
    if lp:
        y = filt(y, 'lp', lp)
    y = circ(y, int(off * SR), L + int(2 * SR))
    if k == 2:
        y = y[:, ::-1]                    # каналы местами: голоса из разных мест
    layers.append(y)
# три куска записи звучат одновременно: отдельные слова тонут в гомоне
bed = layers[0] * 0.62 + layers[1] * 0.58 + layers[2] * 0.55
save('market_crowd', seamless(bed, 2.0))

# --- птицы: убираем машины и самолёт (всё ниже ~1,6 кГц), моно для 3D ----------------------
print('птицы (solarpsychedelic)')
b = load('birds_876938.wav').mean(axis=1, keepdims=True)[int(78 * SR):int(180 * SR)]  # 78–180 с: меньше всего машин
b = filt(b, 'hp', 1600, order=8)
b = filt(b, 'lp', 11000)
save('birds_morning_mono', seamless(b, 2.0))

# --- ветер-дрон: середина без фейдов, бесшовно -------------------------------------------
print('ветер (cat-fox_alex)')
w = load('wind_876947.wav')[int(1.0 * SR):int(28.0 * SR)]
save('wind_drone', seamless(w, 3.0))

# --- тёмный фон: середина без фейдов, бесшовно --------------------------------------------
print('тёмный фон (Daniel_Brooks)')
d = load('darkamb_876811.mp3')[int(5.0 * SR):int(62.5 * SR)]
save('dark_ambience', seamless(d, 3.0))

# --- индастриал-петля: ровно 32 доли при 107 уд/мин ----------------------------------------
print('индастриал (looplicator)')
i = load('industrial_877426.wav')
beats = int(round(len(i) / SR / (60 / 107)))
n = int(round(beats * 60 / 107 * SR))
print('   долей', beats, 'сэмплов', n, 'в файле', len(i))
i = i[:n] if len(i) >= n else np.pad(i, ((0, n - len(i)), (0, 0)))
save('industrial_loop', seamless(i, 0.012))  # 12 мс на стыке — без щелчка
