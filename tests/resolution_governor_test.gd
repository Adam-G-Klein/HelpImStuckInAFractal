extends "res://tests/test_case.gd"
## Pure step() logic on fabricated frame times. Target is 1/30 s.


func run() -> void:
	var slow := 0.1       # 100 ms  >> 1.2 * (1/30) = 40 ms
	var fast := 0.001     # 1 ms    <  0.6 * (1/30) = 20 ms

	# --- slow frames lower the scale, but at most once per 0.5 s ---
	var g := ResolutionGovernor.new()
	g.fast_controls = true
	g.step(slow, true)                       # first slow frame: adjusts
	check_eq(g.mode, ResolutionGovernor.Mode.CONTINUOUS, "changing => CONTINUOUS")
	check(g.scale < 1.0, "a slow frame lowered the scale")
	var after_one := g.scale
	g.step(slow, true)                       # within 0.5 s: no second change
	check_approx(g.scale, after_one, "not lowered twice within 0.5 s", 1e-6)
	# with the cooldown removed, sustained slow frames walk down to the floor
	g.cooldown = 0.0
	for i in 15: g.step(slow, true)
	check_approx(g.scale, 0.25, "sustained slow frames reach the 0.25 floor", 1e-6)

	# --- fast frames raise it again, never above 1.0 ---
	for i in 40: g.step(fast, true)
	check_approx(g.scale, 1.0, "sustained fast frames reach the 1.0 ceiling", 1e-6)

	# --- stopping: one FINAL_FRAME at scale 1, then IDLE ---
	g.step(0.016, true)                      # something is changing
	g.step(0.016, false)                     # first still frame
	check_eq(g.mode, ResolutionGovernor.Mode.FINAL_FRAME, "first still frame is FINAL_FRAME")
	check_approx(g.scale, 1.0, "final frame renders at full scale", 1e-6)
	g.step(0.016, false)                     # next still frame
	check_eq(g.mode, ResolutionGovernor.Mode.IDLE, "then it goes IDLE")

	# --- Fast Controls off: scale stays 1.0, same mode logic ---
	var h := ResolutionGovernor.new()
	h.fast_controls = false
	for i in 10: h.step(slow, true)
	check_approx(h.scale, 1.0, "fast controls off keeps scale at 1.0", 1e-6)
	check_eq(h.mode, ResolutionGovernor.Mode.CONTINUOUS, "still CONTINUOUS while changing")
	h.step(slow, false)
	check_eq(h.mode, ResolutionGovernor.Mode.FINAL_FRAME, "one final frame with fast off")
	h.step(slow, false)
	check_eq(h.mode, ResolutionGovernor.Mode.IDLE, "then idle with fast off")
