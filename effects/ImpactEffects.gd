extends Node
## Autoload "Impacts". Bullet impact effects by surface: dust on dirt,
## splinters on wood, sparks on steel, grit on rock; plus a small decal.
## Particle emitters and decals are pooled so nothing piles up.

signal impact_spawned(info: Dictionary)

const MAX_DECALS := 40
const EMITTERS_PER_SURFACE := 4

var _decals: Array[Decal] = []
var _decal_textures := {}
var _pools := {}       # surface -> Array[CPUParticles3D]
var _pool_index := {}  # surface -> int


func spawn_impact(info: Dictionary) -> void:
	var surface: StringName = info.get("surface", Surface.DIRT)
	var pos: Vector3 = info["position"]
	var normal: Vector3 = info["normal"]
	_emit(surface, pos, normal)
	_play_hit_sound(surface, pos, info.get("ricochet", false))
	if not info.get("ricochet", false) or surface == Surface.METAL:
		_place_decal(info.get("collider"), surface, pos, normal)
	impact_spawned.emit(info)


func decal_count() -> int:
	_decals = _decals.filter(func(d): return is_instance_valid(d))
	return _decals.size()


func _play_hit_sound(surface: StringName, pos: Vector3, ricochet: bool) -> void:
	var pool := get_node_or_null(^"/root/SoundPool")
	if pool == null:
		return
	# Steel rings out far down range; dirt and wood thud nearby.
	var reach := 10.0 if surface == Surface.METAL else 4.0
	pool.play("hit_" + String(surface), pos, {"volume_db": 2.0, "unit_size": reach, "pitch_var": 0.06})
	if ricochet:
		pool.play("ricochet", pos, {"volume_db": 0.0, "unit_size": 6.0, "pitch_var": 0.15})


# --- Particles ----------------------------------------------------------------

func _emit(surface: StringName, pos: Vector3, normal: Vector3) -> void:
	if not _pools.has(surface):
		_pools[surface] = []
		_pool_index[surface] = 0
	var pool: Array = _pools[surface]
	var p: CPUParticles3D
	if pool.size() < EMITTERS_PER_SURFACE:
		p = _make_emitter(surface)
		add_child(p)
		pool.append(p)
	else:
		p = pool[_pool_index[surface]]
		_pool_index[surface] = (_pool_index[surface] + 1) % EMITTERS_PER_SURFACE
	p.global_transform = Transform3D(ImpactEffectsBasis.y_to(normal), pos + normal * 0.005)
	p.restart()
	p.emitting = true


func _make_emitter(surface: StringName) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector3.UP
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	var fade := Gradient.new()
	match surface:
		Surface.WOOD:
			# Splinters: little sticks flying out along their velocity.
			var stick := BoxMesh.new()
			stick.size = Vector3(0.002, 0.016, 0.002)
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.62, 0.45, 0.27)
			stick.material = wm
			p.mesh = stick
			p.particle_flag_align_y = true
			p.amount = 14
			p.lifetime = 0.9
			p.spread = 40.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -9.8, 0)
			p.angular_velocity_min = -720
			p.angular_velocity_max = 720
			return p
		Surface.METAL:
			# Sparks and a puff of lead.
			quad.size = Vector2(0.008, 0.008)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.65, 0.2)
			fade.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
			fade.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
			p.amount = 24
			p.lifetime = 0.35
			p.spread = 70.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 9.0
			p.gravity = Vector3(0, -9.8, 0)
		Surface.ROCK:
			quad.size = Vector2(0.05, 0.05)
			fade.set_color(0, Color(0.6, 0.58, 0.55, 0.7))
			fade.set_color(1, Color(0.6, 0.58, 0.55, 0.0))
			p.amount = 18
			p.lifetime = 0.9
			p.spread = 45.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.damping_min = 2.0
			p.damping_max = 4.0
			p.gravity = Vector3(0, -2.0, 0)
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.6
		_:
			# Dirt: a brown dust plume that hangs and spreads.
			quad.size = Vector2(0.09, 0.09)
			fade.set_color(0, Color(0.66, 0.53, 0.36, 0.75))
			fade.set_color(1, Color(0.7, 0.58, 0.42, 0.0))
			p.amount = 20
			p.lifetime = 1.4
			p.spread = 30.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.6
			p.damping_min = 2.0
			p.damping_max = 3.5
			p.gravity = Vector3(0, -0.6, 0)
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.8
	quad.material = m
	p.mesh = quad
	p.color_ramp = fade
	return p


# --- Decals -------------------------------------------------------------------

func _place_decal(collider: Object, surface: StringName, pos: Vector3, normal: Vector3) -> void:
	var parent: Node = collider as Node3D
	if parent == null:
		parent = self
	var d := Decal.new()
	var size := 0.035 if surface == Surface.METAL else 0.016
	d.size = Vector3(size, 0.03, size)
	d.texture_albedo = _decal_texture(surface)
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	parent.add_child(d)
	var basis := ImpactEffectsBasis.y_to(normal).rotated(normal.normalized(), randf() * TAU)
	d.global_transform = Transform3D(basis, pos)
	_decals.append(d)
	_decals = _decals.filter(func(x): return is_instance_valid(x))
	while _decals.size() > MAX_DECALS:
		var old: Decal = _decals.pop_front()
		old.queue_free()


func _decal_texture(surface: StringName) -> Texture2D:
	var key := &"metal" if surface == Surface.METAL else &"hole"
	if _decal_textures.has(key):
		return _decal_textures[key]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 45
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var c := Color(0, 0, 0, 0)
			if key == &"metal":
				# Lead splash: bright grey centre with ragged spokes; paint knocked off.
				var ang := atan2(y - n * 0.5, x - n * 0.5)
				var ragged := 0.55 + 0.25 * sin(ang * 7.0) * sin(ang * 3.0)
				if d < ragged:
					var v := lerpf(0.85, 0.55, d / ragged)
					c = Color(v, v, v * 1.02, 1.0)
			else:
				# Bullet hole: black core, torn darker ring.
				if d < 0.42:
					c = Color(0.02, 0.015, 0.01, 1.0)
				elif d < 0.9:
					var a := (1.0 - (d - 0.42) / 0.48) * rng.randf_range(0.5, 0.9)
					c = Color(0.12, 0.09, 0.06, a)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_decal_textures[key] = tex
	return tex
