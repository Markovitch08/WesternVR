extends RefCounted
## Scene builders used by tools/build_scenes.gd. Every size is in metres.

const XRT := "res://addons/godot-xr-tools/"

var _errors := 0


func build_all() -> bool:
	build_audio()
	build_revolver_placeholder()
	build_cartridge()
	build_revolver()
	build_ammo_box()
	build_range()
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
	# Slimmer than XR Tools' 0.2 m default so you can step up to the bench.
	body.set("player_radius", 0.12)

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
	add(main, gun, "Revolver", Vector3(-0.1, 0.935, 0.12))
	gun.rotation_degrees = Vector3(0, 80, 90)

	var box: Node3D = inst("res://ammo/AmmoBoxBody.tscn")
	add(main, box, "AmmoBox", Vector3(0.28, 0.91, 0.12))

	var player: Node3D = inst("res://player/Player.tscn")
	# Standing right at the bench (front edge at z = 0.3), facing down range (-Z).
	add(main, player, "Player", Vector3(0, 0, 0.42))

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
	# Top strap with the rear-sight groove along its top: the sight line runs
	# over the groove's edges (SightRear) and the front blade shows in the groove.
	var notch_depth := 0.003
	var groove := 0.0026
	var strap_top := S.SIGHT_REAR.y
	var base_h := 0.008 - notch_depth
	box_mesh(frame, "TopStrap", Vector3(0.016, base_h, 0.066), Vector3(0, strap_top - notch_depth - base_h * 0.5, 0.027), frame_mat)
	var rail_w := (0.016 - groove) * 0.5
	for side in [-1, 1]:
		box_mesh(frame, "TopStrapRail%s" % ("L" if side < 0 else "R"), Vector3(rail_w, notch_depth, 0.066),
				Vector3(side * (groove + rail_w) * 0.5, strap_top - notch_depth * 0.5, 0.027), frame_mat)
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
	body.set("impact_sound_prefix", "gun_land_")

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
	# The OpenXR grip pose's -Z runs up through the fist (little finger to
	# thumb), so the barrel must point ~45 deg below it, as XR Tools does for
	# its own pickups. Raise this angle to point the gun lower, lower it to
	# point the gun higher.
	var gp := Marker3D.new()
	add(body, gp, "GripPoint", S.GRIP_TOP + _grip_axis_down() * 0.045 + Vector3(0, 0, 0.004))
	gp.rotation_degrees = Vector3(45, 0, 0)

	var audio := Node.new()
	audio.set_script(load("res://revolver/RevolverAudio.gd"))
	add(body, audio, "Audio")
	var fx := Node3D.new()
	fx.set_script(load("res://effects/MuzzleEffects.gd"))
	add(body, fx, "MuzzleEffects")

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


# --------------------------------------------------------------------------
# Ammunition
# --------------------------------------------------------------------------

func build_cartridge() -> void:
	var S := RevolverSpec
	var brass := mat(Color(0.85, 0.66, 0.3), 0.3, 0.9)
	var lead := mat(Color(0.42, 0.42, 0.44), 0.55, 0.6)
	var body := RigidBody3D.new()
	body.name = "Cartridge"
	body.set_script(load("res://ammo/Cartridge.gd"))
	body.continuous_cd = true
	body.collision_layer = 1 << 2
	body.collision_mask = (1 << 0) | (1 << 1) | (1 << 2)
	body.physics_material_override = physics_material(0.35, 0.35)
	# Cartridge frame: -Z = bullet end (points down the chamber), origin = case middle.
	var model := pivot(body, "Model", Vector3.ZERO)
	z_cylinder(model, "Case", 0.00605, S.CASE_LENGTH, Vector3.ZERO, brass, 10)
	z_cylinder(model, "Rim", S.CASE_RIM_RADIUS, 0.0015, Vector3(0, 0, S.CASE_LENGTH * 0.5 - 0.00075), brass, 10)
	z_cylinder(model, "Primer", 0.0024, 0.0004, Vector3(0, 0, S.CASE_LENGTH * 0.5 + 0.0001), brass, 8)
	var bullet_len := S.CARTRIDGE_LENGTH - S.CASE_LENGTH
	var nose := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = S.BULLET_DIAMETER * 0.5
	sphere.height = bullet_len * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	sphere.is_hemisphere = true
	sphere.material = lead
	nose.mesh = sphere
	add(model, nose, "Bullet", Vector3(0, 0, -S.CASE_LENGTH * 0.5))
	nose.rotation_degrees = Vector3(-90, 0, 0)
	var cs := CollisionShape3D.new()
	cs.shape = _cyl_shape(S.CASE_RIM_RADIUS, S.CARTRIDGE_LENGTH)
	add(body, cs, "Shape")
	cs.rotation_degrees = Vector3(90, 0, 0)
	save(body, "res://ammo/Cartridge.tscn")


