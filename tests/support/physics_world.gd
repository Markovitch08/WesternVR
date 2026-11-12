extends RefCounted
## Helpers to build small physics worlds inside GUT tests.


static func floor_box(parent: Node, top_y := 0.0, surface := &"dirt", size := Vector3(10, 0.2, 10), pos_xz := Vector2.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.set_meta(&"surface", surface)
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	sb.add_child(cs)
	parent.add_child(sb)
	sb.global_position = Vector3(pos_xz.x, top_y - size.y * 0.5, pos_xz.y)
	return sb


## Lowest Y of any collision shape of a body (from the shapes' surface vertices).
static func lowest_point(body: CollisionObject3D) -> float:
	var low := INF
	for c in body.get_children():
		if c is CollisionShape3D and c.shape:
			var mesh: ArrayMesh = c.shape.get_debug_mesh()
			for s in mesh.get_surface_count():
				for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					low = minf(low, (c.global_transform * v).y)
	return low
