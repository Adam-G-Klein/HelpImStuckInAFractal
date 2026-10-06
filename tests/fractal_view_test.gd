extends "res://tests/test_case.gd"
## project/unproject round-trip, render-scale sizing, and that the view's shader
## material carries the compiled shader.


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var view: FractalView = load("res://src/fractal/fractal_view.tscn").instantiate()
	root.add_child(view)
	await frames(1)                                    # let _ready wire the SubViewport
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)   # stop filling the window so size sticks
	view.size = Vector2(1280, 800)                     # projection uses the Control's own size
	view.setup(params, cam)
	await frames(1)

	# the shader material is wired and compiled
	var names: Array = []
	for u in view.shader_uniform_names():
		names.append(String(u))
	check(names.has("eye") and names.has("box_half"), "view's shader declares the uniforms")

	# project then unproject round-trips a point in front of the camera
	var p := Vector3(0.5, 0.2, 0.1)   # near the origin, in view
	var px: Variant = view.project(p)
	check(px != null, "a point in front projects to a pixel")
	if px != null:
		var rel: Vector3 = p - cam.eye()
		var depth: float = rel.dot(cam.forward())
		var back: Vector3 = view.unproject(px, depth)
		check(back.is_equal_approx(p), "unproject(project(p)) == p (got %s)" % back)

	# a point behind the camera projects to null
	var behind: Vector3 = cam.eye() + cam.forward() * -5.0
	check(view.project(behind) == null, "a point behind the camera projects to null")

	# render scale sets the SubViewport size (rounded to whole pixels)
	view.set_render_scale(0.5)
	await frames(1)
	check_eq(view.viewport_size(), Vector2i(640, 400), "render_scale 0.5 halves the viewport")
	view.set_render_scale(2.0)   # clamps to 1.0
	await frames(1)
	check_eq(view.viewport_size(), Vector2i(1280, 800), "render_scale clamps to 1.0")

	view.queue_free()
	await frames(1)
