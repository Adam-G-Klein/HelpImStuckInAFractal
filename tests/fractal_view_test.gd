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

	# the load-shed level pushes fog, cheaper detail and a smaller step budget;
	# level 0 pushes exactly the view's own values
	var mat := view._material
	check_eq(view.load_level, 0, "the view starts at full quality")
	check_eq(float(mat.get_shader_parameter("fog_dist")), 0.0, "no fog at level 0")
	var base_prec: float = mat.get_shader_parameter("precision")
	var base_coarse: int = mat.get_shader_parameter("coarse_steps")
	view.set_load_level(3)
	var l3 := LoadShedder.settings(3)
	check_approx(mat.get_shader_parameter("fog_dist"), l3["fog"], "level 3 pushes its fog distance")
	check_approx(mat.get_shader_parameter("precision"), base_prec / l3["detail"],
		"level 3 coarsens the precision by its detail factor", 1e-12)
	check(int(mat.get_shader_parameter("coarse_steps")) < base_coarse, "level 3 shrinks the step budget")
	check(Vector3(mat.get_shader_parameter("fog_color")).is_equal_approx(params.fog_color()),
		"the fog takes the colour mode's tint")
	params.color_mode = 14
	check(Vector3(mat.get_shader_parameter("fog_color")).is_equal_approx(params.fog_color()),
		"and follows the colour mode")
	params.max_steps = FractalParams.MAX_STEPS_MIN
	check_eq(int(mat.get_shader_parameter("coarse_steps")) + int(mat.get_shader_parameter("fine_steps")),
		FractalParams.MAX_STEPS_MIN, "the shed budget never drops below MAX_STEPS_MIN")
	params.max_steps = 128
	view.set_load_level(0)
	check_eq(float(mat.get_shader_parameter("fog_dist")), 0.0, "back to level 0: no fog")
	check_approx(mat.get_shader_parameter("precision"), base_prec, "and the original precision", 1e-12)
	check_eq(int(mat.get_shader_parameter("coarse_steps")), base_coarse, "and the original budget")

	view.queue_free()
	await frames(1)
