class_name ProceduralSounds
extends RefCounted
## Placeholder sound synthesis. Baked to res://audio/generated/*.wav by the
## scene generator; real recordings in res://audio/sounds/ replace them.
## Every sound is deterministic (fixed seeds).

const RATE := 44100

## Every sound key the game uses, with a one-line description (see docs/ASSETS.md).
const KEYS := {
	"shot_crack": "close, sharp supersonic-free muzzle crack (first 100 ms)",
	"shot_boom": "deep low-end body of a black-powder .45 shot",
	"shot_tail": "distant rolling echo / tail, played from reflecting surfaces",
	"hammer_half_cock": "hammer drawn to the half-cock notch: one light click",
	"hammer_full_cock": "hammer to full cock: louder click with cylinder ratchet",
	"hammer_lower": "hammer eased down under the thumb",
	"trigger_break": "sear releasing: tiny crisp click just before the shot",
	"dry_fire": "hammer falling on an empty chamber or a spent primer",
	"gate_open": "loading gate snapping open",
	"gate_close": "loading gate snapping shut",
	"cylinder_click": "one pawl click as the free cylinder turns a chamber",
	"ejector_rod": "ejector rod sliding back through the chamber",
	"case_eject": "case pushed out of the gate (brass on steel)",
	"round_insert": "cartridge sliding into the chamber and seating",
	"case_land_dirt": "empty case landing on dirt",
	"case_land_wood": "empty case landing on wood",
	"case_land_metal": "empty case landing on steel",
	"case_land_rock": "empty case landing on rock",
	"gun_land_dirt": "revolver dropped on dirt",
	"gun_land_wood": "revolver dropped on wood",
	"gun_land_metal": "revolver dropped on steel",
	"gun_land_rock": "revolver dropped on rock",
	"hit_dirt": "bullet into dirt (thud)",
	"hit_wood": "bullet into wood (crack/thock)",
	"hit_metal": "bullet hitting a steel plate (ring)",
	"hit_rock": "bullet on rock",
	"ricochet": "ricochet whine",
}


static func generate(key: String) -> AudioStreamWAV:
	var s: PackedFloat32Array
	match key:
		"shot_crack": s = _shot_crack()
		"shot_boom": s = _shot_boom()
		"shot_tail": s = _shot_tail()
		"hammer_half_cock": s = _click(3400.0, 0.012, 0.55, 11)
		"hammer_full_cock": s = _mix([_click(2600.0, 0.018, 0.9, 12), _ratchet(3, 0.012, 0.25, 13, 0.006)])
		"hammer_lower": s = _click(1900.0, 0.02, 0.35, 14)
		"trigger_break": s = _click(4200.0, 0.006, 0.45, 15)
		"dry_fire": s = _mix([_click(1700.0, 0.045, 1.0, 16), _ring([2900.0, 5100.0], 0.03, 0.25, 17)])
		"gate_open": s = _mix([_click(3000.0, 0.01, 0.5, 18), _ratchet(1, 0.02, 0.3, 19, 0.03)])
		"gate_close": s = _click(2500.0, 0.014, 0.6, 20)
		"cylinder_click": s = _click(3800.0, 0.008, 0.4, 21)
		"ejector_rod": s = _mix([_scrape(0.13, 2500.0, 0.25, 22), _ratchet(1, 0.01, 0.4, 23, 0.12)])
		"case_eject": s = _ring([4300.0, 7100.0], 0.05, 0.4, 24)
		"round_insert": s = _mix([_scrape(0.08, 1800.0, 0.2, 25), _ratchet(1, 0.012, 0.45, 26, 0.075)])
		"case_land_dirt": s = _thud(0.03, 900.0, 0.4, 27)
		"case_land_wood": s = _mix([_ring([1100.0], 0.03, 0.4, 28), _ring([5200.0, 8300.0], 0.04, 0.3, 29)])
		"case_land_metal": s = _ring([5600.0, 9100.0, 12200.0], 0.3, 0.6, 30)
		"case_land_rock": s = _mix([_click(4800.0, 0.01, 0.5, 31), _ring([6100.0], 0.05, 0.25, 32)])
		"gun_land_dirt": s = _thud(0.07, 400.0, 0.9, 33)
		"gun_land_wood": s = _mix([_ring([210.0, 430.0], 0.08, 0.8, 34), _thud(0.05, 1200.0, 0.4, 35)])
		"gun_land_metal": s = _ring([1250.0, 2710.0, 4400.0], 0.45, 0.8, 36)
		"gun_land_rock": s = _mix([_thud(0.05, 900.0, 0.7, 37), _ring([2900.0], 0.06, 0.35, 38)])
		"hit_dirt": s = _thud(0.09, 300.0, 0.9, 39)
		"hit_wood": s = _mix([_ring([330.0, 700.0], 0.06, 0.8, 40), _click(2200.0, 0.01, 0.7, 41)])
		"hit_metal": s = _mix([_click(3000.0, 0.004, 1.0, 42), _ring([830.0, 1920.0, 3310.0, 4750.0], 0.9, 0.9, 43)])
		"hit_rock": s = _mix([_click(2600.0, 0.006, 0.9, 44), _thud(0.05, 1500.0, 0.6, 45)])
		"ricochet": s = _ricochet()
		_:
			push_error("ProceduralSounds: unknown key '%s'" % key)
			s = PackedFloat32Array([0.0])
	return to_wav(s)


