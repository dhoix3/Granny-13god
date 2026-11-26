extends Node

# Procedural audio. The original game synthesised every sound at runtime,
# so this port does the same: no external audio files are required.

var streams: Dictionary = {}
var enabled := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rate := 22050
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_all()

func play(sound: String, volume: float = 1.0, pitch: float = 1.0, _reverb: bool = false) -> void:
	if not enabled:
		return
	var s: AudioStream = streams.get(sound)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = linear_to_db(clampf(volume, 0.001, 4.0))
	p.pitch_scale = clampf(pitch, 0.2, 4.0)
	p.play()

func stop_all() -> void:
	for p in _players:
		p.stop()

func _build_all() -> void:
	streams["step"] = _make_step(0.0)
	streams["step2"] = _make_step(1.7)
	streams["step_tile"] = _make_step(3.1)
	streams["creak"] = _make_creak()
	streams["door_slam"] = _make_slam()
	streams["lock"] = _make_lock()
	streams["unlock"] = _make_unlock()
	streams["pickup"] = _make_pickup()
	streams["search"] = _make_search()
	streams["break"] = _make_break()
	streams["snap"] = _make_snap()
	streams["scream"] = _make_scream()
	streams["heart"] = _make_heart()
	streams["meow"] = _make_meow(false)
	streams["hiss"] = _make_meow(true)
	streams["purr"] = _make_purr()
	streams["thunder"] = _make_thunder()
	streams["whisper"] = _make_whisper()
	streams["climb"] = _make_climb()
	streams["crossbow_shot"] = _make_crossbow()
	streams["crossbow_reload"] = _make_reload()
	streams["dart_hit"] = _make_dart_hit()
	streams["win"] = _make_win()
	streams["lose"] = _make_lose()
	streams["car_start"] = _make_car()
	streams["spider_hiss"] = _make_spider()
	streams["ui_move"] = _make_ui(false)
	streams["ui_select"] = _make_ui(true)

func _blank(dur: float) -> PackedFloat32Array:
	var n := int(dur * _rate)
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(0.0)
	return a

func _add_tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, kind: int = 0, curve: float = 1.0, vibrato: float = 0.0, vib_rate: float = 5.0) -> void:
	var i0 := int(start * _rate)
	var n := int(dur * _rate)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / float(_rate)
		var k := t / maxf(dur, 0.0001)
		var f := lerpf(f0, f1, k)
		if vibrato > 0.0:
			f *= 1.0 + sin(t * TAU * vib_rate) * vibrato
		phase += TAU * f / float(_rate)
		var v := 0.0
		match kind:
			0:
				v = sin(phase)
			1:
				v = 1.0 if sin(phase) >= 0.0 else -1.0
			2:
				v = 2.0 * fposmod(phase / TAU, 1.0) - 1.0
			3:
				v = _rng.randf_range(-1.0, 1.0)
		var env := minf(1.0, k * 24.0) * pow(maxf(0.0, 1.0 - k), curve)
		buf[idx] += v * amp * env

func _add_noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, curve: float = 2.0, smooth: float = 0.0) -> void:
	var i0 := int(start * _rate)
	var n := int(dur * _rate)
	var last := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var k := float(i) / float(maxi(1, n))
		var v := _rng.randf_range(-1.0, 1.0)
		if smooth > 0.0:
			last = lerpf(last, v, 1.0 - smooth)
			v = last
		var env := minf(1.0, k * 18.0) * pow(maxf(0.0, 1.0 - k), curve)
		buf[idx] += v * amp * env

func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = _rate
	w.stereo = false
	w.data = data
	return w

func _make_step(shift: float) -> AudioStreamWAV:
	var b := _blank(0.18)
	_add_noise(b, 0.0, 0.12, 0.20, 4.0, 0.55)
	_add_tone(b, 0.0, 0.14, 95.0 + shift * 8.0, 48.0 + shift * 4.0, 0.28, 0, 2.5)
	_add_tone(b, 0.005, 0.05, 1800.0 + shift * 210.0, 900.0, 0.05, 3, 3.0)
	return _wav(b)

func _make_creak() -> AudioStreamWAV:
	var b := _blank(0.62)
	_add_tone(b, 0.0, 0.55, 380.0, 150.0, 0.15, 2, 1.2, 0.05, 9.0)
	_add_tone(b, 0.05, 0.42, 520.0, 210.0, 0.07, 0, 1.4, 0.08, 7.0)
	_add_noise(b, 0.0, 0.5, 0.035, 2.0, 0.8)
	return _wav(b)

func _make_slam() -> AudioStreamWAV:
	var b := _blank(0.45)
	_add_tone(b, 0.0, 0.35, 120.0, 40.0, 0.45, 0, 3.0)
	_add_noise(b, 0.0, 0.22, 0.35, 3.0, 0.7)
	_add_tone(b, 0.02, 0.18, 320.0, 90.0, 0.12, 2, 3.0)
	return _wav(b)

