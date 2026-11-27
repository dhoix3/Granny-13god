class_name Mats
extends RefCounted

# Материалы и текстуры игры. Текстуры генерируются офлайн
# (tools/gen_assets.py) и загружаются из assets/tex — раньше они
# строились пиксельными циклами GDScript при каждом запуске (медленный
# старт, потолок качества). Каждая поверхностная текстура имеет пару
# *_n.png (normal map). Профили качества:
#   0 — Низкий  (без normal-карт, без анизотропии — Android/слабые ПК)
#   1 — Средний (normal-карты, анизотропия 4)
#   2 — Высокий (normal-карты, анизотропия 8)

static var _mats: Dictionary = {}
static var _texs: Dictionary = {}
static var _quality := 2

const QUALITY_LABELS := ["НИЗКОЕ", "СРЕДНЕЕ", "ВЫСОКОЕ"]

static func set_quality(q: int) -> void:
	q = clampi(q, 0, 2)
	if q == _quality and not _mats.is_empty():
		return
	_quality = q
	_mats.clear()
	_texs.clear()

static func quality() -> int:
	return _quality

static func tex(name: String) -> Texture2D:
	if _texs.has(name):
		return _texs[name]
	var t: Texture2D = load("res://assets/tex/%s.png" % name)
	if t == null:
		t = load("res://assets/tex/plaster.png")
	_texs[name] = t
	return t

static func ntex(name: String) -> Texture2D:
	if _quality == 0:
		return null
	if _texs.has(name + "_n"):
		return _texs[name + "_n"]
	var t: Texture2D = load("res://assets/tex/%s_n.png" % name)
	_texs[name + "_n"] = t  # может быть null — нет карты у этой поверхности
	return t