## A wooden box of cartridges with an open top and a grab zone.
func build_ammo_box() -> void:
	var S := RevolverSpec
	var wood := mat(Color(0.5, 0.36, 0.22))
	var body := StaticBody3D.new()
	body.name = "AmmoBoxBody"
	body.set_meta(&"surface", &"wood")
	body.collision_layer = 1
	var w := Vector3(0.14, 0.05, 0.09)
	var t := 0.006
	var walls := [
		["Bottom", Vector3(w.x, t, w.z), Vector3(0, t * 0.5, 0)],
		["Front", Vector3(w.x, w.y, t), Vector3(0, w.y * 0.5, -w.z * 0.5 + t * 0.5)],
		["Back", Vector3(w.x, w.y, t), Vector3(0, w.y * 0.5, w.z * 0.5 - t * 0.5)],
		["Left", Vector3(t, w.y, w.z), Vector3(-w.x * 0.5 + t * 0.5, w.y * 0.5, 0)],
		["Right", Vector3(t, w.y, w.z), Vector3(w.x * 0.5 - t * 0.5, w.y * 0.5, 0)],
	]
	for wl in walls:
		var cs := CollisionShape3D.new()
		cs.shape = _box_shape(wl[1])
		add(body, cs, wl[0] + "Shape", wl[2])
		box_mesh(body, wl[0], wl[1], wl[2], wood)
	# Rows of cartridges standing bullet-up (one MultiMesh: one draw call).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var round_mesh := CylinderMesh.new()
	round_mesh.top_radius = 0.0057
	round_mesh.bottom_radius = 0.00605
	round_mesh.height = S.CARTRIDGE_LENGTH
	round_mesh.radial_segments = 8
	round_mesh.rings = 1
	round_mesh.material = mat(Color(0.8, 0.62, 0.3), 0.35, 0.85)
	mm.mesh = round_mesh
	var cols := 9
	var rows := 6
	mm.instance_count = cols * rows
	for r in rows:
		for c in cols:
			var p := Vector3((c - (cols - 1) * 0.5) * 0.0135, t + S.CARTRIDGE_LENGTH * 0.5, (r - (rows - 1) * 0.5) * 0.0125)
			mm.set_instance_transform(r * cols + c, Transform3D(Basis.IDENTITY, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add(body, mmi, "Rounds")
	var zone := Area3D.new()
	zone.set_script(load("res://ammo/AmmoBox.gd"))
	zone.collision_layer = 1 << 18  # Grab Handles
	zone.collision_mask = 0
	zone.monitoring = false
	add(body, zone, "GrabZone", Vector3(0, w.y * 0.6, 0))
	var zcs := CollisionShape3D.new()
	zcs.shape = _box_shape(Vector3(w.x, w.y * 1.4, w.z))
	add(zone, zcs, "Shape")
	save(body, "res://ammo/AmmoBoxBody.tscn")


# --------------------------------------------------------------------------
# Audio: bus layout and baked placeholder sounds
# --------------------------------------------------------------------------

func build_audio() -> void:
	# Buses: Master (with a limiter so a shot can't clip) <- World (subtle reverb).
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)
	for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		AudioServer.remove_bus_effect(0, i)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "World")
	AudioServer.set_bus_send(1, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.55  # outdoors: small, quiet, mostly the ground and nearby bench
	reverb.damping = 0.6
	reverb.spread = 1.0
	reverb.hipass = 0.25
	reverb.predelay_msec = 35.0
	reverb.predelay_feedback = 0.15
	reverb.dry = 1.0
	reverb.wet = 0.1
	AudioServer.add_bus_effect(1, reverb)
	var layout := AudioServer.generate_bus_layout()
	if ResourceSaver.save(layout, "res://audio/default_bus_layout.tres") != OK:
		_errors += 1
	else:
		print("build_scenes: wrote res://audio/default_bus_layout.tres")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio/generated"))
	var made := 0
	for key in ProceduralSounds.KEYS:
		var path := "res://audio/generated/%s.wav" % key
		if FileAccess.file_exists(path):
			continue
		var err := ProceduralSounds.generate(key).save_to_wav(path)
		if err != OK:
			push_error("build_scenes: could not write %s" % path)
			_errors += 1
		made += 1
	print("build_scenes: baked %d placeholder sounds" % made)


# --------------------------------------------------------------------------
# Test range
# --------------------------------------------------------------------------

func build_range() -> void:
	var root := Node3D.new()
	root.name = "Range"
	root.set_script(load("res://range/Range.gd"))

	# Sky, sun and ambient: one directional shadow, nothing else expensive.
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.8)
	sky_mat.sky_horizon_color = Color(0.86, 0.8, 0.7)
	sky_mat.ground_horizon_color = Color(0.8, 0.7, 0.55)
	sky_mat.ground_bottom_color = Color(0.5, 0.4, 0.3)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add(root, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 25.0
	add(root, sun, "Sun")
	sun.rotation_degrees = Vector3(-52, -35, 0)

	# Materials (shared).
	var dirt_mat := mat(Color(0.78, 0.64, 0.45), 1.0)
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fnl := FastNoiseLite.new()
	fnl.frequency = 0.03
	noise.noise = fnl
	noise.color_ramp = Gradient.new()
	noise.color_ramp.set_color(0, Color(0.82, 0.8, 0.78))
	noise.color_ramp.set_color(1, Color(1, 1, 1))
	dirt_mat.albedo_texture = noise
	dirt_mat.uv1_scale = Vector3(60, 60, 60)
	var wood_mat := mat(Color(0.5, 0.35, 0.21), 0.85)
	var old_wood := mat(Color(0.42, 0.33, 0.25), 0.9)
	var steel_mat := mat(Color(0.55, 0.57, 0.6), 0.45, 0.85)
	var rock_mat := mat(Color(0.6, 0.45, 0.33), 0.95)
	var dirt_pm := physics_material(0.9, 0.05, true)
	var wood_pm := physics_material(0.6, 0.15)
	var steel_pm := physics_material(0.4, 0.3)
	var rock_pm := physics_material(0.8, 0.15)

	# Ground: one big flat slab.
	var ground := StaticBody3D.new()
	add(root, ground, "Ground")
	ground.set_meta(&"surface", &"dirt")
	ground.physics_material_override = dirt_pm
	var gcs := CollisionShape3D.new()
	gcs.shape = _box_shape(Vector3(300, 1, 300))
	add(ground, gcs, "Collision", Vector3(0, -0.5, 0))
	var gmi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	plane.material = dirt_mat
	gmi.mesh = plane
	add(ground, gmi, "Mesh")

	# Shooting bench: top 91 cm high, the player stands behind it at +Z.
	var bench := pivot(root, "Bench", Vector3.ZERO)
	static_box(bench, "Top", Vector3(1.4, 0.06, 0.6), Vector3(0, 0.88, 0), wood_mat, &"wood", wood_pm)
	for lx in [-0.62, 0.62]:
		for lz in [-0.24, 0.24]:
			static_box(bench, "Leg_%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(0.07, 0.85, 0.07),
					Vector3(lx, 0.425, lz), wood_mat, &"wood", wood_pm)

	# Wooden posts.
	var posts := pivot(root, "Posts", Vector3.ZERO)
	var post_spots := [Vector3(-1.2, 0, -5), Vector3(1.0, 0, -8), Vector3(-0.6, 0, -13), Vector3(1.6, 0, -20)]
	for i in post_spots.size():
		var ps: Vector3 = post_spots[i]
		static_box(posts, "Post%d" % i, Vector3(0.12, 1.3, 0.12), ps + Vector3(0, 0.65, 0), old_wood, &"wood", wood_pm)

	# Steel plates hanging from wooden frames; they swing when hit.
	var plates := pivot(root, "SteelPlates", Vector3.ZERO)
	var plate_spots := [Vector3(0.4, 0, -7), Vector3(-1.4, 0, -12), Vector3(0.9, 0, -15), Vector3(-0.3, 0, -18), Vector3(1.8, 0, -25)]
	for i in plate_spots.size():
		_steel_plate(plates, i, plate_spots[i], old_wood, steel_mat, wood_pm, steel_pm)

	# Distance signs.
	for d in [5, 10, 15, 20, 25]:
		var l := Label3D.new()
		l.text = "%d m" % d
		l.font_size = 64
		l.pixel_size = 0.004
		l.modulate = Color(0.25, 0.15, 0.08)
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add(root, l, "Sign%dm" % d, Vector3(-2.6, 0.25, -d))

	# Rock wall behind the targets: stops bullets and throws back the echo.
	var wall := pivot(root, "RockWall", Vector3(0, 0, -40))
	var blocks := [
		[Vector3(14, 7, 4), Vector3(-9, 3.5, 0), 6.0],
		[Vector3(12, 9, 5), Vector3(3, 4.5, -1), -4.0],
		[Vector3(10, 6, 4), Vector3(13, 3, 1), 12.0],
		[Vector3(6, 4, 3), Vector3(-2, 2, 2.5), -15.0],
	]
	for bi in blocks.size():
		var b: Array = blocks[bi]
		var sb := static_box(wall, "Rock%d" % bi, b[0], b[1], rock_mat, &"rock", rock_pm)
		sb.rotation_degrees = Vector3(0, b[2], 3.0 * (bi % 2 * 2 - 1))
	_reflector(wall, "Echo", Vector3(0, 4, 2.5), 0.0)

	# A false-front building off to the left: the second echo.
	var bld := pivot(root, "Building", Vector3(-18, 0, -12))
	bld.rotation_degrees = Vector3(0, 70, 0)
	static_box(bld, "Body", Vector3(8, 4.5, 6), Vector3(0, 2.25, 0), old_wood, &"wood", wood_pm)
	static_box(bld, "FalseFront", Vector3(8.4, 2.2, 0.2), Vector3(0, 5.6, 3.1), wood_mat, &"wood", wood_pm)
	static_box(bld, "Porch", Vector3(8.4, 0.2, 2.2), Vector3(0, 0.1, 4.1), wood_mat, &"wood", wood_pm)
	_reflector(bld, "Echo", Vector3(0, 3, 3.3), -3.0)

	save(root, "res://range/Range.tscn")


func _reflector(parent: Node3D, name: String, pos: Vector3, reflectivity_db: float) -> void:
	var m := Marker3D.new()
	add(parent, m, name, pos)
	m.add_to_group(&"echo_reflector", true)
	m.set_meta(&"reflectivity_db", reflectivity_db)


func _steel_plate(parent: Node3D, i: int, at: Vector3, wood: Material, steel: Material,
		wood_pm: PhysicsMaterial, steel_pm: PhysicsMaterial) -> void:
	var frame := pivot(parent, "Stand%d" % i, at)
	var span := 0.6
	var bar_h := 1.45
	for side in [-1, 1]:
		static_box(frame, "Leg%s" % ("L" if side < 0 else "R"), Vector3(0.08, bar_h, 0.08),
				Vector3(side * span * 0.5, bar_h * 0.5, 0), wood, &"wood", wood_pm)
	var bar := static_box(frame, "Bar", Vector3(span + 0.08, 0.08, 0.08), Vector3(0, bar_h, 0), wood, &"wood", wood_pm)
	# 10 mm AR500-style plate, 25 x 35 cm, ~6.9 kg, hung 18 cm below the bar.
	var size := Vector3(0.25, 0.35, 0.01)
	var plate := RigidBody3D.new()
	add(frame, plate, "Plate%d" % i, Vector3(0, bar_h - 0.18 - size.y * 0.5, 0))
	plate.mass = 7850.0 * size.x * size.y * size.z
	plate.set_meta(&"surface", &"metal")
	plate.physics_material_override = steel_pm
	plate.collision_layer = 1 << 1  # Dynamic World
	plate.collision_mask = (1 << 0) | (1 << 1) | (1 << 2)
	plate.angular_damp = 0.4
	var pcs := CollisionShape3D.new()
	pcs.shape = _box_shape(size)
	add(plate, pcs, "Collision")
	box_mesh(plate, "Mesh", size, Vector3.ZERO, steel)
	# Chains (visual) and a hinge along X at the bar.
	box_mesh(frame, "Chains%d" % i, Vector3(0.18, 0.18, 0.006), Vector3(0, bar_h - 0.09, 0), mat(Color(0.2, 0.2, 0.2), 0.7, 0.8))
	var hinge := HingeJoint3D.new()
	add(frame, hinge, "Hinge%d" % i, Vector3(0, bar_h, 0))
	hinge.rotation_degrees = Vector3(0, 90, 0) # hinge axis (joint Z) along world X
	hinge.node_a = hinge.get_path_to(bar)
	hinge.node_b = hinge.get_path_to(plate)
