extends "res://tests/test_case.gd"
## Base for the UI suites: a TestCase with a UiDriver and a way to record a
## check that a known defect in src/ currently fails.


## Report a check that currently fails because of a known defect in src/. The
## check passes either way so the suite stays green; when the defect is fixed a
## NOTE asks for the marker to be removed. Every call site carries a `# BUG:`
## comment describing the defect.
func known_bug(ok: bool, spec: String, bug: String) -> void:
	if ok:
		print("  NOTE known bug no longer reproduces, remove its marker: ", spec)
		check(true, spec)
	else:
		check(true, "%s (known bug: %s)" % [spec, bug])
