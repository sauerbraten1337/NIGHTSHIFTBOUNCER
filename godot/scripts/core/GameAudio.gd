## Prozedurales Sound-Design.
##
## Kein externes Asset noetig: Kick, Bass, Hats, Crowd-Noise und SFX werden zur
## Laufzeit synthetisiert. Intensitaet folgt der Nacht.
##
## Portierung von src/core/audio.js. Das ist die Stelle, an der sich die
## Vorlage am wenigsten woertlich uebertragen laesst: WebAudio ist ein
## Knotengraph mit Oszillatoren, Filtern und Huellkurven, die die Audio-Engine
## des Browsers selbst rechnet. Godot bietet dafuer nichts Vergleichbares -
## also erzeugt dieses Modul die Samples selbst und schiebt sie ueber einen
## AudioStreamGenerator in die Ausgabe. Aufbau und Werte folgen dabei
## Baustein fuer Baustein der Vorlage:
##
##   WebAudio                       hier
##   ---------------------------    ------------------------------------
##   OscillatorNode                 _Voice mit Wellenform und Phase
##   GainNode + exponentialRamp     _Voice.envelope (dieselbe e-Kurve)
##   BiquadFilterNode               _Biquad (Direktform 1, gleiche Typen)
##   AudioBufferSourceNode (Noise)  _Voice mit weissem/braunem Rauschen
##   setInterval-Scheduler          _schedule() im _process
class_name GameAudio
extends Node

const MIX_RATE := 44100.0
const BUFFER_LENGTH := 0.1

var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null

var _started := false
var _muted := false
var _intensity := 0.4
var _bpm := 132.0

## Laufzeit in Sekunden seit dem Start - die gemeinsame Uhr aller Stimmen,
## entspricht ctx.currentTime.
var _time := 0.0
var _next_note_time := 0.0
var _step := 0

var _voices: Array = []

# Dauerhafte Bausteine des Graphen.
var _music_filter := _Biquad.new()   # lowpass vor dem Master
var _crowd := _Voice.new()           # braunes Rauschen, Bandpass
var _crowd_gain := 0.0
var _crowd_target := 0.0
var _filter_freq := 900.0
var _filter_target := 900.0

var muted: bool:
	get: return _muted

var enabled: bool:
	get: return _started and not _muted

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LENGTH
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = "Master"
	add_child(_player)

	_music_filter.set_lowpass(900.0, 0.7, MIX_RATE)
	_crowd.kind = _Voice.NOISE_BROWN
	_crowd.gain = 1.0
	_crowd.endless = true
	_crowd.filter.set_bandpass(700.0, 0.6, MIX_RATE)

## Muss nicht mehr aus einer Nutzergeste heraus aufgerufen werden - das war
## eine Browser-Auflage. Der Aufruf bleibt, damit der Spielfluss gleich ist.
func start() -> bool:
	if _started:
		return true
	_started = true
	_player.play()
	_playback = _player.get_stream_playback()
	_next_note_time = _time + 0.05
	return true

func stop() -> void:
	_started = false
	_crowd_target = 0.0
	_player.stop()
	_playback = null

func toggle_mute() -> bool:
	_muted = not _muted
	return _muted

## intensity 0..1 steuert Filter, Crowd und Arrangement.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	_filter_target = 500.0 + _intensity * 5200.0
	_crowd_target = 0.02 + _intensity * 0.1
	_bpm = 128.0 + round(_intensity * 10.0)

func set_music_volume(v: float) -> void:
	_music_volume = v

var _music_volume := 0.5

func _process(_delta: float) -> void:
	if not _started or _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_fill(frames)

func _fill(frames: int) -> void:
	var dt := 1.0 / MIX_RATE
	var master_gain := 0.0 if _muted else 0.9
	for i in frames:
		# Weiche Parameterfahrten (entsprechen setTargetAtTime).
		_filter_freq += (_filter_target - _filter_freq) * 0.00005
		_crowd_gain += (_crowd_target - _crowd_gain) * 0.00003
		_music_filter.set_lowpass(_filter_freq, 0.7, MIX_RATE)

		_schedule()

		var music := 0.0
		var sfx := 0.0
		for v: _Voice in _voices:
			if v.dest_music:
				music += v.sample(_time, dt)
			else:
				sfx += v.sample(_time, dt)

		music = _music_filter.process(music) * _music_volume
		var crowd := _crowd.sample(_time, dt) * _crowd_gain
		var out := (music + sfx * 0.55 + crowd) * master_gain
		out = clampf(out, -1.0, 1.0)
		_playback.push_frame(Vector2(out, out))

		_time += dt

	# Verklungene Stimmen aufraeumen.
	var alive: Array = []
	for v: _Voice in _voices:
		if not v.finished(_time):
			alive.append(v)
	_voices = alive

