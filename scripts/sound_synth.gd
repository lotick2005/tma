class_name SoundSynth
extends RefCounted
## Процедурные звуки-заглушки (CLAUDE.md §5): каждый генерируется кодом в AudioStreamWAV.
## Имена функций — поле "synth" в реестре data/sounds.gd. Когда появится запись, заглушка просто
## перестаёт вызываться (в реестре меняется одна строка).
## Моно 22 050 Гц (голоса и фон — 11 025 Гц), 16 бит — как у PS1 этого хватает, и в браузере генерируется быстро.

## Частота по умолчанию; глухим и низким звукам (голоса, дыхание, фон) хватает половины — так вдвое быстрее.
const RATE := 22050
const RATE_LOW := 11025
const TAU_F := TAU


## Сгенерировать звук: имя функции, номер варианта (меняет случайность).
static func make(synth_name: String, variant: int) -> AudioStreamWAV:
	var s := SoundSynth.new()
	if not s.has_method(synth_name):
		push_error("SoundSynth: нет заглушки «%s»" % synth_name)
		return null
	s._rng.seed = hash(synth_name) + variant * 7919
	return s.call(synth_name)


var _rng := RandomNumberGenerator.new()
var _rate := RATE


# ─── Общие кирпичики ─────────────────────────────────────────────────────────

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * _rate))
	return b


