extends "res://tests/test_case.gd"
## Pins the CPU estimator to the site's own numbers (24 fixtures), plus symmetry
## and Julia-sensitivity. The fixtures pin the 64-bit scalar core `estimate_at`
## (passing coordinates as `float`, not a 32-bit `Vector3`), so every row holds
## the spec's tolerance: relative 1e-5, or absolute 1e-9 below 1e-6.


func _de(px: float, py: float, pz: float, params: FractalParams, expected: float, label: String) -> void:
	var got := DistanceEstimator.estimate_at(px, py, pz, params)
	var tol := maxf(1e-9, 1e-5 * absf(expected))
	check(absf(got - expected) <= tol,
		"%s: expected %s got %s (tol %s)" % [label, expected, got, tol])


func run() -> void:
	# --- defaults: scale -2.09, inner 0.7, fold 1, outer 1, no Julia ---
	var d := FractalParams.new()
	_de(0, 0, 0, d, 0.0, "def (0,0,0)")
	_de(0.5, 0.5, 0.5, d, 1.67e-15, "def (0.5,0.5,0.5)")
	_de(1.2, -0.3, 0.8, d, 4.536385e-5, "def (1.2,-0.3,0.8)")
	_de(2, 2, 2, d, 1.84e-20, "def (2,2,2)")
	_de(3, 0, 0, d, 1.0000000, "def (3,0,0)")
	_de(8.18, 3.81, 3.28, d, 6.5655845, "def (8.18,3.81,3.28)")
	_de(0.1, 0.9, 1.5, d, 1.2707534e-5, "def (0.1,0.9,1.5)")
	_de(-1.5, 1.5, -1.5, d, 7.2696999e-3, "def (-1.5,1.5,-1.5)")

	# --- alternative shape: scale -3, inner 0.5, fold 0.8, outer 0.9 ---
	var a := FractalParams.new()
	a.scale = -3.0; a.inner_radius = 0.5; a.fold_limit = 0.8; a.outer_radius = 0.9
	_de(0, 0, 0, a, 0.0, "alt (0,0,0)")
	_de(0.5, 0.5, 0.5, a, 3.9589733e-3, "alt (0.5,0.5,0.5)")
	_de(1.2, -0.3, 0.8, a, 7.3684211e-2, "alt (1.2,-0.3,0.8)")
	_de(2, 2, 2, a, 0.69282032, "alt (2,2,2)")
	_de(3, 0, 0, a, 1.4000000, "alt (3,0,0)")
	_de(8.18, 3.81, 3.28, a, 7.1416315, "alt (8.18,3.81,3.28)")
	_de(0.1, 0.9, 1.5, a, 1.2998357e-2, "alt (0.1,0.9,1.5)")
	_de(-1.5, 1.5, -1.5, a, 3.5649260e-3, "alt (-1.5,1.5,-1.5)")

	# --- defaults with Julia on at (-0.23, 1.512, 1.892) ---
	var j := FractalParams.new()
	j.julia_enabled = true
	_de(0, 0, 0, j, 4.9979908e-3, "jul (0,0,0)")
	_de(0.5, 0.5, 0.5, j, 1.0887837e-2, "jul (0.5,0.5,0.5)")
	_de(1.2, -0.3, 0.8, j, 4.5308936e-3, "jul (1.2,-0.3,0.8)")
	_de(2, 2, 2, j, 4.9979908e-3, "jul (2,2,2)")
	_de(3, 0, 0, j, 8.0696204e-3, "jul (3,0,0)")
	_de(8.18, 3.81, 3.28, j, 2.3521820, "jul (8.18,3.81,3.28)")
	_de(0.1, 0.9, 1.5, j, 3.6647735e-3, "jul (0.1,0.9,1.5)")
	_de(-1.5, 1.5, -1.5, j, 0.25217396, "jul (-1.5,1.5,-1.5)")

	# --- symmetry: D(p) == D(-p) in non-Julia mode ---
	for p in [Vector3(0.7, 0.3, 0.9), Vector3(1.2, -0.3, 0.8), Vector3(3, 0, 0),
			Vector3(8.18, 3.81, 3.28)]:
		check_approx(DistanceEstimator.estimate(p, d), DistanceEstimator.estimate(-p, d),
			"D(p) == D(-p) at %s" % p, 1e-9)

	# --- the Julia point changes the result ---
	check(absf(DistanceEstimator.estimate(Vector3(3, 0, 0), d)
			- DistanceEstimator.estimate(Vector3(3, 0, 0), j)) > 0.5,
		"turning Julia on changes the distance")

	# --- the public Vector3 API delegates to the core ---
	check_approx(DistanceEstimator.estimate(Vector3(3, 0, 0), d),
		DistanceEstimator.estimate_at(3.0, 0.0, 0.0, d), "estimate() == estimate_at()", 1e-6)
