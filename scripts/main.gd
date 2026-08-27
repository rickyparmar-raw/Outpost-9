extends Node2D

const TITLES := {
	"A": "ENDING A — SOLE SURVIVOR",
	"B": "ENDING B — SAVIOR",
	"C": "ENDING C — THE VECTOR",
	"D": "ENDING D — MUTINY",
	"X": "YOU WERE ABSORBED",
}
const COLORS := {
	"A": Color(0.55, 0.75, 1.0), "B": Color(0.4, 0.95, 0.55),
	"C": Color(1.0, 0.3, 0.3), "D": Color(1.0, 0.6, 0.25), "X": Color(0.85, 0.15, 0.2),
}
const TEXTS := {
	"A": "The pod launches into orbit. You look back at Outpost 9 as it fades into the blizzard. The crew is dead, but you are safe. Or are you? You look down at your hand... and notice a tiny black vein pulsing under your skin.\n\nTrust no one. Not even yourself.",
	"B": "The remaining crew strap into the escape pod. The relief is palpable. You successfully purged the Mimic and saved your team. Together, you initiate the hyperspace jump back to Earth.",
	"C": "The pod enters hyperspace. You thank your crewmate for getting through it with you. They turn to you, their face split open into a mass of writhing tentacles. The cockpit fills with screams.\n\nThe parasite has escaped the outpost.",
	"D": "The sight of the dead crewmate's human blood makes your stomach turn. The remaining crewmates look at you with horror. \"He's gone mad!\" Jax yells, raising his rifle.\n\nYou didn't trust them... and now they will never trust you.",
	"X": "Cold floods your veins as the thing that wore a friend's face closes in. The last thing you hear is your own voice calling for help from the corridor behind you.\n\nThe Mimic wears your face now.",
}

var generators_done := 0
var mimic_dead := false
var game_over := false
var boarding := false
var selected := {}
var _ambient_t := 14.0
var _log_tween: Tween
var _board_open_frame := 0
var _tips := [
	"TIP: Hold [E] beside a broken generator to repair it. Your crew repairs too — one of them may be pretending.",
	"TIP: Face a crewmate and press [F] to scan them. Three cartridges. One Mimic.",
	"TIP: [Q] eliminates a suspect. Execute an innocent human and the crew turns on you.",
	"TIP: All three generators online opens the blast door. Get to the pod bay, fast.",
]
var _tip_i := 0
var _tip_t := 9.0

@onready var player: CharacterBody2D = $Player
@onready var pod: StaticBody2D = $EscapePod
@onready var blast_door: Node2D = $BlastDoor
@onready var station: Node2D = $Station
@onready var objective_label: Label = $UI/ObjectiveLabel
@onready var scanner_label: Label = $UI/ScannerLabel
@onready var controls_label: Label = $UI/ControlsLabel
@onready var log_label: Label = $UI/LogLabel
@onready var scan_popup: Label = $UI/ScanPopup
@onready var board_panel: PanelContainer = $UI/BoardPanel
@onready var board_info: Label = $UI/BoardPanel/VBox/BoardInfo
@onready var ending_screen: ColorRect = $UI/EndingScreen
@onready var ending_title: Label = $UI/EndingScreen/Center/VBox/EndingTitle
@onready var ending_body: Label = $UI/EndingScreen/Center/VBox/EndingBody


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c: Node in [player, $Marcus, $Elena, $Jax, $Generator1, $Generator2, $Generator3, pod, blast_door, station]:
		c.process_mode = Node.PROCESS_MODE_PAUSABLE

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 44 * 32
	cam.limit_bottom = 30 * 32

	var crew := get_tree().get_nodes_in_group("crewmates")
	for cm in crew:
		cm.player_ref = player
		cm.revealed.connect(_on_mimic_revealed)
		cm.eliminated.connect(_on_crewmate_eliminated)
		cm.caught_player.connect(_on_caught)
	var victim: Node = crew[randi() % crew.size()]
	victim.set_infected(true)
	print("[Outpost9] The Mimic is: ", victim.crew_name)

	for gen in get_tree().get_nodes_in_group("generators"):
		gen.generator_repaired.connect(_on_generator_repaired)
	pod.board_requested.connect(_open_boarding)
	player.info_log.connect(_log)
	player.scan_result.connect(_on_scan_result)
	player.charges_changed.connect(_on_charges_changed)

	_log("CONTAINMENT BREACH. The cell is shattered. Trust no one.")
	_update_objective()
	Sfx.play("alarm", -10.0)
	scan_popup.modulate.a = 0.0


func _process(delta: float) -> void:
	if game_over or boarding:
		return
	_tip_t -= delta
	if _tip_t <= 0.0 and _tip_i < _tips.size():
		_log(_tips[_tip_i])
		_tip_i += 1
		_tip_t = 24.0
		return
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = randf_range(18.0, 32.0)
		_ambient_event()
	_drive_heartbeat()


