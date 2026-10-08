extends "res://tests/test_case.gd"
## The Mandelbox shape catalogue: every spec has tooltip and effects, defaults
## in range, ids unique, every group has a heading, and the id set is the
## expected 23 catalogue ids.

const EXPECTED_IDS := [
	&"box_scale", &"fold_limit", &"min_radius", &"fixed_radius", &"fold_order", &"w",
	&"julia_all", &"julia_0", &"julia_1", &"julia_2", &"julia_3",
	&"c_0", &"c_1", &"c_2", &"c_3",
	&"iter_rot_xy", &"iter_rot_xz", &"iter_rot_xw", &"iter_rot_yz", &"iter_rot_yw", &"iter_rot_zw",
	&"color_mode", &"precision",
]


func run() -> void:
	var specs := MandelboxShape.specs()
	var tips := MandelboxShape.group_tooltips()

	check_eq(MandelboxShape.catalogue_ids(), EXPECTED_IDS, "the catalogue ids are the expected 23, in order")

	var seen := {}
	for s in specs:
		check(not seen.has(s.id), "id '%s' is unique" % s.id)
		seen[s.id] = true
		check(s.tooltip.strip_edges() != "", "'%s' has a tooltip" % s.id)
		check(s.effects.strip_edges() != "", "'%s' has effects text" % s.id)
		check(s.group != "", "'%s' has a group" % s.id)
		check(tips.has(s.group), "group '%s' has a heading tooltip" % s.group)
		if s.type == AttributeSpec.Type.FLOAT or s.type == AttributeSpec.Type.INT:
			var d := float(s.default_value)
			check(d >= s.hard_min - 1e-9 and d <= s.hard_max + 1e-9,
				"'%s' default %s is within [%s, %s]" % [s.id, d, s.hard_min, s.hard_max])

	# build a table and check specific specs
	var table := AttributeTable.new(specs)
	check_eq(table.get_default(&"box_scale"), -2.09, "box_scale default")
	var box_scale := table.spec(&"box_scale")
	check_eq(box_scale.hard_min, -6.0, "box_scale hard_min is -6")
	check_eq(box_scale.hard_max, 6.0, "box_scale hard_max is +6")
	check(box_scale.bindable, "box_scale is bindable")

	var color := table.spec(&"color_mode")
	check_eq(color.type, AttributeSpec.Type.ENUM, "color_mode is an enum")
	check(not color.bindable, "color_mode is not bindable")
	check_eq(color.enum_values, FractalParams.COLOR_MODE_IDS, "color_mode enum_values are the site ids")
	check_eq(table.get_default(&"color_mode"), 1, "color_mode default is Ice Fractal")

	var prec := table.spec(&"precision")
	check(prec.log_scale, "precision is logarithmic")

	var rot := table.spec(&"iter_rot_xy")
	check(rot.wrap, "iter_rot_xy wraps")

	var fold := table.spec(&"fold_order")
	check(not fold.bindable, "fold_order is not bindable")

	# the c_i rows are shown only when their toggle or julia_all is on
	var c0 := table.spec(&"c_0")
	check(not c0.is_shown({&"julia_all": false, &"julia_0": false}), "c_0 hidden with no Julia on")
	check(c0.is_shown({&"julia_all": false, &"julia_0": true}), "c_0 shown when julia_0 is on")
	check(c0.is_shown({&"julia_all": true, &"julia_0": false}), "c_0 shown when julia_all is on")
