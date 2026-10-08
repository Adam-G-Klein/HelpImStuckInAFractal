class_name ResolutionGovernor
extends Node
## Owns FractalView.render_scale and its update mode. While the view is changing
## it adapts the scale to hold ~30 fps, never below the view's min_render_scale;
## when it stops it renders one full-scale frame and then freezes.

enum Mode { CONTINUOUS, FINAL_FRAME, IDLE }

const TARGET := 1.0 / 30.0
const EMA_ALPHA := 0.2
const STEP := 0.8               # scale multiplier per adjustment

var scale := 1.0
var mode := Mode.IDLE
var fast_controls := true
var min_scale := 0.25           # follows FractalParams.min_render_scale
var cooldown := 0.5             # seconds between scale changes; tests may lower it

var _params: FractalParams
var _view: FractalView
var _ema := TARGET
var _since_change := 0.5        # allow an adjustment on the first frame
var _idle_pending := false
var _dirty := false


func setup(params: FractalParams, view: FractalView) -> void:
	_params = params
	_view = view
	_follow_params()
	params.changed.connect(func(): _dirty = true; _follow_params())


func _follow_params() -> void:
	fast_controls = _params.fast_controls
	min_scale = _params.min_render_scale


func mark_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if _view == null:
		return
	var changing := _dirty
	_dirty = false
	step(delta, changing)
	_view.set_render_scale(scale)
	match mode:
		Mode.CONTINUOUS:
			_view.set_continuous(true)
		Mode.FINAL_FRAME:
			_view.set_continuous(false)
			_view.request_frame()
		Mode.IDLE:
			_view.set_continuous(false)


## Pure logic: update `scale` and `mode` from one frame's time and whether
## anything is changing. No side effects.
func step(frame_time: float, changing: bool) -> void:
	_since_change += frame_time
	scale = maxf(scale, min_scale)   # the floor may have been raised
	if changing:
		mode = Mode.CONTINUOUS
		_idle_pending = true
		if fast_controls:
			_ema = _ema * (1.0 - EMA_ALPHA) + frame_time * EMA_ALPHA
			if _since_change >= cooldown:
				if _ema > 1.2 * TARGET and scale > min_scale:
					scale = clampf(scale * STEP, min_scale, 1.0)
					_since_change = 0.0
				elif _ema < 0.6 * TARGET and scale < 1.0:
					scale = clampf(scale / STEP, min_scale, 1.0)
					_since_change = 0.0
		else:
			scale = 1.0
	elif _idle_pending:
		mode = Mode.FINAL_FRAME
		scale = 1.0
		_idle_pending = false
	else:
		mode = Mode.IDLE
