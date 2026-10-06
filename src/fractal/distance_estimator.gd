class_name DistanceEstimator
extends RefCounted
## CPU copy of the shader's Mandelbox distance estimator (Tom Lowe's formula),
## N = 32 (the high-precision variant). Carries the scalar derivative in `dz`.
## Must give the same numbers as mandelbox.gdshader's `de(p, 32)`.
##
## The orbit runs in scalar `float` locals (GDScript floats are 64-bit) rather
## than Vector3 arithmetic: Vector3 components are 32-bit in a standard Godot
## build, and that lost input precision is amplified near the surface, throwing
## off the near-boundary fixtures. `estimate_at` keeps the coordinates 64-bit;
## `estimate(p: Vector3, …)` is the public API for callers that already hold a
## (32-bit) Vector3 camera position, where the precision loss is harmless.

const ITERATIONS := 32


static func estimate(p: Vector3, params: FractalParams) -> float:
	return estimate_at(p.x, p.y, p.z, params)


static func estimate_at(px: float, py: float, pz: float, params: FractalParams) -> float:
	var scale := params.scale
	var min_r2 := params.inner_radius * params.inner_radius
	var fixed_r2 := params.outer_radius * params.outer_radius
	var fold := params.fold_limit
	var julia := params.julia_enabled
	var cx := params.julia_point.x if julia else px
	var cy := params.julia_point.y if julia else py
	var cz := params.julia_point.z if julia else pz
	var zx := px
	var zy := py
	var zz := pz
	var dz := 1.0
	for i in ITERATIONS:
		# Box fold each component.
		zx = clampf(zx, -fold, fold) * 2.0 - zx
		zy = clampf(zy, -fold, fold) * 2.0 - zy
		zz = clampf(zz, -fold, fold) * 2.0 - zz
		# Sphere fold.
		var r2 := zx * zx + zy * zy + zz * zz
		var k := 1.0
		if r2 < min_r2:
			k = fixed_r2 / min_r2
		elif r2 < fixed_r2:
			k = fixed_r2 / r2
		zx *= k
		zy *= k
		zz *= k
		dz *= k
		# Scale and add.
		zx = scale * zx + cx
		zy = scale * zy + cy
		zz = scale * zz + cz
		dz = -dz * scale + 1.0
	return sqrt(zx * zx + zy * zy + zz * zz) / absf(dz)
