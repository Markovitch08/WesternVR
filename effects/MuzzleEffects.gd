class_name MuzzleEffects
extends Node3D
## Muzzle flash (a brief star of fire + a light) and a black-powder smoke cloud
## that drifts with the wind. Lives as child "MuzzleEffects" of the Revolver.

@export var flash_time := 0.045
@export var light_energy := 6.0
@export var light_time := 0.07
@export var smoke_amount := 36

var gun: Revolver
var _flash: MeshInstance3D
var _light: OmniLight3D
var _smoke: CPUParticles3D
var _gap_smoke: CPUParticles3D
var _flash_left := 0.0
var _light_left := 0.0


func _ready() -> void:
	gun = get_parent() as Revolver
	_build()
	if gun:
		gun.mechanism_event.connect(func(n, _d): if n == &"fired": fire())


func fire() -> void:
	var muzzle := gun.get_muzzle_position()
	var dir := gun.get_bore_direction()
	var basis := Basis.looking_at(dir, gun.global_basis.y)
	_flash.global_transform = Transform3D(basis.rotated(dir, randf() * TAU), muzzle + dir * 0.05)
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.2)
	_flash.visible = true
	_flash_left = flash_time
	_light.global_position = muzzle + dir * 0.15
	_light.light_energy = light_energy
	_light.visible = true
	_light_left = light_time
	_emit(_smoke, muzzle + dir * 0.03, dir)
	# A smaller puff from the gap between cylinder and barrel.
	_emit(_gap_smoke, gun.global_transform * Vector3(0, -0.005, 0.0), gun.global_basis.x)
	_smoke.gravity = Wind.velocity * 0.9 + Vector3.UP * 0.25
	_gap_smoke.gravity = _smoke.gravity


func _emit(p: CPUParticles3D, pos: Vector3, dir: Vector3) -> void:
	p.global_transform = Transform3D(ImpactEffectsBasis.y_to(dir), pos)
	p.restart()
	p.emitting = true


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
	if _light_left > 0.0:
		_light_left -= delta
		_light.light_energy = light_energy * maxf(_light_left / light_time, 0.0)
		if _light_left <= 0.0:
			_light.visible = false


func _build() -> void:
	# Flash: three crossed quads with a procedural star texture, additive.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _flash_texture()
	m.albedo_color = Color(1.0, 0.75, 0.4)
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var rot := Basis(Vector3.FORWARD, PI / 3.0 * k)
		var w := 0.07
		var front := -0.16 # flame reaches ~16 cm out of a black-powder muzzle
		var corners := [Vector3(-w, 0, 0.02), Vector3(w, 0, 0.02), Vector3(w, 0, front), Vector3(-w, 0, front)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(rot * corners[idx])
	am = st.commit()
	_flash = MeshInstance3D.new()
	_flash.mesh = am
	_flash.material_override = m
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.top_level = true
	_flash.visible = false
	add_child(_flash)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_light.top_level = true
	_light.visible = false
	add_child(_light)

	_smoke = _make_smoke(smoke_amount, 0.09, 3.0, 2.5, 7.0)
	_gap_smoke = _make_smoke(8, 0.05, 1.6, 0.6, 1.5)


func _make_smoke(amount: int, size: float, lifetime: float, v_min: float, v_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.damping_min = 5.0
	p.damping_max = 7.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 3.5))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.84, 0.8, 0.55))
	fade.set_color(1, Color(0.85, 0.84, 0.8, 0.0))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _soft_dot()
	q.material = m
	p.mesh = q
	add_child(p)
	return p


static var _dot_tex: Texture2D
static var _flash_tex: Texture2D


static func _soft_dot() -> Texture2D:
	if _dot_tex:
		return _dot_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


static func _flash_texture() -> Texture2D:
	if _flash_tex:
		return _flash_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0     # across the flame
			var v := (y + 0.5) / n                 # 0 = tip, 1 = muzzle
			var width := lerpf(0.05, 0.8, v * v)
			var a := clampf(1.0 - absf(u) / width, 0.0, 1.0) * clampf(v * 1.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, lerpf(0.5, 0.95, a), lerpf(0.2, 0.7, a), a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex
