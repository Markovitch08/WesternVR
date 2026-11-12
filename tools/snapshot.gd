extends Node3D
## Renders the revolver from a few angles to PNGs (geometry check without a
## headset). Needs a display (e.g. xvfb-run) and the Compatibility renderer:
##   xvfb-run godot --path . --xr-mode off --rendering-method gl_compatibility \
##       --rendering-driver opengl3 res://tools/Snapshot.tscn -- <out_dir>

const VIEWS := {
	"right": [Vector3(0.05, 0.02, -0.06), Vector3(0.42, 0.04, -0.06)],
	"left": [Vector3(0.0, 0.0, -0.06), Vector3(-0.42, 0.06, -0.04)],
	"rear_loading": [Vector3(0.01, -0.01, 0.03), Vector3(0.16, 0.06, 0.22)],
	# Eye on the sight line (rear notch -> front blade), 30 cm behind the gun.
	"shooter": [Vector3(0, 0.0185 - 2.06 * 0.0023, -2.0), Vector3(0, 0.0185 + 0.24 * 0.0023, 0.30)],
}


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://.tmp"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.82, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.near = 0.01
	add_child(cam)
	var gun: Revolver = load("res://revolver/Revolver.tscn").instantiate()
	add_child(gun)
	gun.freeze = true
	get_viewport().size = Vector2i(900, 600)
	for view in VIEWS:
		if view == "rear_loading":
			gun.mechanism.half_cock()
			gun.mechanism.open_gate()
		elif view == "shooter":
			gun.mechanism.lower_hammer()
			gun.mechanism.close_gate()
			gun.mechanism.cock()
		var v: Array = VIEWS[view]
		cam.global_position = v[1]
		cam.look_at(v[0], Vector3.UP)
		if view == "shooter":
			cam.fov = 12
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join("revolver_%s.png" % view))
		print("snapshot: ", out.path_join("revolver_%s.png" % view))
	get_tree().quit()
