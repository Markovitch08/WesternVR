extends RefCounted
## Scene builders used by tools/build_scenes.gd. Every size is in metres.

const XRT := "res://addons/godot-xr-tools/"

var _errors := 0


func build_all() -> bool:
	build_revolver_placeholder()
	build_revolver()
	build_player()
	build_main()
	return _errors == 0


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func save(root: Node, path: String) -> void:
	for c in root.get_children():
		_own(c, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("build_scenes: failed to save %s (%s)" % [path, error_string(err)])
		_errors += 1
	else:
		print("build_scenes: wrote ", path)
	root.free()


func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	if node.scene_file_path != "":
		return # Instanced sub-scene: keep it as a reference.
	for c in node.get_children():
		_own(c, owner)


## Instantiates a sub-scene so that property overrides are saved with it.
static func inst(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)


static func mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func add(parent: Node, child: Node, name: String, pos := Vector3.ZERO) -> Node:
	child.name = name
	parent.add_child(child)
	if child is Node3D:
		child.position = pos
	return child


static func box_mesh(parent: Node, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = material
	mi.mesh = bm
	return add(parent, mi, name, pos)


## A cylinder mesh whose axis runs along Z (the bore direction).
static func z_cylinder(parent: Node, name: String, radius: float, length: float, pos: Vector3,
		material: Material, sides := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = sides
	cm.rings = 1
	cm.material = material
	mi.mesh = cm
	add(parent, mi, name, pos)
	mi.rotation_degrees = Vector3(90, 0, 0)
	return mi


static func pivot(parent: Node, name: String, pos: Vector3) -> Node3D:
	return add(parent, Node3D.new(), name, pos)


static func physics_material(friction: float, bounce: float, rough := false) -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = bounce
	pm.rough = rough
	return pm


## A static box with matching visual mesh, tagged with a surface type.
static func static_box(parent: Node, name: String, size: Vector3, pos: Vector3, material: Material,
		surface: StringName, pmat: PhysicsMaterial) -> StaticBody3D:
	var sb := StaticBody3D.new()
	add(parent, sb, name, pos)
	sb.physics_material_override = pmat
	sb.set_meta(&"surface", surface)
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	add(sb, cs, "Collision")
	box_mesh(sb, "Mesh", size, Vector3.ZERO, material)
	return sb


# --------------------------------------------------------------------------
# Player rig
# --------------------------------------------------------------------------

func build_player() -> void:
	var origin := XROrigin3D.new()
	origin.name = "Player"
	origin.set_script(load("res://player/Player.gd"))

	var cam := XRCamera3D.new()
	cam.near = 0.02
	cam.far = 400.0
	add(origin, cam, "XRCamera3D", Vector3(0, 1.7, 0))

	for side in ["Left", "Right"]:
		var lower: String = side.to_lower()
		var ctrl := XRController3D.new()
		ctrl.tracker = StringName(lower + "_hand")
		ctrl.pose = &"grip"
		ctrl.show_when_tracked = true
		add(origin, ctrl, side + "Hand", Vector3(-0.25 if side == "Left" else 0.25, 1.1, -0.35))

		# XR Tools collision hand: follows the controller but collides with the world.
		var coll: Node3D = inst(XRT + "hands/scenes/collision/collision_hand_%s.tscn" % lower)
		add(ctrl, coll, "CollisionHand")
		var hand: Node3D = inst(XRT + "hands/scenes/lowpoly/%s_hand_low.tscn" % lower)
		add(coll, hand, side + "HandModel")

		var grabber_script := load("res://interaction/HandGrabber.gd") if ResourceLoader.exists("res://interaction/HandGrabber.gd") else null
		if grabber_script:
			var grabber := Node3D.new()
			grabber.set_script(grabber_script)
			add(ctrl, grabber, "HandGrabber")

		if side == "Right":
			# Turning on the right thumbstick. Default: 30 degree snap turn.
			# Set turn_mode to SMOOTH (2) for smooth turning.
			var turn: Node = inst(XRT + "functions/movement_turn.tscn")
			add(ctrl, turn, "MovementTurn")
			turn.set("turn_mode", 1)
			turn.set("step_turn_angle", 30.0)
			turn.set("smooth_turn_speed", 2.5)

	var body: Node = inst(XRT + "player/player_body.tscn")
	add(origin, body, "PlayerBody")

	save(origin, "res://player/Player.tscn")


# --------------------------------------------------------------------------
# Main scene
# --------------------------------------------------------------------------

func build_main() -> void:
	var main := Node3D.new()
	main.name = "Main"

	var start_xr: Node = inst(XRT + "xr/start_xr.tscn")
	add(main, start_xr, "StartXR")

	var guard := Node.new()
	guard.set_script(load("res://player/FrameRateGuard.gd"))
	add(main, guard, "FrameRateGuard")
	guard.set("start_xr", start_xr)

	var range_path := "res://range/Range.tscn"
	if ResourceLoader.exists(range_path):
		add(main, inst(range_path), "Range")
	else:
		_build_temp_world(main)

	# The revolver lies on the bench, right side up.
	var gun: Node3D = inst("res://revolver/Revolver.tscn")
	add(main, gun, "Revolver", Vector3(-0.1, 0.935, -0.05))
	gun.rotation_degrees = Vector3(0, 80, 90)

	var player: Node3D = inst("res://player/Player.tscn")
	# Standing behind the bench, facing down-range (-Z).
	add(main, player, "Player", Vector3(0, 0, 0.55))

	save(main, "res://main/Main.tscn")


## Flat ground, a sun and a bench, used until the test range exists.
func _build_temp_world(main: Node3D) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.8, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.75, 0.7)
	add(main, env, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add(main, sun, "Sun")
	static_box(main, "Ground", Vector3(40, 0.2, 40), Vector3(0, -0.1, 0),
			mat(Color(0.76, 0.62, 0.42)), &"dirt", physics_material(0.9, 0.05, true))
	static_box(main, "Bench", Vector3(1.4, 0.06, 0.6), Vector3(0, 0.88, 0),
			mat(Color(0.45, 0.3, 0.18)), &"wood", physics_material(0.6, 0.15))


# --------------------------------------------------------------------------
# Revolver: placeholder model (visual only, separately pivoted parts)
# --------------------------------------------------------------------------

func build_revolver_placeholder() -> void:
	var S := RevolverSpec
	var blued := mat(Color(0.12, 0.13, 0.16), 0.32, 0.9)
	var frame_mat := mat(Color(0.33, 0.29, 0.25), 0.4, 0.85) # case-hardened colours
	var walnut := mat(Color(0.33, 0.17, 0.08), 0.55)
	var dark := mat(Color(0.03, 0.03, 0.03), 0.9)

	var root := Node3D.new()
	root.name = "RevolverModel"

	# Frame: top strap, front, bottom, recoil shield, trigger guard. Static.
	var frame := pivot(root, "Frame", Vector3.ZERO)
	box_mesh(frame, "TopStrap", Vector3(0.016, 0.008, 0.066), Vector3(0, 0.0145, 0.027), frame_mat)
	box_mesh(frame, "FrameFront", Vector3(0.026, 0.036, 0.012), Vector3(0, -0.011, -0.006), frame_mat)
	box_mesh(frame, "FrameBottom", Vector3(0.022, 0.010, 0.050), Vector3(0, -0.039, 0.022), frame_mat)
	# Recoil shield behind the cylinder, with a gap on the right for the loading gate.
	box_mesh(frame, "RecoilShieldLeft", Vector3(0.0295, 0.052, 0.014), Vector3(-0.00725, -0.012, 0.0485), frame_mat)
	box_mesh(frame, "RecoilShieldRightTop", Vector3(0.0145, 0.019, 0.014), Vector3(0.01475, 0.0045, 0.0485), frame_mat)
	box_mesh(frame, "RecoilShieldRightLow", Vector3(0.0145, 0.016, 0.014), Vector3(0.01475, -0.030, 0.0485), frame_mat)
	box_mesh(frame, "Backstrap", Vector3(0.020, 0.032, 0.018), Vector3(0, -0.016, 0.066), frame_mat)
	z_cylinder(frame, "CylinderPin", 0.0035, 0.012, Vector3(0, S.CYLINDER_AXIS_Y, -0.006), blued, 8)
	var guard := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.0115
	torus.outer_radius = 0.0145
	torus.rings = 16
	torus.ring_segments = 6
	torus.material = mat(Color(0.7, 0.55, 0.25), 0.35, 0.9) # brass guard
	guard.mesh = torus
	add(frame, guard, "TriggerGuard", Vector3(0, -0.052, 0.040))
	guard.rotation_degrees = Vector3(0, 0, 90)

	# Barrel with ejector housing on its right side. Static.
	var barrel := pivot(root, "Barrel", Vector3.ZERO)
	z_cylinder(barrel, "Tube", S.BARREL_RADIUS, S.BARREL_LENGTH, Vector3(0, 0, -S.BARREL_LENGTH * 0.5), blued)
	z_cylinder(barrel, "Bore", 0.0058, 0.002, Vector3(0, 0, -S.BARREL_LENGTH - 0.0005), dark, 10)
	z_cylinder(barrel, "EjectorHousing", 0.0055, 0.115, Vector3(S.CHAMBER_RADIUS, S.CYLINDER_AXIS_Y, -0.0715), blued, 10)

	# Cylinder: rotates about Z on its own axis.
	var cyl := pivot(root, "Cylinder", S.CYLINDER_CENTER)
	z_cylinder(cyl, "Body", S.CYLINDER_RADIUS, S.CYLINDER_LENGTH, Vector3.ZERO, blued, 18)
	for i in S.CHAMBER_COUNT:
		var a := deg_to_rad(60.0 * i)
		var p := Vector3(sin(a), cos(a), 0) * S.CHAMBER_RADIUS
		z_cylinder(cyl, "Flute%d" % i, 0.0052, S.CYLINDER_LENGTH + 0.0004, p + Vector3(0, 0, 0), dark, 8)

	# Hammer: pivots about X at its base. Rotates backward to cock.
	var hammer := pivot(root, "Hammer", S.HAMMER_PIVOT)
	box_mesh(hammer, "Body", Vector3(0.008, 0.032, 0.009), Vector3(0, 0.015, 0), frame_mat)
	box_mesh(hammer, "Spur", Vector3(0.010, 0.006, 0.020), Vector3(0, 0.031, 0.010), frame_mat)

	# Trigger: pivots about X; pulled, its blade swings back.
	var trigger := pivot(root, "Trigger", S.TRIGGER_PIVOT)
	box_mesh(trigger, "Blade", Vector3(0.004, 0.020, 0.005), Vector3(0, -0.010, 0.001), blued)

	# Loading gate: right side of the recoil shield, hinged on a fore-aft axis
	# at its bottom edge; opens outward to the right.
	var gate := pivot(root, "LoadingGate", S.GATE_PIVOT)
	box_mesh(gate, "Plate", Vector3(0.012, 0.016, 0.013), Vector3(0, 0.008, 0), frame_mat)

	# Ejector rod: slides back (+Z) through the chamber at the gate.
	var rod := pivot(root, "EjectorRod", S.EJECTOR_PIVOT)
	z_cylinder(rod, "Rod", 0.0022, 0.11, Vector3(0, 0, -0.055), blued, 8)
	box_mesh(rod, "Head", Vector3(0.006, 0.006, 0.010), Vector3(0.006, -0.002, -0.095), blued)

	# Grip: walnut panels on a raked backstrap.
	var grip := pivot(root, "Grip", S.GRIP_TOP)
	grip.rotation_degrees = Vector3(S.GRIP_ANGLE_DEG, 0, 0)
	box_mesh(grip, "Panels", Vector3(0.032, S.GRIP_LENGTH, 0.034), Vector3(0, -S.GRIP_LENGTH * 0.5, 0.002), walnut)

	# Sights and muzzle markers.
	var muzzle := Marker3D.new()
	add(root, muzzle, "Muzzle", S.MUZZLE)
	var rear := Marker3D.new()
	add(root, rear, "SightRear", S.SIGHT_REAR)
	var front_top := front_sight_height()
	var front := Marker3D.new()
	add(root, front, "SightFront", Vector3(0, front_top, S.SIGHT_FRONT_Z))
	var blade_h := front_top - S.BARREL_RADIUS + 0.001
	box_mesh(front, "Blade", Vector3(0.0025, blade_h, 0.012), Vector3(0, -blade_h * 0.5, 0), blued)

	save(root, "res://revolver/RevolverPlaceholder.tscn")


## Height of the front blade top (gun frame) that zeroes the sights at
## RevolverSpec.ZERO_DISTANCE with the bore exactly along -Z.
func front_sight_height() -> float:
	var S := RevolverSpec
	var BallisticsScript = load("res://ballistics/Ballistics.gd") if ResourceLoader.exists("res://ballistics/Ballistics.gd") else null
	if BallisticsScript == null:
		return 0.0175
	return BallisticsScript.front_sight_height_for_zero(S.SIGHT_REAR, S.SIGHT_FRONT_Z, S.MUZZLE,
			S.ZERO_DISTANCE, S.MUZZLE_VELOCITY)


# --------------------------------------------------------------------------
# Revolver: physical body
# --------------------------------------------------------------------------

func build_revolver() -> void:
	var S := RevolverSpec
	var body := RigidBody3D.new()
	body.name = "Revolver"
	body.set_script(load("res://revolver/Revolver.gd"))
	body.mass = S.MASS
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = S.CENTER_OF_MASS
	body.continuous_cd = true
	body.collision_layer = 1 << 2   # Pickable Objects
	body.collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 19) # world, dynamic, pickables, player body
	body.physics_material_override = physics_material(0.45, 0.18) # blued steel / walnut
	body.set("surface", &"metal")

	# Visual model: swap this instance for a real .glb with the same part names.
	add(body, inst("res://revolver/RevolverPlaceholder.tscn"), "Model")

	# Compound collision from convex primitives matching the real gun.
	var shapes := [
		["BarrelShape", _cyl_shape(S.BARREL_RADIUS + 0.0007, S.BARREL_LENGTH), Vector3(0, 0, -S.BARREL_LENGTH * 0.5), Vector3(90, 0, 0)],
		["EjectorShape", _box_shape(Vector3(0.011, 0.011, 0.115)), Vector3(S.CHAMBER_RADIUS, S.CYLINDER_AXIS_Y, -0.0715), Vector3.ZERO],
		["CylinderShape", _cyl_shape(S.CYLINDER_RADIUS, S.CYLINDER_LENGTH), S.CYLINDER_CENTER, Vector3(90, 0, 0)],
		["FrameShape", _box_shape(Vector3(0.030, 0.064, 0.040)), Vector3(0, -0.010, 0.058), Vector3.ZERO],
		["TriggerGuardShape", _box_shape(Vector3(0.016, 0.032, 0.046)), Vector3(0, -0.048, 0.040), Vector3.ZERO],
		["GripShape", _box_shape(Vector3(0.032, S.GRIP_LENGTH, 0.036)), S.GRIP_TOP + _grip_axis_down() * S.GRIP_LENGTH * 0.5, Vector3(S.GRIP_ANGLE_DEG, 0, 0)],
	]
	for sh in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = sh[1]
		add(body, cs, sh[0], sh[2])
		cs.rotation_degrees = sh[3]

	# Where the controller's grip pose sits when holding the gun properly.
	# Pitch it to change how the gun sits in the hand.
	var gp := Marker3D.new()
	add(body, gp, "GripPoint", S.GRIP_TOP + _grip_axis_down() * 0.045 + Vector3(0, 0, 0.004))
	gp.rotation_degrees = Vector3(-15, 0, 0)

	save(body, "res://revolver/Revolver.tscn")


static func _grip_axis_down() -> Vector3:
	var a := deg_to_rad(RevolverSpec.GRIP_ANGLE_DEG)
	# The grip's local -Y axis after rotating about X by the grip angle.
	return Vector3(0, -cos(a), -sin(a))


static func _cyl_shape(radius: float, height: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	return c


static func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b
