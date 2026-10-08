class_name Clock
extends Node
## The global clock: `t`, seconds since the Main scene opened. A binding to the
## &"time" source reads it. It advances in _process; the tree pause pauses it
## (the node inherits the default pausable process mode). It is not saved.

var t: float = 0.0


func _process(delta: float) -> void:
	t += delta


## For loads and tests that want a known clock.
func reset() -> void:
	t = 0.0
