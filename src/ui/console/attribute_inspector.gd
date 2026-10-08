class_name AttributeInspector
extends VBoxContainer
## The Shape pane: a scrolling list of group headings and one AttributeRow per
## spec, built once from the table. The inspector owns no state of its own: it
## shows the shape table, writes edits straight back into it, and forwards the
## per-frame resolved values to the rows so each can show what it is driving.
## Ported from Fractacular's AttributeInspector, simplified to one fixed table.

const SCROLLBAR_ALLOWANCE := 16.0

var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Dictionary = {}
var _table: AttributeTable
var _group_tooltips: Dictionary = {}
var _built := false


## Show the shape table, with the group heading tooltips. Call before adding it
## to the tree (or right after; it builds lazily).
func setup(table: AttributeTable, group_tooltips: Dictionary) -> void:
	_table = table
	_group_tooltips = group_tooltips
	_build()
	_populate()


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", 4)
	custom_minimum_size.x = AttributeRow.WIDE_ROW_MIN_WIDTH + SCROLLBAR_ALLOWANCE

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)


func _populate() -> void:
	if _table == null:
		return
	_rows.clear()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	var last_group := "￿"  # a value no real group can equal
	for spec in _table.specs:
		if spec.group != last_group:
			last_group = spec.group
			if spec.group != "":
				_list.add_child(_make_heading(spec.group, String(_group_tooltips.get(spec.group, spec.group))))
		var row := AttributeRow.new()
		row.setup(spec, _table)
		_list.add_child(row)
		_rows[spec.id] = row


## The axes available as binding sources: Array of {id, label}.
func set_sources(axis_list: Array) -> void:
	for id in _rows:
		(_rows[id] as AttributeRow).set_sources(axis_list)


## Feed one frame of resolved values (id -> value) to the rows.
func set_resolved(values: Dictionary) -> void:
	for id in _rows:
		(_rows[id] as AttributeRow).set_resolved(values.get(id))


func row_count() -> int:
	return _rows.size()


func row(id: StringName) -> AttributeRow:
	return _rows.get(id)


## Godot's default theme has no bold variant, so a heading is set apart by
## capitals, size and colour rather than weight.
func _make_heading(text: String, tooltip: String) -> Label:
	var heading := Label.new()
	heading.text = text.to_upper()
	heading.tooltip_text = tooltip
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0))
	return heading
