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
	var ship_z_size = ceil(width_and_length[0])
	var ship_x_size = ceil(width_and_length[1])
	
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
	 
		var is_symmetrical = randf() > 0.6 and total_width >= 8
	 
		if is_symmetrical:
			# Symmetrical split
			var left_width = randi_range(2, int(total_width / 3))
			var right_width = left_width
			var center_width = total_width - left_width - right_width - 2 # exclude corridor
	 
			if center_width <= 1:
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
	 
			if right_width <= 1:
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

	print("---- Pre-organized groups ----")
	print(ordered_groups)
	print("------------------------------")

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

		var estimated_use = clamp((sum_min *1.2 ) + 2, sum_min, sum_max)
		var best_index = -1
		var best_score = 1e9

		for i in range(available_space_rooms.size()):
			var area = space_left[i]
			var is_empty_space = rooms_assigned_to_spaces[i].is_empty()

			# --- Hard feasibility checks ---
			if area < sum_min:
				continue
			if ext_multiplier > 0 and external_capacity[i] < ext_multiplier:
				continue

			# --- Scoring ---
			var score := 0.0
			var norm = max(sum_max, 1.0)

			# closeness to sum_max — prefer near it
			score += abs(area - sum_max) / norm

			# prefer empty spaces slightly
			if is_empty_space:
				score -= 0.6
				if area > sum_max * 1.5:
					score += (area - sum_max * 1.5) / (area + 1.0)

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

			# penalty for lacking external capacity
			if ext_multiplier > 0:
				var shortfall = max(0, ext_multiplier - external_capacity[i])
				score += float(shortfall) / max(1.0, ext_multiplier) * 0.6

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
				external_capacity[best_index] = max(0, external_capacity[best_index] - ext_multiplier)

			#print("Placed group ", group, " in space ", best_index, " score=", best_score, " remaining=", space_left[best_index])
		else:
			push_error("Could not place group: " + str(group))
			print("Failed to place group: ", group)
			print()

	print("Rooms assigned to spaces: ", rooms_assigned_to_spaces)
	print("Remaining space: ", space_left)
	print("--------------spaces for floor complete--------------")

	#endregion


		
			
	#if we get to here, all the rooms fit, and we might have spare space, so grab
	for i in range(len(available_space_rooms)):
		#this is a patch . we need to not have empty spaces, for the script below to work
		#i would also like to place corridors through large spaces if they're full of small rooms[FIX]
		if rooms_assigned_to_spaces[i] == []: 
			print("empty space - removed from division, as recursive room dividing algorithm assumes contents")
			continue
		divide_space(available_space_rooms[i], rooms_assigned_to_spaces[i], origin.y)

