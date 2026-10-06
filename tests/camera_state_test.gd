extends "res://tests/test_case.gd"


func run() -> void:
	var c := CameraState.make_default()

	# the site's default view
	check(c.eye().is_equal_approx(Vector3(8.175847, 3.812460, 3.283393)), "default eye")
	check(c.forward().is_equal_approx((Vector3.ZERO - c.eye()).normalized()),
		"forward looks at the origin")
	check_approx(c.forward().length(), 1.0, "forward is unit length")
	check_approx(c.right().dot(c.up()), 0.0, "right and up are orthogonal", 1e-5)
	check_approx(c.right().dot(c.forward()), 0.0, "right and forward are orthogonal", 1e-5)
	# +Z is the up hint: right stays horizontal
	check_approx(c.right().z, 0.0, "right is level (world +Z up hint)", 1e-5)
	check_approx(c.speed_factor, 1.0, "speed factor default")

	# setters emit changed
	var fired := [0]
	c.changed.connect(func(): fired[0] += 1)
	c.transform = Transform3D.IDENTITY
	c.speed_factor = 2.0
	check_eq(fired[0], 2, "both setters emitted changed")
	check(c.eye().is_equal_approx(Vector3.ZERO), "transform setter moved the eye")
