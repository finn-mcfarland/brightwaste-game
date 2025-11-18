extends Control

@export var is_active : bool
var Animator : AnimationPlayer

func _ready():
	Global.pause_menu = self
	Animator = $AnimationPlayer

func _on_resume_pressed() -> void:
	Global.resume()

func _on_options_pressed() -> void:
	pass # Replace with function body.

func release_all_focus():
	var button = $PanelContainer/MarginContainer/VBoxContainer/Resume
	button.grab_focus()
	button.release_focus()

func _on_menu_pressed() -> void:
	#load main menu
	pass
