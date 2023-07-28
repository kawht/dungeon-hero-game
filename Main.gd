extends Node2D

# notes 72823
# make corridors start one tile away

var Room = preload("res://room.tscn")
var Rooms
@onready var Map = $TileMap

# Map generation specs
const TILE_SIZE = 32
const AMOUNT_ROOMS = 30
const ROOM_MAX_SIZE_TILES = 30
const ROOM_MIN_SIZE_TILES = 15
const ROOM_H_SPREAD = 50
const ROOM_CULL_PERCENTAGE = 0.3
const ROOM_INNER_MARGIN = 3
const map_border_size = 150 # unit of tiles

var room_positions = []
var path #Astar
var temp_count = 0
var tiles = {
	black=Vector2i(4,0),
	white=Vector2i(3,0),
	green=Vector2i(0,0)
}

func _ready(): generate_new_floor()

func _draw():
	if is_instance_valid(Rooms):
		for room in Rooms.get_children():
			draw_rect(Rect2(room.position-(room.size/2), room.size), Color8(28, 255, 32), false, 10)
		if path:
			for p in path.get_point_ids():
				for c in path.get_point_connections(p):
					var pp = path.get_point_position(p)
					var cp = path.get_point_position(c)
					draw_line(Vector2(pp.x, pp.y), Vector2(cp.x, cp.y), Color(1,1,0), 15, true)

func _process(_delta):
	queue_redraw()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		reset_gen()
	if event.is_action_pressed("ui_focus_next"):
		#print("[input] generating tileset...")
		make_map()


# Custom functions
func generate_new_floor():
	randomize() # or seed()
	await make_rooms()
	print("Generated room shapes.")
	cull_rooms()
	print("Removed "+str(ROOM_CULL_PERCENTAGE*100)+"% of generated rooms.")
	path = find_mst(room_positions)
	print("Path finding complete with "+str(path.get_point_count())+" connections.")
	make_map()
	print("Tilemap generated.")
	print("Cleanup in 1 second.")
	await get_tree().create_timer(1).timeout
	cleanup()
	print("Cleaned up.")
#	reset_gen()

func make_rooms():
	# create node to contain all rooms
	Rooms = Node.new()
	add_child(Rooms)
	for i in AMOUNT_ROOMS:
		var pos = Vector2(randf_range(-ROOM_H_SPREAD, ROOM_H_SPREAD), 0.0)
		var r = Room.instantiate()
		var w = randi_range(ROOM_MIN_SIZE_TILES, ROOM_MAX_SIZE_TILES)
		var h = randi_range(ROOM_MIN_SIZE_TILES, ROOM_MAX_SIZE_TILES)
		#print("room size of newly made room is "+str(Vector2(w,h)))
		r.make_room(pos, Vector2(w,h)*TILE_SIZE)
		Rooms.add_child(r)
	#print("Rooms created... waiting for settle")
	# wait for all rooms to emit the signal that they are no longer moving
	for room in Rooms.get_children():
		await room.not_moving


func cull_rooms():
	# get all rooms that are generated
	for room in Rooms.get_children():
		# cull %
		if randf() < ROOM_CULL_PERCENTAGE:
			room.state = room.states.CULLED
			room.queue_free()
		else:
			room.state = room.states.NOT_CULLED
			room_positions.append(room.position)
	return true

func find_mst(nodes : Array):
	var _path = AStar2D.new()
	_path.add_point(_path.get_available_point_id(), nodes.pop_front())
	while nodes:
		var min_dist = INF
		var min_pos = null
		var p = null
		for p1_ in _path.get_point_ids():
			var p1 = _path.get_point_position(p1_)
			for p2 in nodes:
				if p1.distance_to(p2) < min_dist:
					min_dist = p1.distance_to(p2)
					min_pos = p2
					p = p1
			var n = _path.get_available_point_id()
			_path.add_point(n, min_pos)
			_path.connect_points(_path.get_closest_point(p), n)
			nodes.erase(min_pos)
	return _path

func make_map():
	#print("POPULATING MAP")
	Map.clear()
	var map_rect = Rect2()
	for room in Rooms.get_children():
		#if room.state == room.states.CULLED:
		var r = Rect2(room.position, room.get_node("CollisionShape").shape.size)
		map_rect = map_rect.merge(r)
	var topleft = Map.local_to_map(map_rect.position)
	var bottomright = Map.local_to_map(map_rect.end)
	# create border black tiles
	for x in range(-map_border_size, map_border_size):
		for y in range(-map_border_size, map_border_size):
			if !is_tile(Vector2i(x,y), tiles.white):
				Map.set_cell(0, Vector2(x,y), 0, tiles.black)
	# carve rooms from square
	var corridors = []
	for room in Rooms.get_children():
		if not room.state == room.states.CULLED:
			temp_count += 1
			# convert room size in px to amount of tiles, floored to smallest fittable
			var room_size_map = (room.size / TILE_SIZE).floor()
			#print("proccess room size of "+str(room_size_map))
			var room_position_map = Map.local_to_map(room.position)
			var room_topleftcorner_map = room_position_map - Vector2i(room_size_map/2)
			#print("top left corner is "+str(room_topleftcorner_map))
			for x in range(3, room_size_map.x - 2):
				for y in range(3, room_size_map.y - 2):
					Map.set_cell(0, Vector2(room_topleftcorner_map.x + x, room_topleftcorner_map.y + y), 0, tiles.white)
			
			# Carve out corridors
			var closest_point_id = path.get_closest_point(room.position, false)

			# for every connection belonging to point that was close to room
			for connection in path.get_point_connections(closest_point_id):
				# carve path if it hasnt already been
				if not connection in corridors:
					var start = Map.local_to_map(path.get_point_position(closest_point_id))
					var end = Map.local_to_map(path.get_point_position(connection))
					carve_path(start, end)
					corridors.append(closest_point_id)
					corridors.append(connection)
					
#	print(temp_count)
#	print(Rooms.get_child_count())

func cleanup():
	Rooms.queue_free()
	path = null

func reset_gen():
	#get_tree().reload_current_scene()
	if is_instance_valid(Rooms):
		for n in Rooms.get_children():
			path = null
			Map.clear()
			n.queue_free()
			Rooms.queue_free()
	else:
		Map.clear()
	generate_new_floor()

func carve_path(start,end):
	# Carve path between two points
	var x_diff = sign(end.x - start.x)
	var y_diff = sign(end.y - start.y)
	if x_diff == 0: x_diff = pow(-1.0, randi() % 2)
	if y_diff == 0: y_diff = pow(-1.0, randi() % 2)
	
	var x_y = start
	var y_x = end
	if (randi() % 2) > 0:
		x_y = start
		y_x = end
	for x in range(start.x, end.x, x_diff):
		set_tile(Vector2(x, x_y.y), tiles.white)
		set_tile(Vector2(x, x_y.y + y_diff), tiles.white)
	for y in range(start.y, end.y, y_diff):
		set_tile(Vector2(y_x.x, y), tiles.white)
		set_tile(Vector2(y_x.x + x_diff, y), tiles.white)

func set_tile(tile_coords: Vector2, tile_type: Vector2i, tile_layer: int = 0, source_id: int = 0) -> void:
	Map.set_cell(tile_layer, tile_coords, source_id, tile_type)
	
func is_tile(tile_position : Vector2, tile_type : Vector2i) -> bool:
	var result = false
	if Map.get_cell_atlas_coords(0, tile_position) == tile_type:
		result = true
	return result
	
func divisible_random(a,b,n):
	var result = randi_range(a,b)
	while result % n != 0:
		result = randi_range(a,b)
		print(result)
	return result