## Der Sequenzer aus der Vorlage: 16tel-Raster, Kick auf jeder Viertel,
## Hats ab mittlerer Intensitaet, Bass auf 3 und 11, Zusatzbass auf 14.
func _schedule() -> void:
	if _muted:
		return
	var seconds_per_step := 60.0 / _bpm / 4.0
	while _next_note_time < _time + 0.15:
		var t := _next_note_time
		var s := _step % 16
		if s % 4 == 0:
			_kick(t, 0.7 + _intensity * 0.4)
		if _intensity > 0.25 and s % 2 == 1:
			_hat(t, 0.08 + _intensity * 0.14)
		if _intensity > 0.45 and (s == 3 or s == 11):
			_sub(t, 55.0, 0.25 + _intensity * 0.25)
		if _intensity > 0.7 and s == 14:
			_sub(t, 73.0, 0.28)
		_next_note_time += seconds_per_step
		_step += 1

# ---------------- Bausteine des Beats ----------------

func _kick(time: float, gain: float = 1.0) -> void:
	var v := _Voice.new()
	v.kind = _Voice.SINE
	v.start_time = time
	v.freq_from = 150.0
	v.freq_to = 42.0
	v.freq_time = 0.11
	v.set_envelope(0.005, 0.9 * gain, 0.28)
	_voices.append(v)

func _sub(time: float, freq: float, gain: float = 0.5) -> void:
	var v := _Voice.new()
	v.kind = _Voice.SAW
	v.start_time = time
	v.freq_from = freq
	v.freq_to = freq
	v.set_envelope(0.01, gain, 0.19)
	v.filter.set_lowpass(320.0, 0.707, MIX_RATE)
	_voices.append(v)

func _hat(time: float, gain: float = 0.18) -> void:
	var v := _Voice.new()
	v.kind = _Voice.NOISE_WHITE
	v.start_time = time
	v.set_envelope(0.0, gain, 0.05)
	v.filter.set_highpass(7200.0, 0.707, MIX_RATE)
	_voices.append(v)

# ---------------- Kurze UI-/Gameplay-Sounds ----------------

func sfx(name: String) -> void:
	if not _started or _muted:
		return
	var t := _time
	match name:
		"beep":
			_tone(_Voice.SQUARE, 1100.0, 0.06, 0.12, t)
		"scan":
			_sweep(420.0, 1700.0, 0.22, 0.1, t)
		"ok":
			_tone(_Voice.SINE, 660.0, 0.09, 0.16, t)
			_tone(_Voice.SINE, 990.0, 0.1, 0.14, t + 0.09)
		"deny":
			_tone(_Voice.SAW, 190.0, 0.18, 0.16, t)
			_tone(_Voice.SAW, 120.0, 0.22, 0.16, t + 0.1)
		"alarm":
			_sweep(900.0, 300.0, 0.35, 0.18, t)
			_sweep(900.0, 300.0, 0.35, 0.18, t + 0.4)
		"door":
			_noise_hit(220.0, 0.3, 0.35, t)
		"radio":
			_tone(_Voice.SQUARE, 1500.0, 0.04, 0.07, t)
			_tone(_Voice.SQUARE, 1200.0, 0.04, 0.07, t + 0.06)
		"cash":
			_tone(_Voice.TRIANGLE, 880.0, 0.07, 0.14, t)
			_tone(_Voice.TRIANGLE, 1320.0, 0.12, 0.12, t + 0.07)
		"upgrade":
			_sweep(300.0, 1400.0, 0.5, 0.14, t)

func _tone(wave: int, freq: float, dur: float, gain: float, time: float) -> void:
	var v := _Voice.new()
	v.kind = wave
	v.dest_music = false
	v.start_time = time
	v.freq_from = freq
	v.freq_to = freq
	v.set_envelope(0.008, gain, dur)
	_voices.append(v)

func _sweep(from: float, to: float, dur: float, gain: float, time: float) -> void:
	var v := _Voice.new()
	v.kind = _Voice.SAW
	v.dest_music = false
	v.start_time = time
	v.freq_from = from
	v.freq_to = maxf(30.0, to)
	v.freq_time = dur
	v.set_envelope(0.02, gain, dur)
	v.filter.set_bandpass((from + to) * 0.5, 3.0, MIX_RATE)
	_voices.append(v)

func _noise_hit(freq: float, dur: float, gain: float, time: float) -> void:
	var v := _Voice.new()
	v.kind = _Voice.NOISE_WHITE
	v.dest_music = false
	v.start_time = time
	v.set_envelope(0.0, gain, dur)
	v.filter.set_lowpass(freq, 0.707, MIX_RATE)
	_voices.append(v)

# ================================================================
# Eine Stimme: Wellenform + Huellkurve + optionaler Filter.
# ================================================================