func divide_space(space: Array, rooms: Array, floor_number: int) -> void:
	# --- Early exits (kept minimal) a---
	if rooms.is_empty():
		return
	if rooms.size() == 1:
		var room = rooms[0]
		var room_size = Vector3(space[2], room_height, space[3])
		var room_position = Vector3(space[0], floor_number * room_height, space[1])
		room.populate_room(room_size, room_position)
		return

	# --- Categorize rooms ---
	var externals: Array = []
	var free_rooms: Array = []
	var pairs: Array = []

	for r in rooms:
		if r.info.needs_external_access:
			externals.append(r)
		elif not r.info.adjacent_room_requirements.is_empty():
			# keep potential pair candidates in free_rooms (we'll pair later)
			free_rooms.append(r)
		else:
			free_rooms.append(r)

	# Build adjacency pairs (produce a list of pair-arrays)
	var free_copy = free_rooms.duplicate()
	while free_copy.size() > 0:
		var r = free_copy.pop_front()
		var matched = false
		for other in free_copy:
			if r.info.adjacent_room_requirements.has(other.name):
				pairs.append([r, other])
				free_copy.erase(other)
				matched = true
				break
		if not matched:
			pairs.append([r]) # unpaired but kept as single-element array

	# --- External-only shortcut (prevents infinite recursion) ---
	if externals.size() == rooms.size():
		var along_axis = 0 if space[2] >= space[3] else 1  # lay them along longest wall
		var available = space[2] if along_axis == 0 else space[3]

		# distribute proportionally by min_size (defensive)
		var total_min = 0
		for r in externals:
			total_min += r.info.min_size
		var scale = 1.0
		if total_min > available and total_min > 0:
			scale = float(available) / float(total_min)

		var cur = space[along_axis]
		for i in range(externals.size()):
			var r = externals[i]
			var seg_size = int(clamp(r.info.min_size * scale, 1, r.info.max_size))

			# last absorbs leftover
			if i == externals.size() - 1:
				seg_size = available - (cur - space[along_axis])

			var s = space.duplicate()
			s[along_axis] = cur
			s[2 + along_axis] = seg_size
			var room_size = Vector3(s[2], room_height, s[3])
			var room_pos = Vector3(s[0], floor_number * room_height, s[1])
			r.populate_room(room_size, room_pos)
			cur += seg_size
		return

	# --- Init groups (ensure groups are arrays of room objects, not nested arrays) ---
	var groups = [[], []] # groups[0] and groups[1] will be flat arrays of Room objects
	if externals.size() > 0:
		# choose side heuristics as your original: using space[0]==0 as sentinel
		if space[0] == 0:
			groups[0] = externals.duplicate()
		else:
			groups[1] = externals.duplicate()

	# --- Assign pairs & free rooms into groups (flatten pairs into groups) ---
	var pool: Array = []
	for p in pairs:
		# p is an Array containing 1 or more Room objects
		var needs_external = false
		for item in p:
			if item.info.needs_external_access:
				needs_external = true
				break
		if needs_external:
			if space[0] == 0:
				for item in p: groups[0].append(item)
			else:
				for item in p: groups[1].append(item)
		else:
			# add to pool as flattened array for later balancing
			pool.append(p.duplicate())

	# Also add any leftover unpaired free rooms that weren't in `pairs` (defensive)
	# (In this implementation `pairs` already contains them, so this is extra-safety.)

	# --- Ratio balancing: distribute pool into groups (flattening pairs) ---
	var ratio_goal = [1, 1]
	if (space[3] / max(1, rooms.size())) * 3 > space[2]:
		ratio_goal = [1, 2]
		if space[0] == 0:
			ratio_goal = [2, 1]

	var current_ratio = [groups[0].size(), groups[1].size()]
	for item in pool:
		var size = 0
		if item is Array:
			size = item.size()
		else:
			size = 1
		var r0 = float(current_ratio[0]) / float(ratio_goal[0])
		var r1 = float(current_ratio[1]) / float(ratio_goal[1])
		var g = 0 if (r0 < r1) else 1
		# append flattened
		if item is Array:
			for it in item:
				groups[g].append(it)
		else:
			groups[g].append(item)
		current_ratio[g] += size

	# --- Compute group "weights" (group_areas) safely ---
	var group_areas = []
	for g in groups:
		var total = 0.0
		for r in g:
			# defensive: ensure r is object with info
			if typeof(r) != TYPE_OBJECT:
				push_error("divide_space: non-object room in group: %s" % str(r))
				continue
			# use average size as weight to avoid zero weights
			var min_s = int(r.info.min_size)
			var max_s = int(r.info.max_size)
			var weight = float(min_s + max_s) / 2.0
			# ensure positive
			weight = max(0.001, weight)
			total += weight
		group_areas.append(total)

	# --- Decide axis and dist consistently ---
	var axis = 0 if (space[2] > space[3]) else 1
	var dist = space[2] if axis == 0 else space[3]
	dist = int(max(1, dist))
	# --- Robust proportional split: compute float shares, floor them, distribute remainder by largest remainders ---
	var total_area = 0.0
	for a in group_areas:
		total_area += a

	var counts = []
	for i in range(group_areas.size()):
		counts.append(0)

	if total_area <= 0.0:
		# fallback: even split
		for i in range(counts.size()):
			counts[i] = int(floor(dist / counts.size()))
		var leftover = dist - Global.sum(counts)
		var idx = 0
		while leftover > 0:
			counts[idx] += 1
			leftover -= 1
			idx = (idx + 1) % counts.size()
	else:
		# compute float shares
		var float_shares = []
		for a in group_areas:
			float_shares.append((a / total_area) * float(dist))
		# floor
		var floored = []
		for f in float_shares:
			floored.append(int(floor(f)))
		var floored_sum = Global.sum(floored)
		var remainder = dist - floored_sum

		# compute fractional remainders and sort indices by largest fractional part
		var fracs = []
		for i in range(float_shares.size()):
			fracs.append({ "idx": i, "frac": float_shares[i] - floored[i] })
		fracs.sort_custom(func(a,b):
			if a["frac"] > b["frac"]: return -1
			if a["frac"] < b["frac"]: return 1
			return 0
		)

		# distribute remainder
		for i in range(floored.size()):
			counts[i] = floored[i]
		var j = 0
		while remainder > 0 and j < fracs.size():
			counts[fracs[j]["idx"]] += 1
			remainder -= 1
			j += 1
		while remainder > 0:
			counts[j % counts.size()] += 1
			remainder -= 1
			j += 1

	# --- Enforce minimum segment length ---
	var MIN_SEGMENT = 2
	MIN_SEGMENT = min(MIN_SEGMENT, dist)

	# --- CRITICAL FIX: Pre-emptively shrink earlier segments so later ones can still reach MIN_SEGMENT ---
	var running_total = 0
	for i in range(counts.size()):
		running_total += counts[i]
		var remaining = counts.size() - (i + 1)
		if remaining <= 0:
			break

		var remaining_space = dist - running_total
		var min_needed = remaining * MIN_SEGMENT

		# If remaining_space < min_needed, shrink this segment just enough
		if remaining_space < min_needed:
			var excess = min_needed - remaining_space
			counts[i] = max(MIN_SEGMENT, counts[i] - excess)
			running_total = Global.sum(counts.slice(0, i + 1))

	# --- Pass 2: lift up any segment smaller than MIN_SEGMENT by borrowing from largest donors ---
	var changed = true
	var safety = 0
	while changed and safety < 100:
		changed = false
		safety += 1
		for i in range(counts.size()):
			if counts[i] < MIN_SEGMENT:
				var need = MIN_SEGMENT - counts[i]
				var donor = -1
				var donor_spare = 0
				for j in range(counts.size()):
					if j == i:
						continue
					var spare = counts[j] - MIN_SEGMENT
					if spare > donor_spare:
						donor_spare = spare
						donor = j
				if donor != -1 and donor_spare > 0:
					var give = min(donor_spare, need)
					counts[donor] -= give
					counts[i] += give
					changed = true

	# --- Final normalization: make sure sum == dist ---
	var sum_counts = Global.sum(counts)
	if sum_counts != dist:
		var adjust = dist - sum_counts
		counts[counts.size() - 1] += adjust

	# --- Validation and logging ---
	for i in range(counts.size()):
		if counts[i] < MIN_SEGMENT:
			push_error("divide_space: could not enforce min segment for index %d (counts=%s dist=%d)" % [i, str(counts), dist])
		if counts[i] <= 0:
			push_error("divide_space: final counts[%d] <= 0 (value=%s)." % [i, str(counts[i])])
		if counts[i] > dist:
			push_error("divide_space: final counts[%d] > dist (value=%s)." % [i, str(counts[i])])

	# --- Subdivide and recurse ---
	var cur = space[axis]
	var subspaces = []
	for i in range(counts.size()):
		var t = counts[i]
		if t <= 0:
			continue
		var s = space.duplicate()
		s[axis] = cur
		s[2 + axis] = t
		# defensive clamp: don't let subspace grow beyond original extents
		if s[2 + axis] > (space[2] if axis == 0 else space[3]):
			push_error("divide_space: clamping oversized subspace t=%d to max extents" % t)
			s[2 + axis] = (space[2] if axis == 0 else space[3])
		subspaces.append(s)
		cur += t

	# Recurse into valid subspaces only, matching group -> subspace count
	for i in range(min(groups.size(), subspaces.size())):
		if groups[i].size() > 0:
			# skip degenerate subspaces
			if subspaces[i][2] <= 1 or subspaces[i][3] <= 1:
				push_error("divide_space: skipping degenerate subspace: %s" % str(subspaces[i]))
				continue
			divide_space(subspaces[i], groups[i], floor_number)


