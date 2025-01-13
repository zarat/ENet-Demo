extends CharacterBody3D

# onready variables
@onready var collision_shape = $CollisionShape3D 
@onready var head = $Head
@onready var weaponcamera = $Head/MainCamera/SubViewportContainer/SubViewport/WeaponCamera
@onready var maincamera = $Head/MainCamera

# variables
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 3.0  
var jump_speed = 4.0
var mouse_sensitivity = 0.002  
var vertical_angle = 0.0 
var is_running = false
var is_paused = false
var health = 100

var target_position: Vector3

func _ready():
	
	# display our name
	name = str(get_multiplayer_authority())
	$Name.text = str(name)
	
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Nose.layers = 4
		$Head/Weapon.visible = true
		$Head/Weapon.layers = 2
		get_tree().root.get_node("Main/Boxes/Box/MeshInstance3D").layers = 4
		
	else:
		weaponcamera.current = false
		maincamera.current = false
	
	var spawnarea = get_tree().root.get_node("Main/Area3D")
	if spawnarea:
		position = spawnarea.get_random_position_within_area()
	
func _process(delta):
	if is_multiplayer_authority():
		get_input()
		maincamera.global_transform = head.global_transform
		weaponcamera.global_transform = head.global_transform

func _physics_process(delta):
	if is_multiplayer_authority():
		velocity.y += -gravity * delta
		rpc("remote_set_position", global_position)
		rpc("remote_set_rotation", global_rotation)
		move_and_slide()
	else:
		# interpolate towards target position set by remote_set_position.rpc()
		global_position = global_position.lerp(target_position, 10 * delta)
		
func get_input():
	if !is_multiplayer_authority():
		return
	
	# mouse capture
	if Input.is_action_just_pressed("escape"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			is_paused = true
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			is_paused = false
		
	if is_paused: return
		
	# movement
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y)
	var speed_t = speed
	if Input.is_action_pressed("left_shift"):
		speed_t *= 2
	velocity.x = movement_dir.x * speed_t
	velocity.z = movement_dir.z * speed_t

	# shoot
	if Input.is_action_just_pressed("shoot"):
		shoot()
	
	# jumping
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_speed

# mouse input
func _unhandled_input(event):
	
	if not is_multiplayer_authority():
		return
		
	if is_paused:
		return
		
	if event is InputEventMouseMotion:
		# Horizontale Charakterrotation (um die y-Achse)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertikale Kamerarotation (um die x-Achse des SpringArm3D)
		vertical_angle -= event.relative.y * mouse_sensitivity
		vertical_angle = clamp(vertical_angle, -PI / 2, PI / 2)  # Begrenzung der vertikalen Rotation auf +-90°
		head.rotation.x = vertical_angle
	
