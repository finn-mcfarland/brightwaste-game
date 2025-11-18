extends CharacterBody3D

#lerp var
const WALKING_LERP_SPEED = 10.0
const CROUCHING_LERP_SPEED = 8.0
#speed vars
const WALKING_SPEED = 5.0
const SPRINT_SPEED = 9.0
const CROUCHING_SPEED = 2.0
#movement vars
var current_speed = 0
var crouch_depth = 1
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var direction = Vector3.ZERO
#interaction vars
const REACH = 2
const PUSHFORCE = 5
#settings
@onready var mouse_sensitivity = Global.mouse_sensitivity
#player nodes
@onready var PromptWidget := $Neck/Camera3D/InteractionRay/Prompt
@onready var Crosshair := $TextureRect
@onready var Neck := $Neck
@onready var cam := $Neck/Camera3D
@onready var crouching_col: CollisionShape3D = $CrouchingCol
@onready var standing_col: CollisionShape3D = $StandingCol
@onready var ray_cast_3d: RayCast3D = $RayCast3D


func _ready():
	Global.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$Neck/Camera3D/InteractionRay.target_position = Vector3(0,0,-REACH)
	crouch_depth = standing_col.shape.height-crouching_col.shape.height

func board():
	pass
	#body.get_parent().remove_child(body)
	#ship_root.add_child(body)

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			Neck.rotate_y(-event.relative.x * mouse_sensitivity)
			cam.rotate_x(-event.relative.y * mouse_sensitivity)
			cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-65), deg_to_rad(65))

func _physics_process(delta: float) -> void:
	#gravity so the player falls
	if not is_on_floor():
		velocity += get_gravity() * delta * Global.time_speed
	
	#movement state
	if Input.is_action_pressed("crouch_button"):
		#crouch
		current_speed = CROUCHING_SPEED
		Neck.position.y = lerp(Neck.position.y, 0.75 - crouch_depth, delta*CROUCHING_LERP_SPEED)
		standing_col.disabled = true
		crouching_col.disabled = false
	#if not under something
	elif !ray_cast_3d.is_colliding():
		#standing up
		Neck.position.y = lerp(Neck.position.y, 0.75, delta*CROUCHING_LERP_SPEED)
		standing_col.disabled = false
		crouching_col.disabled = true
		if Input.is_action_pressed("sprint_button"):
			#sprint
			current_speed = SPRINT_SPEED
		else:
			#walk
			current_speed = WALKING_SPEED
	
	# Handle jump.
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY * Global.time_speed

	#schmovement dir
	var input_dir := Input.get_vector("left_button", "right_button", "forward_button", "backward_button")
	direction = lerp(direction, (Neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*WALKING_LERP_SPEED)
	if direction:
		velocity.x = direction.x * current_speed * Global.time_speed
		velocity.z = direction.z * current_speed * Global.time_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * Global.time_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed * Global.time_speed)
	move_and_slide()
	
	#collisions for pushing
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D: #not a great way of checking pushables
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSHFORCE)
			