class _Voice extends RefCounted:
	enum { SINE, SAW, SQUARE, TRIANGLE, NOISE_WHITE, NOISE_BROWN }

	var kind := SINE
	var dest_music := true
	var start_time := 0.0
	var freq_from := 440.0
	var freq_to := 440.0
	## Ueber welche Zeit laeuft die Frequenzrampe? 0 = keine Rampe.
	var freq_time := 0.0
	var gain := 1.0
	var attack := 0.005
	var release := 0.2
	var endless := false

	var filter := _Biquad.new()
	var _phase := 0.0
	var _brown := 0.0

	func set_envelope(a: float, g: float, r: float) -> void:
		attack = maxf(a, 0.0005)
		gain = g
		release = r

	func finished(now: float) -> bool:
		if endless:
			return false
		return now > start_time + release + 0.05

	## Liefert das naechste Sample. `dt` ist die Dauer eines Samples.
	func sample(now: float, dt: float) -> float:
		if not endless and now < start_time:
			return 0.0
		var age := now - start_time

		# Frequenzrampe: WebAudio nutzt exponentialRampToValueAtTime, also
		# geometrisch zwischen from und to.
		var freq := freq_from
		if freq_time > 0.0 and freq_to != freq_from:
			var p := clampf(age / freq_time, 0.0, 1.0)
			freq = freq_from * pow(freq_to / freq_from, p)

		var raw := 0.0
		match kind:
			SINE:
				raw = sin(_phase * TAU)
			SAW:
				raw = _phase * 2.0 - 1.0
			SQUARE:
				raw = 1.0 if _phase < 0.5 else -1.0
			TRIANGLE:
				raw = 4.0 * absf(_phase - 0.5) - 1.0
			NOISE_WHITE:
				raw = randf() * 2.0 - 1.0
			NOISE_BROWN:
				var white := randf() * 2.0 - 1.0
				_brown = (_brown + 0.02 * white) / 1.02
				raw = _brown * 3.5
		_phase = fmod(_phase + freq * dt, 1.0)

		raw = filter.process(raw)
		return raw * _envelope(age)

	## Attack und Release wie in der Vorlage: von 0.0001 hoch und wieder
	## herunter, beide Rampen exponentiell.
	func _envelope(age: float) -> float:
		if endless:
			return gain
		if age < 0.0:
			return 0.0
		if age < attack:
			var p := age / attack
			return 0.0001 * pow(gain / 0.0001, p)
		var rest := release - attack
		if rest <= 0.0:
			return 0.0
		var q := clampf((age - attack) / rest, 0.0, 1.0)
		if q >= 1.0:
			return 0.0
		return gain * pow(0.0001 / gain, q)

# ================================================================
# Biquad-Filter (Direktform 1) - Ersatz fuer BiquadFilterNode.
# Formeln nach der Audio-EQ-Cookbook, dieselben wie im Browser.
# ================================================================

class _Biquad extends RefCounted:
	var _b0 := 1.0
	var _b1 := 0.0
	var _b2 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0
	var _active := false

	func set_lowpass(freq: float, q: float, rate: float) -> void:
		var w := TAU * clampf(freq, 20.0, rate * 0.45) / rate
		var alpha := sin(w) / (2.0 * maxf(0.0001, q))
		var cos_w := cos(w)
		var a0 := 1.0 + alpha
		_b0 = ((1.0 - cos_w) * 0.5) / a0
		_b1 = (1.0 - cos_w) / a0
		_b2 = _b0
		_a1 = (-2.0 * cos_w) / a0
		_a2 = (1.0 - alpha) / a0
		_active = true

	func set_highpass(freq: float, q: float, rate: float) -> void:
		var w := TAU * clampf(freq, 20.0, rate * 0.45) / rate
		var alpha := sin(w) / (2.0 * maxf(0.0001, q))
		var cos_w := cos(w)
		var a0 := 1.0 + alpha
		_b0 = ((1.0 + cos_w) * 0.5) / a0
		_b1 = -(1.0 + cos_w) / a0
		_b2 = _b0
		_a1 = (-2.0 * cos_w) / a0
		_a2 = (1.0 - alpha) / a0
		_active = true

	func set_bandpass(freq: float, q: float, rate: float) -> void:
		var w := TAU * clampf(freq, 20.0, rate * 0.45) / rate
		var alpha := sin(w) / (2.0 * maxf(0.0001, q))
		var cos_w := cos(w)
		var a0 := 1.0 + alpha
		_b0 = alpha / a0
		_b1 = 0.0
		_b2 = -alpha / a0
		_a1 = (-2.0 * cos_w) / a0
		_a2 = (1.0 - alpha) / a0
		_active = true

	func process(x: float) -> float:
		if not _active:
			return x
		var y := _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y
