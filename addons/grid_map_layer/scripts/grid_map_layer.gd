@tool
extends TileMapLayer
class_name GridMapLayer


@export var data_layer_name:String = "gml"
@export var target_gridmap:GridMap
@export var target_layer:int = 0
@export var tile_subdivision:int = 0
@export_tool_button("Set GridMap Tiles") var _set_gridmap_tiles := func():
	_set_gridmap_tiles_impl()

func _set_gridmap_tiles_impl() -> void:
	for cell_position: Vector2i in get_used_cells():
		var tile_data: TileData = get_cell_tile_data(cell_position)
		if tile_data == null:
			continue

		var grid_data := tile_data.get_custom_data(data_layer_name) as Array[Dictionary]
		if grid_data == null:
			continue

		var gridmap_position := Vector3i(
			cell_position.x * (tile_subdivision + 1),
			target_layer,
			cell_position.y * (tile_subdivision + 1)
		)

		for tile_index: int in grid_data.size():
			var tile := grid_data[tile_index]
			var subgrid_position := gridmap_position + Vector3i(
				tile_index % (tile_subdivision + 1),
				0,
				tile_index / (tile_subdivision + 1)
			)

			var tile_id := target_gridmap.mesh_library.find_item_by_name(tile.get("name"))
			target_gridmap.set_cell_item(
				subgrid_position,
				tile_id,
				tile.get("orientation")
			)
			
func _get_configuration_warnings():
	if not tile_set:
		return ["Need a tile set defined"]
	if not tile_set.has_custom_data_layer_by_name(data_layer_name):
		return ["Tile Set needss a custom data layer named {0}".format([data_layer_name])]
