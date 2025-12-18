extends Node3D

#figure out why moving the roombox origin multiplicatively affects the draw_box function

var Room = preload("res://Prefabs/Generation/Room.tscn")

var tile_size = 1
var room_height = 1.5
var ship_length_ratio = 2.5

var max_width
var max_length

#[progress]i dunno i'd like to be able to say full power to shields or some such bs
#shut off the power to the gens
var wiring_layouts = ["fractal_grid", "mininum_spanning_tree", "regular_tree"]
@onready var corridor_map := $Corridor

func _ready():
	corridor_map.cell_size = Vector3(tile_size,room_height,tile_size)
	null
	# Select random ship type and define levels
	var selected_ship = Global.ship_setups[randi_range(0, Global.ship_setups.size() - 1)]
	var width_and_length = area_to_width_and_length(selected_ship.min_size, selected_ship.max_size, selected_ship.ratio_lims)
	var ship_z_size = max(ceil(width_and_length[0]), 3)
	var ship_x_size = max(ceil(width_and_length[1]), 3)
	
	#used for snapping eventually.
	#var ship_levels = randi_range(1, 3)
	print("selected = " +  str(selected_ship.ship_class))
	
	build_ship(ship_x_size, ship_z_size, selected_ship)
	
func build_ship(x_size, z_size, ship_type):

	var origin = Vector3.ZERO # center
	max_width = z_size #sqrt(Global.sum(room_quantity.values()))+ship_x_size
	max_length = x_size
	
	
	print("max width: "+ str(max_width))
	print("max length: "+ str(max_length))
	var floor_sizes: Array = []
	var floor_areas_for_room_so_i_can_skip_the_computation: Array = []
	var area = x_size * z_size
	var base_floor_count = round(clamp(area / 125.0, 1, 2))
	var floor_count = base_floor_count if x_size >= 5 else max(1, base_floor_count - 1)
	print("floors " + str(floor_count))
	for floor in range(floor_count):
		var floor_width = max_width
		var floor_length = max_length
		
		floor_sizes.append(Vector3(floor_width, 0, floor_length))
		floor_areas_for_room_so_i_can_skip_the_computation.append(floor_width * floor_length)

	var room_quantity = room_quantities(z_size, x_size, ship_type, floor_count, floor_areas_for_room_so_i_can_skip_the_computation)

	for i in range(floor_count):
		var y_offset = i * room_height
		var floor_origin = origin + Vector3(0, y_offset, 0)
		build_floor(floor_origin, ship_type, i, room_quantity[i], floor_sizes[i])

	