func _noise(sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	for i in b.size():
		b[i] = _rng.randf() * 2.0 - 1.0
	return b


## Однополюсный ФНЧ (на месте).
func _lp(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU_F * hz / _rate)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y
	return b


## Однополюсный ФВЧ (на месте).
func _hp(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU_F * hz / _rate)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = b[i] - y
	return b


## Полосовой биквад (RBJ, пик 0 дБ). Возвращает новый массив.
func _bp(b: PackedFloat32Array, hz: float, q: float) -> PackedFloat32Array:
	var w := TAU_F * hz / _rate
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w) / a0
	var a2 := (1.0 - alpha) / a0
	var out := PackedFloat32Array()
	out.resize(b.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in b.size():
		var x := b[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Сумма полосовых (форманты голоса): [[частота, добротность, вес], …].
func _formants(b: PackedFloat32Array, bands: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(b.size())
	for band in bands:
		var f := _bp(b, band[0], band[1])
		var g: float = band[2]
		for i in out.size():
			out[i] += f[i] * g
	return out


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, at := 0) -> void:
	var n := mini(src.size(), dst.size() - at)
	for i in n:
		dst[at + i] += src[i] * gain


func _normalize(b: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0
	for v in b:
		m = maxf(m, absf(v))
	if m > 1e-6:
		var k := peak / m
		for i in b.size():
			b[i] *= k
	return b


## Бесшовная петля: хвост длиной fade сек плавно вкладывается в начало. Длина уменьшается на fade.
func _seamless(b: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var f := int(fade * _rate)
	var n := b.size() - f
	var out := b.slice(0, n)
	for i in f:
		var t := float(i) / f
		out[i] = b[i] * sqrt(t) + b[n + i] * sqrt(1.0 - t)
	return out


## Короткие плавные края, чтобы не щёлкало.
func _edges(b: PackedFloat32Array, sec := 0.005) -> PackedFloat32Array:
	var f := mini(int(sec * _rate), b.size() / 2)
	for i in f:
		var t := float(i) / f
		b[i] *= t
		b[b.size() - 1 - i] *= t
	return b


## Таблица одного периода: сумма гармоник [вес 1-й, 2-й, …].
func _table(harmonics: Array, size := 2048) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(size)
	for i in size:
		var ph := TAU_F * i / size
		var v := 0.0
		for k in harmonics.size():
			v += harmonics[k] * sin(ph * (k + 1))
		t[i] = v
	return t


## «Пила» с ограниченной полосой: n гармоник 1/k — источник для голосов.
func _saw_table(n := 28) -> PackedFloat32Array:
	var h := []
	for k in n:
		h.append(1.0 / (k + 1))
	return _table(h)


func _wav(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = _rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w


## Затухающий синус со спадом высоты (удар, «тук»): в буфер с позиции at.
func _thump(b: PackedFloat32Array, at: float, f0: float, f1: float, decay: float, gain: float) -> void:
	var start := int(at * _rate)
	var n := mini(int(decay * 6.0 * _rate), b.size() - start)
	var ph := 0.0
	for i in n:
		var t := float(i) / _rate
		var f := f1 + (f0 - f1) * exp(-t / (decay * 0.5))
		ph += TAU_F * f / _rate
		var env := (1.0 - exp(-t / 0.002)) * exp(-t / decay)
		b[start + i] += sin(ph) * env * gain


## Шумовой щелчок / всплеск: в буфер с позиции at.
func _burst(b: PackedFloat32Array, at: float, decay: float, gain: float, lp_hz := 0.0) -> void:
	var start := int(at * _rate)
	var n := mini(int(decay * 6.0 * _rate), b.size() - start)
	if n <= 0:
		return
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / _rate
		s[i] = (_rng.randf() * 2.0 - 1.0) * exp(-t / decay) * (1.0 - exp(-t / 0.0008))
	if lp_hz > 0.0:
		_lp(s, lp_hz)
	_mix(b, s, gain, start)


# ─── Фон и день ──────────────────────────────────────────────────────────────

## Гомон толпы на площади: невнятные голоса, слоги, шорох шагов.
func day_crowd() -> AudioStreamWAV:
	_rate = RATE_LOW
	var sec := 12.0
	var out := _buf(sec)
	# Шумовой «ковёр» далёких голосов
	var carpet := _formants(_noise(sec), [[450.0, 1.2, 1.0], [1300.0, 1.5, 0.6]])
	var n := out.size()
	var mod := 0.0
	for i in n:
		if i % 220 == 0:
			mod = 0.55 + 0.45 * _rng.randf()
		out[i] = carpet[i] * mod * 0.6
	_lp(out, 2200.0)
	# Отдельные голоса: «пила» с интонацией через форманты, слогами
	var saw := _saw_table()
	var voices := _buf(sec)
	for v in 9:
		var f := _rng.randf_range(95.0, 240.0)
		var ph := _rng.randf()
		var gate := 0.0
		var target := 0.0
		var syl_left := 0
		var gain := _rng.randf_range(0.3, 1.0)
		for i in n:
			if syl_left <= 0:
				syl_left = int(_rng.randf_range(0.08, 0.25) * _rate)
				target = 0.0 if _rng.randf() < 0.35 else _rng.randf_range(0.4, 1.0)
				f = clampf(f * _rng.randf_range(0.93, 1.07), 90.0, 260.0)
			syl_left -= 1
			gate += (target - gate) * 0.004
			ph = fmod(ph + f / _rate, 1.0)
			voices[i] += saw[int(ph * 2048.0)] * gate * gain
	var vf := _formants(voices, [[600.0, 2.0, 1.0], [1150.0, 2.5, 0.7], [2400.0, 3.0, 0.3]])
	_lp(vf, 2500.0)
	_normalize(vf, 0.5)
	_mix(out, vf, 1.0)
	return _wav(_normalize(_seamless(out, 1.5), 0.8), true)


## Птицы: группы коротких свистов-чириканий.
func birds() -> AudioStreamWAV:
	var sec := 8.0
	var out := _buf(sec)
	var t := _rng.randf_range(0.1, 0.6)
	while t < sec - 1.0:
		var count := _rng.randi_range(2, 6)
		var f0 := _rng.randf_range(2600.0, 4800.0)
		for c in count:
			var dur := _rng.randf_range(0.04, 0.12)
			var f1 := f0 + _rng.randf_range(-1500.0, 1200.0)
			var start := int(t * _rate)
			var n := int(dur * _rate)
			var ph := 0.0
			var trill := _rng.randf() < 0.3
			for i in n:
				if start + i >= out.size():
					break
				var k := float(i) / n
				ph += TAU_F * lerpf(f0, f1, k) / _rate
				var env := sin(PI * k)
				if trill:
					env *= 0.5 + 0.5 * sin(TAU_F * 35.0 * i / _rate)
				out[start + i] += sin(ph) * env * 0.5
			t += dur + _rng.randf_range(0.03, 0.14)
		t += _rng.randf_range(0.4, 1.6)
	return _wav(_normalize(_edges(out, 0.02), 0.8), true)


## Собаки вдали: пара-тройка гавков и тишина.
func dogs() -> AudioStreamWAV:
	_rate = RATE_LOW
	var sec := 9.0
	var out := _buf(sec)
	var saw := _saw_table(20)
	for at in [0.4, 0.8, 1.25, 5.1, 5.5]:
		var dur := _rng.randf_range(0.14, 0.22)
		var n := int(dur * _rate)
		var start := int(float(at) * _rate)
		var bark := PackedFloat32Array()
		bark.resize(n)
		var ph := 0.0
		var f0 := _rng.randf_range(480.0, 620.0)
		for i in n:
			var k := float(i) / n
			var f := lerpf(f0, f0 * 0.62, k)
			ph = fmod(ph + f / _rate, 1.0)
			var env := minf(1.0, k * 25.0) * pow(1.0 - k, 1.6)
			bark[i] = (saw[int(ph * 2048.0)] * 0.8 + (_rng.randf() * 2.0 - 1.0) * 0.35) * env
		var shaped := _formants(bark, [[850.0, 3.0, 1.0], [1700.0, 4.0, 0.6]])
		_mix(out, shaped, 1.0, start)
	_lp(out, 2000.0)
	return _wav(_normalize(out, 0.8), true)


## Далёкое пение псалма: несколько голосов в унисон и октаву, протяжная мелодия.
func distant_singing() -> AudioStreamWAV:
	_rate = RATE_LOW
	var notes := [0, 2, 3, 2, 0, -2, 0, 0, 3, 5, 3, 2, 0, -2, -4, 0]
	var note_len := 0.9
	var sec := notes.size() * note_len + 1.5
	var saw := _saw_table(24)
	var src := _buf(sec)
	var n := src.size()
	var voices := [[146.8, 0.0, 1.0], [147.6, 0.03, 0.8], [293.7, 0.02, 0.5], [220.4, 0.05, 0.35]]
	for v in voices:
		var base: float = v[0]
		var note_f := PackedFloat32Array()
		for nt in notes:
			note_f.append(base * pow(2.0, nt / 12.0))
		var lag: float = v[1]
		var gain: float = v[2]
		var ph := _rng.randf()
		var f := base
		for i in n:
			var t := float(i) / _rate - lag
			var idx := clampi(int(t / note_len), 0, notes.size() - 1)
			var target := note_f[idx]
			f += (target - f) * 0.0009
			var vib := 1.0 + 0.006 * sin(TAU_F * 5.2 * t + gain)
			ph = fmod(ph + f * vib / _rate, 1.0)
			var nt := fmod(maxf(t, 0.0), note_len) / note_len
			var env := 0.75 + 0.25 * sin(PI * nt)
			src[i] += saw[int(ph * 2048.0)] * gain * env
	var out := _formants(src, [[700.0, 2.0, 1.0], [1150.0, 2.5, 0.5], [2600.0, 4.0, 0.15]])
	_lp(out, 1600.0)
	return _wav(_normalize(_seamless(out, 1.5), 0.8), true)


# ─── Ангел ───────────────────────────────────────────────────────────────────

## Чистый мажорный аккорд (до мажор в несколько октав) — слишком красивый; к концу голоса расходятся и фальшивят.
func angel_chord() -> AudioStreamWAV:
	_rate = RATE_LOW
	var sec := 10.0
	var out := _buf(sec)
	var n := out.size()
	var table := _table([1.0, 0.35, 0.12, 0.06])
	var freqs := PackedFloat32Array([130.81, 164.81, 196.0, 261.63, 329.63, 392.0, 523.25, 659.26])
	var dirs := PackedFloat32Array()
	var phases := PackedFloat32Array()
	for f in freqs:
		dirs.append(_rng.randf_range(-1.0, 1.0))
		phases.append(_rng.randf())
	var voices := freqs.size()
	for i in n:
		var t := float(i) / _rate
		var k := t / sec
		# Расстройка нарастает: к концу до ±4 % (почти четверть тона)
		var detune := k * k * 0.04
		var env := minf(1.0, t / 2.0) * minf(1.0, (sec - t) / 1.5)
		var v := 0.0
		for j in voices:
			var vib := 1.0 + 0.003 * sin(TAU_F * (4.5 + j * 0.3) * t)
			phases[j] = fmod(phases[j] + freqs[j] * (1.0 + detune * dirs[j]) * vib / _rate, 1.0)
			v += table[int(phases[j] * 2048.0)]
		out[i] = v * env
	_lp(out, 4000.0)
	return _wav(_normalize(out, 0.8))


## Крылья: медленные волны низкого шума, хлопанье огромного паруса.
func angel_wings() -> AudioStreamWAV:
	_rate = RATE_LOW
	var sec := 9.5
	var low := _lp(_lp(_noise(sec), 350.0), 500.0)
	var air := _bp(_noise(sec), 900.0, 0.7)
	var out := _buf(sec)
	for i in out.size():
		var t := float(i) / _rate
		var swell := pow(0.5 - 0.5 * cos(TAU_F * t / 4.0), 2.0)
		var luff := 1.0 + 0.6 * swell * sin(TAU_F * 9.0 * t + sin(TAU_F * 0.7 * t) * 2.0)
		out[i] = (low[i] * 1.0 + air[i] * 0.25 * swell) * (0.15 + swell) * luff
	return _wav(_normalize(_seamless(out, 1.5), 0.8), true)


## Звон в ушах: высокий синус с биением ~7 Гц (целое число периодов в петле — без шва).
func tinnitus() -> AudioStreamWAV:
	var sec := 4.0
	var out := _buf(sec)
	for i in out.size():
		var t := float(i) / _rate
		out[i] = sin(TAU_F * 6200.0 * t) * 0.6 + sin(TAU_F * 6207.0 * t) * 0.4 + sin(TAU_F * 3100.0 * t) * 0.05
	return _wav(_normalize(out, 0.7), true)


# ─── Святые и голоса ─────────────────────────────────────────────────────────

## Монотонный низкий напев: речитатив на одной ноте, в конце фразы — спад на тон и вдох.
func saint_chant() -> AudioStreamWAV:
	_rate = RATE_LOW
	var phrases := [3.4, 2.6, 3.8]
	var pause := 0.7
	var sec := 0.0
	for p in phrases:
		sec += p + pause
	var saw := _saw_table(30)
	var src := _buf(sec)
	var breath := _bp(_noise(sec), 1400.0, 0.8)
	var t0 := 0.0
	var ph := 0.0
	var f := 98.0
	for p in phrases:
		var plen: float = p
		var start := int(t0 * _rate)
		var n := int(plen * _rate)
		var syl := 0.0
		var syl_target := 1.0
		var syl_left := 0
		for i in n:
			var k := float(i) / n
			if syl_left <= 0:
				syl_left = int(_rng.randf_range(0.18, 0.32) * _rate)
				syl_target = _rng.randf_range(0.55, 1.0)
			syl_left -= 1
			syl += (syl_target - syl) * 0.002
			var target := 98.0 if k < 0.8 else 87.3
			f += (target - f) * 0.0006
			var t := float(start + i) / _rate
			ph = fmod(ph + f * (1.0 + 0.004 * sin(TAU_F * 4.8 * t)) / _rate, 1.0)
			var env := minf(1.0, k * 8.0) * minf(1.0, (1.0 - k) * 10.0)
			src[start + i] = saw[int(ph * 2048.0)] * env * syl + breath[start + i] * env * 0.08
		t0 += plen + pause
	# Гласная «о-у», глухо и низко
	var out := _formants(src, [[400.0, 3.0, 1.0], [750.0, 4.0, 0.55], [2400.0, 6.0, 0.12]])
	_lp(out, 2200.0)
	return _wav(_normalize(_edges(out, 0.05), 0.8), true)


## Шёпот: невнятные глухие слоги с шипящими.
func whisper() -> AudioStreamWAV:
	var vowels := [[300.0, 2300.0], [500.0, 1800.0], [600.0, 1000.0], [700.0, 1250.0], [350.0, 800.0]]
	var syllables := _rng.randi_range(3, 5)
	var sec := 0.25 + syllables * 0.32 + 0.4
	var out := _buf(sec)
	var t := 0.15
	for s in syllables:
		var dur := _rng.randf_range(0.2, 0.34)
		var v: Array = vowels[_rng.randi() % vowels.size()]
		var seg := _noise(dur)
		var shaped := _formants(seg, [[v[0], 4.0, 1.0], [v[1], 5.0, 0.7]])
		var n := shaped.size()
		for i in n:
			var k := float(i) / n
			shaped[i] *= sin(PI * k) * (0.7 + 0.3 * _rng.randf())
		_mix(out, shaped, 1.0, int(t * _rate))
		# Шипящая в начале слога
		if _rng.randf() < 0.6:
			var sib := _bp(_noise(0.09), 5200.0, 2.0)
			for i in sib.size():
				sib[i] *= sin(PI * float(i) / sib.size())
			_mix(out, sib, 0.5, int(maxf(t - 0.07, 0.0) * _rate))
		t += dur + _rng.randf_range(0.04, 0.12)
	return _wav(_normalize(_edges(out, 0.01), 0.8))


# ─── Герой ───────────────────────────────────────────────────────────────────

## Шаг по каменной мостовой: сухой щелчок подошвы и короткий скрежет.
func step_stone() -> AudioStreamWAV:
	var out := _buf(0.2)
	_burst(out, 0.0, 0.006, 0.9)
	_burst(out, _rng.randf_range(0.018, 0.035), 0.012, 0.5, 4000.0)
	_thump(out, 0.0, 220.0, 140.0, 0.018, 0.5)
	_hp(out, 300.0)
	return _wav(_normalize(_edges(out, 0.002), 0.9))


## Шаг по утоптанной земле: глухой удар и хруст мелких камешков.
func step_earth() -> AudioStreamWAV:
	var out := _buf(0.22)
	_thump(out, 0.0, 120.0, 70.0, 0.03, 0.8)
	_burst(out, 0.0, 0.025, 0.6, 900.0)
	for c in _rng.randi_range(3, 7):
		_burst(out, _rng.randf_range(0.005, 0.08), 0.002, _rng.randf_range(0.1, 0.3), 3000.0)
	return _wav(_normalize(_edges(out, 0.002), 0.9))


## Шаг по дереву: гулкий удар доски, иногда скрип.
func step_wood() -> AudioStreamWAV:
	var out := _buf(0.3)
	var f := _rng.randf_range(150.0, 190.0)
	_thump(out, 0.0, f * 1.2, f, 0.06, 0.8)
	_thump(out, 0.0, f * 2.3, f * 2.1, 0.035, 0.35)
	_burst(out, 0.0, 0.008, 0.5, 2500.0)
	if _rng.randf() < 0.5:
		# Скрип: короткая серия частых щелчков
		var at := 0.04
		var rate := _rng.randf_range(250.0, 400.0)
		while at < 0.16:
			_burst(out, at, 0.0012, 0.12, 2000.0)
			at += 1.0 / rate
	return _wav(_normalize(_edges(out, 0.002), 0.9))


## Дыхание: вдох (выше, светлее) и выдох (ниже), паузы. cycle — длина цикла, сек.
func _breath(cycles: int, cycle: float, inhale: float, exhale: float, voiced: float, tremble: float) -> AudioStreamWAV:
	_rate = RATE_LOW
	var sec := cycles * cycle
	var noise := _noise(sec)
	var hi := _formants(noise, [[1900.0, 1.5, 1.0], [3200.0, 2.0, 0.4]])
	var lo := _formants(noise, [[800.0, 1.2, 1.0], [1500.0, 1.8, 0.5]])
	var saw := _saw_table(16)
	var out := _buf(sec)
	var gains := []
	for c in cycles:
		gains.append(_rng.randf_range(0.8, 1.0))
	var ph := 0.0
	for i in out.size():
		var t := float(i) / _rate
		var c := mini(int(t / cycle), cycles - 1)
		var p := fmod(t, cycle) / cycle
		var g: float = gains[c]
		var v := 0.0
		if p < inhale:
			v = hi[i] * pow(sin(PI * p / inhale), 1.5) * 0.7 * g
		elif p < inhale + exhale:
			var k := (p - inhale) / exhale
			var env := pow(sin(PI * k), 1.2) * g
			if tremble > 0.0:
				env *= 1.0 - tremble * (0.5 + 0.5 * sin(TAU_F * 11.0 * t))
			ph = fmod(ph + 105.0 / _rate, 1.0)
			v = (lo[i] + saw[int(ph * 2048.0)] * voiced) * env
		out[i] = v
	_lp(out, 4500.0)
	return _wav(_normalize(out, 0.8), true)


func breath_calm() -> AudioStreamWAV:
	return _breath(3, 4.2, 0.32, 0.42, 0.0, 0.0)


func breath_heavy() -> AudioStreamWAV:
	return _breath(5, 1.5, 0.38, 0.5, 0.06, 0.0)


func breath_fast() -> AudioStreamWAV:
	return _breath(8, 0.8, 0.4, 0.5, 0.03, 0.35)


## Один удар сердца: «тук-тук» (низкие глухие толчки).
func heartbeat() -> AudioStreamWAV:
	var out := _buf(0.55)
	_thump(out, 0.0, 70.0, 42.0, 0.05, 1.0)
	_thump(out, 0.0, 150.0, 95.0, 0.025, 0.35)
	_thump(out, 0.17, 62.0, 40.0, 0.045, 0.7)
	_thump(out, 0.17, 130.0, 85.0, 0.02, 0.25)
	_lp(out, 300.0)
	return _wav(_normalize(_edges(out, 0.003), 0.95))


# ─── Предметы и ложные тревоги ───────────────────────────────────────────────

## Разбитый черепок: треск, звенящие осколки, раскатившиеся кусочки.
func shard_break() -> AudioStreamWAV:
	var out := _buf(0.8)
	_burst(out, 0.0, 0.004, 1.0)
	_thump(out, 0.0, 180.0, 110.0, 0.02, 0.6)
	for c in 24:
		var at := _rng.randf_range(0.0, 0.2)
		var start := int(at * _rate)
		var f := _rng.randf_range(1500.0, 5200.0)
		var decay := _rng.randf_range(0.01, 0.05)
		var n := mini(int(decay * 5.0 * _rate), out.size() - start)
		var g := _rng.randf_range(0.1, 0.35)
		for i in n:
			var t := float(i) / _rate
			out[start + i] += sin(TAU_F * f * t) * exp(-t / decay) * g
	for c in 10:
		_burst(out, _rng.randf_range(0.18, 0.65), 0.003, _rng.randf_range(0.08, 0.25), 3500.0)
	return _wav(_normalize(_edges(out, 0.002), 0.9))


## Упал камень: удар и затихающие подскоки.
func stone_fall() -> AudioStreamWAV:
	var out := _buf(1.8)
	_thump(out, 0.0, 160.0, 90.0, 0.03, 0.7)
	_burst(out, 0.0, 0.01, 0.8, 2500.0)
	var at := 0.0
	var gap := _rng.randf_range(0.22, 0.32)
	var g := 0.6
	for b in _rng.randi_range(5, 8):
		at += gap
		gap *= _rng.randf_range(0.62, 0.75)
		g *= 0.7
		_burst(out, at, 0.005, g, 3000.0)
		_thump(out, at, 300.0, 200.0, 0.01, g * 0.6)
	# Мелкие камешки осыпаются
	for c in 6:
		_burst(out, _rng.randf_range(0.1, 1.1), 0.002, 0.08, 4000.0)
	return _wav(_normalize(_edges(out, 0.003), 0.9))


## Скрип двери: прерывистое трение (частота «щелчков» плавает).
func door_creak() -> AudioStreamWAV:
	var sec := _rng.randf_range(1.2, 1.8)
	var pulses := _buf(sec)
	var n := pulses.size()
	var ph := 0.0
	var a := _rng.randf_range(25.0, 45.0)
	var b := _rng.randf_range(70.0, 110.0)
	for i in n:
		var k := float(i) / n
		var rate := lerpf(a, b, sin(PI * k)) * (1.0 + 0.15 * sin(TAU_F * 3.0 * k + 1.0))
		ph += rate / _rate
		if ph >= 1.0:
			ph -= 1.0
			pulses[i] = 1.0 if _rng.randf() < 0.9 else 0.3
	var out := _formants(pulses, [[650.0, 6.0, 1.0], [1650.0, 8.0, 0.6], [2900.0, 10.0, 0.3]])
	for i in n:
		var k := float(i) / n
		out[i] *= minf(1.0, k * 6.0) * minf(1.0, (1.0 - k) * 4.0)
	return _wav(_normalize(_edges(out, 0.005), 0.9))


## Далёкий глухой удар (дверь, обвал где-то за домами).
func distant_thud() -> AudioStreamWAV:
	var out := _buf(2.6)
	_thump(out, 0.0, 70.0, 36.0, 0.18, 1.0)
	_burst(out, 0.0, 0.12, 0.6, 250.0)
	if _rng.randf() < 0.6:
		_thump(out, _rng.randf_range(0.3, 0.6), 60.0, 34.0, 0.12, 0.5)
	# Гул после удара
	var rumble := _lp(_lp(_noise(2.6), 120.0), 120.0)
	for i in rumble.size():
		var t := float(i) / _rate
		rumble[i] *= exp(-t / 0.7) * 2.0
	_mix(out, rumble, 1.0)
	_lp(out, 400.0)
	return _wav(_normalize(_edges(out, 0.003), 0.9))


## Шарканье: кто-то медленно волочит ноги по камню.
func shuffle() -> AudioStreamWAV:
	var sec := 3.2
	var noise := _bp(_noise(sec), 900.0, 0.8)
	var out := _buf(sec)
	var at := _rng.randf_range(0.1, 0.3)
	while at < sec - 0.5:
		var dur := _rng.randf_range(0.3, 0.5)
		var start := int(at * _rate)
		var n := int(dur * _rate)
		for i in n:
			var k := float(i) / n
			out[start + i] += noise[start + i] * pow(sin(PI * k), 0.7) * (1.0 - 0.6 * k)
		for c in 3:
			_burst(out, at + _rng.randf_range(0.0, dur), 0.002, 0.15, 3000.0)
		at += dur + _rng.randf_range(0.35, 0.7)
	_lp(out, 2500.0)
	return _wav(_normalize(_edges(out, 0.01), 0.85))

# ─── Вступление (этап 4) ─────────────────────────────────────────────────────

## Крик и плач толпы: много голосов, у каждого протяжные вопли с падающей высотой, всхлипы, срывы.
## Петля 8 с. «Обращу все песни ваши в плач» (Ам 8:10) — то же пение, сломанное.
func crowd_wail() -> AudioStreamWAV:
	_rate = RATE_LOW
	var sec := 9.5
	var saw := _saw_table(20)
	var src := _buf(sec)
	var n := src.size()
	for v in 9:
		var base := _rng.randf_range(180.0, 420.0)
		var gain := _rng.randf_range(0.5, 1.0)
		var ph := _rng.randf()
		var t0 := _rng.randf_range(0.0, 1.5)
		var t := t0
		while t < sec - 0.5:
			# Один вопль: резкий подъём и долгое падение высоты, дрожание голоса
			var dur := _rng.randf_range(1.2, 2.8)
			var f0 := base * _rng.randf_range(1.1, 1.5)
			var f1 := base * _rng.randf_range(0.55, 0.8)
			var start := int(t * _rate)
			var count := mini(int(dur * _rate), n - start)
			for i in count:
				var k := float(i) / (dur * _rate)
				var f := lerpf(f0, f1, k * k) * (1.0 + 0.02 * sin(TAU_F * 6.5 * k * dur + v))
				var sob := 0.75 + 0.25 * sin(TAU_F * _rng.randf_range(3.0, 3.4) * k * dur)
				ph = fmod(ph + f / _rate, 1.0)
				var env := minf(k * 12.0, 1.0) * pow(1.0 - k, 0.6) * sob
				src[start + i] += saw[int(ph * 2048.0)] * env * gain
			t += dur + _rng.randf_range(0.1, 0.9)
	var voiced := _formants(src, [[750.0, 2.5, 1.0], [1250.0, 3.0, 0.6], [2700.0, 4.0, 0.2]])
	# Дыхание и хрип поверх
	var air := _lp(_noise(sec), 2200.0)
	for i in n:
		air[i] *= 0.06 * (0.6 + 0.4 * sin(TAU_F * 0.37 * float(i) / _rate))
	_mix(voiced, air, 1.0)
	_lp(voiced, 2400.0)
	return _wav(_normalize(_seamless(voiced, 1.5), 0.85), true)


## Сбивчивая речь (вестник): быстрые невнятные слоги с придыханием, сбои, паузы. Заглушка — потом запишем голос.
func voice_babble() -> AudioStreamWAV:
	_rate = RATE_LOW
	var vowels := [[300.0, 2300.0], [500.0, 1800.0], [650.0, 1050.0], [720.0, 1250.0], [380.0, 850.0]]
	var saw := _saw_table(18)
	var sec := 2.6
	var out := _buf(sec)
	var t := 0.08
	var base := _rng.randf_range(150.0, 175.0)
	while t < sec - 0.35:
		var dur := _rng.randf_range(0.09, 0.2)
		var v: Array = vowels[_rng.randi() % vowels.size()]
		var src := _buf(dur)
		var ph := _rng.randf()
		var f := base * _rng.randf_range(0.95, 1.35)
		for i in src.size():
			var k := float(i) / src.size()
			ph = fmod(ph + f * (1.0 - 0.1 * k) / _rate, 1.0)
			src[i] = saw[int(ph * 2048.0)] * sin(PI * k)
		var shaped := _formants(src, [[v[0], 3.0, 1.0], [v[1], 4.0, 0.6]])
		_mix(out, shaped, 1.0, int(t * _rate))
		# Придыхание между слогами
		if _rng.randf() < 0.5:
			var h := _bp(_noise(0.07), 1800.0, 1.0)
			for i in h.size():
				h[i] *= sin(PI * float(i) / h.size())
			_mix(out, h, 0.25, int((t + dur) * _rate))
		t += dur + (_rng.randf_range(0.25, 0.45) if _rng.randf() < 0.15 else _rng.randf_range(0.01, 0.05))
	return _wav(_normalize(_edges(out, 0.01), 0.8))
