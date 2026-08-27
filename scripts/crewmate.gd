extends CharacterBody2D

signal revealed(crew_name: String)
signal eliminated(crew_name: String, was_infected: bool)
signal caught_player

@export var crew_name: String = "Crewmate"
@export var role: String = "Technician"
@export var texture_path: String = "res://assets/sprites/characters/crew_engineer.png"
@export var speed: float = 120.0

var is_infected := false
var is_revealed := false
var is_dead := false
var verified_human := false
var state := "idle"
var player_ref: Node2D = null

var _target := Vector2.ZERO
var _threat: Node2D = null
var _wait := 1.0
var _talk_count := 0
var _anim_t := 0.0
var _frame := 0
var _last_pos := Vector2.ZERO
var _stuck_t := 0.0
var _path: Array = []
var _goal := ""
var repair_target: Node = null
var repair_rate := 7.0
var _threat_scan := 0.0
var _vent_cd := 0.0
var _far_t := 0.0

const LINES := {
	"Marcus": [
		"I don't care about your scanner, Vance. If I don't fix the power grid, we freeze to death anyway.",
		"I was fixing a faulty fuse box when the alarm went off. That's ALL!",
		"Get out of my way, Captain. Pipes don't repair themselves."],
	"Elena": [
		"It isn't a monster, Captain. It's an evolutionary masterpiece.",
		"I suggest you stay away from Marcus. I saw him talking to himself in the dark.",
		"The lab readings were fascinating... simply fascinating."],
	"Jax": [
		"One wrong twitch, and I'll vent you into the vacuum myself.",
		"I don't trust Elena, and I sure as hell don't trust Marcus. What about you, Captain?",
		"How do we know YOU'RE clean, Vance?"]
}
const COLD_LINES := [
	"...",
	"We are fine, Captain. All of us. One being.",
	"Go to the dark junction box. Alone, Captain."]

const WAYPOINTS := {
	"hub": Vector2(688, 528),
	"hub_n": Vector2(704, 348),
	"cor_n_w": Vector2(208, 336),
	"cor_n_e": Vector2(1200, 336),
	"lab_door": Vector2(224, 272),
	"gen3_door": Vector2(704, 272),
	"sec_door": Vector2(1152, 272),
	"lab": Vector2(208, 160),
	"gen3": Vector2(688, 176),
	"sec": Vector2(1168, 176),
	"hub_s": Vector2(704, 656),
	"cor_s_w": Vector2(208, 720),
	"cor_s_c": Vector2(688, 720),
	"cor_s_c2": Vector2(720, 720),
	"cor_s_e": Vector2(1200, 720),
	"eng_door": Vector2(240, 752),
	"pod_door": Vector2(1088, 752),
	"eng": Vector2(240, 912),
	"pod": Vector2(1120, 912),
}
const EDGES := [
	["hub", "hub_n"], ["hub", "hub_s"],
	["hub_n", "gen3_door"], ["gen3_door", "gen3"],
	["hub_n", "cor_n_w"], ["cor_n_w", "lab_door"], ["lab_door", "lab"],
	["hub_n", "cor_n_e"], ["cor_n_e", "sec_door"], ["sec_door", "sec"],
	["hub_s", "cor_s_w"], ["cor_s_w", "eng_door"], ["eng_door", "eng"],
	["cor_s_w", "cor_s_c"], ["cor_s_c", "hub_s"],
	["hub_s", "cor_s_c2"], ["cor_s_c2", "cor_s_e"],
	["cor_s_e", "pod_door"], ["pod_door", "pod"],
]
const WANDER_ROOMS := ["lab", "gen3", "sec", "eng", "pod", "hub"]

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("crewmates")
	sprite.texture = load(texture_path)
	sprite.hframes = 4
	sprite.vframes = 4
	repair_rate = 11.0 if crew_name == "Marcus" else 7.0
	_last_pos = global_position


func set_infected(v: bool) -> void:
	is_infected = v


func panic(duration: float = 7.0, threat: Node2D = null) -> void:
	if is_revealed or is_dead:
		return
	_threat = threat
	state = "fleeing"
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = duration
	t.timeout.connect(_end_panic)
	add_child(t)
	t.start()


func _end_panic() -> void:
	if state == "fleeing":
		state = "idle"
		_wait = 0.5