static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := 0.89 / peak
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


# --- Building blocks -------------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


## One-pole low-pass in place.
static func _lowpass(s: PackedFloat32Array, cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in s.size():
		y += a * (s[i] - y)
		s[i] = y


static func _highpass(s: PackedFloat32Array, cutoff: float) -> void:
	var a := exp(-TAU * cutoff / RATE)
	var x1 := 0.0
	var y := 0.0
	for i in s.size():
		y = a * (y + s[i] - x1)
		x1 = s[i]
		s[i] = y


## Short noise burst with an exponential decay plus a resonant ping: a click.
static func _click(freq: float, decay: float, amp: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := _buf(decay * 6.0 + 0.005)
	for i in s.size():
		var t := float(i) / RATE
		var env := exp(-t / decay)
		var noise := rng.randf_range(-1, 1) * exp(-t / (decay * 0.25))
		s[i] = amp * (0.6 * noise + 0.8 * sin(TAU * freq * t) * env)
	_highpass(s, 400.0)
	return s


## A few clicks in quick succession (ratchet, pawl), starting at [param offset].
static func _ratchet(count: int, spacing: float, amp: float, seed: int, offset := 0.0) -> PackedFloat32Array:
	var parts := []
	for k in count:
		var c := _click(3600.0 + 400.0 * k, 0.006, amp, seed + k * 101)
		var pad := _buf(offset + spacing * k)
		pad.append_array(c)
		parts.append(pad)
	return _mix(parts)


## Sum of decaying sine partials with a noise strike: metal rings and tinks.
static func _ring(freqs: Array, decay: float, amp: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := _buf(decay * 5.0 + 0.01)
	var phases := []
	for f in freqs:
		phases.append(rng.randf() * TAU)
	for i in s.size():
		var t := float(i) / RATE
		var v := rng.randf_range(-1, 1) * exp(-t / 0.002) * 0.5
		for k in freqs.size():
			var d: float = decay * (1.0 - 0.15 * k)
			v += sin(TAU * freqs[k] * t + phases[k]) * exp(-t / d) / (1.0 + k * 0.6)
		s[i] = v * amp
	return s


## Low-passed noise thump.
static func _thud(decay: float, cutoff: float, amp: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := _buf(decay * 6.0)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = rng.randf_range(-1, 1) * exp(-t / decay) * amp
	_lowpass(s, cutoff)
	_lowpass(s, cutoff * 1.5)
	return s


## Band-limited noise for sliding metal.
static func _scrape(length: float, cutoff: float, amp: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := _buf(length)
	for i in s.size():
		var t := float(i) / RATE
		var env := sin(PI * t / length) * (0.7 + 0.3 * sin(TAU * 37.0 * t))
		s[i] = rng.randf_range(-1, 1) * env * amp
	_lowpass(s, cutoff)
	_highpass(s, cutoff * 0.3)
	return s


# --- Gunshot layers ----------------------------------------------------------------

static func _shot_crack() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1873
	var s := _buf(0.16)
	for i in s.size():
		var t := float(i) / RATE
		# Muzzle blast: an N-wave front edge, then a burst of hot noise.
		var nwave := 0.0
		if t < 0.0012:
			nwave = 1.0 - 2.0 * t / 0.0012
		var noise := rng.randf_range(-1, 1) * exp(-t / 0.012)
		s[i] = 1.2 * nwave + noise
	_highpass(s, 700.0)
	return s


static func _shot_boom() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 45
	var s := _buf(1.6)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 38.0 + 70.0 * exp(-t / 0.08)  # pitch drops as the blast expands
		phase += TAU * f / RATE
		var body := sin(phase) * exp(-t / 0.22)
		var rumble := rng.randf_range(-1, 1) * exp(-t / 0.45) * 0.6
		s[i] = body + rumble * (1.0 - exp(-t / 0.004))
	_lowpass(s, 260.0)
	_lowpass(s, 400.0)
	return s


static func _shot_tail() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1860
	var s := _buf(2.6)
	for i in s.size():
		var t := float(i) / RATE
		var env := (1.0 - exp(-t / 0.03)) * exp(-t / 0.55)
		var flutter := 0.75 + 0.25 * sin(TAU * 3.1 * t) * sin(TAU * 1.7 * t)
		s[i] = rng.randf_range(-1, 1) * env * flutter
	_lowpass(s, 900.0)
	_lowpass(s, 1400.0)
	_highpass(s, 60.0)
	return s


static func _ricochet() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s := _buf(0.7)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 3200.0 - 2200.0 * t / 0.7 + 180.0 * sin(TAU * 23.0 * t)
		phase += TAU * f / RATE
		var env := (1.0 - exp(-t / 0.01)) * exp(-t / 0.25)
		s[i] = (sin(phase) * 0.8 + rng.randf_range(-1, 1) * 0.25) * env
	return s
