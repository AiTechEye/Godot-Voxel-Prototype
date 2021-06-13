extends KinematicBody

var direction = Vector3()
var velocity = Vector3()
var gravity = -27
var jump_height = 10
var walk_speed = 10
var fpv_camera_angle = 0
var fpv_mouse_sensitivity = 0.3
var fly_mode = false

func _ready():
	core.player.object = self

#camera
func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventMouseMotion:
		rotate_y(deg2rad(-event.relative.x * fpv_mouse_sensitivity))
		var change = -event.relative.y * fpv_mouse_sensitivity
		if change + fpv_camera_angle < 90 and change + fpv_camera_angle > -90:
			$head/Camera.rotate_x(deg2rad(change))
			fpv_camera_angle += change
	elif event is InputEventMouseButton:
		if Input.is_action_just_pressed("LMB"):
			core.pointed_node_action(0)
		elif Input.is_action_just_pressed("RMB"):
			core.pointed_node_action(1)
		elif Input.is_action_just_pressed("WHEEL_UP"):
			core.player.inventory_index += 1
			if core.player.inventory_index >= core.player.inventory.size():
				core.player.inventory_index = 0
		elif Input.is_action_just_pressed("WHEEL_DOWN"):
			core.player.inventory_index -= 1
			if core.player.inventory_index <= 0:
				core.player.inventory_index = core.player.inventory.size()-1
# moving
func _process(delta):
	direction = Vector3()
	var aim = $head/Camera.get_global_transform().basis
	var pos = transform.origin
	var con = Vector3()
	if Input.is_key_pressed(KEY_W):
		con -= aim.z
	if Input.is_key_pressed(KEY_S):
		con += aim.z
	if Input.is_key_pressed(KEY_A):
		con -= aim.x
	if Input.is_key_pressed(KEY_D):
		con += aim.x
	if Input.is_action_just_pressed("fly_mode"):
			fly_mode = fly_mode == false
			$Collision.disabled = fly_mode
			velocity = Vector3(0,0,0)
#this lines just updates the screen info
#if you are not trying to solve a problem, this 4 lines is kinda useless, and useing unnecessarily performance 
	ui.screeninfo("player_pos",transform.origin)
	ui.screeninfo("chunk_id",core.chunk.pos_to_chunkid(transform.origin))
	ui.screeninfo("chunk_pos",core.chunk.to_chunk_pos(transform.origin))
	ui.screeninfo("pointing_at",core.pointed_at_node())


	if fly_mode:
		if Input.is_key_pressed(KEY_E):
			con.y += 1
		if Input.is_key_pressed(KEY_Q):
			con.y -= 1
		if Input.is_key_pressed(KEY_SHIFT):
			con*=0.1
		transform.origin += con*0.2
	else:
		var on_floor = is_on_floor()
		direction = con
		direction = direction.normalized()
		if on_floor:
			velocity.y = 0
		else:
			#if player is inside a collidable block, freeze the movement to prevent falling through the ground
			var id = core.map.get(pos.round())
			var n = core.register.id.get(id) if id != null else "default"
			var reg = core.register.nodes.get(n)
			if reg.get("collidable") != false:
				velocity.y = 0
				return
			velocity.y += gravity * delta
		var tv = velocity
		tv = velocity.linear_interpolate(direction * walk_speed,15 * delta)
		velocity.x = tv.x
		velocity.z = tv.z
		velocity = move_and_slide(velocity,Vector3(0,1,0))
	# == jumping
		if on_floor and Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_height
