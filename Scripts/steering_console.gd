extends Interactable

@export var path_to_drone_root := ".."
var drone
var drone_being_controlled = false


func _ready():
	drone = get_node(path_to_drone_root)

#i'd also like the control console (not started) to be able to change where controlled steering consoles are targeting, 
#provided you own the console and the targeted ship (introduce claiming process)

func interact(body):
	Global.switch_control(body, drone)
	
	
	#issue 7 making the ship collide with hardbodies makes it fall through the earth
	#also a more streamlined camera switch would be good
	#issue 4 i'd like to have the player camera switch, their body can stay at the console if you'd like though
	#issue 3, i can't seem to unride the ship
	#issue 2 - we need to reparent on player boarding, not on interaction
	#issue 1 - this repositions the player poorly
	
	#pass