func shoot():
	var space = get_world_3d().direct_space_state
	var center = get_viewport().get_size()/2
	var raystartposition = maincamera.project_ray_origin(center)
	var rayendposition = raystartposition + maincamera.project_ray_normal(center) * 100
	var query = PhysicsRayQueryParameters3D.create(raystartposition, rayendposition)
	var collision = space.intersect_ray(query)
	
	if collision:
		
		if collision.collider.has_method("send_message"):
			# send message to ourself
			send_message("You hit " + str(collision.collider.get_multiplayer_authority()))
			# send message to target
			rpc_id(collision.collider.get_multiplayer_authority(), "send_message", "You was shot by " + str(get_multiplayer_authority()))
			# send message to everyone except ourself
			rpc("send_message", str(collision.collider.get_multiplayer_authority()) + " was shot by " + str(get_multiplayer_authority()))
		
		if collision.collider.has_method("take_damage"):
			collision.collider.take_damage(10)
			#rpc_id(collision.collider.get_multiplayer_authority(), "take_damage", int(30 - collision.position.distance_to(raystartposition)))
			#rpc_id(collision.collider.get_multiplayer_authority(), "_take_damage", 10)
			
		var linemesh = ImmediateMesh.new()
		linemesh.surface_begin(Mesh.PRIMITIVE_LINES)
		linemesh.surface_add_vertex(raystartposition)
		linemesh.surface_add_vertex(collision.position)
		linemesh.surface_end()
		
		var line = MeshInstance3D.new()
		line.mesh = linemesh
		line.material_override = StandardMaterial3D.new()
		line.material_override.albedo_color = Color(0, 1, 0)  # Grün
		get_tree().root.add_child(line)
		
		var linetimer = Timer.new()
		linetimer.wait_time = 3  # seconds
		linetimer.one_shot = true  
		linetimer.timeout.connect(line.queue_free)
		get_tree().root.add_child(linetimer)
		linetimer.start()
		
		var bullet_hole = MeshInstance3D.new()
		bullet_hole.mesh = PlaneMesh.new()
		bullet_hole.mesh.size = Vector2(.1, .1) 
		bullet_hole.material_override = StandardMaterial3D.new()
		bullet_hole.material_override.albedo_color = Color(0, 0, 0) 
		get_tree().root.add_child(bullet_hole)
		
		var rotation = bullet_hole.basis #Basis()
		rotation = rotation.rotated(collision.normal, randf())  # Drehung um die Normalenachse
		bullet_hole.basis = rotation * bullet_hole.basis
		bullet_hole.global_position = collision.position + collision.normal * 0.001
		bullet_hole.global_transform = align_with_normal(bullet_hole.global_transform, collision.normal)

		var bullet_holetimer = Timer.new()
		bullet_holetimer.wait_time = 5.0  # seconds
		bullet_holetimer.one_shot = true  
		bullet_holetimer.timeout.connect(bullet_hole.queue_free)
		get_tree().root.add_child(bullet_holetimer)
		bullet_holetimer.start()
		
		rpc("_shoot", raystartposition, collision)
		
	else:
		
		var linemesh = ImmediateMesh.new()
		linemesh.surface_begin(Mesh.PRIMITIVE_LINES)
		linemesh.surface_add_vertex(raystartposition)
		linemesh.surface_add_vertex(rayendposition)
		linemesh.surface_end()
		
		var line = MeshInstance3D.new()
		line.mesh = linemesh
		line.material_override = StandardMaterial3D.new()
		line.material_override.albedo_color = Color(1, 0, 0)  # Rot
		get_tree().root.add_child(line)
		
		var linetimer = Timer.new()
		linetimer.wait_time = 3  # seconds
		linetimer.one_shot = true  
		linetimer.timeout.connect(line.queue_free)
		get_tree().root.add_child(linetimer)
		linetimer.start()
		
		rpc("_shoot", raystartposition, collision)

func align_with_normal(xform, normal):
	xform.basis.y = normal
	xform.basis.x = -xform.basis.z.cross(normal)
	xform.basis = xform.basis.orthonormalized()
	return xform

# Gets called from remote player 
func take_damage(amount):
	health -= amount
	if health <= 0:
		var area = get_tree().root.get_node("Main/Area3D")
		if area:
			var random_position = area.get_random_position_within_area()
			position = random_position
			print(str(position))
		health = 100
	$Message.text = str(health)
	rpc("sync_health", health) 

# Gets called by take_damage
@rpc ("any_peer")
func sync_health(new_health):
	health = new_health
	$Message.text = str(health)
	
# Gets called by shoot()
@rpc
func _shoot(root, target):

	var bullet_hole = MeshInstance3D.new()
	bullet_hole.mesh = PlaneMesh.new()
	bullet_hole.mesh.size = Vector2(.1, .1) 
	bullet_hole.material_override = StandardMaterial3D.new()
	bullet_hole.material_override.albedo_color = Color(0, 0, 0) 
	get_tree().root.add_child(bullet_hole)
	
	var rotation = bullet_hole.basis #Basis()
	rotation = rotation.rotated(target.normal, randf())  # Drehung um die Normalenachse
	bullet_hole.basis = rotation * bullet_hole.basis
	bullet_hole.global_position = target.position + target.normal * 0.01
	bullet_hole.global_transform = align_with_normal(bullet_hole.global_transform, target.normal)

	var bullet_holetimer = Timer.new()
	bullet_holetimer.wait_time = 2.0  # seconds
	bullet_holetimer.one_shot = true  
	bullet_holetimer.timeout.connect(bullet_hole.queue_free)
	get_tree().root.add_child(bullet_holetimer)
	bullet_holetimer.start()
	
@rpc 
func remote_set_position(authority_position):
	target_position = authority_position
	
@rpc 
func remote_set_rotation(authority_rotation):
	global_rotation = authority_rotation

@rpc ("any_peer")
func send_message(message):
	print(message)
