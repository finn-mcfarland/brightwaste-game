extends RigidBody3D

var info
var size
@onready var title = $Name
var OURMAT : StandardMaterial3D
var room_rect : Rect2i

var has_corridor_access
var connections = []
var max_connections

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
	max_connections = 1 if info.is_secure_room else 4
	

func populate_room(_size, _pos):
	size = _size
	position = _pos
	room_rect = Rect2i(
		Vector2i(roundi(position.x), roundi(position.z)), 
		Vector2i(roundi(size.x), roundi(size.z))
	)
	
	var s = BoxShape3D.new()
	s.size = size
	#$CorridorEnforce.position = size/2
	#$CorridorEnforce.shape = s
	
	var cubemesh = BoxMesh.new()
	cubemesh.size = size
	$RoomCube.position = size/2
	$RoomCube.mesh = cubemesh
	
	$RoomCube.material_override = OURMAT
	
	#if name.contains("Locker"):
		#position.y += 0.3
	$Name.position = Vector3(1,1,1)
	
	
	self.visible = true
	
	#this is also where we'd grab the unspawned room list if we can be complex
	#self.can_be_complex_room = can_be_complex_room
	#you should probably be using all of these - complex room means it can have rooms inside it
	#self.no_door = no_door
	#means it doesn't neccessarily need a door, 
	#self.has_divider = has_divider
	#means it opens into another space with like a cafeteria bench kind of thing
	#[FIX]also do props and walls and cubegrid and so on
	
# Helper to check if another room shares a wall with this one
# Helper to check if another room shares a wall with this one
func shares_wall_with(other_room) -> bool:
	if self == other_room: return false
	
	# 1. Calculate the exact amount of physical overlap on both axes
	var x_overlap_dist = min(position.x + size.x, other_room.position.x + other_room.size.x) - max(position.x, other_room.position.x)
	var z_overlap_dist = min(position.z + size.z, other_room.position.z + other_room.size.z) - max(position.z, other_room.position.z)
	
	# 2. Check if they are flush against each other (distance between boundaries is 0)
	var x_adjacent = (position.x + size.x == other_room.position.x) or (other_room.position.x + other_room.size.x == position.x)
	var z_adjacent = (position.z + size.z == other_room.position.z) or (other_room.position.z + other_room.size.z == position.z)
	
	# 3. The Cross-Check: Touch on one axis + Overlap on the OTHER axis
	# We require an overlap of > 0.99 (basically 1 tile) to prevent diagonal corner touches
	if x_adjacent and z_overlap_dist >= 0.99: return true
	if z_adjacent and x_overlap_dist >= 0.99: return true
	
	return false
	
	
func get_wall_tiles(other_room):
	return room_rect.grow(1).intersection(other_room.room_rect.grow(1))
	
