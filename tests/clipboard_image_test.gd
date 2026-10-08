extends "res://tests/test_case.gd"
## ClipboardImage picks a clipboard command per platform and refuses empty images.
## (It never runs the command here: a test must not overwrite the clipboard.)


func run() -> void:
	var mac := ClipboardImage.command_for("macOS", "/tmp/a'b.png", "/tmp/c.js")
	check_eq(mac[0], "osascript", "macOS uses osascript")
	check_eq(mac[1], ["-l", "JavaScript", "/tmp/c.js", "/tmp/a'b.png"], "running the script on the PNG")

	var win := ClipboardImage.command_for("Windows", "C:/a'b.png", "")
	check_eq(win[0], "powershell", "Windows uses PowerShell")
	check(String(win[1][-1]).contains("'C:/a''b.png'"), "with the PNG's path, quotes doubled")

	check_eq(ClipboardImage.command_for("Linux", "/tmp/a.png", "")[0], "xclip", "Linux uses xclip")
	check(ClipboardImage.command_for("Web", "/tmp/a.png", "").is_empty(), "an unknown platform has none")

	check_eq(ClipboardImage.copy(null), ERR_INVALID_DATA, "a null image is refused")
	check_eq(ClipboardImage.copy(Image.new()), ERR_INVALID_DATA, "an empty image is refused")

	check(InputMap.has_action(&"copy_screenshot"), "the copy_screenshot action exists")
