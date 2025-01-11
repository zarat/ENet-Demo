extends CharacterBody3D

# onready variables
@onready var collision_shape = $CollisionShape3D 
@onready var head = $Head
@onready var guncamera = $Head/SubViewportContainer/SubViewport/WeaponCamera

var spawnarea
var viewportcontainer

# variables
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 3.0  
var jump_speed = 4.0
var mouse_sensitivity = 0.002  
var vertical_angle = 0.0 
var is_running = false
var is_paused = false
var main_camera
var health = 100

func _ready():
	
	# display our name
	name = str(get_multiplayer_authority())
	$Name.text = str(name)
	
	# deactivate weaponcamera on non-authoritative players
	get_node("Head/SubViewportContainer/SubViewport/WeaponCamera").current = false
	
	if is_multiplayer_authority():
		head.visible = true
		main_camera = get_tree().root.get_node("Main/Camera3D")
		main_camera.reparent(head)
		#main_camera.position = head.position
		main_camera.global_transform = head.global_transform
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		spawnarea = get_tree().root.get_node("Main/Area3D")
		viewportcontainer = get_node("Head/SubViewportContainer")
		viewportcontainer.reparent(main_camera)
		take_damage(0)

	var area = get_tree().root.get_node("Main/Area3D")
	if area:
		var random_position = area.get_random_position_within_area()
		position = random_position
	print(str(position))
	
func _process(delta):
	if is_multiplayer_authority():
		get_input()
		guncamera.global_transform = head.global_transform

func _physics_process(delta):
	if is_multiplayer_authority():
		velocity.y += -gravity * delta
		move_and_slide()
		rpc("remote_set_position", global_position)

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
		
	if is_paused:
		return
		
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

func _unhandled_input(event):
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
	
	#var query = PhysicsRayQueryParameters3D.create(head.global_position, head.global_position - head.global_transform.basis.z * 50)
	var center = get_viewport().get_size()/2
	var o = main_camera.project_ray_origin(center)
	var e = o + main_camera.project_ray_normal(center) * 100
	
	var query = PhysicsRayQueryParameters3D.create(o, e)
	
	var collision = space.intersect_ray(query)
	if collision:

		print("You hit " +collision.collider.name + " at a length of ", collision.position.distance_to(o))
		
		if collision.collider.has_method("take_damage"):
			collision.collider.take_damage(int(30 - collision.position.distance_to(o)))
			
		#var hit_position = collision.position
		#var hit_normal = collision.normal
		#var hit_collider = collision.collider

		var linemesh = ImmediateMesh.new()
		linemesh.surface_begin(Mesh.PRIMITIVE_LINES)
		linemesh.surface_add_vertex(o)
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
		
		rpc("_shoot", o, collision)
		
	else:
		
		var linemesh = ImmediateMesh.new()
		linemesh.surface_begin(Mesh.PRIMITIVE_LINES)
		linemesh.surface_add_vertex(o)
		linemesh.surface_add_vertex(e)
		linemesh.surface_end()
		
		var line = MeshInstance3D.new()
		line.mesh = linemesh
		line.material_override = StandardMaterial3D.new()
		line.material_override.albedo_color = Color(1, 0, 0)  # Grün
		get_tree().root.add_child(line)
		
		var linetimer = Timer.new()
		linetimer.wait_time = 3  # seconds
		linetimer.one_shot = true  
		linetimer.timeout.connect(line.queue_free)
		get_tree().root.add_child(linetimer)
		linetimer.start()
		
		rpc("_shoot", o, e)

func align_with_normal(xform, normal):
	xform.basis.y = normal
	xform.basis.x = -xform.basis.z.cross(normal)
	xform.basis = xform.basis.orthonormalized()
	return xform

func _on_mouse_click_area_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		rpc("clicked_by_player")

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
	#_take_damage.rpc(amount)
	rpc("_take_damage", amount)
	
@rpc ("any_peer")
func _take_damage(amount):
	health -= amount
	if health <= 0:
		var area = get_tree().root.get_node("Main/Area3D")
		if area:
			var random_position = area.get_random_position_within_area()
			position = random_position
			print(str(position))
		health = 100
	$Message.text = str(health)
	
@rpc
func _shoot(root, target):
	
	# only print a line and a bullethole
	var linemesh = ImmediateMesh.new()
	linemesh.surface_begin(Mesh.PRIMITIVE_LINES)
	linemesh.surface_add_vertex(root)
	linemesh.surface_add_vertex(target.position)
	linemesh.surface_end()
		
	var line = MeshInstance3D.new()
	line.mesh = linemesh
	line.material_override = StandardMaterial3D.new()
	line.material_override.albedo_color = Color(0, 1, 0)  # Grün
	get_tree().root.add_child(line)

	var linetimer = Timer.new()
	linetimer.wait_time = 2.0  # seconds
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
	
# deprecated
@rpc 
func remote_set_position(authority_position):
	global_position = authority_position

@rpc 
func display_message(message):
	$Message.text = str(message)

@rpc 
func clicked_by_player():
	$Message.text = str(multiplayer.get_remote_sender_id()) + " clicked on me!"

@rpc
func change_scene_for_all(new_scene_path):
	get_tree().change_scene_to_file(new_scene_path)
	
@rpc
func spawn_player(peer_id: int, position: Vector3):
	var player_scene = preload("res://prefabs/player/player.tscn")
	var player_instance = player_scene.instantiate()
	player_instance.set_multiplayer_authority(peer_id)
	player_instance.global_position = position
	add_child(player_instance)
	
