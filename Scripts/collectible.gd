extends Interactable

const TYPE_DATA = {
	CollectibleType.MACHINE_PART: {"mesh": preload("res://Workshop/Imports/Blender/MeshSavePaths/cube.res"), "counter": "machine_parts", "name":"Machine Part", "scale_factor":0.7, "collision_name":"MachinePartColl"},
	CollectibleType.FUEL_CELL: {"mesh": preload("res://Workshop/Imports/Blender/MeshSavePaths/cell.res"),"counter": "fuel_cells", "name":"Fuel Cell", "scale_factor":4, "collision_name":"FuelCellColl"},
	CollectibleType.HULL_PLATE: {"mesh": preload("res://Workshop/Imports/Blender/MeshSavePaths/plate.res"),"counter": "hull_plating", "name":"Metal Plate", "scale_factor":2, "collision_name":"HullPartColl"}
}
enum CollectibleType {MACHINE_PART, FUEL_CELL, HULL_PLATE}

@export_enum("Machine Part", "Fuel Cell", "Hull Plate") var override_type: int = -1
		
var chosen_type: int
@onready var mesh_instance: MeshInstance3D = $Collectible2
@onready var coll_instance:CollisionShape3D = $CollisionShape3D

func _ready():
	chosen_type = override_type if override_type >= 0 else randi_range(0, TYPE_DATA.size()-1)
	#load mesh
	var mesh : Mesh = TYPE_DATA[chosen_type]["mesh"]
	mesh_instance.mesh = mesh
	
	#name it right
	name = TYPE_DATA[chosen_type]["name"]
	
	#pretty
	var factor = TYPE_DATA[chosen_type]["scale_factor"]
	mesh_instance.transform = mesh_instance.transform.scaled(Vector3(factor,factor,factor))
	#i'd like to have specific collisions at some point, but godot seems to have an issue with disc collisions
	#coll_instance
	
func interact(body):
	var counter = TYPE_DATA[chosen_type]["counter"]
	if counter in Global:
		Global.set(counter, Global.get(counter) + 1)
	self.queue_free()
