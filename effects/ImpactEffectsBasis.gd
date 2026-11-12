class_name ImpactEffectsBasis
extends RefCounted
## Basis whose +Y axis points along [param n] (for emitters and decals).


static func y_to(n: Vector3) -> Basis:
	n = n.normalized()
	var side := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := side.cross(n).normalized()
	var z := x.cross(n).normalized()
	return Basis(x, n, z)
