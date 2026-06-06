extends Node

var mouse_sensitivity = 0.005
#also allow people to choose between holding crouch and toggling it (same for sprint)

#resources
var machine_parts = 0
var fuel_cells = 0
var hull_plating = 0

var time_speed = 1 #to pause, use pause functions . otherwise slow it down here
var player: CharacterBody3D = null
var pause_menu: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
func switch_control(body_a, body_b):
	if body_a.is_physics_processing() != body_b.is_physics_processing():
		var to_deactivate = body_a if body_a.is_physics_processing() else body_b
		var to_activate = body_b if to_deactivate == body_a else body_a
		deactivate(to_deactivate)
		activate(to_activate)
		update_ui_for_control(to_activate, to_deactivate)
				
func activate(body):
	body.set_process_input(true)
	body.set_physics_process(true)
	body.find_child("Camera3D").make_current()
			
func deactivate(body):
	body.set_process_input(false)
	body.set_physics_process(false)

func update_ui_for_control(active, inactive):
	if "Player" in [active.name, inactive.name]:
		var is_player_active = active.name == "Player"
		#player = active if is_player_active else inactive
		player.PromptWidget.visible = is_player_active
		player.Crosshair.visible = is_player_active
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if is_player_active else Input.MOUSE_MODE_VISIBLE)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if player != null and player.is_physics_processing() and !pause_menu.is_active:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.PromptWidget.visible = true
			player.Crosshair.visible = true
	elif event.is_action_pressed("pause"):
		if pause_menu.is_active:
			resume()
		elif !pause_menu.is_active:
			pause()
			
	
func resume():
	pause_menu.is_active = false
	get_tree().paused = false
	pause_menu.Animator.play_backwards("blurAndPull")
	pause_menu.release_all_focus()
	if player.is_physics_processing(): #or turret
		player.PromptWidget.visible = true
		player.Crosshair.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pause():
	pause_menu.is_active = true
	get_tree().paused = true
	pause_menu.Animator.play("blurAndPull")
	if player.is_physics_processing():
		player.PromptWidget.visible = false
		player.Crosshair.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.warp_mouse((get_viewport().get_visible_rect().size / 2)-Vector2(9,9))

func repeat_string(_string:String, count:int) -> String:
	var string:String = ""
	for i in range(count):
		string += _string
	return string

func is_list_in_list(list_a, list_b) -> bool:
	for item in list_a:
		if item in list_b:
			return true
	return false
	
func sum(list):
	var my_sum = 0
	for item in list:
		my_sum += item
	return my_sum

class RoomInfo:
	var room_name;
	#building it
	var min_size;
	var max_size;
	var can_be_complex_room; # Can be a larger room, containing subrooms
	var needs_external_access; # Needs to be on the ship wall
	var needs_wall; # For when we want open spaces with tables in them
	var can_be_sub_room; # Can be a part of a larger room
	var is_secure_room; # Indicates if the room is a secure room # could be building if this changes placement
	var no_door; # Indicates if the room has no door
	var has_divider; # Indicates if the room can have a divider
	var allowable_sub_rooms; # List of allowable subrooms
	var adjacent_room_requirements; # List of rooms that need to be adjacent
	var allowable_props; # List of allowable props in the room
	var placement_data; # Orientation and positioning value # now vestigial
	var room_class; # Room classification or vibe
	var population_threshold; # Population threshold for requiring additional rooms

	func _init(room_name, min_size, max_size, can_be_complex_room, needs_external_access, needs_wall, can_be_sub_room, is_secure_room, no_door, has_divider, allowable_props, adjacent_room_requirements, allowable_sub_rooms, orientation, room_class, population_threshold):
		self.room_name = room_name
		self.min_size = min_size
		self.max_size = max_size
		self.can_be_complex_room = can_be_complex_room
		self.needs_external_access = needs_external_access
		self.needs_wall = needs_wall
		self.can_be_sub_room = can_be_sub_room
		self.is_secure_room = is_secure_room
		self.no_door = no_door
		self.has_divider = has_divider
		self.allowable_props = allowable_props
		self.adjacent_room_requirements = adjacent_room_requirements
		self.allowable_sub_rooms = allowable_sub_rooms
		self.placement_data = placement_data
		self.room_class = room_class
		self.population_threshold = population_threshold
		
class ShipInfo:
	var ship_class = ""
	var min_size = 0
	var max_size = 0
	var population_density = 0
	var ratio_lims = []
	var required_rooms = []
	var banned_rooms = []
	var required_room_classes = []
	var optional_room_classes = []

	func _init(ship_class, min_size, max_size, population_density, ratio_lims, required_rooms, banned_rooms, required_room_classes, optional_room_classes):
		self.ship_class = ship_class
		self.min_size = min_size
		self.max_size = max_size
		self.population_density = population_density
		self.ratio_lims = ratio_lims
		self.required_rooms = required_rooms
		self.banned_rooms = banned_rooms
		self.required_room_classes = required_room_classes
		self.optional_room_classes = optional_room_classes
		
