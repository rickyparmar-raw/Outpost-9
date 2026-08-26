extends CharacterBody2D

signal info_log(text: String)
signal scan_result(crew_name: String, infected: bool)
signal charges_changed(charges: int)

@export var speed: float = 210.0
@export var scan_charges: int = 3

var facing := Vector2(0, 1)
var _anim_t := 0.0
var _frame := 0
var _controls := true
var _step_acc := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var ray: RayCast2D = $RayCast2D
@onready var cam: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	_add_light()


func set_controls(on: bool) -> void:
	_controls = on
	if not on:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _controls:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	move_and_slide()
	if velocity.length() > 10.0:
		_step_acc += velocity.length() * delta
		if _step_acc >= 17.0:
			_step_acc = 0.0
			Sfx.play("step", -14.0, randf_range(0.85, 1.15))
	if input_dir.length() > 0.1:
		facing = input_dir.normalized()
		_anim_t += delta
		if _anim_t >= 0.13:
			_anim_t = 0.0
			_frame = (_frame + 1) % 4
	else:
		_frame = 1
		_anim_t = 0.0
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 3 if facing.x > 0 else 2
	else:
		row = 0 if facing.y > 0 else 1
	sprite.frame = row * 4 + _frame
	ray.target_position = facing.normalized() * 54.0


func _unhandled_input(event: InputEvent) -> void:
	if not _controls:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scan"):
		_try_scan()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("eliminate"):
		_try_eliminate()
		get_viewport().set_input_as_handled()


func _try_interact() -> void:
	var collider: Object = ray.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact(self)


func _try_scan() -> void:
	if scan_charges <= 0:
		Sfx.play("deny")
		info_log.emit("Scanner out of cartridges!")
		return
	var collider: Object = ray.get_collider()
	if collider and collider.is_in_group("crewmates") and not collider.is_revealed and not collider.is_dead and collider.state != "venting":
		scan_charges -= 1
		charges_changed.emit(scan_charges)
		Sfx.play("scan")
		var cname: String = collider.crew_name
		var infected: bool = collider.get_scanned()
		scan_result.emit(cname, infected)
	else:
		Sfx.play("deny")
		info_log.emit("No crewmate in scanner range.")


func _try_eliminate() -> void:
	var collider: Object = ray.get_collider()
	if collider and collider.is_in_group("crewmates") and not collider.is_dead and collider.state != "venting":
		var cname: String = collider.crew_name
		var was_infected: bool = collider.eliminate()
		if not was_infected:
			info_log.emit("You shot %s... their blood is HUMAN." % cname)
	else:
		info_log.emit("Nothing to eliminate.")


func _add_light() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.96, 0.85, 0.95), Color(1.0, 0.85, 0.6, 0.35), Color(1.0, 0.8, 0.5, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.98, 0.5)
	var l := PointLight2D.new()
	l.texture = tex
	l.energy = 1.3
	l.texture_scale = 2.2
	add_child(l)
