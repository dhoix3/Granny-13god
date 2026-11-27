extends Node

# Аудио-директор: шины Master/Music/SFX, музыкальные состояния,
# амбиентные петли по этажам (ветер/чердак/подвал), 3D-позиционирование
# с грубым приглушением стенами (occlusion) и лёгкое затухание плееров.

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

# --- амбиентные слои (петля на этаж + ветер на весь дом) ---
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_flip := false
var _amb_track := ""
var _amb_fade := 0.0
var _amb_target := ""

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
	_amb_a = AudioStreamPlayer.new()
	_amb_a.bus = "SFX"
	add_child(_amb_a)
	_amb_b = AudioStreamPlayer.new()
	_amb_b.bus = "SFX"
	add_child(_amb_b)
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

# Приглушение стенами: фактор 1.0 — прямая видимость, 0.45 — за стеной/дверью.
# level — номер этажа, от и до — локальные координаты точек.
func occlusion_factor(level: LevelData, from: Vector2, to: Vector2) -> float:
	if level == null:
		return 1.0
	if level.line_of_sight(from.x, from.y, to.x, to.y):
		return 1.0
	return 0.45

# Мировой звук в точке уровня. root — корень уровня (HouseWorld.get_root),
# local_pos — координаты внутри уровня. occ — готовый фактор приглушения.
func play3d(sound: String, root: Node3D, local_pos: Vector3, volume: float = 1.0, pitch: float = 1.0, unit_size: float = 7.0, max_dist: float = 0.0, occ: float = 1.0) -> void:
	if not enabled or root == null or not root.is_inside_tree():
		return
	var s: AudioStream = streams.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = linear_to_db(clampf(volume * occ, 0.001, 4.0))
	p.pitch_scale = clampf(pitch * (0.92 + 0.08 * occ), 0.2, 4.0)
	p.unit_size = unit_size
	p.max_distance = max_dist
	p.max_db = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	root.add_child(p)
	p.position = local_pos
	p.play()
	p.finished.connect(p.queue_free)

# --- амбиент: плавный переход между этажными петлями ---
func set_ambient(track: String) -> void:
	# цель обновляется всегда: запрос текущего слоя отменяет затухающий переход
	_amb_target = track

# --- музыка: переключение петли с мягким переходом ---
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
	_update_ambient(dt)

func _update_ambient(dt: float) -> void:
	if _amb_target != _amb_track:
		# кроссфейд на новый слой
		_amb_fade = maxf(0.0, _amb_fade - dt * 0.7)
		if _amb_fade <= 0.001:
			_amb_track = _amb_target
			var s: AudioStream = streams.get(_amb_track)
			var inp: AudioStreamPlayer = _amb_b if _amb_flip else _amb_a
			var outp: AudioStreamPlayer = _amb_a if _amb_flip else _amb_b
			_amb_flip = not _amb_flip
			inp.stream = s
			if s != null:
				inp.play()
			else:
				inp.stop()
			outp.stop()
	else:
		_amb_fade = minf(1.0, _amb_fade + dt * 0.5)
	var vin := linear_to_db(clampf(0.42 * _amb_fade, 0.0001, 4.0))
	var on_player: AudioStreamPlayer = _amb_b if _amb_flip else _amb_a
	var off_player: AudioStreamPlayer = _amb_a if _amb_flip else _amb_b
	if on_player.stream != null:
		on_player.volume_db = vin
	if off_player.stream != null and off_player.playing:
		off_player.volume_db = maxf(-50.0, off_player.volume_db - dt * 9.0)
		if off_player.volume_db <= -48.0:
			off_player.stop()

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
	_amb_a.stop()
	_amb_b.stop()
	_amb_track = ""
	_amb_target = ""

# ------------------------------------------------------------------ загрузка ресурсов

const LOOPED := ["music_menu", "music_ambient", "music_tension", "music_chase", "music_return", "wind_loop", "cellar_loop", "attic_loop"]
const SOUNDS := [
	"step", "step2", "step_tile", "step_wood", "step_concrete", "step_rug",
	"granny_step", "granny_step2", "granny_step3", "granny_gasps", "granny_lost",
	"granny_pant", "granny_hum", "granny_rummage",
	"creak", "floor_creak2", "door_slam", "metal_door", "lock", "unlock",
	"pickup", "item_drop", "drawer", "search", "stairs",
	"break", "snap", "scream", "heart", "meow", "hiss", "purr", "thunder",
	"whisper", "climb", "crossbow_shot", "crossbow_reload", "dart_hit",
	"win", "lose", "car_start", "spider_hiss", "ui_move", "ui_select",
	"hum", "house_settle", "distant_noise", "something_falls", "window_scratch",
	"wind_loop", "cellar_loop", "attic_loop",
	"music_menu", "music_ambient", "music_tension", "music_chase", "music_return",
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
