extends Area3D

func get_random_position_within_area() -> Vector3:

	var collision_shape = get_node_or_null("CollisionShape3D")
	
	if collision_shape == null or collision_shape.shape == null:
		push_error("CollisionShape3D oder Shape ist null!")
		return Vector3.ZERO
		
	var shape = collision_shape.shape
	var aabb: AABB
	if shape is BoxShape3D:
		var half_extents = (shape as BoxShape3D).size * 0.5
		aabb = AABB(-half_extents, shape.size)
	else:
		return Vector3.ZERO
		
	# Transformiere lokale AABB in den globalen Raum
	var global_position = global_transform.origin
	var global_aabb = AABB(
		global_position + aabb.position,
		aabb.size
	)

	# Generiere eine zufällige Position innerhalb der globalen AABB
	var random_position: Vector3 = Vector3(
		randf_range(global_aabb.position.x, global_aabb.position.x + global_aabb.size.x),
		randf_range(global_aabb.position.y, global_aabb.position.y + global_aabb.size.y),
		randf_range(global_aabb.position.z, global_aabb.position.z + global_aabb.size.z)
	)

	# Optional: Stelle sicher, dass die Position innerhalb der tatsächlichen Form liegt
	#if not is_point_inside(random_position):
		#return get_random_position_within_area()  # Rekursiver Aufruf bei ungültiger Position

	return random_position

# Überprüft, ob ein Punkt innerhalb der Area3D liegt
func is_point_inside(point: Vector3) -> bool:
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape == null or collision_shape.shape == null:
		return false

	return collision_shape.shape.intersects_point(
		point - global_transform.origin,
		Transform3D()
	)
