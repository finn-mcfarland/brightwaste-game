extends RigidBody3D

var info
var size
var OURMAT : StandardMaterial3D


#[FIX]we're gonna wanna have these handle their own prop placements.
func _make_room(room_info):
	randomize()
	info = room_info
	$Name.text = info.room_name
	name = room_info.room_name
	visible = false
	var our_color = Color(randf(),randf(),randf())
	OURMAT = StandardMaterial3D.new()
	OURMAT.albedo_color = our_color
	
	

func populate_room(_size, _pos):
	size = _size
	position = _pos
	var s = BoxShape3D.new()
	s.size = size
	$CorridorEnforce.position = size/2
	$CorridorEnforce.shape = s
	
	var cubemesh = BoxMesh.new()
	cubemesh.size = size
	$RoomCube.position = size/2
	$RoomCube.mesh = cubemesh
	
	$RoomCube.material_override = OURMAT
	
	#if name.contains("Locker"):
		#position.y += 0.3
	$Name.position.y += randf()
	
	self.visible = true
	
	#this is also where we'd grab the unspawned room list if we can be complex
	#self.can_be_complex_room = can_be_complex_room
	#you should probably be using all of these - complex room means it can have rooms inside it
	#self.no_door = no_door
	#means it doesn't neccessarily need a door, 
	#self.has_divider = has_divider
	#means it opens into another space with like a cafeteria bench kind of thing
	#[FIX]also do props and walls and cubegrid and so on
