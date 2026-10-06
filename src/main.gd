class_name Main
extends Node
## Wires the two resources into every child, selects the active camera from
## camera_mode, owns the mouse capture, and is the single mouse-event dispatcher.
## Also saves and loads views: WorkspaceFiles picks the file, Workspace does the
## reading and writing, and the panel shows the result.

var params: FractalParams
var camera: CameraState

@onready var view: FractalView = $FractalView
@onready var panel: ControlsPanel = $ControlsPanel
@onready var governor: ResolutionGovernor = $ResolutionGovernor
@onready var fly: FlyCamera = $FlyCamera

var _orbit: OrbitCamera
var _marker: JuliaMarker
var _last_mode := -1
var _files: WorkspaceFiles


func _ready() -> void:
	params = FractalParams.new()
	camera = CameraState.make_default()

	view.setup(params, camera)
	panel.setup(params, camera)
	governor.setup(params, view)
	fly.setup(params, camera)

	_orbit = get_node_or_null("OrbitCamera")
	if _orbit:
		_orbit.setup(params, camera, view)
	_marker = get_node_or_null("JuliaMarker")
	if _marker:
		_marker.setup(params, camera, view)

	_build_workspace_files()

	panel.visible = false
	params.changed.connect(_apply_mode)
	camera.changed.connect(func(): governor.mark_changed())
	_apply_mode()


func workspace_files() -> WorkspaceFiles:
	return _files


## The buttons and the quick-save key only choose a file; the saving and
## loading happen here, and the chosen file becomes current only if it worked.
func _build_workspace_files() -> void:
	_files = WorkspaceFiles.new()
	_files.name = "WorkspaceFiles"
	add_child(_files)
	_files.save_to.connect(save_view_to)
	_files.load_from.connect(load_view_from)
	_files.current_changed.connect(panel.show_file)
	_files.prompting.connect(_on_prompting)
	panel.save_button.pressed.connect(_files.prompt_save)
	panel.load_button.pressed.connect(_files.prompt_load)
	var directory := WorkspaceFiles.directory()
	if directory != WorkspaceFiles.REPO_DIR:
		_report("Saves go to %s: this build cannot write into the project." % directory)
	elif WorkspaceFiles.ensure_directory() != OK:
		_report("Could not create %s; the file panel opens at your home folder." % directory)


func save_view_to(path: String) -> void:
	var err := Workspace.save_file(path, params, camera)
	if err != OK:
		_report("Save failed (error %d): %s" % [err, path])
		return
	_files.note_saved(path)
	_report("Saved %s" % path.get_file())


func load_view_from(path: String) -> void:
	var result := Workspace.load_file(path, params, camera)
	var warnings: Array = result["warnings"]
	if not result["ok"]:
		_report("Load failed: %s" % warnings[0])
		return
	_files.note_loaded(path)
	# The camera moved after the mode was applied, so re-centre the orbit on it.
	if _orbit and params.camera_mode == FractalParams.CameraMode.ORBIT:
		_orbit.enter()
	if warnings.is_empty():
		_report("Loaded %s" % path.get_file())
	else:
		_report("Loaded %s with %d warning(s): %s" % [path.get_file(), warnings.size(), "; ".join(warnings)])


func _report(line: String) -> void:
	print(line)
	panel.show_status(line)


## A file panel is opening (possibly from Cmd+S with the mouse captured): free
## the mouse so the panel can be used.
func _on_prompting() -> void:
	panel.visible = true
	_update_mouse()


func _apply_mode() -> void:
	var is_fly := params.camera_mode == FractalParams.CameraMode.FLY
	fly.enabled = is_fly
	if _orbit:
		_orbit.enabled = not is_fly
		# enter() only when the mode actually changed, not on every slider move
		if not is_fly and params.camera_mode != _last_mode:
			_orbit.enter()
	_last_mode = params.camera_mode
	_update_mouse()


func _update_mouse() -> void:
	var capture := (params.camera_mode == FractalParams.CameraMode.FLY) and not panel.visible
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE)


func _active_camera() -> Node:
	return fly if params.camera_mode == FractalParams.CameraMode.FLY else _orbit


# The only mouse dispatcher: Q -> JuliaMarker -> active camera.
func _unhandled_input(event: InputEvent) -> void:
	# 1. Q toggles the panel (ignored while a panel text field has focus)
	if event.is_action_pressed("toggle_panel"):
		if panel.text_field_has_focus():
			return
		panel.visible = not panel.visible
		_update_mouse()
		get_viewport().set_input_as_handled()
		return

	# 2. Julia marker drag, only while the mouse is free
	if _marker and params.julia_enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _marker.begin_drag(event.position):
					get_viewport().set_input_as_handled()
					return
			else:
				_marker.end_drag()
		elif event is InputEventMouseMotion and _marker.is_dragging():
			_marker.update_drag(event.position)
			get_viewport().set_input_as_handled()
			return

	# 3. click outside the panel in FLY mode while free: hide panel, recapture.
	# (The panel consumes clicks inside itself, so a click reaching here is outside.)
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and params.camera_mode == FractalParams.CameraMode.FLY \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		panel.visible = false
		_update_mouse()
		get_viewport().set_input_as_handled()
		return

	# 4. the active camera handles the rest (look when captured, wheel, orbit drags)
	var cam_node := _active_camera()
	if cam_node and cam_node.handle_event(event):
		get_viewport().set_input_as_handled()
