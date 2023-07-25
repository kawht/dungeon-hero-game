extends TileMap

# tileset coords to human readable variables
var tiles = {
	green = Vector2i(0,0),
	yellow = Vector2i(1,0),
	red = Vector2i(2,0),
	white = Vector2i(3,0),
	black = Vector2i(4,0)
}

# basic variables
var window_s = ProjectSettings.get_setting("display/window/size/viewport_width")
var base_width
var base_height
var tile_size = 32
var tick_duration = 0.0000001
var generation_complete = false
var playing = false
var ends
var sides

func get_sanitized_map_size(w:int,h:int,pixel_count:int) -> Vector2:
	# If width & height for the maze is even, make it odd. This ensures proper border sizing.
	if is_even(w):
		w -= 1
	if is_even(h):
		h -= 1
	# convert tiles to pixels and resize to screen
	var x_scale = window_s/(w*pixel_count+.0)
	var y_scale = window_s/(h*pixel_count+.0)
	return Vector2(x_scale, y_scale)
	
func generate_map(width:int=32,height:int=32):
	base_width = width
	base_height = height
	scale = get_sanitized_map_size(width, height, tile_size)
	for x in width:
		for y in height:
			# If looped tiles is onoe tile inside of the total dimensions, set its color.
			if x == 0 or y == 0 or x == width-1 or y == height-1:
				# surrounding border wall
				set_tile(Vector2(x,y), tiles.black)
			elif is_even(x) or is_even(y): # make every odd tile a wall
				# regular wall
				set_tile(Vector2(x,y), tiles.black)
			else: # make every other tile a floor
				# floor (walkable)
				set_tile(Vector2(x,y), tiles.white)

	ends = {start={x=0,y=3},finish={x=width-1,y=height-4}}
	set_tile(Vector2(ends.start.x,ends.start.y), tiles.green)
	set_tile(Vector2(ends.finish.x,ends.finish.y), tiles.green)
	find_first_tile()
	
# run once
func _ready():
	var seed1 = "Turtle".hash()
	seed(seed1)

var time_since_tick = 0.0
func _process(delta):
	if not generation_complete:
		if playing: dfs_step()
		time_since_tick += delta
		if time_since_tick > tick_duration:
			time_since_tick -= tick_duration
			#if playing: dfs_step()
	
# play/pause and step controls for maze generation
func _input(event):
	if event.is_action_pressed("ui_accept", true):
		if !generation_complete: dfs_step()
	if event.is_action_pressed("ui_focus_next"):
		playing = !playing
	if event.is_action_pressed("Reset"):
		get_tree().reload_current_scene()
#	if event.is_action_pressed("Preset1"):
#		generate_map(32,32,true)
		
func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			print(event.as_text())
			match int(event.as_text()):
				1:
					generate_map(8,8)
				2:
					generate_map(16,16)
				3:
					generate_map(32,32)
				4:
					generate_map(64,64)
				4:
					generate_map(128,128)
				5:
					generate_map(200,200)

func set_tile(pos:Vector2,tile_type:Vector2):
	set_cell(0, pos, 1, tile_type)

var dfs_tiles = []
func save_tile_to_stack(v:Vector2):
	dfs_tiles.push_back(v)

# Depth First Sort
func find_first_tile():
	# 4 sides of a tile
	sides = [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)] # right, left, down, up
	
	# look for the first white tile
	for o in sides:
		# vector for tile that is one tile over in one of 4 directions
		var search_vector = Vector2(ends.start.x + o.x, ends.start.y + o.y)
		# if the tile one tile away from start postion is white, then add it to the stack list
		if get_cell_atlas_coords(0, search_vector) == tiles.white:
			save_tile_to_stack(search_vector)
		set_tile(dfs_tiles[0], tiles.yellow)
		
func dfs_step():
	# if there are NO tiles left in the stack
	if len(dfs_tiles) <= 0:
		generation_complete = true
		
		# convert all remaining tiles after generation to black and white
		for x in base_width:
			for y in base_height:
				if get_cell_atlas_coords(0, Vector2(x,y)) == tiles.white:
					set_tile(Vector2(x,y), tiles.black)
				elif get_cell_atlas_coords(0, Vector2(x,y)) == tiles.green:
					set_tile(Vector2(x,y), tiles.white)
		return
	
	# get last tile from stack and delete it
	var selected_tile = dfs_tiles.pop_back()
	var next_dir
	var white_tile_found = false
	
	# check neighbors random
	var directions = [Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2)]
	directions.shuffle()
	for val in directions:
		next_dir = Vector2(val.x, val.y)
		if get_cell_atlas_coords(0, selected_tile + next_dir) == tiles.white:
			white_tile_found = true
			break # stop loop at first found white tile
	if white_tile_found:
		# go forwards
		save_tile_to_stack(selected_tile)
		set_tile(selected_tile + (next_dir/2), tiles.yellow) # division converts to one tile ahead isntad of 2
		set_tile(selected_tile, tiles.yellow)
		set_tile(selected_tile + next_dir, tiles.red)
		save_tile_to_stack(selected_tile+next_dir)
	else:
		# go backwards
		set_tile(selected_tile, tiles.green)
		# look at direct sides
		for dir in sides:
			if get_cell_atlas_coords(0, selected_tile + dir) == tiles.yellow:
				set_tile(selected_tile+dir, tiles.green)
			if len(dfs_tiles) > 0 and dfs_tiles[0] != null:
				set_tile(dfs_tiles.back(), tiles.red)
				
func is_even(number : int) -> bool:
	# If number divided by 2 has no remainder, it's even
	if (number % 2 == 0):
		return true
	else:
		return false
