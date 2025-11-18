extends RayCast3D

@onready var prompt := $Prompt

var empty_material = ShaderMaterial.new()
var outline_material = load("res://Workshop/Mats/Prop.tres")
var current_detection: Object = null

func _ready() -> void:
	add_exception(owner)

func _physics_process(_delta: float) -> void:
	if is_colliding():
		var detected = get_collider()
		#new interactable detected
		if detected != current_detection:
			#clear current
			clear_detection()
			#apply new
			if detected is Interactable:
				current_detection = detected
				find_mesh_node(detected).material_overlay = outline_material
				prompt.text = detected.get_prompt()
	else:
		clear_detection()

	if current_detection and Input.is_action_just_pressed(current_detection.prompt_input):
		current_detection.interact(owner)
		
func find_mesh_node(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			return child

func clear_detection() -> void:
	if current_detection != null:
		find_mesh_node(current_detection).material_overlay = empty_material
		prompt.text = ""
		current_detection = null
