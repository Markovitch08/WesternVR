class_name RevolverSpec
extends RefCounted
## Real dimensions of a Colt Single Action Army, 7.5" barrel, .45 Colt.
## Gun frame: metres, -Z = forward (down the bore), +Y = up, +X = right.
## Origin = on the bore axis, at the barrel breech (front face of the cylinder).

const MASS := 1.05                     # kg, unloaded
const BARREL_LENGTH := 0.1905          # 7.5 in, breech face to muzzle
const BARREL_RADIUS := 0.0088          # 0.69 in muzzle diameter
const CYLINDER_LENGTH := 0.0406        # 1.60 in
const CYLINDER_RADIUS := 0.0211        # 1.66 in diameter
const CYLINDER_AXIS_Y := -0.0135       # cylinder axis sits below the bore
const CHAMBER_RADIUS := 0.0135         # bore axis to cylinder axis = chamber circle radius
const CHAMBER_COUNT := 6
const CASE_RIM_RADIUS := 0.00645       # .45 Colt rim 0.512 in
const CASE_LENGTH := 0.0325            # 1.285 in
const CARTRIDGE_LENGTH := 0.0406       # 1.60 in overall
const BULLET_DIAMETER := 0.01148       # .452 in
const BULLET_MASS := 0.0165            # 255 grain
const POWDER_MASS := 0.0026            # 40 grain black powder
const MUZZLE_VELOCITY := 260.0         # m/s, black-powder load from a 7.5 in barrel
const ZERO_DISTANCE := 15.0            # m

const MUZZLE := Vector3(0, 0, -BARREL_LENGTH)
const CYLINDER_CENTER := Vector3(0, CYLINDER_AXIS_Y, CYLINDER_LENGTH * 0.5)
const SIGHT_REAR := Vector3(0, 0.0185, 0.060)   # bottom of the notch in the top strap
const SIGHT_FRONT_Z := -0.183                    # front blade, near the muzzle
const HAMMER_PIVOT := Vector3(0, -0.010, 0.064)
const TRIGGER_PIVOT := Vector3(0, -0.036, 0.040)
const GATE_PIVOT := Vector3(CHAMBER_RADIUS, CYLINDER_AXIS_Y - 0.008, 0.048)
const EJECTOR_PIVOT := Vector3(CHAMBER_RADIUS, CYLINDER_AXIS_Y, -0.012)
const GRIP_TOP := Vector3(0, -0.030, 0.070)
const GRIP_ANGLE_DEG := -30.0          # grip rakes back 30 degrees from vertical
const GRIP_LENGTH := 0.11
const CENTER_OF_MASS := Vector3(0, -0.018, -0.015)

# Animation angles (degrees) and travel (m)
const HAMMER_HALF_COCK_DEG := 22.0
const HAMMER_FULL_COCK_DEG := 48.0
const TRIGGER_PULL_DEG := -14.0
const GATE_OPEN_DEG := -95.0           # swings out to the right about the fore-aft axis
const EJECTOR_STROKE := 0.048
