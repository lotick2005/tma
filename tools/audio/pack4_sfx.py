"""Звуки четвёртого набора (27.11): треск огня (петля), лязг засова, скрип дерева под нагрузкой.
python3 pack4_sfx.py <папка с исходниками wav, имя = id с freesound> <папка audio/ игры> <out>
Результат — wav в <out>, в ogg кодирует ffmpeg. Источники и лицензии — audio/CREDITS.md."""
import sys, os, subprocess
import numpy as np, soundfile as sf
from scipy.signal import resample_poly, butter, sosfiltfilt

SRC, GAME_AUDIO, OUT = sys.argv[1:4]
os.makedirs(OUT, exist_ok=True)
SR = 44100

def load(i):
    x, r = sf.read(os.path.join(SRC, f'{i}.wav'), always_2d=True)
    x = x.mean(1).astype(np.float64)
    if r != SR:
        from math import gcd
        g = gcd(SR, r); x = resample_poly(x, SR // g, r // g)
    return x

def load_game(name):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(GAME_AUDIO, name), '-ar', str(SR), '-f', 'f32le', '-ac', '1', '-'], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)

def filt(x, kind, f, order=4):
    return sosfiltfilt(butter(order, f, kind, fs=SR, output='sos'), x)

def pitch(x, semi):
    r = 2 ** (semi / 12); return resample_poly(x, 1000, int(round(1000 * r)))

def env(x, w=0.02):
    n = max(1, int(w * SR)); return np.sqrt(np.convolve(x ** 2, np.ones(n) / n, 'same') + 1e-12)

def fade(y, fi=0.004, fo=0.06):
    y = y.copy(); a, b = int(fi * SR), int(fo * SR)
    if a: y[:a] *= np.linspace(0, 1, a)
    if b: y[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return y

def loud(x):
    n = min(len(x), int(0.12 * SR)); e = np.convolve(x ** 2, np.ones(n) / n, 'valid')
    return 10 * np.log10(e.max() + 1e-12)

def set_loud(x, db):
    y = x * 10 ** ((db - loud(x)) / 20); pk = np.abs(y).max()
    return y * min(1.0, 10 ** (-1 / 20) / pk)

def save(name, x, sr=SR):
    if sr != SR: x = resample_poly(x, sr, SR)
    sf.write(os.path.join(OUT, name + '.wav'), x.astype(np.float32), sr)
    print(name, f'{len(x)/sr:.2f} s', f'loud {loud(x if sr==SR else resample_poly(x,SR,sr)):.1f} dB', f'peak {20*np.log10(np.abs(x).max()):.1f}')

# Ориентиры громкости — уже выровненные звуки игры
ref_gate = loud(load_game('gate_rattle_01.ogg'))
ref_stone = loud(load_game('stone_drop_01.ogg'))
print('ref gate_rattle', round(ref_gate, 1), 'stone_drop', round(ref_stone, 1))

# 1. Треск огня: бесшовная петля 24 с, моно 32 кГц (3D у жаровен, огонь за скалой)
x = filt(filt(load('363093'), 'highpass', 90), 'lowpass', 12000)
seg = x[int(2.0 * SR):int(28.5 * SR)]
X = int(2.5 * SR); t = np.linspace(0, np.pi / 2, X)
body = seg[:-X].copy(); body[:X] = seg[-X:] * np.cos(t) + seg[:X] * np.sin(t)
# громкость по самому громкому куску 120 мс, пик не выше −1 дБ (треск — сплошные острые щелчки)
# мягкий лимитер: щелчки сжаты, тело треска слышно (RMS ≈ −34 дБ, пик −1 дБ)
lim = 10 ** (-1 / 20)
for g_db in np.arange(0, 30, 0.5):
    y = np.tanh(body / np.abs(body).max() * 10 ** (g_db / 20)) / np.tanh(10 ** (g_db / 20)) * lim
    if 10 * np.log10(np.mean(y ** 2)) >= -34: break
save('fire_crackle_loop', y, 32000)

# 2. Лязг засова: 4 удара с хвостом эха коридора, моно
x = filt(load('407320'), 'highpass', 70)
for n, t0 in enumerate([3.40, 6.69, 8.21, 9.39], 1):
    y = x[int((t0 - 0.03) * SR):int((t0 + 0.75) * SR)]
    e = env(y, 0.005); i = int(np.argmax(e > e.max() * 0.1)); y = y[max(0, i - int(0.004 * SR)):]
    save(f'bolt_clank_{n:02d}', set_loud(fade(y, fo=0.25), ref_gate))

# 3. Скрип дерева под нагрузкой: самые длинные скрипы, опущены на 4–6 полутонов (тяжёлая балка, крест)
x = filt(filt(load('851663'), 'highpass', 60), 'lowpass', 9000)
e = 20 * np.log10(env(x, 0.15)); thr = np.median(e) + 9
on = e > thr; d = np.flatnonzero(np.diff(on.astype(int)))
if on[0]: d = np.r_[0, d]
if on[-1]: d = np.r_[d, len(on) - 1]
segs = [(d[k] / SR, d[k + 1] / SR) for k in range(0, len(d) - 1, 2)]
segs = [(a, b) for a, b in segs if 0.5 <= b - a <= 4.0]
segs = sorted(segs, key=lambda s: -(s[1] - s[0]))[:6]
segs.sort()
segs = segs[1:]  # первый (5,0–5,95 с) — отдельные щелчки шагов, не скрип: не берём
print('creak segments', [(round(a, 2), round(b, 2)) for a, b in segs])
for n, (a, b) in enumerate(segs, 1):
    y = x[int(max(0, a - 0.05) * SR):int((b + 0.25) * SR)]
    y = pitch(y, -(4 + (n % 3)))
    save(f'wood_strain_{n:02d}', set_loud(fade(y, fi=0.02, fo=0.2), ref_stone - 2))
