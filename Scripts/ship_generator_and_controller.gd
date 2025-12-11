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
	var rooms_assigned_to_spaces : Array = []
	var external_capacity : Array = []

	# --- setup spaces ---
	for space in available_space_rooms:
		var area = space[2] * space[3]
		space_left.append(area)
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
		var ext_multiplier = 0
		var group_classes := {}
		var any_secure = false

		for r in group:
			sum_min += r.info.min_size
			sum_max += r.info.max_size
			if r.info.needs_external_access:
				ext_multiplier += 1
			group_classes[r.info.room_class] = true
			if r.info.is_secure_room:
				any_secure = true

		var estimated_use = clamp((sum_min *1.5 ) + 4, sum_min, sum_max)
		
		var best_index = -1
		var best_score = 1e9

		for i in range(available_space_rooms.size()):
			var area = space_left[i]
			if area < 8:
				estimated_use = sum_min
			var is_empty_space = rooms_assigned_to_spaces[i].is_empty()

			# --- Hard feasibility checks ---
			if area < estimated_use:
				continue
			if ext_multiplier > 0 and external_capacity[i] < ext_multiplier*3:
				continue

			# --- Scoring ---
			var score := 0.0
			var norm = max(sum_max, 1.0)

			# closeness to sum_max — prefer near it
			score += abs(area - sum_max) / norm

			# prefer empty spaces slightly
			if is_empty_space:
				score -= 0.6
				#if area > sum_max * 1.5:
				#	score += (area - sum_max * 1.5) / (area + 1.0)
					
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
func divide_space(space: Array, rooms: Array, floor_number: int) -> void:
	# --- 1. Base Cases ---
	if rooms.is_empty():
		return
	
	# space format: [x, y, width, depth]
	var s_w = int(space[2]) # Width (X)
	var s_d = int(space[3]) # Depth (Z)

	# Enforce that the *usable* dimensions are even numbers (round down)
	# This avoids creating 1-wide strips after splits.
	if s_w > 1:
		s_w = (s_w / 2) * 2
	if s_d > 1:
		s_d = (s_d / 2) * 2
	# apply back to space copy so subspaces inherit even dims
	var working_space = space.duplicate()
	working_space[2] = s_w
	working_space[3] = s_d

	# --- Base Case: two rooms (adjacent pair must be placed) ---
	if rooms.size() == 2:
		var r1 = rooms[0]
		var r2 = rooms[1]

		# Choose split axis by longest side of the working space
		var axis = 0 if s_w >= s_d else 1
		var available_dist = s_w if axis == 0 else s_d
		var cross_length = s_d if axis == 0 else s_w

		# Determine which side (0 = left/top, 1 = right/bottom) is external (if any)
		var external_side_idx = -1
		if working_space[0] == 0:
			external_side_idx = 0
		elif working_space[0] + working_space[2] == max_width:
			external_side_idx = 1

		# If one or both need external access, try to put the needing room on the external side
		var r1_ext = r1.info.needs_external_access
		var r2_ext = r2.info.needs_external_access

		# Compute minimum required lengths for each room (in this axis) with helper
		# For single room, min requirement is its min_size (interpreted as side length)
		

		var min_len_r1 = min_len_for_single(r1)
		var min_len_r2 = min_len_for_single(r2)

		# If external side preference exists, assign split so that external-needed room sits on that side.
		var split_pos = 0
		if external_side_idx != -1:
			# side 0 = left/top = r_on_side0 ; side 1 = r_on_side1
			var r_on_side0 = null
			var r_on_side1 = null
			# put external-required room on the external side if exactly one requires it
			if r1_ext and not r2_ext:
				if external_side_idx == 0:
					r_on_side0 = r1; r_on_side1 = r2
				else:
					r_on_side0 = r2; r_on_side1 = r1
			elif r2_ext and not r1_ext:
				if external_side_idx == 0:
					r_on_side0 = r2; r_on_side1 = r1
				else:
					r_on_side0 = r1; r_on_side1 = r2
			else:
				# neither or both require external -> place by min_size ratio
				# compute proportional split based on min sizes
				var total_min = float(min_len_r1 + min_len_r2)
				var ratio = min_len_r1 / max(1.0, total_min)
				split_pos = int(floor(available_dist * ratio))
				# snap to even and clamp
				if split_pos < 2: split_pos = 2
				if split_pos > available_dist - 2: split_pos = available_dist - 2
				if split_pos % 2 == 1: split_pos -= 1
			# if we assigned r_on_side0/r_on_side1 above, compute split from their min lengths
			if r_on_side0 != null:
				var ml0 = min_len_for_single(r_on_side0)
				var ml1 = min_len_for_single(r_on_side1)
				# ensure we reserve at least ml0 for side0
				split_pos = ml0
				# enforce even/clamps
				if split_pos < 2: split_pos = 2
				if split_pos > available_dist - 2: split_pos = available_dist - 2
				if split_pos % 2 == 1: split_pos -= 1

				# Place accordingly: compute s0 and s1
				var s0 = working_space.duplicate()
				s0[2 + axis] = split_pos
				var s1 = working_space.duplicate()
				s1[axis] += split_pos
				s1[2 + axis] = available_dist - split_pos

				# populate: r_on_side0 -> s0, r_on_side1 -> s1
				r_on_side0.populate_room(Vector3(s0[2], room_height, s0[3]), Vector3(s0[0], floor_number * room_height, s0[1]))
				r_on_side1.populate_room(Vector3(s1[2], room_height, s1[3]), Vector3(s1[0], floor_number * room_height, s1[1]))
				return
		else:
			# No clear external side -> use min-size proportional split
			var total_min = float(min_len_r1 + min_len_r2)
			var ratio = min_len_r1 / max(1.0, total_min)
			split_pos = int(floor(available_dist * ratio))
			if split_pos < 2: split_pos = 2
			if split_pos > available_dist - 2: split_pos = available_dist - 2
			if split_pos % 2 == 1: split_pos -= 1

		# If we reach here and split_pos is still 0, fallback
		if split_pos <= 0:
			split_pos = max(2, int(available_dist / 2))
			if split_pos % 2 == 1: split_pos -= 1

		# Create subspaces and populate (order: rooms[0] -> left/top ; rooms[1] -> right/bottom)
		var s0 = working_space.duplicate()
		s0[2 + axis] = split_pos
		var s1 = working_space.duplicate()
		s1[axis] += split_pos
		s1[2 + axis] = available_dist - split_pos

		# Populate r1 in s0 and r2 in s1 (original ordering). If you'd rather honor adjacency direction,
		# swap here based on r1_ext/r2_ext logic - we've tried to place external folks above already.
		r1.populate_room(Vector3(s0[2], room_height, s0[3]), Vector3(s0[0], floor_number * room_height, s0[1]))
		r2.populate_room(Vector3(s1[2], room_height, s1[3]), Vector3(s1[0], floor_number * room_height, s1[1]))
		return

	# --- Base Case: single room fills whole subspace ---
	if rooms.size() == 1:
		var r = rooms[0]
		# enforce minimum even sizes for the single room
		var width = max(2, s_w)
		var depth = max(2, s_d)
		if width % 2 == 1: width -= 1
		if depth % 2 == 1: depth -= 1
		r.populate_room(Vector3(width, room_height, depth), Vector3(working_space[0], floor_number * room_height, working_space[1]))
		return

	# --- 3. Create pairs and singles; we collect plain room objects into a single pool ---
	var pairs: Array = []
	var singles: Array = []
	var assigned_rooms: Array = []

	for i in range(rooms.size()):
		var r1 = rooms[i]
		if assigned_rooms.has(r1):
			continue
		var found_pair = false
		for j in range(i + 1, rooms.size()):
			var r2 = rooms[j]
			if assigned_rooms.has(r2):
				continue
			var r1_wants_r2 = r1.info.adjacent_room_requirements.has(r2.info.room_name)
			var r2_wants_r1 = r2.info.adjacent_room_requirements.has(r1.info.room_name)
			if r1_wants_r2 or r2_wants_r1:
				pairs.append([r1, r2])
				assigned_rooms.append(r1)
				assigned_rooms.append(r2)
				found_pair = true
				break
		if not found_pair:
			singles.append(r1)
			assigned_rooms.append(r1)

	# --- 4. Flatten pairs into a single pool of room objects and assign to groups ---
	var groups = [[], []] # each group is an array of room objects
	var pool: Array = []
	# flatten pairs into pool (we keep pairs as atomic for ordering but in group we push rooms individually)
	for p in pairs:
		# p is [r1,r2] - append as an item to pool so we can preserve pair adjacency if needed
		pool.append(p)
	for s in singles:
		pool.append(s)

	# Determine which side (0/1) is external for the current space (left/right)
	var external_side_idx = -1
	if working_space[0] == 0:
		external_side_idx = 0
	elif working_space[0] + working_space[2] == max_width:
		external_side_idx = 1

	# helper counts per group
	var current_counts = [0, 0]
	for item in pool:
		var is_pair = item is Array
		var needs_external = false
		if is_pair:
			for r in item:
				if r.info.needs_external_access:
					needs_external = true
		else:
			if item.info.needs_external_access:
				needs_external = true

		var g_idx = -1
		if needs_external and external_side_idx != -1:
			g_idx = external_side_idx
		else:
			# simple balancing by number of rooms
			g_idx = 0 if current_counts[0] <= current_counts[1] else 1

		# Add to group: if pair, append both rooms individually so groups are plain room arrays
		if is_pair:
			for r in item:
				groups[g_idx].append(r)
			current_counts[g_idx] += 2
		else:
			groups[g_idx].append(item)
			current_counts[g_idx] += 1

	# --- 5. Circuit breaker: avoid empty groups (split middle of full group) ---
	if groups[0].is_empty() and not groups[1].is_empty():
		var full = groups[1]
		var mid = int(full.size() / 2)
		groups[0] = full.slice(0, mid)
		groups[1] = full.slice(mid, full.size())
	elif groups[1].is_empty() and not groups[0].is_empty():
		var full = groups[0]
		var mid = int(full.size() / 2)
		groups[0] = full.slice(0, mid)
		groups[1] = full.slice(mid, full.size())

	# --- 6. Split Axis selection (by longest side) ---
	var axis = 0 if s_w >= s_d else 1
	var available_dist = s_w if axis == 0 else s_d
	var cross_length = s_d if axis == 0 else s_w

	# Ensure available_dist is even and >= 2
	if available_dist < 2:
		push_error("Available distance too small (%d) for splitting; aborting." % available_dist)
		return
	available_dist = int((available_dist / 2) * 2)

	# --- 7. Compute min lengths for each group (using helper) ---
	var min_len_0 = get_min_length_for_group(groups[0], cross_length)
	var min_len_1 = get_min_length_for_group(groups[1], cross_length)

	# If the min lengths alone exceed available distance, warn and squeeze proportionally
	var total_req = min_len_0 + min_len_1
	var split_pos = 0
	if total_req > available_dist:
		var total_min_req = float(min_len_0 + min_len_1)
		var ratio = 0.0
		if total_min_req > 0:
			ratio = float(min_len_0) / total_min_req
		split_pos = int(floor(available_dist * ratio))
		# snapping/clamping to even
		if split_pos < 2: split_pos = 2
		if split_pos > available_dist - 2: split_pos = available_dist - 2
		if split_pos % 2 == 1: split_pos -= 1
		push_warning("Map Overcrowded: total required %d > available %d; squeezed." % [total_req, available_dist])
	else:
		# normal distribution: give each group its min and distribute slack by room count ratio
		var slack = available_dist - total_req
		var total_rooms = float(groups[0].size() + groups[1].size())
		var count_ratio = 0.5
		if total_rooms > 0:
			count_ratio = float(groups[0].size()) / total_rooms
		split_pos = min_len_0 + int(round(slack * count_ratio))
		# snap to even and clamp
		if split_pos < 2: split_pos = 2
		if split_pos > available_dist - 2: split_pos = available_dist - 2
		if split_pos % 2 == 1: split_pos -= 1

	# Final clamp safety
	var min_seg = 2
	if groups[0].size() > 0 and groups[1].size() > 0:
		split_pos = clampi(split_pos, min_seg, available_dist - min_seg)
	elif groups[0].size() > 0:
		split_pos = available_dist
	else:
		split_pos = 0

	var rem_len = available_dist - split_pos
	if rem_len < 0:
		rem_len = 0

	# --- 8. Recurse into each subspace (ensuring we provide even sizes) ---
	var current_pos = working_space[axis]
	for i in range(2):
		var size_alloc = split_pos if i == 0 else rem_len
		var group_rooms = groups[i]
		if group_rooms.size() == 0:
			current_pos += size_alloc
			continue

		if size_alloc <= 0:
			push_error("Group %d requires space but got 0. Forcing 2." % i)
			size_alloc = 2

		# ensure even
		if size_alloc % 2 == 1:
			size_alloc -= 1
			if size_alloc < 2:
				size_alloc = 2

		var sub_space = working_space.duplicate()
		sub_space[axis] = current_pos
		sub_space[2 + axis] = size_alloc

		# Recurse with the rooms for this group
		divide_space(sub_space, group_rooms, floor_number)

		current_pos += size_alloc
		
