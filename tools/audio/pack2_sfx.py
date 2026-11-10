"""Звуки второго набора (ноябрь): нарезка разовых звуков, напевы святых, сборная «паника» и «топот».
python3 pack2_sfx.py <папка с исходниками в wav 44,1 кГц, имя = id с freesound> <папка audio/ игры> <out>
Результат — wav в <out>; в ogg кодирует ffmpeg (см. конец файла). Источники и лицензии — audio/CREDITS.md."""
import sys, os, subprocess
import numpy as np, soundfile as sf
from scipy.signal import resample_poly, butter, sosfiltfilt, fftconvolve

SRC, GAME_AUDIO, OUT = sys.argv[1:4]
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(33)


def load(i, ch=None):
    x, r = sf.read(os.path.join(SRC, f'{i}.wav'), always_2d=True)
    assert r == SR
    x = x.astype(np.float64)
    return x[:, ch] if ch is not None else x.mean(1)


def load_game(name):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(GAME_AUDIO, name), '-ar', str(SR), '-f', 'f32le', '-ac', '2', '-'],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


def filt(x, kind, f, order=4):
    return sosfiltfilt(butter(order, f, kind, fs=SR, output='sos'), x, axis=0)


def pitch(x, semi):
    """Высота и скорость вместе (как у плёнки): +12 — вдвое выше и короче."""
    r = 2 ** (semi / 12)
    return resample_poly(x, 1000, int(round(1000 * r)), axis=0)