func is_space_external(space) -> bool:
	return space[0] == 0 or space[0] + space[2] == max_width
	
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
	# so multiply by floor_count only if your density is per-floor total. Adjust as needed.
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
		elif Global.is_list_in_list(room.room_class, selected_ship.optional_room_classes):
			# optional rooms appear probabilistically
			if randf() > 0.35:
				count = int(round(float(ship_population) / max(1.0, float(room.population_threshold))))
			else:
				count = 0
		else:
			# default optional-like behavior
			if randf() > 0.85 and room.room_name != "Empty":
				count = int(round(float(ship_population) / max(1.0, float(room.population_threshold))))
			else:
				count = 0
		room_counts[room.room_name] = max(0, count)

	# --- Step 1.5: second pass to enforce adjacency and mutual requirements ---
	# Ensure that if room A requires N of room B nearby, there are at least N of B.
	# We'll do repeated passes until no change or a small number of iterations.
	var changed = true
	var iter = 0
	while changed and iter < 5:
		changed = false
		iter += 1
		for room in Global.all_rooms:
			var base_count = int(room_counts.get(room.room_name, 0))
			if base_count <= 0:
				continue
			# for each adjacent requirement, ensure it's present in sufficient numbers
			if typeof(room.adjacent_room_requirements) == TYPE_ARRAY:
				for adjacent in room.adjacent_room_requirements:
					if adjacent == null or adjacent == "":
						continue
					var adj_count = int(room_counts.get(adjacent, 0))
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
		return int(sign(b["size"] - a["size"]))  # return >0 if a should come after b
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