func build_floor(origin, ship_type, floor_number, floor_rooms, dimensions):
	#decide which rooms will go in which spaces 
	#set up multifloor infrastructure and odd room borders 
	
	#large room spaces
	#currently, we need room control - between spaces, they need to be sorted before we do any more

	#print("dimensions x and z: "+ str(dimensions))
	var current_length = 0
	var sliding_origin: Vector3 = origin
	var available_space_rooms = []
	var horizontal_divider_length_coords : Array = []

	# Define or generate widths along the ship's length
	var width_array = []
	while current_length < dimensions.z:
		var remaining_length = dimensions.z - current_length
		var upper_limit = int(remaining_length / ship_length_ratio) if remaining_length > (ship_length_ratio * 4) + 1 else remaining_length
		var lower_limit = min(6, upper_limit)
		var random_length_increase = randi_range(lower_limit, upper_limit)
		if remaining_length - random_length_increase <= 3:
			random_length_increase = remaining_length
	 
		var random_width = dimensions.x
		width_array.append([random_width, random_length_increase])
	 
		current_length += random_length_increase
	 
	# Reset for room generation
	current_length = 0
	sliding_origin = origin
	 
	for width_info in width_array:
		var total_width = width_info[0]
		var segment_length = width_info[1]
	 
		var new_rooms = []
	 
		# Corridor stays unchanged
		draw_line(total_width, Vector3.RIGHT, sliding_origin)
	 
		var is_symmetrical = randf() > 1.0 and total_width >= 8
	 
		if is_symmetrical:
			# Symmetrical split
			var left_width = randi_range(2, int(total_width / 3))
			var right_width = left_width
			var center_width = total_width - left_width - right_width - 2 # exclude corridor
	 
			if center_width == 1:
				center_width = 2
				left_width = max(2, left_width - 1)
				right_width = max(2, right_width - 1)
	 
			draw_symmetrical_segment(sliding_origin, left_width, total_width, segment_length)
	 
			new_rooms = [
				[sliding_origin.x + left_width + 1, sliding_origin.z + 1, center_width, segment_length - 1],
				[sliding_origin.x, sliding_origin.z + 1, left_width, segment_length - 1],
				[sliding_origin.x + total_width - right_width, sliding_origin.z + 1, right_width, segment_length - 1],
			]
		else:
			# Asymmetrical split
			var left_width = randi_range(2, int(total_width / 2) - 1)
			var right_width = total_width - left_width - 1 # exclude corridor
	 
			if right_width == 1:
				right_width = 2
				left_width = max(2, left_width - 1)
	 
			draw_asymmetrical_segment(sliding_origin, total_width, segment_length, left_width)
	 
			new_rooms = [
				[sliding_origin.x, sliding_origin.z + 1, left_width, segment_length - 1],
				[sliding_origin.x + left_width + 1, sliding_origin.z + 1, right_width, segment_length - 1],
			]
	 
		available_space_rooms += new_rooms
		current_length += segment_length
		sliding_origin.z += segment_length
		horizontal_divider_length_coords.append(sliding_origin.z)
	 
		var marker = MeshInstance3D.new()
		marker.position = sliding_origin
		marker.mesh = BoxMesh.new()
		marker.mesh.size = Vector3(0.1, 5, 0.1)
		self.add_child(marker)

 

	draw_line(dimensions.x, Vector3.RIGHT, origin)
	draw_line(dimensions.x, Vector3.RIGHT, Vector3(origin.x, origin.y, origin.z + sliding_origin.z))

	#END CORRIDOR CONSTRUCTION
	
	#empty out 0 width boxes.
	var boxes_to_remove : Array = []
	for box in available_space_rooms:
		if box[2]*box[3] <= 0:
			boxes_to_remove.append(box)
	for box in boxes_to_remove:
		available_space_rooms.erase(box)
	available_space_rooms.sort_custom(custom_box_sort)
	
	var total_area = 0
	var total_area_required = 0
	#draw room allocations
	"""
	for box in available_space_rooms:
		draw_box(box[0], box[1], box[2], box[3], origin)
		total_area += box[2]*box[3]
	"""
	
	#okay fix this to work normally so we actually place the rooms

	var spawned_room_list = []
	var unspawned_room_list = []
	for room in Global.all_rooms:
		if floor_rooms.has(room.room_name):
				
			for j in range(floor_rooms[room.room_name]):
				var r = Room.instantiate()
				r._make_room(room)
				r.name = r.name + "-" + str(j)
				#self.can_be_sub_room = can_be_sub_room
				#means it can be inside another room
				if room.room_name == "Locker" or room.room_name == "Fresher" or room.room_name == "Fuel":
					unspawned_room_list.append(r)
				else:
					spawned_room_list.append(r)
					$RoomBox.add_child(r)
	
	spawned_room_list.sort_custom(custom_room_sort)
	var special_rooms_placed_for_removal :Array = []
	#handling rooms that are exceptions to the standard structure, at least for now
	
	for room in spawned_room_list:
		match room.info.room_name:
			"Bridge":
				var length = randi_range(2, dimensions.x / 2)
				var room_size = Vector3(dimensions.x, room_height, length)
				var room_position = origin + Vector3(0, 0, current_length+1)
				room.populate_room(room_size, room_position)
				special_rooms_placed_for_removal.append(room)
			"Engineering":
				var length = randi_range(2, dimensions.x / 2)
				var room_size = Vector3(dimensions.x, room_height, length)
				var room_position = origin - Vector3(0, 0, length)
				room.populate_room(room_size, room_position)
				special_rooms_placed_for_removal.append(room)
			"Airlock":
				special_rooms_placed_for_removal.append(room)
				# Handle Airlock placement logic here
				#probably just pick a good corridor and ban doors from it, put this one down the end. Maybe have it extend into a space if possible
				#pass
				
	for room in special_rooms_placed_for_removal:
		spawned_room_list.erase(room)
	
	#region CODE THAT ASSIGNS ROOMS TO SPACES (COMPACT SINGLE PASS)
	var space_left : Array = []
	var slots_left : Array = []
	var rooms_assigned_to_spaces : Array = []
	var external_capacity : Array = []

	# --- setup spaces ---
	for space in available_space_rooms:
		var area = space[2] * space[3]
		space_left.append(area)
		slots_left.append(floor(space[2]/2)*floor(space[3]/2))
		rooms_assigned_to_spaces.append([])
		external_capacity.append(space[3] if is_space_external(space) else 0)

	# --- cluster adjacency ---
	var unassigned = spawned_room_list.duplicate()
	var clusters : Array = []

	while unassigned.size() > 0:
		var root = unassigned.pop_back()
		var cluster = [root]
		var stack = [root]

		while stack.size() > 0:
			var cur = stack.pop_back()
			
			for j in range(unassigned.size() - 1, -1, -1):
				var cand = unassigned[j]
				if cur.info.adjacent_room_requirements.has(cand.info.room_name) \
					or cand.info.adjacent_room_requirements.has(cur.info.room_name):
					cluster.append(cand)
					stack.append(cand)
					unassigned.pop_at(j)

		clusters.append(cluster)

	# --- order clusters: adjacency clusters first, then external singletons, then others ---
	var ordered_groups : Array = []
	var external : Array = []
	var theRest : Array = []

	for c in clusters:
		if c.size() > 1:
			if c[0].info.needs_external_access or c[1].info.needs_external_access:
				ordered_groups.push_front(c)
			else:
				ordered_groups.append(c)
		elif c.size() == 1:
			if c[0].info.needs_external_access:
				external.append(c)
			else:
				theRest.append(c)

	external.sort_custom(custom_room_array_sort)
	theRest.sort_custom(custom_room_array_sort)

	ordered_groups.append_array(external)
	ordered_groups.append_array(theRest)


	# --- placement loop ---
	for group in ordered_groups:
		var sum_min = 0.0
		var sum_max = 0.0
		var slots_needed = 0
		var ext_multiplier = 0
		var group_classes := {}
		var any_secure = false
		var current_space

		for r in group:
			sum_min += r.info.min_size
			sum_max += r.info.max_size
			slots_needed += 1
			if r.info.needs_external_access:
				ext_multiplier += 1
			group_classes[r.info.room_class] = true
			if r.info.is_secure_room:
				any_secure = true

		var estimated_use = clamp((sum_min * 1.25 ) + 3, sum_min, sum_max)
		
		var best_index = -1
		var best_score = 1e9

		for i in range(available_space_rooms.size()):
			current_space = available_space_rooms[i]
			var area = space_left[i]
			var slots = slots_left[i]
			if area < 8 or slots == slots_needed:
				estimated_use = sum_min
			var is_empty_space = rooms_assigned_to_spaces[i].is_empty()

			# --- Hard feasibility checks ---
			if area < estimated_use:
				continue
			if ext_multiplier > 0 and external_capacity[i] < ext_multiplier*3:
				continue
			if slots < slots_needed or slots < 1:
				continue

			# --- Scoring ---
			var score := 0.0
			var norm = max(sum_max, 1.0)

			# closeness to sum_max — prefer near it
			score += abs(area - sum_max) / norm

			# prefer empty spaces slightly
			if is_empty_space:
				score -= 0.4
				#if area > sum_max * 1.5:
				#	score += (area - sum_max * 1.5) / (area + 1.0)
			else:
				var total_current_max = 0
				
				for r2 in rooms_assigned_to_spaces[i]:
					total_current_max += r2.info.max_size
					if total_current_max + sum_max < current_space[2] * current_space[3]:
						score -= 0.7
						break
					
			"""
			# small penalty if same class already present
			if group_classes.size() > 0:
				for r2 in rooms_assigned_to_spaces[i]:
					if group_classes.has(r2.info.room_class):
						score -= 0.1
						break

			# penalty if secure next to secure
			if any_secure:
				for r2 in rooms_assigned_to_spaces[i]:
					if r2.info.is_secure_room:
						score -= 0.2
						break
			"""

			# stable tie-breaker
			score += float(i) * 1e-6

			if score < best_score:
				best_score = score
				best_index = i

		# --- Commit placement ---
		if best_index >= 0:
			var allocate = min(space_left[best_index], min(sum_max, max(sum_min, estimated_use)))
			space_left[best_index] -= allocate
			slots_left[best_index] -= slots_needed 
			for r in group:
				rooms_assigned_to_spaces[best_index].append(r)

			if ext_multiplier > 0:
				external_capacity[best_index] = max(0, external_capacity[best_index] - ext_multiplier*3)

			#print("Placed group ", group, " in space ", best_index, " score=", best_score, " remaining=", space_left[best_index])
		else:
			push_error("Could not place group: " + str(group))
			print("Failed to place group: ", group)
			print()

	print("Rooms assigned to spaces: ", rooms_assigned_to_spaces)
	print("Remaining space: ", space_left)
	print("--------------spaces for floor complete--------------")
	print("\n")
	print("--------------next floor--------------")
	#endregion


		
			
	#if we get to here, all the rooms fit, and we might have spare space, so grab
	for i in range(len(available_space_rooms)):
		#this is a patch . we need to not have empty spaces, for the script below to work
		#i would also like to place corridors through large spaces if they're full of small rooms[FIX]
		if rooms_assigned_to_spaces[i] == []:
			print("empty space - removed from division, as recursive room dividing algorithm assumes contents")
			continue
		divide_space(available_space_rooms[i], rooms_assigned_to_spaces[i], origin.y)
		
