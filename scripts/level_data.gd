class_name LevelData
extends RefCounted

# Tile ids — identical to the original C# build.
const FLOOR := 0
const WP := 1
const PANEL := 2
const BRICK := 3
const DOOR := 4
const FRONT := 5
const WARDROBE := 6
const CABINET := 7
const SHELF := 8
const FRIDGE := 9
const STOVE := 10
const CRATE := 11
const WINDOW := 12
const ATTIC := 13
const ATTICWOOD := 14
const PORTRAIT := 15
const TILEW := 16
const TOWELS := 17
const CAGE := 18
const ATTICUP := 19
const TABLEW := 20
const RUG := 21
const HOLE := 22
const MIRROR := 23
const BOOKS := 24
const PLASTER := 25
const CAR := 26
const GARAGE_DOOR := 27

const WALL_H := 2.60
const EYE_H := 1.55
const DOOR_H := 2.08

static var SOLID: Array[bool] = _make_solid()

static func _make_solid() -> Array[bool]:
	var a: Array[bool] = []
	a.resize(32)
	a.fill(true)
	a[FLOOR] = false
	a[RUG] = false
	a[HOLE] = false
	return a

class ContainerData:
	var x: int
	var y: int
	var label: String
	var item_id: int = 0
	var searched := false

class Door:
	var x: int
	var y: int
	var front := false
	var open := false
	var open_t := 0.0
	var node: Node3D = null

class HideSpot:
	var x: int
	var y: int
	var enter_x: int
	var enter_y: int
	var is_bed := false
	var label := ""
	var node: Node3D = null

class Deco:
	var x: float
	var y: float
	var kind: int
	var name := ""
	var rot := 0
	var rx := 0.5
	var ry := 0.5
	var solid := true
	var container: ContainerData = null
	var hide: HideSpot = null
	var is_car := false
	var is_cradle := false
	var node: Node3D = null

class Trap:
	var x: float
	var y: float
	var armed := true
	var triggered_t := 0.0
	var node: Node3D = null

var w: int
var h: int
var id: int
var name: String
var map: PackedByteArray
var containers: Array[ContainerData] = []
var doors: Array[Door] = []
var hides: Array[HideSpot] = []
var decos: Array[Deco] = []
var traps: Array[Trap] = []
var webs: Array[Rect2] = []
var lamps: Array[Vector3] = []
var room_names: Array[String] = []
var spawn_x := 1.5
var spawn_y := 1.5
var spawn_a := 0.0
var origin := Vector3.ZERO
var garage_door_open := false
var ai_blocked := PackedByteArray()

func _init(pw: int, ph: int, pid: int, pname: String) -> void:
	w = pw
	h = ph
	id = pid
	name = pname
	map = PackedByteArray()
	map.resize(w * h)
	map.fill(BRICK)
	ai_blocked.resize(w * h)
	ai_blocked.fill(0)

func get_tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return BRICK
	return map[y * w + x]

