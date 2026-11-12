extends RefCounted
## Scene builders used by tools/build_scenes.gd. Every size is in metres.

const XRT := "res://addons/godot-xr-tools/"

var _errors := 0


func build_all() -> bool:
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