# --- MAIN DIVIDE FUNCTION ---
# --- MAIN DIVIDE FUNCTION ---
func divide_space(space: Array, rooms: Array, floor_number: int) -> void:
	if rooms.is_empty():
		return

	var s_x = int(space[0]); var s_z = int(space[1])
	var s_w = int(space[2]); var s_d = int(space[3])
	var working_space = [s_x, s_z, s_w, s_d]

	# --- 2. CAPACITY CHECK ---
	var slots_x = max(1, floor(s_w / 2)) 
	var slots_z = max(1, floor(s_d / 2))
	var max_capacity = slots_x * slots_z
	
	if rooms.size() > max_capacity:
		print(space)
		print(rooms)
		push_error("CRITICAL: Overcrowded. %d rooms in space for %d." % [rooms.size(), max_capacity])
		return 

	# --- 3. Base Case: Single Room ---
	if rooms.size() == 1:
		var r = rooms[0]
		r.populate_room(Vector3(s_w, room_height, s_d), Vector3(s_x, floor_number * room_height, s_z))
		return

	# --- 4. Grouping Strategy (Adjacency Pairing) ---
	var pairs: Array = []
	var singles: Array = []
	var assigned_rooms: Array = []

	for i in range(rooms.size()):
		var r1 = rooms[i]
		if assigned_rooms.has(r1): continue
		var found_pair = false
		for j in range(i + 1, rooms.size()):
			var r2 = rooms[j]
			if assigned_rooms.has(r2): continue
			if r1.info.adjacent_room_requirements.has(r2.info.room_name) or r2.info.adjacent_room_requirements.has(r1.info.room_name):
				pairs.append([r1, r2])
				assigned_rooms.append(r1); assigned_rooms.append(r2)
				found_pair = true
				break
		if not found_pair:
			singles.append(r1)
			assigned_rooms.append(r1)

	var pool = []
	pool.append_array(pairs)
	pool.append_array(singles)

	# --- 5. Axis Selection (Robust) ---
	var touches_left = (s_x == 0)
	var touches_right = (s_x + s_w == max_width) 
	
	# Default: Split the longest side
	var axis = 0 if s_w >= s_d else 1
	
	# Check External Needs
	var ext_needs_count = 0
	for item in pool:
		var item_rooms = item if item is Array else [item]
		for r in item_rooms:
			if r.info.needs_external_access: ext_needs_count += 1
	
	# OVERRIDE: If multiple external needs exist, try to pick the axis that gives BOTH children wall access.
	# Axis 1 (Horizontal Split) keeps Left/Right wall access for both Top and Bottom children.
	# CRITICAL FIX: Only force this override if the depth is actually large enough to be split (>= 4).
	# Otherwise, we create a tiny room that causes overflow.
	if ext_needs_count > 1 and (touches_left or touches_right):
		if s_d >= 4: 
			axis = 1

	var available_dist = s_w if axis == 0 else s_d
	var valid_groups_for_ext = []
	
	if axis == 0: # Vertical Split (Left | Right)
		if touches_left: valid_groups_for_ext.append(0)
		if touches_right: valid_groups_for_ext.append(1)
	else: # Horizontal Split (Top / Bottom) - Both touch the side walls
		if touches_left or touches_right:
			valid_groups_for_ext.append(0); valid_groups_for_ext.append(1)

	# --- 6. Group Assignment ---
	var groups = [[], []]
	
	# CASE A: Final Adjacency Pair (The "Last Split")
	if pool.size() == 1 and pool[0] is Array:
		var pair = pool[0]
		
		# 1. Check if the current axis actually fits 2 rooms (min 4 units)
		# If not, and the other axis IS big enough, flip the axis.
		if available_dist < 4:
			var alt_dist = s_d if axis == 0 else s_w
			if alt_dist >= 4:
				axis = 1 - axis
				available_dist = alt_dist
				# Re-evaluate valid external sides for the new axis
				valid_groups_for_ext.clear()
				if axis == 0:
					if touches_left: valid_groups_for_ext.append(0)
					if touches_right: valid_groups_for_ext.append(1)
				else:
					if touches_left or touches_right: valid_groups_for_ext.append(0); valid_groups_for_ext.append(1)
		
		# 2. Assign Rooms
		var r0 = pair[0]
		var r1 = pair[1]
		
		# 3. FIX ADJACENCY ORIENTATION
		# Check if one room needs ext access and is about to be put in a group without it
		var r0_needs = r0.info.needs_external_access
		var r1_needs = r1.info.needs_external_access
		
		var g0_valid = valid_groups_for_ext.has(0)
		var g1_valid = valid_groups_for_ext.has(1)
		
		# If r0 needs it but G0 is invalid, and G1 IS valid... SWAP.
		if r0_needs and not g0_valid and g1_valid:
			groups[0] = [r1]
			groups[1] = [r0]
		# If r1 needs it but G1 is invalid, and G0 IS valid... SWAP (implicit via assignment)
		elif r1_needs and not g1_valid and g0_valid:
			groups[0] = [r1] # Put r1 in the valid group 0
			groups[1] = [r0]
		else:
			# Default
			groups[0] = [r0]
			groups[1] = [r1]
			
	# CASE B: Standard Partitioning
	else:
		var solved_groups = find_valid_partition(pool, s_w, s_d, axis, valid_groups_for_ext)
		
		# Retry with other axis if failed
		if solved_groups.is_empty():
			var alt_axis = 1 - axis
			var alt_dist = s_d if alt_axis == 0 else s_w
			# Quick valid_ext recalc for retry
			var alt_valid_ext = [] 
			if alt_axis == 0: 
				if touches_left: alt_valid_ext.append(0)
				if touches_right: alt_valid_ext.append(1)
			else: 
				if touches_left or touches_right: alt_valid_ext.append(0); alt_valid_ext.append(1)
				
			solved_groups = find_valid_partition(pool, s_w, s_d, alt_axis, alt_valid_ext)
			
			if not solved_groups.is_empty():
				axis = alt_axis
				available_dist = alt_dist
				# print("Swapped axis to solve layout")

		if solved_groups.is_empty():
			push_error(rooms)
			push_error(space)
			push_error("CRITICAL: No Valid Partition found. %d rooms." % rooms.size())
			return
		
		groups = solved_groups

	# --- 7. Calculate Split Position (with External Wall Capacity Clamp) ---
	var cross_dim_size = s_d if axis == 0 else s_w
	var cross_slots = max(1, int(cross_dim_size / 2))
	
	var n0 = get_room_count(groups[0])
	var n1 = get_room_count(groups[1])
	
	# Standard Area-based rigid length (stacking rooms)
	var req_len_0 = get_rigid_min_length(n0, cross_slots)
	var req_len_1 = get_rigid_min_length(n1, cross_slots)
	
	# --- NEW: External Wall Perimeter Check ---
	# If we are splitting the wall (Horizontal Split / Axis 1), we must ensure 
	# each group gets enough WALL LENGTH (2 units per external room).
	if axis == 1:
		var ext_c0 = 0
		for item in flatten_group(groups[0]):
			if item.info.needs_external_access: ext_c0 += 1
			
		var ext_c1 = 0
		for item in flatten_group(groups[1]):
			if item.info.needs_external_access: ext_c1 += 1
			
		# The wall length needed is simply 2 * external_room_count
		req_len_0 = max(req_len_0, ext_c0 * 2)
		req_len_1 = max(req_len_1, ext_c1 * 2)

	var total_req = req_len_0 + req_len_1
	var split_pos = 0

	if total_req >= available_dist:
		# Tight fit: Give exactly what is needed based on ratio
		var ratio = float(req_len_0) / float(max(1, total_req))
		split_pos = int(available_dist * ratio)
	else:
		# Slack exists: Distribute slack based on total room count
		var slack = available_dist - total_req
		var ratio = float(n0) / float(max(1, n0 + n1))
		split_pos = req_len_0 + int(slack * ratio)

	# Final Hard Clamps
	# Ensure we don't violate the minimums we just calculated
	split_pos = max(split_pos, req_len_0)
	split_pos = min(split_pos, available_dist - req_len_1)
	
	# Sanity check (absolute min 2)
	split_pos = max(split_pos, 2)
	split_pos = min(split_pos, available_dist - 2)

	# --- 8. Recurse ---
	var s0 = working_space.duplicate()
	var s1 = working_space.duplicate()

	s0[2 + axis] = split_pos             
	s1[axis] += split_pos                
	s1[2 + axis] = available_dist - split_pos 
	
	divide_space(s0, flatten_group(groups[0]), floor_number)
	divide_space(s1, flatten_group(groups[1]), floor_number)

