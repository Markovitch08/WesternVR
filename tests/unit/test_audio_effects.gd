extends GutTest
## Sound pooling and layering, recoil, muzzle flash and smoke.

const Rig := preload("res://tests/support/rig.gd")

var gun: Revolver
var right: HandGrabber


func before_each() -> void:
	gun = load("res://revolver/Revolver.tscn").instantiate()
	add_child_autofree(gun)
	gun.global_position = Vector3(0, 1.2, 0)
	gun.gravity_scale = 0.0
	var rig := Rig.make(self)
	autofree(rig["origin"])
	right = rig["right"]
	Rig.hold(right, gun)


func after_each() -> void:
	Bullets.clear()


func _fire() -> void:
	gun.mechanism.chambers.fill(RevolverMechanism.Chamber.LIVE)
	gun.mechanism.cock()
	gun.mechanism.set_trigger(1.0)
	gun.mechanism.set_trigger(0.0)


func test_every_sound_key_has_a_stream() -> void:
	for key in ProceduralSounds.KEYS:
		assert_not_null(SoundLibrary.pick(key), key)


func test_sound_pool_never_grows() -> void:
	var children := SoundPool.get_child_count()
	for i in 200:
		SoundPool.play("cylinder_click", Vector3.ZERO)
	assert_eq(SoundPool.get_child_count(), children, "no new nodes")
	assert_eq(SoundPool.player_count(), SoundPool.POOL_SIZE)
	assert_lte(SoundPool.playing_count(), SoundPool.POOL_SIZE)


func test_repeats_vary_in_pitch_and_volume() -> void:
	var pitches := {}
	var vols := {}
	for i in 10:
		var p := SoundPool.play("trigger_break", Vector3.ZERO, {"pitch_var": 0.04, "volume_var": 1.5})
		pitches[snappedf(p.pitch_scale, 0.0001)] = true
		vols[snappedf(p.volume_db, 0.001)] = true
		assert_between(p.pitch_scale, 0.96, 1.04)
		assert_between(p.volume_db, -1.5, 1.5)
	assert_gt(pitches.size(), 5)
	assert_gt(vols.size(), 5)


func test_delayed_sounds_play_later() -> void:
	var before := SoundPool.pending_count()
	SoundPool.play("shot_tail", Vector3.ZERO, {"delay": 0.1})
	assert_eq(SoundPool.pending_count(), before + 1)
	await wait_seconds(0.25)
	assert_eq(SoundPool.pending_count(), before)


func test_echo_delay_follows_distance_to_reflectors() -> void:
	var gun_pos := Vector3.ZERO
	var near := {"position": Vector3(0, 0, -30)}
	var far := {"position": Vector3(60, 0, -60)}
	var e := RevolverAudio.echoes(gun_pos, gun_pos, [near, far])
	assert_almost_eq(e[0]["delay"], 60.0 / 343.0, 0.001, "30 m wall: there and back")
	assert_almost_eq(e[1]["delay"], 2.0 * Vector3(60, 0, -60).length() / 343.0, 0.001)
	assert_gt(e[0]["gain_db"], e[1]["gain_db"], "nearer wall is louder")


func test_shot_is_layered_crack_boom_and_echo_tails() -> void:
	var wall := Node3D.new()
	wall.add_to_group(&"echo_reflector")
	add_child_autofree(wall)
	wall.global_position = Vector3(0, 2, -40)
	var playing_before := SoundPool.playing_count()
	var pending_before := SoundPool.pending_count()
	_fire()
	var streams := []
	for p in SoundPool.get_children():
		if p.playing and p.stream:
			streams.append(p.stream.resource_path.get_file())
	assert_has(streams, "shot_crack.wav", "close crack")
	assert_has(streams, "shot_boom.wav", "low boom")
	assert_eq(SoundPool.pending_count(), pending_before + 2, "one echo from the wall + the far tail")


func test_recoil_flips_the_muzzle_up_and_pushes_back_then_settles() -> void:
	await wait_physics_frames(20)
	var aim := gun.get_bore_direction()
	var pos := gun.global_position
	_fire()
	var max_flip := 0.0
	var max_back := 0.0
	for i in 12:
		await wait_physics_frames(1)
		var d := gun.get_bore_direction()
		max_flip = maxf(max_flip, rad_to_deg(d.angle_to(aim)) * signf(d.y - aim.y))
		max_back = maxf(max_back, (gun.global_position - pos).dot(-aim))
	assert_gt(max_flip, 10.0, "muzzle flips up")
	assert_lt(max_flip, 70.0, "but not out of the hand")
	assert_gt(max_back, 0.01, "pushed back")
	await wait_physics_frames(90)
	assert_lt(rad_to_deg(gun.get_bore_direction().angle_to(aim)), 2.0, "settles back on aim")
	assert_lt(gun.global_position.distance_to(pos), 0.01, "and back in the hand")


func test_muzzle_flash_light_and_smoke() -> void:
	var fx: MuzzleEffects = gun.get_node("MuzzleEffects")
	_fire()
	assert_true(fx._flash.visible, "flash")
	assert_true(fx._light.visible, "light")
	assert_true(fx._smoke.emitting, "smoke")
	assert_gt(fx._smoke.gravity.dot(Wind.velocity), 0.0, "smoke drifts downwind")
	await wait_seconds(0.15)
	assert_false(fx._flash.visible, "flash is brief")
	assert_false(fx._light.visible, "light is brief")


func test_no_case_is_ejected_by_firing() -> void:
	_fire()
	await wait_physics_frames(5)
	var cases := get_tree().root.find_children("*", "Cartridge", true, false)
	assert_eq(cases.size(), 0, "the SAA keeps its empties until you eject them")
