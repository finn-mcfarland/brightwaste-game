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
	func _init(room_name, room_class, can_be_multi_floor, min_size, max_size, needs_external_access, has_secure_doors, needs_wall, population_threshold, can_have_toilet, can_have_locker, required_decorative_prop_classes, allowable_decorative_prop_classes, is_control_room, adjacent_room_requirements, has_divider):
		self.room_name = room_name
		self.room_class = room_class
		self.can_be_multi_floor = can_be_multi_floor
		self.min_size = min_size 
		self.max_size = max_size
		self.needs_external_access = needs_external_access
		self.has_secure_doors = has_secure_doors
		self.needs_wall = needs_wall
		self.population_threshold = population_threshold
		#props
		self.can_have_toilet = can_have_toilet
		self.can_have_locker = can_have_locker 
		self.required_decorative_prop_classes = required_decorative_prop_classes
		self.allowable_decorative_prop_classes = allowable_decorative_prop_classes
		self.is_control_room = is_control_room
		#adjacency rules
		self.adjacent_room_requirements = adjacent_room_requirements
		self.has_divider = has_divider
#second definitions for adjacency i think
#define room layouts
#
		
# Define room array
var all_rooms = [
	#style rooms
	RoomInfo.new("SleepingQuarters", "Personnel", false, 4, 24, false, false, true, 2, true, true, ["Beds"],["Tables_And_Chairs", "Screens"], false, [], false),
	RoomInfo.new("MessHall", "Personnel", false, 4, 48, false, false, false, 30, false, false, ["Tables_And_Chairs"],[], false, ["Kitchen"], false),
	RoomInfo.new("Kitchen", "Personnel", false, 4, 48, false, false, true, 30, false, true, ["Cooking"],[], false, ["MessHall"], true),
	RoomInfo.new("Jail", "Secure", false, 4, 40, false, true, true, 20, false, false, ["Beds", "Toilets"],["Posters"], false, ["Security"], false),
	RoomInfo.new("SmallStorage", "Storage", false, 2, 12, false, false, true, 12, false, false, ["Storage"],[], false, [], false),
	RoomInfo.new("Greenhouse", "Production", false, 6, 72, true, false, true, 10, false, false, ["Farms"], [], false, [], false),
	RoomInfo.new("Laboratory", "Production", false, 8, 32, false, false, true, 10, false, true, ["Tables_And_Chairs", "Science"], ["Posters", "Medical"], false, [], false),
	RoomInfo.new("Armory", "Secure", false, 4, 40, false, true, true, 40, false, true, ["Tables_And_Chairs", "Storage"], [], false, [], false),
	RoomInfo.new("Lounge", "Personnel", false, 4, 32, false, false, false, 10, false, true, ["Tables_And_Chairs"],["Cooking"], false, [], false),
	RoomInfo.new("Office", "Personnel", false, 4, 12, false, false, true, 6, false, false, ["Tables_And_Chairs", "Computers"], ["Posters"], false, [], false),
	RoomInfo.new("Medical", "Personnel", false, 4, 32, false, false, true, 15, false, true, ["Tables_And_Chairs", "Medical"], ["Posters"], false, [], false),
	RoomInfo.new("RepairBay", "Maintenance", false, 6, 24, false, false, false, 16, false, false, ["Tables_And_Chairs", "Tools", "Posters"], [], false, [], false ),
	RoomInfo.new("Workshop", "Maintenance", false, 4, 32, false, true, false, 16, true, true, ["Tables_And_Chairs", "Tools"], ["Posters"], false, [], false),
	RoomInfo.new("Thruster", "Propulsion", false, 4, 200, true, false, false, 60, false, false, ["Thrusters"], ["Tables_And_chairs"], false, [], false),
	RoomInfo.new("RepairBay", 6, 24, true, false, true, false, false, false, false, [], [], [], "", ["Repair"], 16),
	RoomInfo.new("Workshop", 4, 32, true, false, true, true, false, false, true, ["Workbench", "ToolRack"], [], [], "", ["Repair"], 16),

	#control rooms
	RoomInfo.new("Bridge", "Control", false, 8, 64, true, true, true, 10000, false, false, ["Tables_And_Chairs", "Screens", "Controls"], [], true, [], false),
	RoomInfo.new("Generator", "Control", false, 8, 64, false, true, true, 10000, false, false, ["IndustrialMachines", "Controls"], [], true, [], false),
	RoomInfo.new("Security", "Control", false, 4, 40, false, true, true, 20, false, false, ["Tables_And_Chairs", "Screens", "Controls"], [], true, [], false),
	RoomInfo.new("GunneryControl", "Combat", false, 4, 12, true, true, true, 10000, false, false, ["Tables_And_Chairs", "Screens", "Controls"], [], true, [], false),

	#movingparts
	RoomInfo.new("TrashCompactor", "Storage", false, 4, 24, true, false, true, 25, false, false, ["Conveyer", "Crusher"],[], false, [], false),
	RoomInfo.new("EscapePod", "Personnel", false, 6, 6, true, false, true, 5, false, false, [], [], false, [], false),
	RoomInfo.new("Cargo", "Storage", true, 12, 304, true, true, true, 40, false, false, ["BigStorage"],["Storage"], false, [], false),
	RoomInfo.new("Hangar", "Combat", true, 21, 200, true, false, false, 80, false, true, ["Ships"], [], false, [], false)
]