func get_room_count(group_arr: Array) -> int:
	var c = 0
	for item in group_arr:
		if item is Array: c += 2
		else: c += 1
	return c

func flatten_group(group_arr: Array) -> Array:
	var out = []
	for item in group_arr:
		if item is Array:
			out.append(item[0])
			out.append(item[1])
		else:
			out.append(item)
	return out

func find_valid_partition(pool: Array, s_w: int, s_d: int, axis: int, valid_groups_for_ext: Array) -> Array:
	var forced_0 = []
	var forced_1 = []
	var flex_ext = []
	var flex_int = []

	# 1. Categorize Rooms
	for item in pool:
		var item_rooms = item if item is Array else [item]
		var needs_ext = false
		for r in item_rooms:
			if r.info.needs_external_access:
				needs_ext = true
				break
		
		if needs_ext:
			var can_0 = valid_groups_for_ext.has(0)
			var can_1 = valid_groups_for_ext.has(1)
			
			if can_0 and not can_1: forced_0.append(item)
			elif can_1 and not can_0: forced_1.append(item)
			elif can_0 and can_1: flex_ext.append(item)
			else: return [] # Impossible
		else:
			flex_int.append(item)

	# 2. Build Candidate Permutations (The Fix)
	# We create different sort orders to ensure we find size-combinations (like Pair+Single)
	var all_flexible = []
	all_flexible.append_array(flex_ext)
	all_flexible.append_array(flex_int)
	
	var candidate_lists = []
	
	# A. Balanced Sort (Alternating Ext/Int - Good for wall crowding)
	var list_balanced = []
	var g0_ext = []; var g1_ext = []
	for x in range(flex_ext.size()):
		if x % 2 == 0: g0_ext.append(flex_ext[x])
		else: g1_ext.append(flex_ext[x])
	list_balanced.append_array(g0_ext)
	list_balanced.append_array(flex_int) # Append internals after
	list_balanced.append_array(g1_ext)   # Sandwich method
	candidate_lists.append(list_balanced)
	
	# B. Size Ascending (Singles first - Good for fitting small remainders)
	var list_asc = all_flexible.duplicate()
	list_asc.sort_custom(func(a, b): return get_room_count([a]) < get_room_count([b]))
	candidate_lists.append(list_asc)

	# C. Size Descending (Pairs first - Good for main chunks)
	var list_desc = all_flexible.duplicate()
	list_desc.sort_custom(func(a, b): return get_room_count([a]) > get_room_count([b]))
	candidate_lists.append(list_desc)

	# 3. Middle-Out Search
	var total_flex = all_flexible.size()
	var search_indices = []
	var mid = int(total_flex / 2)
	search_indices.append(mid)
	for i in range(1, mid + 2):
		if mid - i >= 0: search_indices.append(mid - i)
		if mid + i <= total_flex: search_indices.append(mid + i)

	# Try every split index on every list type
	for i in search_indices:
		for candidate_list in candidate_lists:
			
			var g0 = forced_0.duplicate()
			var g1 = forced_1.duplicate()
			
			# Slice from the current candidate list
			if i > 0:
				g0.append_array(candidate_list.slice(0, i))
			if i < total_flex:
				g1.append_array(candidate_list.slice(i, total_flex))
				
			if g0.is_empty() or g1.is_empty(): continue

			# --- VALIDATION ---
			# 1. Area Check
			if not can_split(s_w, s_d, axis, get_room_count(g0), get_room_count(g1)):
				continue

			# 2. Wall Perimeter Check (From previous fix)
			if axis == 1:
				var ext_c0 = count_external_in_group(g0)
				var ext_c1 = count_external_in_group(g1)
				var total_wall_needed = (ext_c0 * 2) + (ext_c1 * 2)
				if total_wall_needed > s_d:
					continue
			
			# Found a valid configuration!
			return [g0, g1]

	return []

