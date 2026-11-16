# res://autoload/ProceduralSFX.gd
# Весь звук синтезируется кодом при старте — никаких внешних .wav/.ogg.
# Детерминированный генератор шума (LCG) вместо RNG.
extends Node

const RATE: int = 22050
const MUSIC_RATE: int = 16000

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _siren: AudioStreamPlayer
var _music: AudioStreamPlayer
var _lcg: int = 20240611
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(10):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_siren = AudioStreamPlayer.new()
	_siren.volume_db = -17.0
	add_child(_siren)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -17.0
	add_child(_music)
	_build_all()
	muted = GameState.sfx_muted
	_apply_mute()


func _rnd() -> float:
	_lcg = (_lcg * 1103515245 + 12345) & 0x7fffffff
	return float(_lcg) / float(0x3fffffff) - 1.0


func _make(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _buf(dur: float, rate: int = RATE) -> PackedFloat32Array:
	var a: PackedFloat32Array = PackedFloat32Array()
	a.resize(int(dur * rate))
	return a


# Простой «инструмент»: частота может скользить от f0 к f1, огибающая — экспоненциальный спад.
func _tone(dur: float, f0: float, f1: float, wave: String, decay: float, vol: float, noise_mix: float = 0.0) -> PackedFloat32Array:
	var a: PackedFloat32Array = _buf(dur)
	var phase: float = 0.0
	var n: int = a.size()
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var k: float = float(i) / float(n)
		var f: float = lerpf(f0, f1, k)
		phase += TAU * f / float(RATE)
		var w: float = 0.0
		match wave:
			"sine": w = sin(phase)
			"square": w = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw": w = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"tri": w = absf(fmod(phase / TAU, 1.0) * 4.0 - 2.0) - 1.0
		var env: float = exp(-t * decay)
		var attack: float = minf(1.0, t / 0.004)
		a[i] = (w * (1.0 - noise_mix) + _rnd() * noise_mix) * env * attack * vol
	return a


func _concat(parts: Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = a.duplicate()
	if b.size() > out.size():
		out.resize(b.size())
	for i in range(b.size()):
		out[i] += b[i]
	return out


func _arp(notes: Array, step: float, wave: String, decay: float, vol: float) -> PackedFloat32Array:
	var parts: Array = []
	for f in notes:
		parts.append(_tone(step, float(f), float(f), wave, decay, vol))
	return _concat(parts)


func _build_all() -> void:
	_sounds["step"] = _make(_mix(_tone(0.09, 95.0, 60.0, "sine", 32.0, 0.5), _tone(0.05, 0.0, 0.0, "sine", 80.0, 0.25, 1.0)))
	_sounds["wait"] = _make(_tone(0.05, 700.0, 700.0, "sine", 90.0, 0.15))
	_sounds["dash"] = _make(_mix(_tone(0.2, 900.0, 200.0, "saw", 9.0, 0.22), _tone(0.2, 0.0, 0.0, "sine", 12.0, 0.3, 1.0)))
	_sounds["pickup"] = _make(_arp([880.0, 1320.0], 0.07, "square", 14.0, 0.2))
	_sounds["gold"] = _make(_arp([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.09, "tri", 7.0, 0.4))
	_sounds["door"] = _make(_mix(_tone(0.28, 150.0, 340.0, "square", 6.0, 0.18), _tone(0.28, 0.0, 0.0, "sine", 8.0, 0.1, 1.0)))
	_sounds["alarm_on"] = _make(_arp([880.0, 620.0, 880.0, 620.0], 0.11, "square", 4.0, 0.3))
	_sounds["alarm_off"] = _make(_arp([523.0, 392.0, 262.0], 0.13, "tri", 6.0, 0.35))
	_sounds["laser"] = _make(_mix(_tone(0.32, 1500.0, 150.0, "saw", 6.0, 0.28), _tone(0.32, 0.0, 0.0, "sine", 8.0, 0.15, 1.0)))
	_sounds["shot"] = _make(_mix(_tone(0.3, 0.0, 0.0, "sine", 9.0, 0.5, 1.0), _tone(0.3, 140.0, 40.0, "sine", 10.0, 0.6)))
	_sounds["hit"] = _make(_mix(_tone(0.35, 90.0, 35.0, "sine", 8.0, 0.7), _tone(0.2, 0.0, 0.0, "sine", 14.0, 0.4, 1.0)))
	_sounds["smoke"] = _make(_tone(0.55, 0.0, 0.0, "sine", 4.0, 0.22, 1.0))
	_sounds["throw"] = _make(_tone(0.14, 400.0, 900.0, "sine", 14.0, 0.25))
	_sounds["decoy"] = _make(_arp([1568.0, 1568.0, 1175.0, 1568.0], 0.08, "sine", 10.0, 0.3))
	_sounds["emp"] = _make(_mix(_tone(0.55, 160.0, 1900.0, "saw", 4.0, 0.2), _tone(0.55, 0.0, 0.0, "sine", 5.0, 0.2, 1.0)))
	_sounds["stun"] = _make(_mix(_tone(0.3, 0.0, 0.0, "sine", 7.0, 0.4, 1.0), _tone(0.3, 220.0, 110.0, "square", 8.0, 0.2)))
	_sounds["cloak"] = _make(_concat([_tone(0.12, 500.0, 900.0, "sine", 7.0, 0.25), _tone(0.2, 900.0, 300.0, "sine", 8.0, 0.2)]))
	_sounds["suspicious"] = _make(_arp([660.0, 880.0], 0.1, "sine", 8.0, 0.3))
	_sounds["spotted"] = _make(_mix(_tone(0.25, 1100.0, 1100.0, "saw", 6.0, 0.28), _tone(0.25, 550.0, 550.0, "square", 6.0, 0.18)))
	_sounds["switch"] = _make(_concat([_tone(0.03, 1800.0, 1800.0, "square", 60.0, 0.3), _tone(0.14, 300.0, 200.0, "sine", 10.0, 0.3)]))
	_sounds["vent"] = _make(_tone(0.2, 70.0, 55.0, "sine", 5.0, 0.55, 0.25))
	_sounds["win"] = _make(_arp([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0, 1568.0], 0.1, "tri", 4.0, 0.4))
	_sounds["fail"] = _make(_arp([392.0, 370.0, 330.0, 262.0, 196.0], 0.17, "saw", 3.5, 0.25))
	_sounds["click"] = _make(_tone(0.04, 1200.0, 1200.0, "square", 70.0, 0.22))
	_sounds["select"] = _make(_arp([660.0, 990.0], 0.06, "square", 16.0, 0.2))
	_sounds["undo"] = _make(_tone(0.22, 700.0, 250.0, "tri", 8.0, 0.35))
	_sounds["error"] = _make(_tone(0.12, 140.0, 120.0, "square", 14.0, 0.22))
	_sounds["spawn"] = _make(_tone(0.45, 100.0, 400.0, "saw", 5.0, 0.3))
	_sounds["climax"] = _make(_mix(_arp([196.0, 185.0, 196.0, 185.0, 196.0, 185.0], 0.12, "saw", 3.0, 0.3), _tone(0.72, 0.0, 0.0, "sine", 2.0, 0.12, 1.0)))
	_sounds["hover"] = _make(_tone(0.03, 1500.0, 1700.0, "square", 90.0, 0.12))
	_sounds["blip_h"] = _make(_tone(0.045, 520.0, 560.0, "square", 50.0, 0.14))
	_sounds["blip_ai"] = _make(_mix(_tone(0.06, 180.0, 120.0, "saw", 40.0, 0.18), _tone(0.06, 0.0, 0.0, "sine", 60.0, 0.06, 1.0)))
	_sounds["blip_t"] = _make(_tone(0.04, 880.0, 920.0, "tri", 60.0, 0.16))
	_sounds["stamp"] = _make(_mix(_tone(0.5, 70.0, 28.0, "sine", 7.0, 0.9), _tone(0.3, 0.0, 0.0, "sine", 14.0, 0.5, 1.0)))
	_sounds["achieve"] = _make(_arp([659.0, 880.0, 1175.0, 1760.0], 0.08, "square", 6.0, 0.22))
	_sounds["combo"] = _make(_arp([880.0, 1320.0], 0.05, "tri", 14.0, 0.28))
	_sounds["whoosh"] = _make(_tone(0.35, 200.0, 1200.0, "sine", 6.0, 0.18, 0.5))
	_sounds["glitch"] = _make(_mix(_tone(0.22, 0.0, 0.0, "sine", 6.0, 0.35, 1.0), _tone(0.22, 90.0, 60.0, "square", 8.0, 0.2)))
	_sounds["boot"] = _make(_arp([262.0, 330.0, 392.0, 523.0, 659.0, 784.0], 0.05, "square", 10.0, 0.16))
	_build_siren()
	_build_music()


func _build_siren() -> void:
	var dur: float = 1.6
	var a: PackedFloat32Array = _buf(dur)
	var phase: float = 0.0
	for i in range(a.size()):
		var t: float = float(i) / float(RATE)
		var f: float = 640.0 + 280.0 * sin(TAU * t / dur - PI * 0.5)
		phase += TAU * f / float(RATE)
		var w: float = sin(phase) + 0.35 * sin(phase * 2.0)
		a[i] = w * 0.35
	_sounds["siren"] = _make(a, RATE, true)


func _build_music() -> void:
	# 4 такта по 2 секунды, до-минор: Cm | Ab | Bb | Gm — гул + пульсирующий арпеджио.
	var dur: float = 8.0
	var n: int = int(dur * MUSIC_RATE)
	var a: PackedFloat32Array = PackedFloat32Array()
	a.resize(n)
	var roots: Array = [65.41, 51.91, 58.27, 49.0]
	var chords: Array = [
		[261.63, 311.13, 392.0, 523.25], [207.65, 261.63, 311.13, 415.3],
		[233.08, 293.66, 349.23, 466.16], [196.0, 233.08, 293.66, 392.0],
	]
	var step_len: float = 0.25
	for i in range(n):
		var t: float = float(i) / float(MUSIC_RATE)
		var bar: int = int(t / 2.0) % 4
		var bt: float = fmod(t, 2.0)
		# бас-гул
		var bass: float = sin(TAU * roots[bar] * t) * 0.5 + sin(TAU * roots[bar] * 2.0 * t + 0.4) * 0.12
		bass *= 0.5 + 0.5 * sin(TAU * bt / 2.0 * 0.5 + 1.0) * 0.4
		# арпеджио
		var st: int = int(bt / step_len)
		var local: float = fmod(bt, step_len)
		var pattern: Array = [0, 2, 1, 3, 2, 1, 3, 2]
		var note: float = chords[bar][pattern[st % 8]]
		var env: float = exp(-local * 9.0)
		var arp: float = (1.0 if sin(TAU * note * t) >= 0.0 else -1.0) * 0.5 + sin(TAU * note * 2.0 * t) * 0.2
		arp *= env * 0.25
		# пэд
		var pad: float = 0.0
		for c in chords[bar]:
			pad += sin(TAU * c * 0.5 * t + sin(TAU * 0.2 * t) * 0.6)
		pad *= 0.045
		a[i] = (bass * 0.55 + arp + pad)
	# склейка петли: плавное затухание краёв
	var fade: int = int(0.02 * MUSIC_RATE)
	for i in range(fade):
		var k: float = float(i) / float(fade)
		a[i] *= k
		a[n - 1 - i] *= k
	_sounds["music"] = _make(a, MUSIC_RATE, true)


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not _sounds.has(sound):
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db - 6.0
	p.play()


func start_siren() -> void:
	if _siren.playing or not _sounds.has("siren"):
		return
	_siren.stream = _sounds["siren"]
	_siren.play()


func stop_siren() -> void:
	_siren.stop()


func start_music() -> void:
	if _music.playing or not _sounds.has("music"):
		return
	_music.stream = _sounds["music"]
	_music.play()


func stop_music() -> void:
	_music.stop()


func toggle_mute() -> void:
	muted = not muted
	GameState.sfx_muted = muted
	GameState.save_progress()
	_apply_mute()


func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, muted)
