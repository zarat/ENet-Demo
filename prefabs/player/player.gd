extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head

var main_camera : Camera3D
var vertical_angle = 0.0
var mouse_sensitivity = 0.01
var speed = 8.0;
var jump_speed = 4.0
var paused = false

func _ready():
	name = str(get_multiplayer_authority())
	$Name.text = str(name)
	if is_multiplayer_authority():
		main_camera = get_tree().root.get_node("Main/Camera3D")
		head.add_child(main_camera)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	if is_multiplayer_authority():
		get_input()
		main_camera.global_transform = head.global_transform
		
func _physics_process(delta):
	if is_multiplayer_authority():
		velocity.y += -gravity * delta
		move_and_slide()
		rpc("remote_set_position", global_position)
		
func get_input():
	if is_multiplayer_authority():
		# pause
		if Input.is_action_just_pressed("escape"):
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				paused = true
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				paused = false
		
		if paused:
			return
			
		# movement
		var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var movement_dir = transform.basis * Vector3(input.x, 0, input.y)
		var speed_t = speed
		velocity.x = movement_dir.x * speed_t
		velocity.z = movement_dir.z * speed_t
		
		# jumping
		if Input.is_action_pressed("jump") and is_on_floor():
			velocity.y = jump_speed
	
func _unhandled_input(event):
	if paused:
		return
	if event is InputEventMouseMotion:
		# Horizontale Charakterrotation (um die y-Achse)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertikale Kamerarotation (um die x-Achse des SpringArm3D)
		vertical_angle -= event.relative.y * mouse_sensitivity
		vertical_angle = clamp(vertical_angle, -PI / 2, PI / 2)  # Begrenzung der vertikalen Rotation auf +-90°
		head.rotation.x = vertical_angle
		
@rpc #(unreliable)
func remote_set_position(authority_position):
	global_position = authority_position

@rpc #(authority, call_local, reliable, 1)
func display_message(message):
	$Message.text = str(message)

@rpc #(any_peer, call_local, reliable, 1)
func clicked_by_player():
	$Message.text = str(multiplayer.get_remote_sender_id()) + " clicked on me!"

func _on_mouse_click_area_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		rpc("clicked_by_player")
