extends Node

# Procedural audio. The original game synthesised every sound at runtime,
# so this port does the same: no external audio files are required.
# Плюс: шины Master/Music/SFX, музыкальные петли и 3D-позиционирование.

var streams: Dictionary = {}
var enabled := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0

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
	_ensure_buses()
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_load_all()

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
			# У новой шины ещё нет имени — get_bus_index(name) вернёт -1.
			# add_bus() добавляет в конец, индекс = bus_count - 1.
			var idx := AudioServer.bus_count - 1
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

# Переключить музыкальную петлю с мягким переходом.
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

func set_music(track: String) -> void:
	if track == music_track:
		_pending_track = ""
		music_target_fade = 1.0
		return
	if music_track == "":
		music_fade = 0.0  # старт из тишины — плавное появление
	_pending_track = track
	_pending_t = 0.8 if music_track != "" else 0.0

func stop_all() -> void:
	for p in _players:
		p.stop()

# ------------------------------------------------------------------ загрузка ресурсов

const LOOPED := ["music_menu", "music_ambient", "music_tension", "music_chase"]
const SOUNDS := [
	"step", "step2", "step_tile", "step_wood", "step_concrete", "step_rug",
	"granny_step", "creak", "door_slam", "lock", "unlock", "pickup", "search",
	"break", "snap", "scream", "heart", "meow", "hiss", "purr", "thunder",
	"whisper", "climb", "crossbow_shot", "crossbow_reload", "dart_hit",
	"win", "lose", "car_start", "spider_hiss", "ui_move", "ui_select",
	"hum", "music_menu", "music_ambient", "music_tension", "music_chase",
]

func _load_all() -> void:
	for snd in SOUNDS:
		var s: AudioStream = load("res://assets/snd/%s.wav" % snd)
		if s == null:
			push_warning("audio: нет файла %s.wav" % snd)
			continue
		if snd in LOOPED:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		streams[snd] = s
