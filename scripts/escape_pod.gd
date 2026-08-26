extends StaticBody2D

signal board_requested

const FONT := preload("res://assets/fonts/Monocraft.ttf")

var powered := false
var _player_in_range := false

@onready var hint: Label = $Hint


func _ready() -> void:
	add_to_group("escape_pod")
	hint.visible = false
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	$Area2D.body_entered.connect(_on_enter)
	$Area2D.body_exited.connect(_on_exit)


func set_powered() -> void:
	powered = true


func _process(_delta: float) -> void:
	hint.visible = _player_in_range
	if powered:
		hint.text = "[E] BOARD ESCAPE POD"
		hint.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	else:
		hint.text = "POWER OFFLINE"
		hint.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))


func interact(_player: Node2D) -> void:
	if powered:
		Sfx.play("click")
		board_requested.emit()
	else:
		Sfx.play("deny")


func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
