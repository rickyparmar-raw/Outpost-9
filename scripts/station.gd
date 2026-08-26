extends Node2D


const TILE := 32
const MAP := [
	"############################################",
	"#............#  #..........#  #..........L.#",
	"#.........V..####..........#  #............#",
	"#..hhh....V..BhhB....G.....#  #.....G......#",
	"#..hhh.......BhhB..........#  #............#",
	"#..hhh.......BhhB..........#  #............#",
	"#............BhhB..........#  #............#",
	"#............#  #..........#  #............#",
	"######..#############..############..#######",
	"#    #.L.............................L#    #",
	"#    #................................#    #",
	"#              ######..######              #",
	"#              #..L.........#              #",
	"#              #.....3......#              #",
	"#              #............#              #",
	"#              #...1....2...#              #",
	"#              #.....P......#              #",
	"#              #............#              #",
	"#              #.........L..#              #",
	"#              ######..######              #",
	"#                   #..#                   #",
	"#                   #..#                   #",
	"#    #.L.............................L#    #",
	"#######..########################..#########",
	"#.L..........#                #...hhhhhh.L.#",
	"#............#                #...h....h...#",
	"#......G.....#                #...h.E..h...#",
	"#.....hhh....#                #...h....h...#",
	"#.....hhh....#                #...hhhhhh...#",
	"#.........V..#                #............#",
	"############################################"]

var emergency_lights: Array[PointLight2D] = []
var _phases: Array[float] = []
var _blackout := 0.0

const VENT_SPOTS := [
	Vector2(560, 592), Vector2(400, 336), Vector2(976, 720),
	Vector2(336, 848), Vector2(1072, 816)]


func _ready() -> void:
	_build()
	_spawn_markers()


func _process(_delta: float) -> void:
	_blackout = maxf(0.0, _blackout - _delta)
	if randf() < 0.003:
		_blackout = randf_range(0.05, 0.2)
	var t := Time.get_ticks_msec() / 1000.0
	for i in emergency_lights.size():
		var l := emergency_lights[i]
		var flick := 0.8 + 0.2 * sin(t * 6.3 + _phases[i]) * sin(t * 13.1 + _phases[i] * 1.7)
		l.energy = 1.15 * flick * (0.1 if _blackout > 0.0 else 1.0)


func surge(duration: float = 0.8) -> void:
	_blackout = duration


func cell(x: int, y: int) -> String:
	if y < 0 or y >= MAP.size() or x < 0 or x >= MAP[y].length():
		return "#"
	return MAP[y][x]


func is_open(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c != "#" and c != " "


func _build() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src_floor := _atlas("res://assets/sprites/tiles/floor_variants.png", 4, 1)
	ts.add_source(src_floor, 0)
	var src_hazard := _atlas("res://assets/sprites/tiles/hazard.png", 1, 1)
	ts.add_source(src_hazard, 1)
	var src_wall := _atlas("res://assets/sprites/tiles/wall.png", 1, 1)
	ts.add_source(src_wall, 2)
	_solidify(src_wall, 1, 1)
	var src_co := _atlas("res://assets/sprites/tiles/wall_corner_outer.png", 4, 1)
	ts.add_source(src_co, 3)
	_solidify(src_co, 4, 1)
	var src_ci := _atlas("res://assets/sprites/tiles/wall_corner_inner.png", 4, 1)
	ts.add_source(src_ci, 4)
	_solidify(src_ci, 4, 1)
	var src_dmg := _atlas("res://assets/sprites/tiles/wall_damaged.png", 4, 1)
	ts.add_source(src_dmg, 5)
	_solidify(src_dmg, 4, 1)
	var src_cap := _atlas("res://assets/sprites/tiles/wall_endcap.png", 1, 1)
	ts.add_source(src_cap, 6)
	_solidify(src_cap, 1, 1)
	var src_deck := _atlas("res://assets/sprites/tiles/deck.png", 1, 1)
	ts.add_source(src_deck, 7)
	var src_shaft := _atlas("res://assets/sprites/tiles/shaft.png", 1, 1)
	ts.add_source(src_shaft, 8)

	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = ts
	floor_layer.z_index = -10
	add_child(floor_layer)
	var wall_layer := TileMapLayer.new()
	wall_layer.tile_set = ts
	wall_layer.z_index = -5
	add_child(wall_layer)

	var rnd := RandomNumberGenerator.new()
	rnd.seed = 9
	var goo_spots: Array[Vector2] = []

	for y in MAP.size():
		for x in MAP[y].length():
			var c := cell(x, y)
			if c == " ":
				floor_layer.set_cell(Vector2i(x, y), 8, Vector2i(0, 0))
				continue
			if c == "h":
				floor_layer.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
			elif x >= 35 and x <= 38 and y >= 25 and y <= 27:
				floor_layer.set_cell(Vector2i(x, y), 7, Vector2i(0, 0))
			else:
				var r := rnd.randf()
				var v := 0 if r < 0.55 else (1 if r < 0.8 else (2 if r < 0.93 else 3))
				floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(v, 0))
			match c:
				"#":
					var wc := _wall_cell(x, y)
					wall_layer.set_cell(Vector2i(x, y), wc[0], wc[1], wc[2])
				"B":
					var spr := Sprite2D.new()
					spr.texture = load("res://assets/sprites/tiles/wall_damaged.png")
					spr.hframes = 4
					spr.frame = 2 if (x + y) % 2 == 0 else 3
					spr.position = Vector2(x * TILE + 16, y * TILE + 16)
					spr.z_index = -4
					add_child(spr)
					goo_spots.append(Vector2(x * TILE + 16, y * TILE + 16))

	var goo_tex := _light_texture()
	for pos in goo_spots:
		var l := PointLight2D.new()
		l.texture = goo_tex
		l.color = Color(0.35, 1.0, 0.5)
		l.energy = 0.75
		l.texture_scale = 1.3
		l.position = pos
		add_child(l)


