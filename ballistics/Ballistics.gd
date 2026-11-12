class_name Ballistics
extends RefCounted
## Exterior ballistics for slow, heavy pistol bullets: gravity plus quadratic
## air drag, integrated in short steps (no hitscan). Pure functions, so the
## same maths drives the bullets in game, the sight zero and the unit tests.

## Drag constant k = rho * Cd * A / (2 m), in 1/m. For a 255 gr .45 Colt
## round-nose bullet (Cd ~0.45 at ~Mach 0.76) this is ~1.7e-3: about 4%
## velocity lost over 25 m, matching published .45 Colt black-powder data.
const DRAG_K_45_COLT := 1.7e-3
## Air density (kg/m^3) and speed of sound (m/s), for reference and audio.
const SPEED_OF_SOUND := 343.0


static func gravity() -> Vector3:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var dir: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	return dir * g


static func drag_k(diameter: float, mass: float, cd: float, air_density := 1.2) -> float:
	var area := PI * diameter * diameter * 0.25
	return air_density * cd * area / (2.0 * mass)


## Acceleration of a bullet moving at [param vel].
static func acceleration(vel: Vector3, g: Vector3, k: float) -> Vector3:
	return g - vel * (k * vel.length())


## Advances a bullet by [param dt] seconds (midpoint / RK2).
## Returns [new_position, new_velocity].
static func step(pos: Vector3, vel: Vector3, dt: float, g: Vector3, k: float) -> Array:
	var a1 := acceleration(vel, g, k)
	var v_mid := vel + a1 * (dt * 0.5)
	var a2 := acceleration(v_mid, g, k)
	return [pos + v_mid * dt, vel + a2 * dt]


## Flies a bullet fired horizontally until it has travelled [param distance]
## metres down-range. Returns {drop (m, positive = below the bore line),
## velocity (m/s), time (s)}.
static func fly_level(distance: float, muzzle_velocity: float, k := DRAG_K_45_COLT,
		g := 9.8, dt := 1.0 / 720.0) -> Dictionary:
	var pos := Vector3.ZERO
	var vel := Vector3(0, 0, -muzzle_velocity)
	var gv := Vector3(0, -g, 0)
	var t := 0.0
	while -pos.z < distance and t < 10.0:
		var prev := pos
		var r := step(pos, vel, dt, gv, k)
		pos = r[0]
		vel = r[1]
		t += dt
		if -pos.z >= distance:
			# Interpolate back to exactly [distance].
			var f := (distance + prev.z) / (prev.z - pos.z)
			pos = prev.lerp(pos, f)
			t -= dt * (1.0 - f)
	return {"drop": -pos.y, "velocity": vel.length(), "time": t}


## Height of the bullet above the line of sight at [param distance] metres
## past the muzzle, when the bore is tilted [param bore_angle] radians above the
## line of sight. [param muzzle_below_los]: how far the bore is below the line
## of sight at the muzzle. The line of sight is level.
static func height_over_los(bore_angle: float, muzzle_below_los: float, distance: float,
		muzzle_velocity: float, k := DRAG_K_45_COLT, g := 9.8, dt := 1.0 / 720.0) -> float:
	var pos := Vector2(0.0, -muzzle_below_los) # x down-range, y up
	var vel := Vector2(cos(bore_angle), sin(bore_angle)) * muzzle_velocity
	var t := 0.0
	while pos.x < distance and t < 10.0:
		var prev := pos
		var r := step(Vector3(pos.x, pos.y, 0), Vector3(vel.x, vel.y, 0), dt, Vector3(0, -g, 0), k)
		pos = Vector2(r[0].x, r[0].y)
		vel = Vector2(r[1].x, r[1].y)
		t += dt
		if pos.x >= distance:
			return lerpf(prev.y, pos.y, (distance - prev.x) / (pos.x - prev.x))
	return pos.y


## Bore angle above the line of sight (rad) that makes the bullet meet the line
## of sight at [param zero_distance] metres past the muzzle.
static func zero_angle(muzzle_below_los: float, zero_distance: float, muzzle_velocity: float,
		k := DRAG_K_45_COLT, g := 9.8) -> float:
	var lo := -0.05
	var hi := 0.05
	for i in 50:
		var mid := (lo + hi) * 0.5
		if height_over_los(mid, muzzle_below_los, zero_distance, muzzle_velocity, k, g) < 0.0:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Bore direction (gun frame) that zeroes sights at [param rear] / [param front]
## for a muzzle at [param muzzle], all in the gun's local space (+Y up).
static func bore_direction_for_zero(muzzle: Vector3, rear: Vector3, front: Vector3,
		zero_distance: float, muzzle_velocity: float, k := DRAG_K_45_COLT, g := 9.8) -> Vector3:
	var los := (front - rear).normalized()
	var up := (Vector3.UP - los * los.dot(Vector3.UP)).normalized()
	var to_muzzle := muzzle - rear
	var below := -to_muzzle.dot(up)
	var angle := zero_angle(below, zero_distance, muzzle_velocity, k, g)
	return (los * cos(angle) + up * sin(angle)).normalized()


## Front sight blade top height (gun frame Y) that zeroes the sights at
## [param zero_distance] with the bore exactly along -Z (used to build the
## placeholder model). [param rear]: rear notch position; [param front_z]: Z of
## the front blade; [param muzzle]: muzzle position.
static func front_sight_height_for_zero(rear: Vector3, front_z: float, muzzle: Vector3,
		zero_distance: float, muzzle_velocity: float, k := DRAG_K_45_COLT, g := 9.8) -> float:
	var drop: float = fly_level(zero_distance, muzzle_velocity, k, g)["drop"]
	var target := Vector2(muzzle.z - zero_distance, muzzle.y - drop) # (z, y) where the LOS must pass
	var f := (front_z - rear.z) / (target.x - rear.z)
	return rear.y + (target.y - rear.y) * f


# --- Ricochets ----------------------------------------------------------------

## Grazing angle (degrees) between a velocity and a surface: 0 = skimming, 90 = head-on.
static func grazing_angle_deg(velocity: Vector3, normal: Vector3) -> float:
	return rad_to_deg(asin(clampf(-velocity.normalized().dot(normal.normalized()), -1.0, 1.0)))


## Chance (0..1) that a lead bullet glances off [param surface] at this angle.
## Only hard steel at shallow angles (under 20 degrees) ricochets.
static func ricochet_chance(surface: StringName, grazing_deg: float) -> float:
	if surface != &"metal" or grazing_deg >= 20.0 or grazing_deg < 0.0:
		return 0.0
	return lerpf(0.9, 0.3, grazing_deg / 20.0)


## Velocity after a ricochet: mirrored, slowed and scattered a little.
static func ricochet_velocity(velocity: Vector3, normal: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var out := velocity.bounce(normal.normalized()) * rng.randf_range(0.5, 0.7)
	var scatter := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.06
	out = (out.normalized() + scatter).normalized() * out.length()
	# Never back into the surface.
	if out.dot(normal) < 0.0:
		out -= normal * out.dot(normal) * 1.1
	return out
