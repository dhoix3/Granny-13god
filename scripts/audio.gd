extends Node

# Procedural audio. The original game synthesised every sound at runtime,
# so this port does the same: no external audio files are required.
# Плюс: шины Master/Music/SFX, музыкальные петли и 3D-позиционирование.

var streams: Dictionary = {}
var enabled := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rate := 22050
var _rng := RandomNumberGenerator.new()

var _buses_ready := false
var music_player: AudioStreamPlayer
var music_track := ""
var music_fade := 1.0
var music_target_fade := 1.0
var music_energy := 1.0
var _pending_track := ""
var _pending_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	_ensure_buses()
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_build_all()

func set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)

func _ensure_buses() -> void:
	if _buses_ready:
		return
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_index(bus_name)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_buses_ready = true

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

# Мировой звук в точке уровня. root — корень уровня (WorldBuilder.get_root),
# local_pos — координаты внутри уровня. Плеер освобождается сам.
func play3d(sound: String, root: Node3D, local_pos: Vector3, volume: float = 1.0, pitch: float = 1.0, unit_size: float = 7.0, max_dist: float = 0.0) -> void:
	if not enabled or root == null or not root.is_inside_tree():
		return
	var s: AudioStream = streams.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = linear_to_db(clampf(volume, 0.001, 4.0))
	p.pitch_scale = clampf(pitch, 0.2, 4.0)
	p.unit_size = unit_size
	p.max_distance = max_dist
	p.max_db = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	root.add_child(p)
	p.position = local_pos
	p.play()
	p.finished.connect(p.queue_free)

func _process(dt: float) -> void:
	if music_player == null:
		return
	if _pending_track != "":
		_pending_t -= dt
		music_fade = maxf(0.0, music_fade - dt * 2.0)
		if _pending_t <= 0.0 or music_fade <= 0.0:
			if _pending_track != music_track:
				music_track = _pending_track
				var s: AudioStream = streams.get(music_track)
				music_player.stream = s
				if s != null:
					music_player.play()
				else:
					music_player.stop()
				_pending_track = ""
			music_fade = minf(1.0, music_fade + dt * 0.8)
			music_target_fade = 1.0
	else:
		music_fade = move_toward(music_fade, music_target_fade, dt * 0.8)
	if music_player.stream != null:
		music_player.volume_db = linear_to_db(clampf(0.55 * music_energy * music_fade, 0.0001, 4.0))

# Переключить музыкальную петлю с мягким переходом.
func set_music(track: String) -> void:
	if track == music_track:
		_pending_track = ""
		music_target_fade = 1.0
		return
	_pending_track = track
	_pending_t = 0.8 if music_track != "" else 0.0

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
	streams["hum"] = _make_hum()
	streams["music_menu"] = _make_music_menu()
	streams["music_ambient"] = _make_music_ambient()

func _loop_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	# бесшовная петля: перекрёстный раствор последних 0.5 с в начало
	var n := buf.size()
	var m := int(0.5 * _rate)
	if n > m * 2:
		for i in m:
			var k := float(i) / float(m)
			buf[i] = buf[i] * k + buf[n - m + i] * (1.0 - k)
		buf.resize(n - m)
	var w := _wav(buf)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w

# Мелодичный гул Гренни — слышен при её патруле, выдаёт позицию.
func _make_hum() -> AudioStreamWAV:
	var b := _blank(2.6)
	var notes := [[0.0, 0.5, 220.0], [0.5, 0.4, 233.0], [0.9, 0.7, 196.0], [1.6, 0.45, 174.6], [2.05, 0.5, 220.0]]
	for n in notes:
		_add_tone(b, float(n[0]), float(n[1]), float(n[2]), float(n[2]) * 0.98, 0.16, 0, 1.6, 0.03, 5.5)
		_add_tone(b, float(n[0]), float(n[1]), float(n[2]) * 0.5, float(n[2]) * 0.49, 0.05, 0, 1.8)
	_add_noise(b, 0.0, 2.4, 0.012, 1.5, 0.92)
	return _wav(b)

# Тема главного меню: низкий дрон + редкие «колокольчики» в ля-миноре.
func _make_music_menu() -> AudioStreamWAV:
	var b := _blank(24.0)
	_add_tone(b, 0.0, 24.0, 55.0, 55.0, 0.10, 0, 0.15)
	_add_tone(b, 0.0, 24.0, 110.0, 109.5, 0.05, 0, 0.15)
	_add_noise(b, 0.0, 24.0, 0.014, 0.2, 0.985)
	var seq := [440.0, 523.25, 392.0, 329.63, 440.0, 659.25, 523.25, 392.0, 329.63, 293.66, 329.63, 440.0]
	var t := 1.0
	for i in seq.size():
		var f: float = seq[i]
		_add_tone(b, t, 2.6, f, f, 0.045, 0, 2.6)
		_add_tone(b, t + 0.02, 2.2, f * 2.0, f * 2.0, 0.016, 0, 3.4)
		t += 1.8 + _rng.randf() * 0.4
	# мягкое эхо
	var echo := _blank(24.0)
	for i in b.size():
		if i >= 3300:
			echo[i] += b[i - 3300] * 0.35
		if i >= 6600:
			echo[i] += b[i - 6600] * 0.16
	for i in b.size():
		b[i] += echo[i]
	return _loop_wav(b)

# Эмбиент дома: дождь + ветер + низкий гул. Тихий фон игрового процесса.
func _make_music_ambient() -> AudioStreamWAV:
	var b := _blank(32.0)
	# низкий дрон
	_add_tone(b, 0.0, 32.0, 46.0, 46.0, 0.16, 0, 0.1)
	_add_tone(b, 0.0, 32.0, 92.0, 91.5, 0.05, 0, 0.12)
	# шум дождя — плотный сглаженный белый шум
	_add_noise(b, 0.0, 32.0, 0.055, 0.25, 0.86)
	# порывы ветра
	var wind_t := 3.0
	while wind_t < 30.0:
		var dur := 2.5 + _rng.randf() * 3.0
		_add_noise(b, wind_t, dur, 0.045 + _rng.randf() * 0.03, 1.0, 0.97)
		wind_t += dur + 2.0 + _rng.randf() * 4.0
	# редкие дальние раскаты
	_add_noise(b, 9.5, 2.2, 0.03, 2.2, 0.93)
	_add_tone(b, 9.5, 2.0, 50.0, 30.0, 0.05, 0, 1.5)
	_add_noise(b, 23.0, 2.5, 0.035, 2.4, 0.92)
	return _loop_wav(b)

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