func _drive_heartbeat() -> void:
	var mimic: Node = null
	for cm in get_tree().get_nodes_in_group("crewmates"):
		if cm.is_revealed and not cm.is_dead:
			mimic = cm
			break
	if mimic != null:
		var d: float = mimic.global_position.distance_to(player.global_position)
		Sfx.set_heartbeat(true, clampf(1.0 - d / 480.0, 0.0, 1.0))
	else:
		Sfx.set_heartbeat(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and game_over:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and game_over:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	if not boarding:
		return
	if Engine.get_process_frames() <= _board_open_frame + 2:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				_toggle(int(event.keycode - KEY_1))
			KEY_ENTER, KEY_E:
				_launch()
			KEY_ESCAPE:
				_close_boarding()


func _ambient_event() -> void:
	match randi() % 3:
		0:
			Sfx.play("scream", -7.0, randf_range(0.9, 1.15))
			_log("You hear a scream echo from somewhere in the outpost...")
		1:
			station.surge()
			_log("The lights flicker and die for a moment.")
		2:
			_log("Something moves inside the ventilation shafts...")


func _log(text: String) -> void:
	log_label.text = text
	log_label.modulate.a = 1.0
	if _log_tween and _log_tween.is_valid():
		_log_tween.kill()
	_log_tween = create_tween()
	_log_tween.tween_interval(4.0)
	_log_tween.tween_property(log_label, "modulate:a", 0.0, 1.2)


func _update_objective() -> void:
	if generators_done < 3:
		objective_label.text = "GENERATORS ONLINE: %d/3" % generators_done
	else:
		objective_label.text = "REACH THE ESCAPE POD"


func _on_charges_changed(charges: int) -> void:
	scanner_label.text = "SCANNER [%d/3]" % charges


func _on_generator_repaired() -> void:
	generators_done += 1
	Sfx.play("online", -4.0)
	if generators_done < 3:
		_log("Generator %d/3 online! Watch the crew — not everyone pulls their weight." % generators_done)
	else:
		_log("Generator 3/3 online!")
	_update_objective()
	if generators_done >= 3:
		pod.set_powered()
		blast_door.open()
		Sfx.play("alarm", -8.0)
		_log("ALL GENERATORS ONLINE. The blast door to the pod bay is open!")


func _on_scan_result(cname: String, infected: bool) -> void:
	if infected:
		scan_popup.text = "!! %s — MIMIC !!" % cname.to_upper()
		scan_popup.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_log("%s screams and TRANSFORMS! RUN!" % cname)
		_spread_panic(cname)
	else:
		scan_popup.text = "%s — HUMAN [VERIFIED]" % cname.to_upper()
		scan_popup.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	scan_popup.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(scan_popup, "modulate:a", 0.0, 0.8)


func _spread_panic(cname: String) -> void:
	var mimic: Node2D = null
	for cm in get_tree().get_nodes_in_group("crewmates"):
		if cm.crew_name == cname:
			mimic = cm
	for cm in get_tree().get_nodes_in_group("crewmates"):
		if cm != mimic:
			cm.panic(7.0, mimic)


func _on_mimic_revealed(cname: String) -> void:
	_log("%s IS THE MIMIC! It's hunting you!" % cname)
	_update_objective()
	_spread_panic(cname)


func _on_crewmate_eliminated(cname: String, was_infected: bool) -> void:
	if was_infected:
		mimic_dead = true
		_log("The creature dissolves into viscous fluid. It is dead.")
	else:
		_ending("D")


func _on_caught() -> void:
	if game_over:
		return
	Sfx.play("screech")
	_ending("X")


func _open_boarding() -> void:
	if game_over:
		return
	boarding = true
	selected.clear()
	_board_open_frame = Engine.get_process_frames()
	get_tree().paused = true
	board_panel.visible = true
	_render_boarding()


func _render_boarding() -> void:
	var lines: Array[String] = []
	var crew := get_tree().get_nodes_in_group("crewmates")
	for i in crew.size():
		var cm: Node = crew[i]
		var status := "? UNVERIFIED"
		if cm.is_revealed:
			status = "MIMIC — REVEALED!"
		elif cm.verified_human:
			status = "HUMAN [VERIFIED]"
		var mark := "[X]" if selected.get(cm.crew_name, false) else "[ ]"
		lines.append("%s  [%d]  %s (%s) — %s" % [mark, i + 1, cm.crew_name.to_upper(), cm.role, status])
	if lines.is_empty():
		lines.append("No surviving crew.")
	board_info.text = "\n".join(lines)


func _toggle(i: int) -> void:
	var crew := get_tree().get_nodes_in_group("crewmates")
	if i < 0 or i >= crew.size():
		return
	var cname: String = crew[i].crew_name
	selected[cname] = not selected.get(cname, false)
	Sfx.play("click")
	_render_boarding()


func _launch() -> void:
	var taken: Array = []
	for cm in get_tree().get_nodes_in_group("crewmates"):
		if selected.get(cm.crew_name, false):
			taken.append(cm)
	_close_boarding()
	if taken.is_empty():
		_ending("A")
	elif taken.any(func(c: Node) -> bool: return c.is_infected):
		_ending("C")
	else:
		_ending("B")


func _close_boarding() -> void:
	boarding = false
	board_panel.visible = false
	get_tree().paused = false


func _ending(id: String) -> void:
	if game_over:
		return
	game_over = true
	boarding = false
	board_panel.visible = false
	player.set_controls(false)
	get_tree().paused = true
	if id != "X":
		Sfx.play("launch")
	ending_screen.visible = true
	ending_title.text = TITLES[id]
	ending_title.add_theme_color_override("font_color", COLORS[id])
	ending_body.text = TEXTS[id]
	ending_body.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(ending_body, "visible_ratio", 1.0, 7.0)
