extends RigidBody2D

var size : Vector2
var last_position : Vector2
enum states {CREATED,NOT_CULLED,CULLED}
var state = states.CREATED

signal not_moving

func make_room(_pos,_size):
	# normalize to 32x grid
	var x : float = (_pos.x/32.0)
	var y : float = (_pos.y/32.0)
	position = Vector2(x,y).floor()*32.0
	size = _size
	var room_shape = RectangleShape2D.new()
	room_shape.custom_solver_bias = 1
	room_shape.size = size
	# apply newly generated rectangle shape to the collision node
	$CollisionShape.shape = room_shape

func settled():
	emit_signal("not_moving")
	freeze = true

func _process(_delta):
	# check if room is moving (because of collisions)
	if last_position == position:
		settled()
	last_position = position
