extends Interactable

@export var current_resources = 3
@export var resource_cap = 10
@onready var text := $Text
@onready var timer := $Timer
@onready var anim := $AnimationPlayer

func _ready():
	anim.play("Pulse")
	anim.pause()
	timer.start()
	timer.paused = true
	update_fuel()

func interact(body):
	if timer.paused and current_resources > 0:
		activate()
	else:
		deactivate()
	refill(body)

#[FIX]need to fix deactivation on input, and seperate refill controls from activation
#[FIX]split inputs? also maybe set up prompt to take multiple inputs if required.
func _on_timer_timeout() -> void:
	current_resources -= 1
	update_fuel()
	if current_resources <= 0:
		deactivate()
		
func deactivate():
	timer.paused = true
	anim.pause()
	
func activate():
	timer.paused = false
	anim.play()
	
func refill(body):
	var amount_we_get = clamp(Global.fuel_cells, 0, resource_cap-current_resources)
	current_resources+=amount_we_get
	Global.fuel_cells-=amount_we_get
	update_fuel()

func update_fuel():
	text.text = Global.repeat_string("■", current_resources)
