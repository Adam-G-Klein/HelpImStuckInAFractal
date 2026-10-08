class_name ClipboardImage
extends RefCounted
## Puts an image on the system clipboard. Godot 4.6 can read an image from the
## clipboard but not write one, so this writes a PNG to user:// and hands it to
## the platform's own clipboard tool (osascript, PowerShell or xclip).
##
## On macOS OS.execute runs the command through `sh -c`, wrapping each argument
## in double quotes without escaping any inside it, so an argument must not
## contain `"`, `$` or a backtick. Hence the macOS script lives in a file and
## its only arguments are paths.

const PNG_PATH := "user://clipboard_screenshot.png"
const SCRIPT_PATH := "user://clipboard_image.js"

## JavaScript for Automation: put the PNG file named by argv[0] on the clipboard.
const MAC_SCRIPT := """ObjC.import('AppKit');
function run(argv) {
	var pb = $.NSPasteboard.generalPasteboard;
	pb.clearContents;
	var data = $.NSData.dataWithContentsOfFile(argv[0]);
	if (data.isNil() || !pb.setDataForType(data, $.NSPasteboardTypePNG)) {
		throw new Error('could not copy ' + argv[0]);
	}
}
"""


## The command that copies the PNG at `png` to the clipboard on `os_name` (as
## OS.get_name() reports it), as [program, args]; [] when there is none.
## `script` is where the macOS script has been written.
static func command_for(os_name: String, png: String, script: String) -> Array:
	match os_name:
		"macOS":
			return ["osascript", ["-l", "JavaScript", script, png]]
		"Windows":
			return ["powershell", ["-NoProfile", "-STA", "-Command",
				"Add-Type -AssemblyName System.Windows.Forms, System.Drawing; " +
				"[System.Windows.Forms.Clipboard]::SetImage([System.Drawing.Image]::FromFile('%s'))"
				% png.replace("'", "''")]]
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return ["xclip", ["-selection", "clipboard", "-t", "image/png", "-i", png]]
	return []


## Copy `image` to the clipboard. Returns OK, or why it could not.
static func copy(image: Image) -> Error:
	if image == null or image.is_empty():
		return ERR_INVALID_DATA
	var png := ProjectSettings.globalize_path(PNG_PATH)
	var err := image.save_png(png)
	if err != OK:
		return err
	var script := ProjectSettings.globalize_path(SCRIPT_PATH)
	var cmd := command_for(OS.get_name(), png, script)
	if cmd.is_empty():
		return ERR_UNAVAILABLE
	if OS.get_name() == "macOS":
		var file := FileAccess.open(script, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(MAC_SCRIPT)
		file.close()
	return OK if OS.execute(cmd[0], cmd[1]) == 0 else FAILED