def cut(x, t0, t1, fi=0.003, fo=0.04):
    y = x[max(0, int(t0 * SR)):int(t1 * SR)].copy()
    a, b = int(fi * SR), int(fo * SR)
    if a:
        y[:a] *= np.linspace(0, 1, a)
    if b:
        y[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return y


def onset(x, thr_db=-30):
    """Обрезать тишину перед звуком (оставить 4 мс)."""
    e = np.abs(x)
    i = np.argmax(e > e.max() * 10 ** (thr_db / 20))
    return x[max(0, i - int(0.004 * SR)):]


def loud(x):
    """Громкость самого громкого куска 120 мс, дБ."""
    n = min(len(x), int(0.12 * SR))
    e = np.convolve(x ** 2, np.ones(n) / n, 'valid')
    return 10 * np.log10(e.max() + 1e-12)


def norm(x, target_db, peak_db=-1.0):
    """К общей громкости; если пик выше потолка — тише целиком (без ограничителя: щелчки остаются щелчками)."""
    x = x * 10 ** ((target_db - loud(x)) / 20)
    pk = np.abs(x).max()
    lim = 10 ** (peak_db / 20)
    return x * (lim / pk) if pk > lim else x


def mix(parts, length=None):
    """parts: [(сигнал, время начала с, усиление дБ)] → сумма."""
    n = length or max(int(t * SR) + len(s) for s, t, g in parts)
    y = np.zeros(n)
    for s, t, g in parts:
        a = int(t * SR)
        y[a:a + len(s)] += s[:n - a] * 10 ** (g / 20)
    return y


def save(name, x, sr=SR):
    if sr != SR:
        x = resample_poly(x, sr, SR, axis=0)
    sf.write(os.path.join(OUT, name + '.wav'), x.astype(np.float32), sr, subtype='FLOAT')
    ch = 1 if x.ndim == 1 else x.shape[1]
    print(f'{name}: {len(x) / sr:.2f} с, {ch} к, пик {20 * np.log10(np.abs(x).max() + 1e-9):.1f} дБ')


def group(prefix, items, target_db, sr=SR):
    for k, x in enumerate(items, 1):
        save(f'{prefix}_{k:02d}', norm(x, target_db), sr)


def lufs(x, sr):
    p = os.path.join(OUT, '_tmp.wav')
    sf.write(p, x.astype(np.float32), sr, subtype='FLOAT')
    out = subprocess.run(['ffmpeg', '-v', 'info', '-i', p, '-af', 'ebur128', '-f', 'null', '-'], capture_output=True, text=True).stderr
    os.remove(p)
    return float(out.split('Integrated loudness:')[1].split('I:')[1].split('LUFS')[0])


def to_lufs(x, target, sr=SR):
    x = x * 10 ** ((target - lufs(x, sr)) / 20)
    pk = np.abs(x).max()
    return x * (0.89 / pk) if pk > 0.89 else x


def seamless(x, xf):
    n = int(xf * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    t = np.linspace(0, 1, n)
    t = t[:, None] if x.ndim == 2 else t
    return np.concatenate([body, tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)])


def room(x, sec, wet, seed=1):
    """Простое эхо двора: свёртка с затухающим шумом."""
    r = np.random.default_rng(seed)
    n = int(sec * SR)
    ir = r.standard_normal(n) * np.exp(-np.linspace(0, 6.9, n))
    ir = filt(ir, 'lp', 5000)
    ir /= np.sqrt((ir ** 2).sum())
    return x + wet * fftconvolve(x, ir)[:len(x)]


# ───────────── глина: кувшин бьётся ─────────────
pots = [onset(load(540336)), onset(load(540337)), onset(load(540339)), onset(load(810043)),
        cut(onset(load(810041)), 0, 2.4, fo=0.5), cut(onset(load(810042)), 0, 2.6, fo=0.5)]
group('pot_break', [filt(p, 'hp', 90) for p in pots], -9)

# кувшин качается и катится (пластик → ниже и глуше, ближе к глине)
w1 = cut(load(101549), 0.13, 0.80, fo=0.08)
w2 = cut(load(732124), 0.11, 0.90, fo=0.08)
group('pot_wobble', [filt(pitch(w1, -5), 'lp', 5500), w2, filt(pitch(w2, -4), 'lp', 6000)], -16)

# ───────────── камень ─────────────
peb = load(734669)
stones = [cut(load(655350), 0.66, 1.25, fo=0.15)] + [cut(peb, a - 0.006, a + d + 0.22, fo=0.12)
                                                      for a, d in ((0.19, 0.21), (1.47, 0.39), (4.23, 0.18), (5.48, 0.22))]
group('stone_drop', [filt(s, 'hp', 70) for s in stones], -12)

deb1, deb2 = load(554148), load(550342)
rub = [onset(load(437602)), cut(deb1, 0.0, 2.5, fo=0.3), cut(deb1, 4.0, 5.7, fo=0.3), cut(deb1, 7.98, 9.2, fo=0.2),
       cut(deb2, 0.0, 1.6, fo=0.3), cut(deb2, 15.22, 16.9, fo=0.3), cut(deb2, 25.03, 26.8, fo=0.3)]
group('rubble_fall', [filt(r, 'hp', 60) for r in rub], -11)

# ───────────── дерево ─────────────
wb = load(543705)
clacks = [onset(load(870350))] + [cut(wb, a - 0.004, a + 0.28, fo=0.1) for a in (13.62, 14.15, 17.56, 21.80)]
group('wood_clack', clacks, -12)
# табурет падает: три удара ниже тоном — упал, подпрыгнул, лёг
falls = []
for a, b, c, gap in ((1, 2, 3, 0.14), (3, 4, 1, 0.11), (2, 0, 4, 0.17)):
    falls.append(filt(mix([(pitch(clacks[a], -9), 0, 0), (pitch(clacks[b], -6), gap, -5), (pitch(clacks[c], -11), gap * 2.6, -11)]), 'lp', 7000))
group('wood_fall', falls, -11)
save('wood_drag_01', norm(cut(load(147009), 0.08, 1.15, fo=0.12), -13))

# ───────────── молоток по гвоздю ─────────────
nail = load(850175)
hits = [filt(pitch(cut(nail, a - 0.004, a + 0.44, fo=0.12), -3), 'hp', 70) for a in (5.66, 6.20, 6.72, 13.99, 14.58, 16.36)]
group('hammer_nail', hits, -9)

# ───────────── крики ─────────────
scr = load(325548)
screams = [cut(scr, a - 0.03, a + d + 0.2, fo=0.15) for a, d in ((1.07, 1.82), (4.67, 2.15), (10.33, 1.64), (14.10, 2.19), (19.18, 2.49), (24.50, 2.34))]
group('scream_man', [filt(s, 'hp', 90) for s in screams], -10)
pain = load(876075)
group('scream_pain', [filt(cut(pain, 3.86, 6.6, fo=0.25), 'hp', 90), filt(load(401211), 'hp', 90)], -11)
group('groan_pain', [cut(pain, 0.55, 1.0, fo=0.1), cut(pain, 2.57, 3.25, fo=0.12)], -14)

# ───────────── ворота ─────────────
gate = filt(load(330522), 'lp', 7500)
group('gate_rattle', [cut(gate, 4.84, 8.5, fo=0.3), cut(gate, 11.6, 13.0, fo=0.3), cut(gate, 23.2, 24.4, fo=0.25), cut(gate, 15.8, 18.7, fo=0.3)], -11)

# ───────────── папирус, ткань ─────────────
pap = filt(load(204046), 'hp', 150)
group('parchment', [cut(pap, 7.2, 8.45, fi=0.02, fo=0.1), cut(pap, 12.1, 14.1, fi=0.02, fo=0.15), cut(pap, 4.5, 5.5, fi=0.02, fo=0.1),
                    cut(pap, 17.85, 19.6, fi=0.02, fo=0.15)], -18)
fab = filt(load(852785), 'hp', 120)
group('cloth_rustle', [cut(fab, 0.17, 0.72, fi=0.02, fo=0.1), cut(fab, 2.47, 2.95, fi=0.02, fo=0.1), cut(fab, 5.53, 6.1, fi=0.02, fo=0.1),
                       cut(fab, 7.3, 8.2, fi=0.02, fo=0.12), cut(fab, 9.55, 10.1, fi=0.02, fo=0.1), cut(fab, 11.08, 11.75, fi=0.02, fo=0.1)], -20)

# ───────────── босые шаги (святые) ─────────────
bf = filt(load(101755), 'hp', 80)
steps = [cut(bf, a - 0.01, a + d + 0.12, fo=0.08) for a, d in ((0.86, 0.22), (1.32, 0.21), (1.85, 0.20), (2.29, 0.17), (2.81, 0.21),
                                                              (3.26, 0.34), (3.86, 0.26), (4.37, 0.28), (4.95, 0.19), (5.44, 0.21))]
group('steps_barefoot', steps, -22)

# ───────────── удары: мокрый камень по телу, удар по голове, падение тела ─────────────
pn = load(96486)
punches = [cut(pn, a - 0.005, a + 0.30, fo=0.12) for a in (0.44, 1.44, 2.86, 4.35)]
wet = [onset(load(532139)), onset(load(532140))]
wets = [mix([(wet[0], 0.0, 0), (filt(pitch(punches[2], -4), 'lp', 1400), 0.0, 2)]),
        mix([(wet[1], 0.0, 0), (filt(pitch(punches[1], -5), 'lp', 1200), 0.0, 3)]),
        mix([(pitch(wet[0], -3), 0.0, 0), (filt(pitch(punches[3], -6), 'lp', 1000), 0.0, 3)]),
        mix([(pitch(wet[1], -2), 0.0, 0), (filt(pitch(punches[0], -3), 'lp', 1500), 0.0, 2)])]
group('hit_wet', wets, -12)
t = np.arange(int(0.5 * SR)) / SR
thump = np.sin(2 * np.pi * (70 - 35 * t / 0.5) * t) * np.exp(-t * 14)      # глухой низкий удар
save('hit_head', norm(mix([(punches[2], 0, 0), (filt(pitch(punches[1], -7), 'lp', 900), 0.0, 2), (thump, 0.0, 3)]), -8))
bodies = []
for k, (p, c, semi) in enumerate(((0, 0, -9), (3, 3, -11), (1, 4, -8))):
    cl = cut(fab, *((0.17, 0.72), (2.47, 2.95), (5.53, 6.1), (7.3, 8.2), (9.55, 10.1))[c], fi=0.02, fo=0.1)
    bodies.append(mix([(filt(pitch(punches[p], semi), 'lp', 700), 0.0, 0), (thump[:int(0.3 * SR)], 0.0, -2), (cl, 0.03, -14),
                       (filt(pitch(punches[(p + 1) % 4], semi - 2), 'lp', 500), 0.16, -9)]))
group('body_fall', bodies, -11)

# ───────────── схватили: борьба, хрип, судорожный вдох ─────────────
ch1, ch2 = load(573900), load(869797)
group('choke', [filt(cut(ch1, 2.44, 3.95, fo=0.15), 'hp', 90), filt(cut(ch2, 0.98, 3.1, fo=0.25), 'hp', 90),
                filt(cut(ch1, 0.02, 1.85, fo=0.15), 'hp', 90), filt(cut(load(252242), 0.03, 1.48, fo=0.08), 'hp', 90)], -14)
save('struggle_01', norm(filt(cut(load(682137), 0.01, 0.9, fo=0.08), 'hp', 90), -13))
gs = load(218410)
group('gasp_wake', [cut(load(588666), 0.04, 1.05, fo=0.12), cut(gs, 0.93, 1.6, fo=0.12), cut(gs, 4.0, 5.35, fo=0.15), cut(gs, 6.54, 7.05, fo=0.1)], -15)

# ───────────── напевы святых (моно, 22 кГц) ─────────────
low = filt(filt(load(319253), 'hp', 80), 'lp', 4000)
phrase = cut(low, 0.15, 10.5, fi=0.05, fo=2.5)                      # одна фраза без слов: нарастает и гаснет
save('saint_chant_phrase_01', to_lufs(phrase, -22), 22050)
# петля ~47 с: та же фраза четыре раза на разной высоте (ниже — медленнее), между ними вдох-тишина
parts, t = [], 0.0
for semi, pause in ((0, 1.8), (-2, 2.6), (1.5, 1.4), (-3.5, 3.0)):
    ph = pitch(phrase, semi)
    parts.append((ph, t, 0))
    t += len(ph) / SR - 1.2 + pause                                  # следующий вступает на хвосте прежнего
loop = mix(parts, int(t * SR) + int(1.2 * SR))
tail = loop[int(t * SR):]                                            # хвост последней фразы заворачиваем в начало
loop = loop[:int(t * SR)]
loop[:len(tail)] += tail
save('saint_chant_01', to_lufs(loop, -23), 22050)
rap = filt(filt(load(686617), 'hp', 120), 'lp', 3500)               # быстрый монотонный речитатив — «бормочет, ищет»
save('saint_mumble_01', to_lufs(seamless(rap[int(0.5 * SR):int(28.2 * SR)], 1.0), -24), 22050)
dr = filt(filt(load(876338), 'hp', 60), 'lp', 3000)                  # низкая ровная нота — гудение под напевом
save('saint_drone_01', to_lufs(seamless(dr[int(0.2 * SR):int(4.7 * SR)], 0.7), -24), 22050)

# ───────────── паника толпы: сборная петля 40 с из отдельных криков и гомона базара ─────────────
L = 40.0
n = int(L * SR)
pan = np.zeros((n, 2))
bazaar = load_game('market_crowd.ogg')
for r_, g, off in ((1.16, 0.0, 3.0), (1.32, -2.0, 21.0)):             # гомон выше и быстрее — взволнованный
    b = resample_poly(bazaar, 1000, int(1000 * r_), axis=0)
    b = filt(b, 'hp', 350)
    b = np.tanh(b * 6) / 6 * 2.2                                      # «перекрик»: плотнее и грубее
    idx = (np.arange(n) + int(off * SR)) % len(b)
    pan += b[idx] * 10 ** (g / 20)
voices = screams + [cut(pain, 3.86, 6.6, fo=0.25), load(813303), load(813307), cut(load(588666), 0.04, 1.05, fo=0.12),
                    cut(load(682137), 0.01, 0.9, fo=0.08), cut(gs, 4.0, 5.35, fo=0.15)]
voices = [v / (np.abs(v).max() + 1e-9) for v in voices]
for k in range(70):
    v = voices[rng.integers(len(voices))]
    v = pitch(v, rng.uniform(-3.5, 8.0))                              # выше — женские и детские голоса
    v = filt(v, 'lp', rng.uniform(1800, 7000))                        # кто-то ближе, кто-то дальше
    v = room(v, 0.7, rng.uniform(0.3, 1.2), seed=k)
    g = 10 ** (rng.uniform(-20, -7) / 20)
    p = rng.uniform(0.1, 0.9)
    a = rng.integers(n)
    idx = (a + np.arange(len(v))) % n                                 # по кругу — петля без шва
    np.add.at(pan[:, 0], idx, v * g * np.cos(p * np.pi / 2))
    np.add.at(pan[:, 1], idx, v * g * np.sin(p * np.pi / 2))
pan = filt(pan, 'hp', 120)
save('crowd_panic', to_lufs(pan, -19), 32000)

# ───────────── топот толпы: сборная петля 30 с из шагов ─────────────
L = 30.0
n = int(L * SR)
st = np.zeros((n, 2))
run = []
for k in range(1, 7):
    x = load_game(f'steps_stone_run_{k:02d}.ogg').mean(1)
    run.append(x / (np.abs(x).max() + 1e-9))
allsteps = run + [s / (np.abs(s).max() + 1e-9) for s in steps]
for k in range(int(L * 26)):                                          # ~26 шагов в секунду
    s = allsteps[rng.integers(len(allsteps))]
    s = pitch(s, rng.uniform(-5, 4))
    s = filt(s, 'lp', rng.uniform(1500, 8000))
    g = 10 ** (rng.uniform(-22, -6) / 20)
    p = rng.uniform(0.05, 0.95)
    a = rng.integers(n)
    idx = (a + np.arange(len(s))) % n
    np.add.at(st[:, 0], idx, s * g * np.cos(p * np.pi / 2))
    np.add.at(st[:, 1], idx, s * g * np.sin(p * np.pi / 2))
noise = filt(rng.standard_normal((n + SR, 2)), 'lp', 110)[SR // 2:SR // 2 + n]          # гул земли под ногами
env = 1 + 0.35 * np.sin(2 * np.pi * np.arange(n) / n * 7)[:, None]
st = room(st[:, 0], 0.5, 0.5, 3)[:, None] * [1, 0] + room(st[:, 1], 0.5, 0.5, 4)[:, None] * [0, 1] + noise * env * 0.25 * np.abs(st).max()
save('crowd_stampede', to_lufs(filt(st, 'hp', 40), -20), 32000)
