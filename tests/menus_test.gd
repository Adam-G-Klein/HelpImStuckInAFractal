extends "res://tests/test_case.gd"
## The main menu's layout and navigation, and the shared settings page.

const TMP := "user://menus_test_settings.cfg"


func run() -> void:
	var settings: Node = root.get_node("Settings")
	var original: float = settings.mouse_sensitivity
	settings.config_path = TMP

	check_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://src/ui/main_menu.tscn",
		"the game starts on the main menu")

	# Untyped: naming MainMenu here would compile it (and its use of the Settings
	# autoload) before the autoloads exist, which fails under -s.
	var menu = load("res://src/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await frames(1)

	var title := _find_label(menu, "Icebox Nav")
	check(title != null, "the title reads Icebox Nav")
	if title:
		check(title.get_theme_font_size("font_size") >= 64, "in big text")
	check_eq(menu.play_button.text, "Play Game", "Play Game button")
	check_eq(menu.settings_button.text, "Settings", "Settings button")
	check_eq(menu.quit_button.text, "Quit", "Quit button")
	check(not menu.settings_menu.visible, "settings start hidden")

	menu.settings_button.pressed.emit()
	check(menu.settings_menu.visible and not menu.play_button.is_visible_in_tree(),
		"Settings swaps the list for the settings page")
	menu.settings_menu.sens_slider.value = 0.2
	check_approx(settings.mouse_sensitivity, 0.2, "the slider sets the mouse sensitivity")
	settings.mouse_sensitivity = 0.15
	check_approx(menu.settings_menu.sens_slider.value, 0.15, "and follows outside changes")
	var tabs: TabContainer = menu.settings_menu.tabs
	check_eq(tabs.get_tab_count(), 2, "settings has two tabs")
	check_eq([tabs.get_tab_title(0), tabs.get_tab_title(1)], ["Controls", "Renderer"], "Controls and Renderer")
	check(tabs.is_tab_disabled(1), "with no view open, the Renderer tab is disabled")
	check(tabs.get_tab_tooltip(1) != "", "and says where to find it")
	await press_action("pause")
	check(not menu.settings_menu.visible and menu.play_button.is_visible_in_tree(),
		"Escape goes back to the list")
	menu.settings_button.pressed.emit()
	menu.settings_menu.back_button.pressed.emit()
	check(not menu.settings_menu.visible, "so does Back")

	menu.queue_free()
	await frames(1)
	settings.mouse_sensitivity = original
	await frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _find_label(node: Node, text: String) -> Label:
	for child in node.find_children("*", "Label", true, false):
		if child.text == text:
			return child
	return null