# --- Helper ---
func count_external_in_group(grp: Array) -> int:
	var c = 0
	for item in grp:
		var rooms = item if item is Array else [item]
		for r in rooms:
			if r.info.needs_external_access:
				c += 1
				break # Count item once if it has external needs (or loop if you count rooms)
				 # Note: If 'item' is a pair, do you need 2 wall units or 4?
				 # If the pair is side-by-side against wall, 4. If one behind other, 2.
				 # Safer to assume '2 per room' if both need it.
	
	# Accurate count of actual room objects needing access
	var actual_count = 0
	for item in grp:
		var rooms = item if item is Array else [item]
		for r in rooms:
			if r.info.needs_external_access:
				actual_count += 1
	return actual_count

func get_rigid_min_length(room_count: int, cross_slots: int) -> int:
	if room_count == 0: return 0
	
	var rows_needed = ceil(float(room_count) / float(cross_slots))
	return int(rows_needed * 2)
		

# --- HELPER: is the space external (left/right) ---
func is_space_external(space) -> bool:
	# true if the subspace touches the left (x==0) or right (x+width==max_width) boundary
	return space[0] == 0 or (space[0] + space[2] == max_width)

# --- NEW/REVISED HELPER FUNCTIONS ---

# Replaces 'find_valid_groups' entirely
func can_split(space_w, space_d, axis, n0, n1) -> bool:
	# Axis 0 = Vertical Split (Left | Right)
	# We check if items fit into the Width (space_w) given the Depth (space_d)
	
	if axis == 0:
		var cross_slots = max(1, floor(space_d / 2)) # Use floor!
		var req0 = ceil(float(n0) / cross_slots) * 2
		var req1 = ceil(float(n1) / cross_slots) * 2
		return (req0 + req1) <= space_w
	
	# Axis 1 = Horizontal Split (Top / Bottom)
	else:
		var cross_slots = max(1, floor(space_w / 2)) # Use floor!
		var req0 = ceil(float(n0) / cross_slots) * 2
		var req1 = ceil(float(n1) / cross_slots) * 2
		return (req0 + req1) <= space_d