class ShipInfo:
	func _init(ship_class, min_width, max_width, min_length, max_length, population_density, ratio_lims, required_rooms, banned_rooms, required_room_classes, optional_room_classes):
		self.ship_class = ship_class
		self.min_width = min_width
		self.max_width = max_width
		self.min_length = min_length
		self.max_length = max_length
		self.population_density = population_density
		self.ratio_lims = ratio_lims
		self.required_rooms = required_rooms
		self.banned_rooms = banned_rooms
		self.required_room_classes = required_room_classes
		self.optional_room_classes = optional_room_classes
		
#required classes, and optional classes.
#higher density is lower, it's how many tiles are required for a ship to have +1 person
var ship_setups = [
	ShipInfo.new("Transporter", 10, 20, 20, 40, 19, [1, 2],  ["SmallStorage", "Bridge", "Airlock"], ["", ""], ["Personnel", "Propulsion", "Transportation"], ["", "", ""]),
	ShipInfo.new("Production", 15, 40, 30, 60, 9, [1, 2], ["Factory", "Airlock", "Bridge", "Lounge"], ["BayGunnery", ""], ["Repair", "Utility", ""], ["Production", "Personnel", "Propulsion"]),
	ShipInfo.new("Combat", 10, 40, 40, 70, 13, [1, 3], ["Bridge", "Airlock", ""], ["EscapePod", "Lounge", ""], ["Combat", "Propulsion", "Personnel"], ["Secure", "Utility", "Transportation"]),
	ShipInfo.new("Research", 20, 60, 20, 60, 23, [1, 1], ["Laboratory", "Medical", "Airlock", "Bridge"], ["", "", ""], ["Personnel", "", ""], ["Secure", "Propulsion", "Utility", "Administration"]),
	#ShipInfo.new("Auxiliary", 3, 8, 6, 20, 20, [1, 3], ["Bridge", "Airlock", ""], ["Personnel", "", ""], ["", "Propulsion", ""], ["Utility"]),
	#ShipInfo.new("Station", 20, 40, 20, 40, 14, [1, 1], ["Bridge", "Airlock", ""], ["Personnel", "", ""], ["", "Propulsion", ""], ["Utility"])
]

class blockInfo:
	func _init(blockClass,can_be_secure, required_rooms,optional_rooms, big_room):
		self.blockClass = blockClass
		self.can_be_secure = can_be_secure
		self.required_rooms = required_rooms
		self.optional_rooms = optional_rooms
		self.big_room = big_room
		
var block_classes = [
	#propulsion - big prop space/thruster, repair area, workshop,
	blockInfo.new("Propulsion", false, [], ["RepairBay", "Workshop"], "Thruster"),
	#bridge - computer, bridgeroom, escape_pods, workshop, smallstorage, bedrooms, gunnery?
	blockInfo.new("Bridge", true, ["Bridge"], ["EscapePod", "Office", "Workshop", "SmallStorage", "SleepingQuarters", "GunneryControl","Cartography", "Transporter"], ""),
	#storage - big prop space/cargo, smallstorage, office
	blockInfo.new("Storage", false, [], ["SmallStorage", "Office", "TrashCompactor"], "Cargo"),
	#engine - big prop space/engine, workshop, office, 
	blockInfo.new("Engine", false, [], ["Workshop", "Office"], "Generator"),
	#combat - might be armory/security, launch bay/hangar, briefing rooms, bedrooms, repairbay, gunnery, storage, lounge, office
	blockInfo.new("Combat", true, ["Security"], ["Hangar", "Office", "GunneryControl", "Armory", "SleepingQuarters", "RepairBay, Lounge, SmallStorage"], ""),
	#landing - big prop space/hangar, maybe an office, a repairbay, some storage, 
	blockInfo.new("Landing", false, [], ["Office", "RepairBay", "SmallStorage"], "Hangar"),
	#personnel - bedrooms, messhall, storage, kitchen, laundry, medical, 
	blockInfo.new("Personnel", false, ["SleepingQuarters", "Kitchen","Lounge", "EscapePod"],["Medical", "Laundry","Messhall","SmallStorage"],""),
	#cell
	blockInfo.new("Cell", true, ["Jail", "Security"], ["Medical", "Hangar", "Office", "Transporter"], ""),
	#production
	blockInfo.new("Production", false, [], ["Laboratory", "Greenhouse", "Office", "SmallStorage", "TrashCompactor"], ""),
]
