extends Node2D

var _open := false

@onready var sprite: Sprite2D = $Body/Sprite2D
@onready var shape: CollisionShape2D = $Body/Shape


func open() -> void:
	if _open:
		return
	_open = true
	Sfx.play("door")
	sprite.texture = preload("res://assets/sprites/tiles/door_open.png")
	shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.7, 1.7, 1.7), 0.12)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)