func _make_lock() -> AudioStreamWAV:
	var b := _blank(0.25)
	_add_noise(b, 0.0, 0.04, 0.25, 2.0)
	_add_tone(b, 0.01, 0.08, 900.0, 500.0, 0.16, 0, 2.5)
	_add_noise(b, 0.13, 0.05, 0.20, 2.0)
	_add_tone(b, 0.14, 0.09, 700.0, 380.0, 0.13, 0, 2.5)
	return _wav(b)

func _make_unlock() -> AudioStreamWAV:
	var b := _blank(0.55)
	for i in 3:
		var s := i * 0.11
		_add_noise(b, s, 0.05, 0.18, 2.0)
		_add_tone(b, s, 0.10, 620.0 + i * 180.0, 420.0 + i * 90.0, 0.14, 0, 2.5)
	_add_tone(b, 0.34, 0.18, 520.0, 260.0, 0.12, 2, 2.0)
	return _wav(b)

func _make_pickup() -> AudioStreamWAV:
	var b := _blank(0.42)
	_add_tone(b, 0.0, 0.16, 640.0, 880.0, 0.22, 0, 1.5)
	_add_tone(b, 0.10, 0.25, 960.0, 1240.0, 0.18, 0, 1.8)
	_add_tone(b, 0.0, 0.30, 320.0, 480.0, 0.08, 0, 2.0)
	return _wav(b)

func _make_search() -> AudioStreamWAV:
	var b := _blank(0.45)
	for i in 4:
		_add_noise(b, i * 0.10, 0.08, 0.15, 3.0, 0.4)
		_add_tone(b, i * 0.10, 0.06, 260.0 + i * 40.0, 160.0, 0.07, 0, 2.0)
	return _wav(b)

func _make_break() -> AudioStreamWAV:
	var b := _blank(0.65)
	_add_noise(b, 0.0, 0.5, 0.38, 3.0, 0.15)
	_add_tone(b, 0.0, 0.10, 2400.0, 900.0, 0.16, 3, 3.0)
	for i in 5:
		_add_tone(b, 0.04 + i * 0.06, 0.07, 1200.0 + i * 240.0, 700.0, 0.07, 0, 3.0)
	return _wav(b)

func _make_snap() -> AudioStreamWAV:
	var b := _blank(0.42)
	_add_noise(b, 0.0, 0.04, 0.35, 2.0)
	_add_tone(b, 0.0, 0.16, 1400.0, 420.0, 0.28, 1, 2.4)
	_add_tone(b, 0.02, 0.30, 260.0, 90.0, 0.20, 0, 2.0)
	return _wav(b)

func _make_scream() -> AudioStreamWAV:
	var b := _blank(0.95)
	_add_tone(b, 0.0, 0.85, 780.0, 260.0, 0.28, 2, 1.2, 0.10, 8.0)
	_add_tone(b, 0.02, 0.75, 390.0, 130.0, 0.16, 1, 1.4, 0.06, 6.0)
	_add_noise(b, 0.0, 0.7, 0.16, 1.6, 0.35)
	return _wav(b)

func _make_heart() -> AudioStreamWAV:
	var b := _blank(0.65)
	_add_tone(b, 0.0, 0.22, 72.0, 42.0, 0.45, 0, 2.5)
	_add_tone(b, 0.25, 0.22, 66.0, 38.0, 0.32, 0, 2.5)
	return _wav(b)

func _make_meow(hiss: bool) -> AudioStreamWAV:
	var b := _blank(0.55 if not hiss else 0.45)
	if hiss:
		_add_noise(b, 0.0, 0.35, 0.32, 2.0, 0.05)
		_add_tone(b, 0.0, 0.35, 1500.0, 900.0, 0.10, 3, 2.0)
	else:
		_add_tone(b, 0.0, 0.48, 720.0, 480.0, 0.22, 0, 1.2, 0.12, 9.0)
		_add_tone(b, 0.08, 0.36, 960.0, 620.0, 0.10, 0, 1.4, 0.1, 8.0)
		_add_noise(b, 0.0, 0.25, 0.03, 2.0, 0.8)
	return _wav(b)

func _make_purr() -> AudioStreamWAV:
	var b := _blank(1.05)
	var n := b.size()
	for i in n:
		var t := float(i) / float(_rate)
		var env := minf(1.0, t * 8.0) * minf(1.0, (1.05 - t) * 8.0)
		var am := 0.55 + 0.45 * sin(t * TAU * 24.0)
		b[i] = sin(t * TAU * 52.0) * 0.16 * env * am + _rng.randf_range(-0.015, 0.015) * env
	return _wav(b)

func _make_thunder() -> AudioStreamWAV:
	var b := _blank(1.6)
	_add_noise(b, 0.0, 1.4, 0.45, 1.4, 0.90)
	_add_tone(b, 0.0, 1.2, 55.0, 28.0, 0.35, 0, 1.6)
	_add_noise(b, 0.15, 0.7, 0.25, 2.5, 0.75)
	return _wav(b)