# Define room array
var all_rooms = [
	RoomInfo.new("Empty", 1, 20, false, false, false, false, false, false, false, [], [], [], "", ["Meta"], -1),
	RoomInfo.new("SleepingQuarters", 4, 24, true, false, true, false, false, false, false, [], [], [], "", ["Personnel"], 2),
	RoomInfo.new("MessHall", 4, 48, false, false, false, false, false, false, true, [], [], [], "", ["Personnel"], 30),
	RoomInfo.new("Kitchen", 4, 48, false, false, true, false, false, false, true, [], ["MessHall"], [], "", ["Personnel"], 30),
	RoomInfo.new("Cargo", 12, 304, false, true, true, false, true, false, false, [], [], [], "", ["Transportation"], 30), #in a manner of speaking this does need external access, also consider a secure room variable - bulkhead shit
	RoomInfo.new("SmallStorage", 2, 12, false, false, true, true, false, false, false, [], [], [], "", ["Utility"], 4),
	RoomInfo.new("Hangar", 15, 1300, false, true, true, false, false, false, false, [], [], [], "", ["Transportation"], 80),
	RoomInfo.new("Factory", 16, 400, false, false, true, false, true, false, false, [], [], [], "",["Production"], 30),
	RoomInfo.new("Airlock", 1, 16, false, true, true, false, true, false, false, [], [], [], "", ["Access"], 10),
	RoomInfo.new("GreenHouse", 6, 72, true, false, true, false, false, false, false, [], [], [], "", ["Production"], 10),
	RoomInfo.new("GunneryControl", 4, 12, false, false, true, true, true, false, false, [], [], [], "", ["Combat"], 30),
	RoomInfo.new("BayGunnery", 2, 32, false, true, true, false, true, true, false, [], ["GunneryControl"], [], "", ["Combat"], 30), #not to mention we need a way to define what props could go in each room
	RoomInfo.new("Laboratory", 8, 32, true, false, true, false, true, false, false, [], [], [], "", ["Production"], 10),
	RoomInfo.new("TrashCompactor", 4, 24, false, true, true, false, true, false, false, [], [], [], "", ["Utility"], 25),
	RoomInfo.new("Lounge", 4, 32, true, false, false, false, false, false, false, [], [], [], "", ["Personnel"], 10), #this should not be the subroom for the prison
	RoomInfo.new("Fresher", 1, 12, false, false, true, true, false, false, false, [], [], [], "", ["Personnel"], 5),
	RoomInfo.new("Locker", 1, 2, false, false, true, true, false, false, false, [], [], [], "", ["Personnel"], 1),
	RoomInfo.new("Office", 4, 12, false, false, true, true, false, false, false, [], [], [], "", ["Administration"], 6),
	RoomInfo.new("EscapePod", 6, 12, false, true, true, true, true, false, false, [], [], [], "", ["Personnel"], 5),
	RoomInfo.new("Medical", 4, 32, true, false, true, false, false, false, false, [], [], [], "", ["Personnel"], 15),
	RoomInfo.new("Bridge", 8, 64, true, true, true, false, true, false, false, [], [], [], "", ["Control"], 1000),
	RoomInfo.new("Fuel", 4, 16, false, false, true, false, false, true, false, [], [], [], "", ["Propulsion"], 4),
	RoomInfo.new("Security", 4, 40, true, false, true, false, true, false, false, [], [], [], "", ["Secure"], 4),
	RoomInfo.new("Prison", 2, 6, false, false, true, true, true, true, false, [], ["Security"], [], "", ["Secure"], 4), #yeah making sure some rooms are more secure would be cool, also forcing them to only spawn as subrooms maybe? also this wouldn't have an office as a subroom? maybe a locker and or a fresher, but we need a way to indicate that.
	RoomInfo.new("RepairBay", 6, 24, true, false, true, false, false, false, false, [], [], [], "", ["Repair"], 16),
	RoomInfo.new("Workshop", 4, 32, true, false, true, true, false, false, true, ["Workbench", "ToolRack"], [], [], "", ["Repair"], 16),
	RoomInfo.new("Engineering", 4, 200, true, true, true, false, false, false, false, [], [], [], "", ["Propulsion"], 60) #subrooms have to be smaller than parent - use the parents max size for this, maybe a way to have gaurenteed sub rooms - or at least more likely (repair bay, workshop)
]

var connectionmap = [
	["Office", "Greenhouse", "SleepingQuarters"],
	["Workshop","RepairBay", "Factory", "Hangar"],
	["Security","Lounge", "GunneryControl", "Office"],
	["SmallStorage", "TrashCompactor", "Cargo"],
	["Kitchen", "SmallStorage"],
	["Messhall", "Lounge", "Greenhouse", "SmallStorage"],
	["Medical", "SmallStorage","Laboratory"],
	["Lounge","Medical","Office"],
	["Laboratory", "Lounge"]
]

#required classes, and optional classes.
#higher density is lower, it's how many tiles are required for a ship to have +1 person
var ship_setups = [
	ShipInfo.new("Transporter", 83, 378, 19, [1, 2],  ["SmallStorage", "Bridge", "Airlock"], ["", ""], ["Personnel", "Propulsion", "Transportation"], ["", "", ""]),
	ShipInfo.new("Production", 80, 200, 9, [1, 2.5], ["Factory", "Airlock", "Bridge", "Lounge"], ["BayGunnery", ""], ["Repair", "Utility", ""], ["Production", "Personnel", "Propulsion"]),
	ShipInfo.new("Combat", 75, 500, 13, [1, 3], ["Bridge", "Airlock", ""], ["EscapePod", "Lounge", ""], ["Combat", "Propulsion", "Personnel"], ["Secure", "Utility", "Transportation"]),
	ShipInfo.new("Research", 100, 300, 23, [1, 2], ["Laboratory", "Medical", "Airlock", "Bridge"], ["", "", ""], ["Personnel", "", ""], ["Secure", "Propulsion", "Utility", "Administration"]),
	ShipInfo.new("Auxiliary", 3, 20, 3, [1, 3], ["Bridge", "Airlock", ""], ["Personnel", "", ""], ["", "Propulsion", ""], ["Utility"])
]