static func mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if _quality >= 1 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.82
	# Оболочка (стены/полы/потолки) красится вершинным AO — включаем
	# vertex-цвета сразу у всех материалов оболочки.
	m.vertex_color_use_albedo = true
	match name:
		"wood":
			m.albedo_texture = tex("wood_floor")
			m.normal_enabled = ntex("wood_floor") != null
			m.normal_texture = ntex("wood_floor")
			m.normal_scale = 0.9
			m.roughness = 0.60
		"wood_dark":
			m.albedo_texture = tex("wood_dark")
			m.roughness = 0.66
		"wood_light":
			m.albedo_texture = tex("wood_light")
			m.roughness = 0.62
		"wallpaper":
			m.albedo_texture = tex("wallpaper")
			m.roughness = 0.94
			m.normal_enabled = ntex("plaster") != null
			m.normal_texture = ntex("plaster")
			m.normal_scale = 0.25
		"panel":
			m.albedo_texture = tex("panel")
			m.normal_enabled = ntex("panel") != null
			m.normal_texture = ntex("panel")
			m.roughness = 0.68
		"plaster":
			m.albedo_texture = tex("plaster")
			m.normal_enabled = ntex("plaster") != null
			m.normal_texture = ntex("plaster")
			m.normal_scale = 0.8
			m.roughness = 0.95
		"brick":
			m.albedo_texture = tex("brick")
			m.normal_enabled = ntex("brick") != null
			m.normal_texture = ntex("brick")
			m.roughness = 0.92
		"tile":
			m.albedo_texture = tex("tile")
			m.normal_enabled = ntex("tile") != null
			m.normal_texture = ntex("tile")
			m.roughness = 0.30
			m.metallic = 0.05
		"attic":
			m.albedo_texture = tex("attic")
			m.roughness = 0.88
		"beam":
			m.albedo_texture = tex("wood_dark")
			m.roughness = 0.85
		"concrete":
			m.albedo_texture = tex("concrete")
			m.normal_enabled = ntex("concrete") != null
			m.normal_texture = ntex("concrete")
			m.normal_scale = 0.7
			m.roughness = 0.96
		"rug":
			m.albedo_texture = tex("rug")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.98
		"door":
			m.albedo_texture = tex("door")
			m.normal_enabled = ntex("door") != null
			m.normal_texture = ntex("door")
			m.roughness = 0.55
		"metal":
			m.albedo_texture = tex("metal")
			m.normal_enabled = ntex("metal") != null
			m.normal_texture = ntex("metal")
			m.roughness = 0.38
			m.metallic = 0.72
		"brass":
			m.albedo_color = Color(0.72, 0.56, 0.22)
			m.roughness = 0.28
			m.metallic = 0.85
		"fabric_red":
			m.albedo_texture = tex("fabric_red")
			m.uv1_scale = Vector3(1.4, 1.4, 1.4)
			m.roughness = 1.0
		"fabric_green":
			m.albedo_texture = tex("fabric_green")
			m.uv1_scale = Vector3(1.4, 1.4, 1.4)
			m.roughness = 1.0
		"fabric_blue":
			m.albedo_texture = tex("fabric_blue")
			m.uv1_scale = Vector3(1.2, 1.2, 1.2)
			m.roughness = 1.0
		"mattress":
			m.albedo_color = Color(0.82, 0.79, 0.68)
			m.roughness = 1.0
		"white":
			m.albedo_color = Color(0.82, 0.83, 0.80)
			m.roughness = 0.45
		"black":
			m.albedo_color = Color(0.035, 0.035, 0.04)
			m.roughness = 0.6
		"screen":
			m.albedo_color = Color(0.02, 0.03, 0.04)
			m.roughness = 0.12
			m.metallic = 0.2
		"paper":
			m.albedo_texture = tex("paper")
			m.roughness = 1.0
		"car":
			m.albedo_color = Color(0.45, 0.10, 0.11)
			m.roughness = 0.30
			m.metallic = 0.55
		"glass":
			m.albedo_color = Color(0.08, 0.12, 0.16, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic = 0.4
		"window":
			m.albedo_texture = tex("window")
			m.emission_enabled = true
			m.emission_texture = tex("window")
			m.emission_energy_multiplier = 0.30
			m.roughness = 0.85
			m.metallic = 0.0
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		"cage":
			m.albedo_texture = tex("cage")
			m.uv1_scale = Vector3(0.8, 0.8, 0.8)
			m.roughness = 0.5
			m.metallic = 0.6
		"garage_door":
			m.albedo_texture = tex("garage")
			m.uv1_scale = Vector3(0.55, 0.55, 0.55)
			m.normal_enabled = ntex("garage") != null
			m.normal_texture = ntex("garage")
			m.roughness = 0.55
			m.metallic = 0.45
		"towel":
			m.albedo_texture = tex("towel")
			m.uv1_scale = Vector3(0.7, 0.7, 0.7)
			m.roughness = 1.0
		"mirror":
			m.albedo_color = Color(0.45, 0.55, 0.6)
			m.roughness = 0.06
			m.metallic = 0.92
		"hole":
			m.albedo_color = Color(0.006, 0.005, 0.006)
			m.roughness = 1.0
		"ceiling":
			m.albedo_texture = tex("plaster")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.emission_enabled = true
			m.emission = Color(0.22, 0.18, 0.13)
			m.emission_energy_multiplier = 0.55
			m.normal_enabled = ntex("plaster") != null
			m.normal_texture = ntex("plaster")
			m.normal_scale = 0.5
		"trap":
			m.albedo_color = Color(0.26, 0.24, 0.21)
			m.roughness = 0.42
			m.metallic = 0.65
		"web":
			m.albedo_color = Color(0.72, 0.72, 0.7, 0.30)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"lamp":
			m.albedo_color = Color(0.95, 0.78, 0.45)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.72, 0.32)
			m.emission_energy_multiplier = 1.8
			m.roughness = 0.5
		"skin":
			m.albedo_texture = tex("skin")
			m.normal_enabled = ntex("skin") != null
			m.normal_texture = ntex("skin")
			m.normal_scale = 0.6
			m.roughness = 0.72
		"car_glass":
			m.albedo_color = Color(0.12, 0.17, 0.20, 0.65)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.06
			m.metallic = 0.5
		"red":
			m.albedo_color = Color(0.55, 0.05, 0.06)
			m.roughness = 0.5
		"bottle":
			m.albedo_color = Color(0.22, 0.46, 0.24, 0.72)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.12
			m.metallic = 0.15
		"eye":
			m.albedo_color = Color(0.9, 0.08, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.12, 0.06)
			m.emission_energy_multiplier = 2.2
			m.roughness = 0.4
		"front_door":
			m.albedo_texture = tex("door")
			m.albedo_color = Color(0.72, 0.62, 0.54)
			m.normal_enabled = ntex("door") != null
			m.normal_texture = ntex("door")
			m.roughness = 0.58
		"lock":
			m.albedo_color = Color(0.62, 0.48, 0.18)
			m.roughness = 0.25
			m.metallic = 0.9
		"mattress_dark":
			m.albedo_color = Color(0.38, 0.34, 0.30)
			m.roughness = 1.0
		_:
			m.albedo_color = Color(0.6, 0.6, 0.6)
	_mats[name] = m
	return m

static func wall_mat(tile: int) -> StandardMaterial3D:
	match tile:
		LevelData.WP: return mat("wallpaper")
		LevelData.PANEL: return mat("panel")
		LevelData.BRICK: return mat("brick")
		LevelData.WINDOW: return mat("window")
		LevelData.ATTIC: return mat("attic")
		LevelData.ATTICWOOD: return mat("beam")
		LevelData.TILEW: return mat("tile")
		LevelData.TOWELS: return mat("towel")
		LevelData.MIRROR: return mat("mirror")
		LevelData.CAGE: return mat("cage")
		LevelData.GARAGE_DOOR: return mat("garage_door")
		LevelData.PORTRAIT: return mat("plaster")
		LevelData.PLASTER: return mat("plaster")
	return mat("plaster")

static func floor_mat(tile: int, level_id: int) -> StandardMaterial3D:
	if tile == LevelData.RUG:
		return mat("rug")
	if tile == LevelData.HOLE:
		return mat("hole")
	if level_id == 0:
		if tile == LevelData.TILEW:
			return mat("tile")
		return mat("wood")
	if level_id == 1:
		return mat("attic")
	if level_id == 2 or level_id == 3:
		return mat("concrete")
	return mat("wood")
