extends Node
## Autoload "Sfx": synthesized sound, no audio files needed.
## The tones are rendered once at startup into AudioStreamWAV buffers.
## To use real audio files instead, replace the entries of `streams`.

const RATE := 16000
const VOICES := 10
const MASTER := 0.8

var streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _heart: AudioStreamPlayer


func _ready() -> void:
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_pool.append(voice)
	_heart = AudioStreamPlayer.new()
	add_child(_heart)

	# One "lub-dub" at full volume; played quieter or louder through volume_db.
	var hb := _buf(0.5)
	_osc(hb, "sine", 70.0, 35.0, 0.12, 0.0, 0.16, 1.0, 0.01)
	_osc(hb, "sine", 58.0, 29.0, 0.12, 0.14, 0.16, 0.7, 0.01)
	streams["heartbeat"] = _to_stream(hb)

	streams["jump"] = _blip(420.0, 0.08, 0.08, "triangle")
	streams["dash"] = _sweep(900.0, 200.0, 0.18, 0.08)
	streams["state_up"] = _sweep(300.0, 900.0, 0.5, 0.1)     # fading further
	streams["state_down"] = _sweep(900.0, 300.0, 0.5, 0.1)   # becoming more solid
	var mir := _buf(0.7)
	_osc(mir, "sine", 200.0, 1600.0, 0.6, 0.0, 0.6, 0.1)
	_osc(mir, "sine", 1600.0, 200.0, 0.6, 0.0, 0.6, 0.06)
	streams["mirror"] = _to_stream(mir)
	streams["plate"] = _blip(160.0, 0.3, 0.2, "square")
	streams["die"] = _sweep(400.0, 40.0, 1.2, 0.2)
	streams["fall"] = _sweep(600.0, 30.0, 3.0, 0.15)
	var win := _buf(1.0)
	_osc(win, "triangle", 523.0, 523.0, 0.0, 0.0, 0.3, 0.1)
	_osc(win, "triangle", 659.0, 659.0, 0.0, 0.15, 0.3, 0.1)
	_osc(win, "triangle", 784.0, 784.0, 0.0, 0.30, 0.5, 0.1)
	streams["win"] = _to_stream(win)
	streams["talk"] = _blip(660.0, 0.05, 0.05, "sine")


func play(sound_name: String) -> void:
	if not streams.has(sound_name):
		return
	var voice: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	voice.stream = streams[sound_name]
	voice.volume_db = linear_to_db(MASTER)
	voice.play()


func heartbeat(volume: float) -> void:
	_heart.stream = streams["heartbeat"]
	_heart.volume_db = linear_to_db(maxf(0.0001, volume * MASTER))
	_heart.play()


# ------------------------------------------------------------ synthesis

func _buf(seconds: float) -> Array:
	var b: Array = []
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


## Adds one oscillator into buffer b.
## Frequency glides exponentially from f0 to f1 over sweep_dur seconds (0 = no glide).
## Gain: optional exponential attack, then an exponential decay to silence at `dur`.
func _osc(b: Array, wave: String, f0: float, f1: float, sweep_dur: float,
		start: float, dur: float, peak: float, attack: float = 0.0) -> void:
	var n0 := int(start * RATE)
	var n1 := mini(b.size(), int((start + dur) * RATE))
	var phase := 0.0
	for i in range(n0, n1):
		var t := float(i - n0) / RATE
		var f := f0
		if sweep_dur > 0.0:
			f = f0 * pow(f1 / f0, minf(t / sweep_dur, 1.0))
		phase += f / RATE
		var ph := fposmod(phase, 1.0)
		var s := 0.0
		match wave:
			"sine":
				s = sin(TAU * ph)
			"triangle":
				s = 4.0 * absf(ph - 0.5) - 1.0
			"square":
				s = 1.0 if ph < 0.5 else -1.0
		var env := 0.0
		if attack > 0.0 and t < attack:
			env = 0.0001 * pow(peak / 0.0001, t / attack)
		else:
			var span := maxf(0.0001, dur - attack)
			env = peak * pow(0.0001 / peak, clampf((t - attack) / span, 0.0, 1.0))
		b[i] = float(b[i]) + s * env


func _blip(freq: float, dur: float, volume: float, wave: String) -> AudioStreamWAV:
	var b := _buf(dur + 0.05)
	_osc(b, wave, freq, freq, 0.0, 0.0, dur, volume)
	return _to_stream(b)


func _sweep(from_hz: float, to_hz: float, dur: float, volume: float) -> AudioStreamWAV:
	var b := _buf(dur + 0.05)
	_osc(b, "sine", from_hz, to_hz, dur, 0.0, dur, volume)
	return _to_stream(b)


func _to_stream(b: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		var v := clampi(int(float(b[i]) * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
