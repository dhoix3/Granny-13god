class_name GameSettings
extends RefCounted

# Настройки игры: громкость, взгляд, видео (профили качества), тач.
# Хранятся в user://settings.cfg, применяются при старте и при изменении.

const PATH := "user://settings.cfg"

const MSAA_OFF := 0
const MSAA_2X := 1
const MSAA_4X := 2

var master_volume := 1.0
var music_volume := 0.75
var sfx_volume := 1.0
var mouse_sensitivity := 1.0
var invert_y := false
var fullscreen := false
var flashlight_shadows := true
var msaa := MSAA_2X
# Профиль качества: 0 Низкий / 1 Средний / 2 Высокий (Mats.QUALITY_LABELS).
# На Android дефолт — Средний (без конфига), на ПК — Высокий.
var quality := 2
# Сенсорное управление: масштаб кнопок/джойстика и признак платформы.
var touch_scale := 1.0
var is_touch := false

static func load_settings() -> GameSettings:
	var s := GameSettings.is_touch_platform()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		s.master_volume = clampf(float(cfg.get_value("audio", "master", s.master_volume)), 0.0, 1.0)
		s.music_volume = clampf(float(cfg.get_value("audio", "music", s.music_volume)), 0.0, 1.0)
		s.sfx_volume = clampf(float(cfg.get_value("audio", "sfx", s.sfx_volume)), 0.0, 1.0)
		s.mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", s.mouse_sensitivity)), 0.2, 2.5)
		s.invert_y = bool(cfg.get_value("input", "invert_y", s.invert_y))
		s.fullscreen = bool(cfg.get_value("video", "fullscreen", s.fullscreen))
		s.flashlight_shadows = bool(cfg.get_value("video", "flashlight_shadows", s.flashlight_shadows))
		s.msaa = clampi(int(cfg.get_value("video", "msaa", s.msaa)), MSAA_OFF, MSAA_4X)
		s.quality = clampi(int(cfg.get_value("video", "quality", s.quality)), 0, 2)
		s.touch_scale = clampf(float(cfg.get_value("touch", "scale", s.touch_scale)), 0.75, 1.8)
	return s

static func is_touch_platform() -> GameSettings:
	var s := GameSettings.new()
	s.is_touch = OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	if s.is_touch:
		s.quality = 1
		s.msaa = MSAA_OFF
		s.fullscreen = true
	return s

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "flashlight_shadows", flashlight_shadows)
	cfg.set_value("video", "msaa", msaa)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("touch", "scale", touch_scale)
	cfg.save(PATH)

func apply(viewport: Viewport) -> void:
	apply_audio()
	apply_video(viewport)

func apply_audio() -> void:
	Audio.set_bus_volume("Master", master_volume)
	Audio.set_bus_volume("Music", music_volume)
	Audio.set_bus_volume("SFX", sfx_volume)

func apply_video(viewport: Viewport) -> void:
	if viewport == null:
		return
	var win := viewport as Window
	if win != null:
		if fullscreen:
			win.mode = Window.MODE_FULLSCREEN
		else:
			win.mode = Window.MODE_WINDOWED
	match msaa:
		MSAA_OFF:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		MSAA_2X:
			viewport.msaa_3d = Viewport.MSAA_2X
		MSAA_4X:
			viewport.msaa_3d = Viewport.MSAA_4X

func msaa_label() -> String:
	match msaa:
		MSAA_OFF: return "ВЫКЛ"
		MSAA_2X: return "2X"
	return "4X"
