extends StaticBody2D

signal generator_repaired

@export var max_progress: float = 100.0
@export var wp_key: String = "gen3"

const TEX_OFFLINE := preload("res://assets/sprites/objects/generator_offline.png")
const TEX_CHARGING := preload("res://assets/sprites/objects/generator_charging.png")
const TEX_ONLINE := preload("res://assets/sprites/objects/generator_online.png")
const FONT := preload("res://assets/fonts/Monocraft.ttf")

var current_progress := 0.0
var is_online := false
var _player_in_range := false
var _snd_cd := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var bar: ProgressBar = $ProgressBar
@onready var hint: Label = $Hint


func _ready() -> void:
	add_to_group("generators")
	bar.visible = false
	bar.show_percentage = false
	hint.visible = false
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	sb_bg.border_color = Color(0.3, 0.33, 0.42)
	sb_bg.set_border_width_all(1)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.35, 0.9, 0.5)
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fill)
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_snd_cd = maxf(0.0, _snd_cd - delta)
	if is_online:
		return
	if _player_in_range and Input.is_action_pressed("interact"):
		current_progress = minf(current_progress + delta * 22.0, max_progress)
		if _snd_cd <= 0.0:
			Sfx.play("repair", -8.0, randf_range(0.95, 1.08))
			_snd_cd = 1.15
		if current_progress >= max_progress:
			_set_online()
	bar.visible = current_progress > 0.0 and not is_online
	bar.value = current_progress
	sprite.texture = TEX_ONLINE if is_online else (TEX_CHARGING if current_progress > 0.0 else TEX_OFFLINE)
	hint.visible = _player_in_range and not is_online


func add_progress(amount: float) -> void:
	if is_online:
		return
	current_progress = minf(current_progress + amount, max_progress)
	if current_progress >= max_progress:
		_set_online()


func interact(player: Node2D) -> void:
	if is_online:
		player.info_log.emit("Generator already fully online.")
	else:
		player.info_log.emit("Hold [E] near the generator to repair it.")


func _set_online() -> void:
	is_online = true
	bar.visible = false
	hint.visible = false
	sprite.texture = TEX_ONLINE
	Sfx.play("online")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.5, 1.0, 0.6, 0.9), Color(0.3, 0.9, 0.5, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.98, 0.5)
	var l := PointLight2D.new()
	l.texture = tex
	l.color = Color(0.45, 1.0, 0.55)
	l.energy = 1.1
	l.texture_scale = 1.6
	add_child(l)
	generator_repaired.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