func _make_whisper() -> AudioStreamWAV:
	var b := _blank(0.85)
	_add_noise(b, 0.0, 0.75, 0.14, 1.5, 0.94)
	_add_tone(b, 0.1, 0.5, 220.0, 140.0, 0.035, 3, 2.0)
	return _wav(b)

func _make_climb() -> AudioStreamWAV:
	var b := _blank(0.75)
	_add_noise(b, 0.0, 0.10, 0.15, 2.0, 0.5)
	_add_tone(b, 0.0, 0.16, 150.0, 90.0, 0.18, 0, 2.0)
	_add_noise(b, 0.20, 0.10, 0.14, 2.0, 0.5)
	_add_tone(b, 0.20, 0.16, 170.0, 100.0, 0.16, 0, 2.0)
	_add_tone(b, 0.4, 0.28, 330.0, 180.0, 0.07, 2, 2.0, 0.04, 8.0)
	return _wav(b)

func _make_crossbow() -> AudioStreamWAV:
	var b := _blank(0.5)
	_add_noise(b, 0.0, 0.05, 0.30, 2.0)
	_add_tone(b, 0.0, 0.22, 1600.0, 300.0, 0.24, 1, 2.2)
	_add_noise(b, 0.04, 0.30, 0.15, 2.5, 0.4)
	_add_tone(b, 0.04, 0.28, 700.0, 180.0, 0.10, 2, 2.0)
	return _wav(b)

func _make_reload() -> AudioStreamWAV:
	var b := _blank(0.32)
	_add_noise(b, 0.0, 0.04, 0.22, 2.0)
	_add_tone(b, 0.0, 0.08, 820.0, 420.0, 0.12, 0, 2.5)
	_add_noise(b, 0.16, 0.05, 0.20, 2.0)
	_add_tone(b, 0.16, 0.10, 640.0, 320.0, 0.11, 0, 2.5)
	return _wav(b)

func _make_dart_hit() -> AudioStreamWAV:
	var b := _blank(0.45)
	_add_tone(b, 0.0, 0.25, 160.0, 70.0, 0.28, 0, 2.0)
	_add_noise(b, 0.0, 0.18, 0.20, 2.5, 0.3)
	_add_tone(b, 0.10, 0.25, 600.0, 300.0, 0.07, 3, 2.0)
	return _wav(b)

func _make_win() -> AudioStreamWAV:
	var b := _blank(1.2)
	var notes := [392.0, 523.25, 659.25, 783.99]
	for i in notes.size():
		_add_tone(b, i * 0.16, 0.5, notes[i], notes[i], 0.16, 0, 1.2)
		_add_tone(b, i * 0.16, 0.5, notes[i] * 0.5, notes[i] * 0.5, 0.07, 0, 1.4)
	_add_tone(b, 0.64, 0.5, 1046.5, 1046.5, 0.10, 0, 1.5)
	return _wav(b)

func _make_lose() -> AudioStreamWAV:
	var b := _blank(1.3)
	var notes := [392.0, 329.63, 261.63, 196.0]
	for i in notes.size():
		_add_tone(b, i * 0.22, 0.6, notes[i], notes[i] * 0.98, 0.16, 2, 1.2)
		_add_tone(b, i * 0.22, 0.6, notes[i] * 0.5, notes[i] * 0.5, 0.08, 0, 1.4)
	return _wav(b)

func _make_car() -> AudioStreamWAV:
	var b := _blank(1.5)
	var n := b.size()
	for i in n:
		var t := float(i) / float(_rate)
		var env := minf(1.0, t * 3.0) * minf(1.0, (1.5 - t) * 2.0)
		var f := 42.0 + sin(t * 3.0) * 5.0 + t * 18.0
		var v := sin(t * TAU * f) * 0.22 + sin(t * TAU * f * 2.0) * 0.10
		v += _rng.randf_range(-0.02, 0.02)
		b[i] = v * env
	_add_noise(b, 0.0, 0.25, 0.12, 2.0, 0.3)
	return _wav(b)

func _make_spider() -> AudioStreamWAV:
	var b := _blank(0.55)
	_add_noise(b, 0.0, 0.4, 0.22, 2.0, 0.15)
	_add_tone(b, 0.0, 0.4, 1800.0, 2600.0, 0.06, 3, 2.0, 0.2, 12.0)
	_add_tone(b, 0.05, 0.3, 300.0, 200.0, 0.06, 2, 2.0)
	return _wav(b)

func _make_ui(select: bool) -> AudioStreamWAV:
	var b := _blank(0.16 if not select else 0.24)
	_add_noise(b, 0.0, 0.03, 0.10, 2.0)
	_add_tone(b, 0.0, 0.08, 520.0 if not select else 760.0, 420.0, 0.09, 0, 2.5)
	if select:
		_add_tone(b, 0.07, 0.12, 980.0, 680.0, 0.08, 0, 2.2)
	return _wav(b)
