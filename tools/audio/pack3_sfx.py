"""Звуки второго набора, дозаливка (ноябрь): 18 записей из того же архива, которые не вошли в pack2_sfx.py.
python3 pack3_sfx.py <папка с исходниками в wav 44,1 кГц, имя = id с freesound> <папка audio/ игры> <out>
Результат — wav в <out>; в ogg кодирует ffmpeg. Источники и лицензии — audio/CREDITS.md.
267344 «irish heart» не взят: внутри не сердцебиение, а голос поверх музыкального тона."""
import sys, os, subprocess
import numpy as np, soundfile as sf
from scipy.signal import resample_poly, butter, sosfiltfilt, fftconvolve, stft, istft

SRC, GAME_AUDIO, OUT = sys.argv[1:4]
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(34)


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



def denoise(x, k=1.5):
    """Простое вычитание шума по спектру: профиль шума — самые тихие 15 % кадров в каждой полосе."""
    f, t, Z = stft(x, SR, nperseg=2048)
    prof = np.percentile(np.abs(Z), 15, axis=1, keepdims=True)
    mag = np.maximum(np.abs(Z) - k * prof, 0.08 * np.abs(Z))
    return istft(mag * np.exp(1j * np.angle(Z)), SR, nperseg=2048)[1][:len(x)]


# ───────────── ткань: ещё шорохи (одежды святых) ─────────────
cl1 = filt(load(128233), 'hp', 120)
cl2 = filt(load(427866), 'hp', 120)
rust = [cut(cl1, 0.26, 1.2, fi=0.02, fo=0.12), cut(cl1, 1.72, 2.6, fi=0.02, fo=0.12)] + \
       [cut(cl2, a, min(b, a + 1.0), fi=0.02, fo=0.12) for a, b in ((0.66, 1.72), (8.18, 9.48), (19.06, 20.56), (31.40, 32.60), (47.52, 48.58), (56.96, 58.86))]
for k, x in enumerate(rust, 7):
    save(f'cloth_rustle_{k:02d}', norm(x, -20))

# пелена сползает и падает (снял одеяние): тихая запись, шум вычтен
robe = denoise(filt(load(395083), 'hp', 150))
save('shroud_drop_01', norm(cut(robe, 2.3, 6.1, fi=0.05, fo=0.4), -22))
robe2 = denoise(filt(load(395081), 'hp', 150))
save('shroud_drop_02', norm(cut(robe2, 3.0, 7.0, fi=0.1, fo=0.4), -24))

# ───────────── молоток: ещё удары ─────────────
out_h = load(342542)          # вдалеке, на улице — для конца демо «из-за скалы»
far = [filt(cut(out_h, a - 0.004, a + 0.38, fo=0.12), 'hp', 70) for a in (0.04, 0.46, 0.88)]
for k, x in enumerate(far, 7):
    save(f'hammer_nail_{k:02d}', norm(x, -12))
blk = load(490752)
near = [filt(pitch(cut(blk, a - 0.004, a + 0.44, fo=0.12), -3), 'hp', 70) for a in (4.2, 10.815, 21.37, 22.23, 26.52, 32.585)]
for k, x in enumerate(near, 10):
    save(f'hammer_nail_{k:02d}', norm(x, -9))

# ───────────── схватка: хрип, рывок, захват ─────────────
chk = filt(load(853561), 'hp', 90)
for k, (a, b) in enumerate(((1.34, 2.12), (3.20, 4.14), (4.40, 5.34), (8.66, 10.7)), 5):
    save(f'choke_{k:02d}', norm(cut(chk, a - 0.02, b + 0.1, fo=0.15), -14))
br = denoise(filt(load(653104), 'hp', 100), k=1.0)
save('breath_struggle_01', norm(cut(br, 0.1, 8.3, fi=0.05, fo=0.4), -18))
grab = filt(pitch(load(539947), -2), 'lp', 3500)
save('grab_01', norm(grab, -12))
save('grab_02', norm(mix([(grab, 0, 0), (cut(rust[1], 0, 0.5, fo=0.15), 0.01, -6)]), -12))

