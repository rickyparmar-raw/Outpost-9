extends Control

@onready var title_label: Label = $TitleLabel
@onready var prompt: Label = $PromptLabel
@onready var eyes: Control = $Eyes

var _eye_timer := 2.0


func _ready() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(prompt, "modulate:a", 0.15, 0.7)
	tw.tween_property(prompt, "modulate:a", 1.0, 0.7)
	_flicker()


func _flicker() -> void:
	var tw := create_tween()
	tw.tween_interval(randf_range(0.4, 1.8))
	tw.tween_callback(func() -> void:
		title_label.modulate.a = randf_range(0.35, 0.7))
	tw.tween_interval(randf_range(0.03, 0.1))
	tw.tween_property(title_label, "modulate:a", 1.0, 0.05)
	tw.tween_callback(_flicker)


func _process(delta: float) -> void:
	_eye_timer -= delta
	if _eye_timer <= 0.0:
		eyes.visible = not eyes.visible
		if eyes.visible:
			_eye_timer = randf_range(0.8, 1.6)
		else:
			_eye_timer = randf_range(1.2, 3.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		Sfx.play("click")
		get_tree().change_scene_to_file("res://scenes/main.tscn")