func set_tile(x: int, y: int, t: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	map[y * w + x] = t

func fill_rect(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			set_tile(x, y, t)

func door_at(x: int, y: int) -> Door:
	for d in doors:
		if d.x == x and d.y == y:
			return d
	return null

func container_at(x: int, y: int) -> ContainerData:
	for c in containers:
		if c.x == x and c.y == y:
			return c
	return null

func hide_at(x: int, y: int) -> HideSpot:
	for hs in hides:
		if hs.x == x and hs.y == y:
			return hs
	return null

func walkable_tile(x: int, y: int) -> bool:
	var t := get_tile(x, y)
	if t == GARAGE_DOOR and garage_door_open:
		return true
	if not SOLID[t]:
		return true
	if t == DOOR:
		var d := door_at(x, y)
		if d != null and d.open:
			return true
	return false

func solid_at(wx: float, wz: float) -> bool:
	var x := int(floor(wx))
	var y := int(floor(wz))
	var t := get_tile(x, y)
	if t == GARAGE_DOOR and garage_door_open:
		return false
	if SOLID[t]:
		if t == DOOR:
			var d := door_at(x, y)
			if d != null and d.open:
				return false
		return true
	return false

func line_of_sight(x0: float, y0: float, x1: float, y1: float) -> bool:
	var dx := x1 - x0
	var dy := y1 - y0
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 0.0001:
		return true
	var steps := int(dist * 12.0) + 1
	var sx := dx / float(steps)
	var sy := dy / float(steps)
	var x := x0
	var y := y0
	for i in steps:
		x += sx
		y += sy
		if solid_at(x, y):
			return false
	return true

func rebuild_ai_blocked() -> void:
	ai_blocked.resize(w * h)
	ai_blocked.fill(0)
	for d in decos:
		if not d.solid:
			continue
		var x0 := int(floor(d.x - d.rx - 0.5))
		var x1 := int(ceil(d.x + d.rx + 0.5))
		var y0 := int(floor(d.y - d.ry - 0.5))
		var y1 := int(ceil(d.y + d.ry + 0.5))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				if absf(x + 0.5 - d.x) < d.rx + 0.26 and absf(y + 0.5 - d.y) < d.ry + 0.26:
					ai_blocked[y * w + x] = 1

func ai_walkable(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	if ai_blocked[y * w + x] != 0:
		return false
	return walkable_tile(x, y)

func trap_near(x: float, y: float, r: float) -> Trap:
	for t in traps:
		if not t.armed:
			continue
		if absf(t.x - x) < r and absf(t.y - y) < r:
			return t
	return null

func add_door(x: int, y: int, front := false) -> Door:
	set_tile(x, y, DOOR if not front else FRONT)
	var d := Door.new()
	d.x = x
	d.y = y
	d.front = front
	doors.append(d)
	return d

# A* over the tile grid. Returns an array of tile indices or an empty array.
func find_path(sx: int, sy: int, tx: int, ty: int, can_open_doors: bool) -> Array[int]:
	var n := w * h
	if sx < 0 or sy < 0 or sx >= w or sy >= h:
		return []
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return []
	var start := sy * w + sx
	var goal := ty * w + tx
	if start == goal:
		return [start]
	if not ai_walkable(tx, ty):
		var best := -1
		var bd := 1.0e9
		for yy in range(ty - 1, ty + 2):
			for xx in range(tx - 1, tx + 2):
				if not ai_walkable(xx, yy):
					continue
				var dd := Vector2(xx - tx, yy - ty).length()
				if dd < bd:
					bd = dd
					best = yy * w + xx
		if best < 0:
			return []
		goal = best
		tx = goal % w
		ty = int(goal / w)

	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(1.0e20)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	var open: Array[int] = [start]
	g[start] = 0.0
	var guard := 0
	while open.size() > 0 and guard < 20000:
		guard += 1
		var bi := 0
		var bf := 1.0e20
		for i in open.size():
			var c := open[i]
			var cx := c % w
			var cy := int(c / w)
			var f := g[c] + absf(cx - tx) + absf(cy - ty)
			if f < bf:
				bf = f
				bi = i
		var cur := open[bi]
		open.remove_at(bi)
		if cur == goal:
			var path: Array[int] = []
			var c := cur
			while c != -1:
				path.append(c)
				c = came[c]
			path.reverse()
			return path
		closed[cur] = 1
		var ux := cur % w
		var uy := int(cur / w)
		for k in 4:
			var nx := ux + (1 if k == 0 else (-1 if k == 1 else 0))
			var ny := uy + (1 if k == 2 else (-1 if k == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if closed[ni] != 0:
				continue
			if not ai_walkable(nx, ny):
				var tt := get_tile(nx, ny)
				if not (can_open_doors and tt == DOOR):
					continue
			var cost := 1.0
			if get_tile(nx, ny) == DOOR:
				cost += 1.5
			var ng := g[cur] + cost
			if ng < g[ni]:
				g[ni] = ng
				came[ni] = cur
				if not open.has(ni):
					open.append(ni)
	return []

func local_to_world(x: float, z: float) -> Vector3:
	return origin + Vector3(x, 0.0, z)

func count_item(item_id: int) -> int:
	var n := 0
	for c in containers:
		if c.item_id == item_id:
			n += 1
	return n