# ───────────── святые: рык, принюхивание ─────────────
gr = filt(filt(load(786537), 'hp', 70), 'lp', 5000)
growls = [cut(gr, a, min(b, a + 3.6), fi=0.03, fo=0.3) for a, b in
          ((1.36, 4.24), (7.06, 10.80), (11.74, 14.36), (15.76, 19.5), (24.08, 28.32), (29.62, 34.14), (36.02, 39.48), (41.08, 44.92))]
for k, x in enumerate(growls, 1):
    save(f'saint_growl_{k:02d}', norm(x, -14))
sn = filt(cut(load(445975), 0.0, 0.85, fo=0.1), 'hp', 150)
save('saint_sniff_01', norm(pitch(sn, -2), -18))
save('saint_sniff_02', norm(pitch(sn, -4), -18))

# второй напев: низкое пение монаха; свист и тон выше 1 кГц срезаны — остаётся глухой голос
mk = filt(filt(load(440243), 'lp', 900, order=8), 'hp', 70)
save('saint_chant_02', to_lufs(seamless(mk[int(4.0 * SR):int(62.0 * SR)], 1.5), -23), 22050)

# далёкий обряд за стеной: пение и стук колотушки, глухо (только низы), с эхом — конец демо, распятие
rit = filt(filt(load(686628), 'lp', 650, order=8), 'hp', 60)
rit = room(rit[int(10 * SR):int(42 * SR)], 1.6, 0.9, 5)
save('ritual_far_01', to_lufs(seamless(rit, 1.5), -26), 22050)

# ───────────── «очнулся»: кряхтение, тяжёлый выдох ─────────────
wk = filt(load(500801), 'hp', 90)
wakes = [cut(wk, a - 0.02, b + 0.15, fo=0.15) for a, b in ((0.78, 2.26), (4.32, 4.92), (8.88, 9.46), (10.60, 11.24), (13.96, 14.56), (19.64, 21.04))]
wakes += [filt(pitch(load(503483), -3), 'hp', 90), filt(pitch(load(503490), -3), 'hp', 90)]   # зевок ниже — тяжёлый выдох
for k, x in enumerate(wakes, 1):
    save(f'wake_groan_{k:02d}', norm(x, -17))

# ───────────── глухой удар вдалеке (дверь, ложные тревоги) ─────────────
sn2 = load(422679)
save('thud_far_01', norm(room(filt(pitch(sn2, -14), 'lp', 1200), 0.9, 0.6, 7), -14))
save('thud_far_02', norm(room(filt(pitch(sn2, -18), 'lp', 900), 1.2, 0.8, 8), -15))

# ───────────── звон в ушах: «заморозка» спектра колокола, только верх ─────────────
bell = load(841352)
f, t, Z = stft(bell[int(6 * SR):int(16 * SR)], SR, nperseg=8192)
mag = np.abs(Z).mean(1)
mag[f < 2500] = 0
mag[f > 9000] = 0
pk = [i for i in range(1, len(mag) - 1) if mag[i] > mag[i - 1] and mag[i] >= mag[i + 1]]
keep = sorted(pk, key=lambda i: -mag[i])[:7]          # оставить 7 самых сильных обертонов — чистый звон, а не шипение
m2 = np.zeros_like(mag)
for i in keep:
    m2[i - 1:i + 2] = mag[i - 1:i + 2]
mag = m2
n = int(7 * SR)
f2, t2, Z2 = stft(np.zeros(n), SR, nperseg=8192)
ph = rng.uniform(0, 2 * np.pi, Z2.shape)
ring = istft(mag[:, None] * np.exp(1j * ph), SR, nperseg=8192)[1][:n]
ring = filt(ring, 'bp', [2600, 8500])
env = np.minimum(1, np.arange(n) / (0.15 * SR)) * np.exp(-np.arange(n) / (3.0 * SR))
save('ring_ears_01', norm(ring * env, -24))
# низкий далёкий гул удара (колокол на две октавы ниже, глухо) — для ангела и тревог
toll = filt(pitch(bell[int(0.0 * SR):int(2.0 * SR)], -24), 'lp', 700)
save('toll_low_01', norm(cut(toll, 0, 7.0, fo=2.5), -16))

# ───────────── в ogg ─────────────
for name in sorted(os.listdir(OUT)):
    if name.endswith('.wav'):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(OUT, name), '-c:a', 'libvorbis', '-q:a', '4',
                        os.path.join(OUT, name[:-4] + '.ogg')], check=True)