func interact(player: Node2D) -> void:
	if is_revealed or is_dead:
		return
	_talk_count += 1
	player.info_log.emit("%s: \"%s\"" % [crew_name, _current_line()])


func get_scanned() -> bool:
	if not is_infected:
		verified_human = true
	elif not is_revealed:
		reveal()
	return is_infected


func reveal() -> void:
	if is_revealed or is_dead:
		return
	is_revealed = true
	sprite.texture = load("res://assets/sprites/characters/mimic.png")
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.frame = 0
	Sfx.play("screech")
	repair_target = null
	state = "chasing"
	revealed.emit(crew_name)


func eliminate() -> bool:
	if is_dead:
		return is_infected
	is_dead = true
	_death_burst()
	if is_infected:
		Sfx.play("screech", -4.0, 1.25)
	else:
		Sfx.play("deny", -2.0, 0.7)
	eliminated.emit(crew_name, is_infected)
	queue_free()
	return is_infected


func _current_line() -> String:
	if is_infected and _talk_count >= 2:
		return COLD_LINES[mini(_talk_count - 2, COLD_LINES.size() - 1)]
	var lines: Array = LINES.get(crew_name, ["..."])
	return lines[mini(_talk_count - 1, lines.size() - 1)]


func _physics_process(delta: float) -> void:
	_threat_scan -= delta
	if _threat_scan <= 0.0:
		_threat_scan = 0.4
		_check_threat()
	match state:
		"idle":
			velocity = Vector2.ZERO
			_wait -= delta
			if _wait <= 0.0:
				_pick_goal()
		"travel":
			if _path.is_empty():
				_arrive()
			else:
				var wp: Vector2 = WAYPOINTS[_path[0]]
				_move_towards(wp, speed, delta)
				if global_position.distance_to(wp) < 14.0 or _stuck_check(delta):
					_path.pop_front()
					if _path.is_empty():
						_arrive()
		"repairing":
			velocity = Vector2.ZERO
			if repair_target == null or not is_instance_valid(repair_target) or repair_target.is_online:
				repair_target = null
				_wait = randf_range(0.5, 2.0)
				state = "idle"
			else:
				var mult := 0.22 if is_infected else 1.0
				repair_target.add_progress(repair_rate * mult * delta)
		"chasing":
			if is_instance_valid(player_ref):
				_move_towards(player_ref.global_position, 196.0, delta)
				_vent_cd -= delta
				var dist: float = global_position.distance_to(player_ref.global_position)
				if dist > 260.0:
					_far_t += delta
				else:
					_far_t = 0.0
				if _far_t > 2.0 and _vent_cd <= 0.0:
					_vent_travel()
				elif dist < 18.0:
					caught_player.emit()
		"fleeing":
			var threat := _threat if is_instance_valid(_threat) else player_ref
			if is_instance_valid(threat):
				var away := global_position + (global_position - threat.global_position).normalized() * 150.0
				_move_towards(away, 155.0, delta)
				if _stuck_check(delta):
					_target = _random_open_point()
					state = "wandering"
		"wandering":
			_move_towards(_target, speed, delta)
			if position.distance_to(_target) < 10.0 or _stuck_check(delta):
				state = "idle"
				_wait = randf_range(1.0, 3.0)
	_animate(delta)


func _pick_goal() -> void:
	if is_revealed or is_dead:
		return
	var gens := get_tree().get_nodes_in_group("generators").filter(func(g): return not g.is_online)
	if not gens.is_empty() and randf() < 0.75:
		var g: Node = gens[randi() % gens.size()]
		repair_target = g
		_goal = "repair"
		_path = _route_to(g.wp_key)
		state = "travel"
	else:
		repair_target = null
		_goal = "wander"
		_path = _route_to(WANDER_ROOMS[randi() % WANDER_ROOMS.size()])
		state = "travel"


func _arrive() -> void:
	if _goal == "repair" and repair_target != null and is_instance_valid(repair_target) and not repair_target.is_online:
		state = "repairing"
	else:
		_target = _random_open_point()
		state = "wandering"


