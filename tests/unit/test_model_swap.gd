extends GutTest
## A real .glb imports as a scene whose parts sit under extra nodes. The gun
## must find its parts by name anywhere under "Model" and zero itself.


func _glb_like_model() -> Node3D:
	# Re-nest the placeholder's parts like an imported glTF: Model/RootNode/<parts>.
	var src: Node3D = load("res://revolver/RevolverPlaceholder.tscn").instantiate()
	var model := Node3D.new()
	model.name = "Model"
	var root_node := Node3D.new()
	root_node.name = "RootNode"
	model.add_child(root_node)
	for n in src.find_children("*", "", true, false):
		n.owner = null
	for c in src.get_children():
		src.remove_child(c)
		root_node.add_child(c)
	src.free()
	return model


func test_parts_found_under_a_glb_style_hierarchy() -> void:
	var gun: Revolver = load("res://revolver/Revolver.tscn").instantiate()
	var old := gun.get_node("Model")
	gun.remove_child(old)
	old.free()
	gun.add_child(_glb_like_model())
	add_child_autofree(gun)
	gun.freeze = true
	for n in Revolver.PART_NAMES:
		assert_not_null(gun.part(n), n)
	assert_almost_eq(gun.bore_direction.angle_to(Vector3.FORWARD), 0.0, 0.001, "zeroed from its sight markers")
	gun.mechanism.cock()
	await wait_frames(30)
	assert_almost_eq(gun.part("Hammer").rotation_degrees.x, RevolverSpec.HAMMER_FULL_COCK_DEG, 1.0,
			"hammer animates on the swapped model")