func min_len_for_single(r):
			# Ensure at least the room's min_size, but not less than 2 and make even
			var m = int(r.info.min_size)
			if m < 2: m = 2
			if m % 2 == 1: m += 1
			return m
			
# --- HELPER: compute minimum length required for a group of room objects along the split axis ---
func get_min_length_for_group(grp: Array, cross_length: float) -> int:
	if grp.is_empty():
		return 0
	var req_area = 0.0
	for r in grp:
		# interpret r.info.min_size as the minimum side length (e.g., 2 means 2x2)
		var m = float(r.info.min_size)
		if m < 2.0:
			m = 2.0
		req_area += (m * m)

	# Minimum length needed along axis is area / cross_length
	var cross = max(1.0, float(cross_length))
	var length_needed = int(ceil(req_area / cross))

	# Make length even, at least 2
	if length_needed < 2:
		length_needed = 2
	if length_needed % 2 == 1:
		length_needed += 1
	return length_needed

# --- HELPER: is the space external (left/right) ---
func is_space_external(space) -> bool:
	# true if the subspace touches the left (x==0) or right (x+width==max_width) boundary
	return space[0] == 0 or (space[0] + space[2] == max_width)


# Helper: Check for class overlap
func has_class_overlap(room_class: Array, class_dict: Dictionary) -> bool:
	for cls in room_class:
		if class_dict.has(cls):
			return true
	return false

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
	return clamp((room.min_size*1.2) + 2, 4, room.max_size)


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
		cost += pow(load_ratio, 3.0) * NEAR_FULL_WEIGHT

		# Class overlap penalty (graded)
		var overlap_count := 0
		for cls in group_classes:
			if floor_classes[i].has(cls):
				overlap_count += 1
		var overlap_ratio = float(overlap_count) / float(max(1, group_classes.size()))
		cost += overlap_ratio * OVERLAP_WEIGHT
		if overlap_ratio > 0.5:
			cost += 0.2  # extra penalty if more than half overlap

		# Slight bonus for adding new class diversity
		if overlap_ratio == 0.0:
			cost -= 0.1

		# Tiny noise to break ties
		cost += randf() * 0.02

		# Slight preference to emptier floors (less rooms currently)
		if floors[i].size() <= 1:
			cost -= 0.05

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
