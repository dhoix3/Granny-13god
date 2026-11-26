class_name Mats
extends RefCounted

static var _mats: Dictionary = {}
static var _texs: Dictionary = {}

static func mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.82
	match name:
		"wood":
			m.albedo_texture = tex("wood_floor")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.72
		"wood_dark":
			m.albedo_texture = tex("wood_dark")
			m.uv1_scale = Vector3(0.9, 0.9, 0.9)
			m.roughness = 0.78
		"wood_light":
			m.albedo_texture = tex("wood_light")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.7
		"wallpaper":
			m.albedo_texture = tex("wallpaper")
			m.albedo_color = Color(0.62, 0.62, 0.74)
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.96
		"panel":
			m.albedo_texture = tex("panel")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.74
		"plaster":
			m.albedo_texture = tex("plaster")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.95
		"brick":
			m.albedo_texture = tex("brick")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.92
		"tile":
			m.albedo_texture = tex("tile")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.35
			m.metallic = 0.05
		"attic":
			m.albedo_texture = tex("attic")
			m.albedo_color = Color(0.72, 0.66, 0.56)
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.9
		"beam":
			m.albedo_texture = tex("wood_dark")
			m.uv1_scale = Vector3(1.5, 1.5, 1.5)
			m.roughness = 0.85
		"concrete":
			m.albedo_texture = tex("concrete")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.96
		"rug":
			m.albedo_texture = tex("rug")
			m.uv1_scale = Vector3(0.45, 0.45, 0.45)
			m.roughness = 0.98
		"door":
			m.albedo_texture = tex("door")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.6
		"metal":
			m.albedo_texture = tex("metal")
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
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
			m.albedo_color = Color(0.84, 0.79, 0.64)
			m.roughness = 1.0
		"car":
			m.albedo_color = Color(0.45, 0.10, 0.11)
			m.roughness = 0.36
			m.metallic = 0.45
		"glass":
			m.albedo_color = Color(0.08, 0.12, 0.16, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic = 0.4
		"window":
			m.albedo_texture = tex("window")
			m.albedo_color = Color(0.85, 0.9, 1.0)
			m.emission_enabled = true
			m.emission_texture = tex("window")
			m.emission_energy_multiplier = 0.45
			m.roughness = 0.9
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
			m.albedo_color = Color(0.92, 0.86, 0.74)
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.emission_enabled = true
			m.emission = Color(0.22, 0.18, 0.13)
			m.emission_energy_multiplier = 0.55
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
			m.albedo_color = Color(0.78, 0.58, 0.47)
			m.roughness = 0.9
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
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
			m.roughness = 0.62
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

static func tex(name: String) -> Texture2D:
	if _texs.has(name):
		return _texs[name]
	var t: Texture2D = null
	match name:
		"wallpaper":
			t = _from_asset("res://assets/wallpaper.png", Color(1.0, 1.0, 1.0))
		"wood_floor":
			t = _make("wood_floor")
		"wood_dark":
			t = _make("wood_dark")
		"wood_light":
			t = _make("wood_light")
		"panel":
			t = _make("panel")
		"plaster":
			t = _make("plaster")
		"brick":
			t = _make("brick")
		"tile":
			t = _make("tile")
		"attic":
			t = _make("attic")
		"concrete":
			t = _make("concrete")
		"rug":
			t = _make("rug")
		"door":
			t = _make("door")
		"metal":
			t = _make("metal")
		"fabric_red":
			t = _make("fabric_red")
		"fabric_green":
			t = _make("fabric_green")
		"fabric_blue":
			t = _make("fabric_blue")
		"window":
			t = _make("window")
		"cage":
			t = _make("cage")
		"garage":
			t = _make("garage")
		"towel":
			t = _make("towel")
	if t == null:
		t = _make("plaster")
	_texs[name] = t
	return t

static func _from_asset(path: String, tint: Color) -> Texture2D:
	var src := load(path) as Texture2D
	if src == null:
		return _make("plaster")
	var img := src.get_image()
	if img == null:
		return src
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	# Shift the artwork so its darkest column/row lands on the repeat seam,
	# then mirror-tile it. This keeps the pattern continuous without a bright
	# stripe where the texture wraps.
	var seam_x := 0
	var seam_y := 0
	var best_x := INF
	var best_y := INF
	for x in w:
		var sum := 0.0
		for y in h:
			sum += img.get_pixel(x, y).get_luminance()
		if sum < best_x:
			best_x = sum
			seam_x = x
	for y in h:
		var sum := 0.0
		for x in w:
			sum += img.get_pixel(x, y).get_luminance()
		if sum < best_y:
			best_y = sum
			seam_y = y
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h * 2:
		var sy := y if y < h else h * 2 - 1 - y
		var src_y := (sy + seam_y) % h
		for x in w * 2:
			var sx := x if x < w else w * 2 - 1 - x
			var src_x := (sx + seam_x) % w
			var c := img.get_pixel(src_x, src_y)
			out.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	out.generate_mipmaps()
	return ImageTexture.create_from_image(out)

static func _make(name: String) -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var c: Color
	match name:
		"wood_floor":
			for y in s:
				for x in s:
					var plank := int(y / 16.0)
					var ly := y % 16
					var joint := (x + plank * 37) % 43
					var base := Color(0.30, 0.19, 0.11).lerp(Color(0.42, 0.27, 0.15), (plank % 3) / 2.0)
					var grain := sin(x * 0.23 + plank * 2.7 + sin(y * 0.31) * 2.0) * 0.025
					var n := rng.randf_range(-0.018, 0.018)
					c = Color(base.r + grain + n, base.g + grain * 0.8 + n, base.b + grain * 0.5 + n)
					if ly <= 1 or ly >= 14 or joint <= 1:
						c = c.darkened(0.45)
					img.set_pixel(x, y, c)
		"wood_dark":
			for y in s:
				for x in s:
					var base := Color(0.18, 0.115, 0.075)
					var g := sin(x * 0.18 + sin(y * 0.13) * 3.0) * 0.018 + rng.randf_range(-0.01, 0.01)
					c = Color(base.r + g, base.g + g * 0.8, base.b + g * 0.5)
					if y % 32 <= 1:
						c = c.darkened(0.3)
					img.set_pixel(x, y, c)
		"wood_light":
			for y in s:
				for x in s:
					var base := Color(0.52, 0.34, 0.18)
					var g := sin(x * 0.2 + y * 0.05) * 0.02 + rng.randf_range(-0.012, 0.012)
					c = Color(base.r + g, base.g + g * 0.8, base.b + g * 0.5)
					img.set_pixel(x, y, c)
		"panel":
			for y in s:
				for x in s:
					var px := x % 32
					var base := Color(0.19, 0.12, 0.08)
					var g := sin(x * 0.14 + sin(y * 0.09) * 2.0) * 0.018 + rng.randf_range(-0.008, 0.008)
					c = Color(base.r + g, base.g + g * 0.8, base.b + g * 0.6)
					if px <= 1:
						c = c.darkened(0.45)
					if px >= 14 and px <= 17:
						c = c.darkened(0.18)
					img.set_pixel(x, y, c)
		"plaster":
			for y in s:
				for x in s:
					var base := Color(0.29, 0.28, 0.25)
					var stain := sin(x * 0.11) * sin(y * 0.08) * 0.03
					var n := rng.randf_range(-0.035, 0.035)
					c = Color(base.r + stain + n, base.g + stain + n, base.b + stain * 0.7 + n)
					if (x * 7 + y * 13) % 211 < 2:
						c = c.darkened(0.3)
					img.set_pixel(x, y, c)
		"brick":
			for y in s:
				for x in s:
					var row := int(y / 16.0)
					var bx := (x + (row % 2) * 16) % 32
					var base := Color(0.25, 0.23, 0.21).lerp(Color(0.34, 0.30, 0.27), (row * 7 + int(x / 32)) % 4 / 3.0)
					var n := rng.randf_range(-0.025, 0.025)
					c = Color(base.r + n, base.g + n, base.b + n)
					if y % 16 <= 1 or bx <= 1:
						c = Color(0.16, 0.155, 0.15)
					img.set_pixel(x, y, c)
		"tile":
			for y in s:
				for x in s:
					var tx := x % 32
					var ty := y % 32
					var base := Color(0.38, 0.43, 0.38).lerp(Color(0.48, 0.52, 0.46), ((x / 32) + (y / 32)) % 2)
					var n := rng.randf_range(-0.012, 0.012)
					c = Color(base.r + n, base.g + n, base.b + n)
					if tx <= 1 or ty <= 1:
						c = Color(0.20, 0.21, 0.19)
					img.set_pixel(x, y, c)
		"attic":
			for y in s:
				for x in s:
					var base := Color(0.21, 0.15, 0.10)
					var g := sin(x * 0.11 + sin(y * 0.07) * 2.0) * 0.02 + rng.randf_range(-0.012, 0.012)
					c = Color(base.r + g, base.g + g * 0.75, base.b + g * 0.5)
					if y % 24 <= 1:
						c = c.darkened(0.4)
					img.set_pixel(x, y, c)
		"concrete":
			for y in s:
				for x in s:
					var base := Color(0.25, 0.25, 0.24)
					var n := rng.randf_range(-0.04, 0.04)
					var stain := sin(x * 0.05 + y * 0.02) * 0.02
					c = Color(base.r + n + stain, base.g + n + stain, base.b + n + stain)
					if (x * 11 + y * 17) % 311 < 2:
						c = c.darkened(0.35)
					img.set_pixel(x, y, c)
		"rug":
			for y in s:
				for x in s:
					var border := x < 10 or x > s - 11 or y < 10 or y > s - 11
					var base := Color(0.34, 0.09, 0.08) if border else Color(0.42, 0.15, 0.11)
					var pat := ((x / 16 + y / 16) % 2 == 0)
					if not border and pat:
						base = Color(0.36, 0.11, 0.09)
					var n := rng.randf_range(-0.018, 0.018)
					c = Color(base.r + n, base.g + n * 0.7, base.b + n * 0.6)
					if border and ((x + y) % 16 < 2):
						c = Color(0.60, 0.42, 0.18)
					img.set_pixel(x, y, c)
		"door":
			for y in s:
				for x in s:
					var base := Color(0.30, 0.19, 0.11)
					var g := sin(y * 0.13 + sin(x * 0.08) * 2.0) * 0.02 + rng.randf_range(-0.01, 0.01)
					c = Color(base.r + g, base.g + g * 0.8, base.b + g * 0.5)
					var panel := Rect2i(18, 16, 92, 40).has_point(Vector2i(x, y)) or Rect2i(18, 72, 92, 40).has_point(Vector2i(x, y))
					if panel:
						c = c.darkened(0.12)
					if panel and (x == 18 or x == 109 or y == 16 or y == 55 or y == 72 or y == 111):
						c = c.darkened(0.35)
					img.set_pixel(x, y, c)
		"metal":
			for y in s:
				for x in s:
					var base := Color(0.38, 0.39, 0.41)
					var n := rng.randf_range(-0.05, 0.05)
					c = Color(base.r + n, base.g + n, base.b + n)
					if (x * 3 + y * 7) % 97 < 2:
						c = c.lightened(0.25)
					img.set_pixel(x, y, c)
		"fabric_red":
			for y in s:
				for x in s:
					var weave := 0.025 if (x + y) % 4 < 2 else -0.015
					var base := Color(0.28, 0.055, 0.05)
					c = Color(base.r + weave, base.g + weave * 0.6, base.b + weave * 0.6)
					img.set_pixel(x, y, c)
		"fabric_green":
			for y in s:
				for x in s:
					var weave := 0.025 if (x + y) % 4 < 2 else -0.015
					var base := Color(0.10, 0.19, 0.12)
					c = Color(base.r + weave, base.g + weave, base.b + weave * 0.7)
					img.set_pixel(x, y, c)
		"fabric_blue":
			for y in s:
				for x in s:
					var weave := 0.025 if (x + y) % 4 < 2 else -0.015
					var base := Color(0.10, 0.12, 0.22)
					c = Color(base.r + weave, base.g + weave, base.b + weave)
					img.set_pixel(x, y, c)
		"window":
			for y in s:
				for x in s:
					var t := float(y) / float(s)
					var base := Color(0.015, 0.025, 0.06).lerp(Color(0.04, 0.07, 0.14), t)
					var n := rng.randf_range(-0.006, 0.006)
					c = Color(base.r + n, base.g + n, base.b + n)
					if rng.randf() < 0.004:
						c = Color(0.7, 0.75, 0.9)
					# moon
					var dx := x - 92
					var dy := y - 34
					if dx * dx + dy * dy < 90:
						c = Color(0.78, 0.80, 0.72)
					# frame
					if x < 7 or x > s - 8 or y < 7 or y > s - 8 or absi(x - 64) < 4 or absi(y - 64) < 4:
						c = Color(0.16, 0.12, 0.08)
					img.set_pixel(x, y, c)
		"cage":
			for y in s:
				for x in s:
					var base := Color(0.035, 0.03, 0.028)
					c = base
					if x % 16 < 4 or y % 48 < 4:
						c = Color(0.20, 0.19, 0.17)
					var n := rng.randf_range(-0.01, 0.01)
					c = Color(c.r + n, c.g + n, c.b + n)
					img.set_pixel(x, y, c)
		"garage":
			for y in s:
				for x in s:
					var base := Color(0.24, 0.25, 0.26)
					var n := rng.randf_range(-0.02, 0.02)
					c = Color(base.r + n, base.g + n, base.b + n)
					if y % 24 <= 2:
						c = Color(0.12, 0.13, 0.14)
					if x % 64 <= 1:
						c = c.darkened(0.25)
					img.set_pixel(x, y, c)
		"towel":
			for y in s:
				for x in s:
					var base := Color(0.44, 0.46, 0.42)
					if x % 32 < 4 or y % 32 < 4:
						base = Color(0.25, 0.27, 0.24)
					if x > 30 and x < 70 and y > 20:
						base = Color(0.46, 0.18, 0.16)
					var n := rng.randf_range(-0.012, 0.012)
					c = Color(base.r + n, base.g + n, base.b + n)
					img.set_pixel(x, y, c)
		_:
			img.fill(Color(0.3, 0.3, 0.3))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