func _wall_cell(x: int, y: int) -> Array:
	var fb := is_open(x, y + 1)
	var fa := is_open(x, y - 1)
	var fl := is_open(x - 1, y)
	var fr := is_open(x + 1, y)
	var fbr := is_open(x + 1, y + 1)
	var fbl := is_open(x - 1, y + 1)
	var ftr := is_open(x + 1, y - 1)
	var ftl := is_open(x - 1, y - 1)
	var FH := TileSetAtlasSource.TRANSFORM_FLIP_H
	var FV := TileSetAtlasSource.TRANSFORM_FLIP_V
	var TR := TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if fbr and not fr and not fb:
		return [3, Vector2i(0, 0), 0]
	if fbl and not fl and not fb:
		return [3, Vector2i(3, 0), 0]
	if ftr and not fr and not fa:
		return [3, Vector2i(1, 0), 0]
	if ftl and not fl and not fa:
		return [3, Vector2i(2, 0), 0]
	if fb and fr:
		if not fa:
			return [6, Vector2i(0, 0), 0]
		if fl:
			return [3, Vector2i(0, 0), 0]
		return [3, Vector2i(1, 0), 0]
	if fb and fl:
		if not fa:
			return [6, Vector2i(0, 0), FH]
		if fr:
			return [3, Vector2i(3, 0), 0]
		return [3, Vector2i(2, 0), 0]
	if fa and fr:
		if not fb:
			return [3, Vector2i(1, 0), 0]
		if ftl:
			return [6, Vector2i(0, 0), FV]
		return [3, Vector2i(1, 0), 0]
	if fa and fl:
		if not fb:
			return [3, Vector2i(2, 0), 0]
		if ftr:
			return [6, Vector2i(0, 0), FH | FV]
		return [3, Vector2i(2, 0), 0]
	if fb:
		return [2, Vector2i(0, 0), 0]
	if fa:
		return [2, Vector2i(0, 0), FH | FV]
	if fr:
		return [2, Vector2i(0, 0), TR]
	if fl:
		return [2, Vector2i(0, 0), TR | FH]
	if fbr and not fr and not fb:
		return [4, Vector2i(0, 0), 0]
	if fbl and not fl and not fb:
		return [4, Vector2i(0, 0), FH]
	if ftr and not fr and not fa:
		return [4, Vector2i(0, 0), FV]
	if ftl and not fl and not fa:
		return [4, Vector2i(0, 0), FH | FV]
	return [2, Vector2i(0, 0), 0]


func _spawn_markers() -> void:
	var tex := _light_texture()
	for pos in VENT_SPOTS:
		var v := Sprite2D.new()
		v.texture = load("res://assets/sprites/tiles/vent.png")
		v.position = pos
		v.z_index = -3
		v.add_to_group("vents")
		add_child(v)
	for y in MAP.size():
		for x in MAP[y].length():
			var c := cell(x, y)
			var pos := Vector2(x * TILE + 16, y * TILE + 16)
			if c == "L":
				var l := PointLight2D.new()
				l.texture = tex
				l.color = Color(1.0, 0.22, 0.16)
				l.texture_scale = 1.8
				l.position = pos
				add_child(l)
				emergency_lights.append(l)
				_phases.append(randf() * TAU)
			elif c == "V":
				var p := CPUParticles2D.new()
				p.position = pos
				p.amount = 14
				p.lifetime = 1.8
				p.preprocess = 2.0
				p.direction = Vector2(0, -1)
				p.spread = 16.0
				p.gravity = Vector2(0, -26)
				p.initial_velocity_min = 12.0
				p.initial_velocity_max = 30.0
				p.scale_amount_min = 1.5
				p.scale_amount_max = 3.5
				p.color = Color(0.75, 0.8, 0.88, 0.14)
				p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				p.emission_sphere_radius = 5.0
				add_child(p)


func _atlas(path: String, h: int, v: int) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in v:
		for x in h:
			src.create_tile(Vector2i(x, y))
	return src


func _solidify(src: TileSetAtlasSource, h: int, v: int) -> void:
	for y in v:
		for x in h:
			var td := src.get_tile_data(Vector2i(x, y), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))


func _light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.98, 0.5)
	return t
