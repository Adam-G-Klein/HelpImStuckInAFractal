extends "res://tests/test_case.gd"
## The shader compiles headless and declares exactly the spec's uniforms.
## (A shader that fails to compile yields an empty uniform list.)


func run() -> void:
	var sh: Shader = load("res://src/fractal/mandelbox.gdshader")
	check(sh != null, "the shader resource loads")
	var names: Array = []
	for u in sh.get_shader_uniform_list():
		names.append(String(u["name"]))
	check(names.size() > 0, "shader compiles (uniform list non-empty)")
	var expected := ["eye", "cam_right", "cam_up", "cam_forward", "tan_half_fov",
		"aspect", "scale", "min_r2", "fixed_r2", "fold_limit", "precision",
		"color_mode", "julia_enabled", "julia_point", "box_half",
		"detail_range", "detail_falloff", "near_dist", "coarse_steps", "fine_steps",
		"fog_dist", "fog_color"]
	check_eq(names.size(), expected.size(), "exactly %d uniforms" % expected.size())
	for u in expected:
		check(names.has(u), "uniform '%s' is declared" % u)