func canonical_key(g0: Array, g1: Array) -> String:
	var k0 := []
	var k1 := []
	for r in g0:
		k0.append(r)
	for r in g1:
		k1.append(r)
	k0.sort()
	k1.sort()
	return str(k0) + "|" + str(k1)	
		




func group_rooms_by_adjacency(rooms: Array, room_counts: Dictionary) -> Array:
	var unassigned := rooms.duplicate()
	var groups := []

	while unassigned.size() > 0:
		var room = unassigned.pop_back()
		var group = [room]

		# Check one-way adjacency requirements
		for req in room.adjacent_room_requirements:
			for other in unassigned:
				if other.room_name == req and room_counts.get(other.room_name, 0) > 0:
					group.append(other)
		# Remove grouped rooms from unassigned
		for g in group:
			unassigned.erase(g)

		groups.append(group)

	return groups

const SAFETY_BUFFER := 1.15  # multiply group_size by this when checking capacity (configurable)
const BALANCE_WEIGHT := 1.2
const NEAR_FULL_WEIGHT := 2.0
const OVERLAP_WEIGHT := 0.8

func _estimate_room_size(room) -> float:
	# Prefer midpoint between min and max if available, else fallback
	return clamp(min(room.min_size*3, room.max_size/2), room.min_size, room.max_size) 