func _route_to(goal_key: String) -> Array:
	var start := _nearest_wp(global_position)
	var goal_pos: Vector2 = WAYPOINTS.get(goal_key, global_position)
	var goal := _nearest_wp(goal_pos)
	if start == goal:
		return [goal] if goal == goal_key else []
	var adj := {}
	for e in EDGES:
		if not adj.has(e[0]):
			adj[e[0]] = []
		adj[e[0]].append(e[1])
		if not adj.has(e[1]):
			adj[e[1]] = []
		adj[e[1]].append(e[0])
	var prev := {start: ""}
	var queue := [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == goal:
			break
		for nb in adj.get(cur, []):
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	if not prev.has(goal):
		return []
	var path := []
	var cur := goal
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	if goal == goal_key:
		path.append(goal_key)
	return path


func _nearest_wp(pos: Vector2) -> String:
	var best := "hub"
	var best_d := INF
	for k in WAYPOINTS:
		var d: float = pos.distance_to(WAYPOINTS[k])
		if d < best_d:
			best_d = d
			best = k
	return best


func _check_threat() -> void:
	if is_revealed or is_dead or state == "chasing":
		return
	for cm in get_tree().get_nodes_in_group("crewmates"):
		if cm.is_revealed and not cm.is_dead and cm.global_position.distance_to(global_position) < 240.0:
			if state != "fleeing":
				panic(2.5, cm)
			return


func _move_towards(point: Vector2, spd: float, delta: float) -> void:
	var dir := (point - global_position)
	if dir.length() < 2.0:
		velocity = Vector2.ZERO
		return
	velocity = dir.normalized() * spd
	move_and_slide()
	if global_position.distance_to(_last_pos) < 0.4:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = global_position


func _stuck_check(delta: float) -> bool:
	if velocity.length() > 1.0 and global_position.distance_to(_last_pos) < 0.3:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	return _stuck_t > 0.7


func _random_open_point() -> Vector2:
	for i in 12:
		var p := global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))
		var q := PhysicsPointQueryParameters2D.new()
		q.position = p
		q.collision_mask = 1
		if get_world_2d().direct_space_state.intersect_point(q, 1).is_empty():
			return p
	return global_position


func _animate(delta: float) -> void:
	if velocity.length() > 5.0:
		_anim_t += delta
		if _anim_t >= 0.16:
			_anim_t = 0.0
			_frame = (_frame + 1) % 4
	else:
		_frame = 1
	var row := 0
	if state == "repairing" and is_instance_valid(repair_target):
		row = _row_for(repair_target.global_position - global_position)
	elif state == "chasing" and is_instance_valid(player_ref):
		row = _row_for(player_ref.global_position - global_position)
	elif velocity.length() > 5.0:
		row = _row_for(velocity)
	sprite.frame = row * 4 + _frame
	if is_revealed:
		sprite.frame = _frame


func _row_for(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return 3 if dir.x > 0 else 2
	return 0 if dir.y > 0 else 1


func _nearest_of(nodes: Array, pos: Vector2) -> Node2D:
	var best: Node2D = nodes[0]
	var bd := INF
	for n in nodes:
		var d: float = n.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = n
	return best


func _vent_travel() -> void:
	var vents := get_tree().get_nodes_in_group("vents")
	if vents.is_empty():
		return
	_vent_cd = 9.0
	_far_t = 0.0
	state = "venting"
	velocity = Vector2.ZERO
	var dive := _nearest_of(vents, global_position)
	Sfx.play("vent", -4.0)
	_goo_burst(dive.global_position)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		global_position = dive.global_position
		var emerge: Node2D = dive
		if is_instance_valid(player_ref):
			emerge = _nearest_of(vents, player_ref.global_position)
		global_position = emerge.global_position
		Sfx.play("vent", -2.0, 1.25)
		_goo_burst(emerge.global_position))
	tw.tween_interval(randf_range(1.2, 2.2))
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func() -> void:
		if state == "venting":
			state = "chasing"
			Sfx.play("screech", -6.0, 1.3))


func _goo_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.16, 0.5, 0.28)
	get_tree().current_scene.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func _death_burst() -> void:
	var p := CPUParticles2D.new()
	p.position = global_position
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30
	p.lifetime = 0.7
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.16, 0.5, 0.28) if is_revealed or is_infected else Color(0.7, 0.08, 0.12)
	get_tree().current_scene.add_child(p)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())