func assign_group_to_floor(group: Array,count_map: Dictionary,floors: Array,floor_classes: Array,floor_loads: Array,floor_areas: Array) -> void:
	# Build group_size and unique class set
	var group_size := 0.0
	var class_set := {}
	for room in group:
		var count = int(count_map.get(room.room_name, 0))
		if count <= 0:
			continue
		var avg_size = _estimate_room_size(room)
		group_size += avg_size * count
		# collect classes into a set to avoid duplicates
		if typeof(room.room_class) == TYPE_ARRAY:
			for cls in room.room_class:
				class_set[cls] = true

	# No rooms to place in this group?
	if group_size <= 0.0:
		return

	# Precompute average load (current)
	var total_load := 0.0
	for load in floor_loads:
		total_load += float(load)
	var avg_load = total_load / max(1, float(floor_loads.size()))

	# Try to find best floor via cost scoring
	var best_floor := -1
	var min_cost := INF
	var group_classes = class_set.keys()

	for i in range(floors.size()):
		var capacity = float(floor_areas[i])
		var load = float(floor_loads[i])
		var projected_load = load + group_size

		# Capacity check with a safety buffer to avoid very tight fits
		if projected_load * SAFETY_BUFFER > capacity:
			continue

		var load_ratio = projected_load / max(1.0, capacity)
		var cost := 0.0

		# Balance penalty: deviation from avg load normalized by capacity
		var balance_penalty = abs(projected_load - avg_load) / max(1.0, capacity)
		cost += balance_penalty * BALANCE_WEIGHT

		# Strong non-linear penalty for nearing full
		cost += pow(load_ratio, 1.5) * NEAR_FULL_WEIGHT

		# Class overlap penalty (graded)
		var overlap_count := 0
		for cls in group_classes:
			if floor_classes[i].has(cls):
				overlap_count += 1
		var overlap_ratio = float(overlap_count) / float(max(1, group_classes.size()))
		cost += overlap_ratio * OVERLAP_WEIGHT
		if overlap_ratio > 0.4:
			cost += 0.4  # extra penalty if more than half overlap

		# Slight bonus for adding new class diversity
		if overlap_ratio == 0.0:
			cost -= 0.3

		# Tiny noise to break ties
		cost += randf() * 0.4

		# Slight preference to emptier floors (less rooms currently)
		if floors[i].size() <= 1:
			cost -= 0.1

		if cost < min_cost:
			min_cost = cost
			best_floor = i

	# If no floor passed the safety capacity check, pick the floor with the most spare (or least negative overflow)
	if best_floor == -1:
		var best_spare := -INF
		for i in range(floors.size()):
			var capacity = float(floor_areas[i])
			var load = float(floor_loads[i])
			var spare = capacity - (load + group_size)  # could be negative
			# prefer largest spare (closest to 0 or most positive)
			if spare > best_spare:
				best_spare = spare
				best_floor = i
		# Note: if best_spare < 0, this will overflow that floor — better than forcing floor 0 blindly

	# If still -1 (shouldn't happen unless no floors), bail
	if best_floor < 0:
		push_error("assign_group_to_floor: no floor available to assign group — skipping")
		return

	# Assign (increment) rooms into selected floor
	for room in group:
		var count = int(count_map.get(room.room_name, 0))
		if count <= 0:
			continue
		# increment existing count if present
		var prev = int(floors[best_floor].get(room.room_name, 0))
		floors[best_floor][room.room_name] = prev + count

		var avg_size = _estimate_room_size(room)
		floor_loads[best_floor] += avg_size * count

		# add classes to floor class set (dictionary used as set)
		if typeof(room.room_class) == TYPE_ARRAY:
			for cls in room.room_class:
				floor_classes[best_floor][cls] = true


func room_quantities(ship_x_size: int, ship_z_size: int, selected_ship, floor_count: int, floor_areas: Array) -> Array:
	# Estimate population — be careful if selected_ship.population_density is per-floor.
	# This implementation assumes population_density is area-per-person (per floor),
	# so multiply by floor_count only if your density is per-floor total. Adjust as needed
	var current_fullness = 0
	var maximum = (max_length*max_width*floor_count)-(max_length+max_width)
	print("maximum: " + str(maximum))
	var ship_population = ceil(float(ship_x_size * ship_z_size) / float(max(1, selected_ship.population_density)))
	ship_population = int(ship_population)  # baseline population across ship area
	# If you intended population per floor, multiply by floor_count here. I will assume baseline (not multiplied).
	print("ship population (baseline): " + str(ship_population))
	# --- Step 1: compute base counts for all rooms (first pass) ---
	var room_counts := {}
	for room in Global.all_rooms:
		var count := 0
		if room.room_name in selected_ship.banned_rooms:
			count = 0
		elif room.room_name in selected_ship.required_rooms or Global.is_list_in_list(room.room_class, selected_ship.required_room_classes):
			count = max(1, int(ship_population / max(1, room.population_threshold)))
		elif Global.is_list_in_list(room.room_class, selected_ship.optional_room_classes) and current_fullness <= maximum:
			# optional rooms appear probabilistically
			if randf() > 0.5:
				count = int(round(float(ship_population) / max(1.0, float(room.population_threshold))))
		room_counts[room.room_name] = max(0, count)
		#if room.room_name not in ["Engineering", "Bridge"]:
		current_fullness += count * 4
	while current_fullness * 2 < maximum:
		for room in Global.all_rooms:
			if current_fullness * 1.5 < maximum:
				if room.population_threshold < 30:
					var amount = ceil(room_counts[room.room_name] * 0.2) 
					room_counts[room.room_name] += amount
					current_fullness += amount * 5
					
			else:
				break

	print("current fullness: " + str(current_fullness))
	# --- Step 1.5: second pass to enforce adjacency and mutual requirements ---
	# Ensure that if room A requires N of room B nearby, there are at least N of B.
	# We'll do repeated passes until no change or a small number of iterations.
	var changed = true
	var iter = 0
	while changed and iter < 5:
		changed = false
		iter += 1
		for room in Global.all_rooms:
			var base_count = room_counts[room.room_name]
			if base_count <= 0:
				continue
			# for each adjacent requirement, ensure it's present in sufficient numbers
			if room.adjacent_room_requirements.size() >= 1:
				for adjacent in room.adjacent_room_requirements:
					var adj_count = room_counts[adjacent]
					# we want at least base_count of adjacent rooms (or some rule); use base_count as target
					if adj_count < base_count: 
						room_counts[adjacent] = base_count
						changed = true
	# (end adjacency enforcement)
	
	# --- Step 2: Prepare floor structures ---
	var floors := []
	var floor_classes := []
	var floor_loads := []
	for i in range(floor_count):
		floors.append({})
		floor_classes.append({})
		floor_loads.append(0.0)

	# --- Step 3: Group rooms by adjacency, then assign groups ---
	var active_rooms := []
	for room in Global.all_rooms:
		if int(room_counts.get(room.room_name, 0)) > 0:
			active_rooms.append(room)

	# group_rooms_by_adjacency expected to return Array of Arrays (groups)
	var groups = group_rooms_by_adjacency(active_rooms, room_counts)

	# Estimate each group's size and sort groups by descending size (place big groups first)
	var sortable := []
	for group in groups:
		var gsize := 0.0
		for room in group:
			var count = int(room_counts.get(room.room_name, 0))
			if count <= 0:
				continue
			gsize += _estimate_room_size(room) * count
		sortable.append({"group": group, "size": gsize})
	# sort desc
	sortable.sort_custom(func(a, b):
		return int(sign(b["size"]- a["size"]))  # return >0 if a should come after b
	)

	# assign in sorted order
	for entry in sortable:
		var group = entry["group"]
		assign_group_to_floor(group, room_counts, floors, floor_classes, floor_loads, floor_areas)

	print("Final floor allocations:")
	print(floors)
	return floors
	

func area_to_width_and_length(min_area, max_area, ratio_limit = [3,1]) -> Array:
	var target_area = randi_range(min_area, max_area) 
	var aspect_ratio = randf_range(ratio_limit[0], ratio_limit[1])
	var length = sqrt(target_area * aspect_ratio)
	var width = target_area / length
	
	return [width, length]

func custom_room_sort(a, b):
	return a.info.max_size > b.info.max_size;
	
func custom_room_array_sort(a, b):
	var asize = a[0].info.max_size
	var bsize = b[0].info.max_size
	if a.size() > 1:
		asize+= a[1].info.max_size
	if b.size() > 1:
		bsize+= b[1].info.max_size
	return asize > bsize;
	
func custom_box_sort(a, b):
	return a[2]*a[3] > b[2]*b[3];

func draw_symmetrical_segment(origin: Vector3, inset: int, width: int, length: int) -> void:
	draw_line(width, Vector3.RIGHT, origin) # horizontal divider
	draw_line(length, Vector3.BACK, origin + Vector3(inset, 0, 0)) 
	draw_line(length, Vector3.BACK, origin + Vector3(width - inset - 1, 0, 0)) 
	
func draw_asymmetrical_segment(origin: Vector3, width: int, length: int, inset: int) -> void:
	draw_line(width, Vector3.RIGHT, origin) # horizontal divider
	draw_line(length, Vector3.BACK, origin + Vector3(inset, 0, 0)) # vertical divider at inset

func draw_line(amount, direction, origin):
	for i in range(amount):
		#the room height adjustment is cause the tiles are currently 2 units tall
		corridor_map.set_cell_item(origin/Vector3(1,room_height,1)+(direction*i), 1)

	
func draw_box(x, z, width, length, origin):
	#counting down on the z, and up on the x
	var our_origin =  Vector3(x, origin.y, z)
	for zed in range(length):
		for ecs in range(width):
			corridor_map.set_cell_item(Vector3(our_origin.x+ecs, our_origin.y/(room_height), our_origin.z+zed), 0)
