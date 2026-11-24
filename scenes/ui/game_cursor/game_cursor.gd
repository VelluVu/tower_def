class_name GameCursor
extends Node

## The game's own mouse cursor (2026-11-24, the user's ask): a pixel art cursor that changes with what the player is
## doing and animates. Anything can ask for a mode through UISignals.cursor_mode_requested(source, mode), and asks for
## POINTER to let go; the strongest request wins (Mode order). Over the game's own UI it stays a pointer, unless the
## player is grabbing. Every button shows a pointing claw (its cursor shape is set to the pointing hand as it enters
## the tree). The arrow darkens while a mouse button is held. It is the hardware cursor (no lag), its frames scaled to
## the window's whole pixel scale. Sheet: tools/art/cursors.py. Made by Main; runs while paused.

## Weakest first: a later mode wins over an earlier one. New modes at the end, with a sheet row.
enum Mode { POINTER, BUILD, TARGET, INVALID, GRAB }

const SHEET : Texture2D = preload("res://assets/art/ui/cursors/cursors.png")
## 20 px: the shapes are 16 px ones moved 1 px in, with room for their outline and the halo round it, so the cursor
## shows on every ground (2026-11-24, the user: it must not get lost in the level or map colours).
const CELL : int = 20
## Per mode (the sheet's row): each frame's seconds. The pointer holds still and glints now and then.
const FRAME_SECONDS : Array[Array] = [
	[3.5, 0.06, 0.06, 0.06],
	[0.22, 0.22, 0.22, 0.22],
	[0.12, 0.12, 0.12, 0.12],
	[0.3, 0.3],
	#the grab claw follows the mouse button, not the clock
	[0.0, 0.0],
]
## Never step a frame shorter than this (a zero duration would loop forever).
const MIN_FRAME_SECONDS : float = 0.02
const HOTSPOTS : Array[Vector2] = [Vector2(2, 2), Vector2(2, 2), Vector2(8, 8), Vector2(8, 8), Vector2(8, 8)]
## The grab claw grips while a mouse button is held, and shows open otherwise.
const GRAB_OPEN_FRAME : int = 0
const GRAB_GRIP_FRAME : int = 1
## The pointing claw over buttons (row 5: open, pressed) and the pressed arrow (row 6).
const POINTING_ROW : int = 5
const POINTING_HOTSPOT : Vector2 = Vector2(6, 2)
const PRESSED_ROW : int = 6
const BASE_SIZE : Vector2 = Vector2(640, 360)

var requests : Dictionary[StringName, Mode] = {}
var is_cursor_on_gui : bool = false
var pixel_scale : int = 0
#scaled frames, rebuilt when the window's scale changes: sheet row -> frames
var frames : Dictionary[int, Array] = {}
var shown_mode : int = -1
var shown_frame : int = -1
var shown_pressed : bool = false
var pointing_pressed : int = -1
var frame : int = 0
var frame_time : float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UISignals.cursor_mode_requested.connect(_on_cursor_mode_requested)
	UISignals.mouse_on_gui.connect(_on_mouse_on_gui)
	GameSignals.level_loaded.connect(_on_level_changed)
	UISignals.to_menu.connect(func(_to_main : bool, _from : String) -> void: _clear())
	get_window().size_changed.connect(_rebuild)
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(node)
	_rebuild()


## The mode on show: the strongest request, a pointer over the UI or while a menu pauses the game.
func current_mode() -> Mode:
	var mode : Mode = Mode.POINTER
	for source in requests:
		mode = maxi(mode, requests[source]) as Mode
	if mode != Mode.GRAB and (is_cursor_on_gui or get_tree().paused):
		return Mode.POINTER
	return mode


func _process(delta : float) -> void:
	var mode : Mode = current_mode()
	var is_pressed : bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	if mode != shown_mode:
		frame = 0
		frame_time = 0.0
	if mode == Mode.GRAB:
		frame = GRAB_GRIP_FRAME if is_pressed else GRAB_OPEN_FRAME
	else:
		frame_time += delta
		var durations : Array = FRAME_SECONDS[mode]
		if durations.size() > 1:
			while frame_time >= maxf(durations[frame], MIN_FRAME_SECONDS):
				frame_time -= maxf(durations[frame], MIN_FRAME_SECONDS)
				frame = (frame + 1) % durations.size()
	var pressed_arrow : bool = mode == Mode.POINTER and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mode != shown_mode or frame != shown_frame or pressed_arrow != shown_pressed:
		_show(mode, frame, pressed_arrow)
	_show_pointing(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func _show(mode : int, frame_index : int, pressed_arrow : bool) -> void:
	shown_mode = mode
	shown_frame = frame_index
	shown_pressed = pressed_arrow
	var row : int = PRESSED_ROW if pressed_arrow else mode
	var row_frames : Array = frames.get(row, [])
	var index : int = 0 if pressed_arrow else frame_index
	if index >= row_frames.size():
		return
	Input.set_custom_mouse_cursor(row_frames[index], Input.CURSOR_ARROW, HOTSPOTS[mode] * pixel_scale)


func _show_pointing(is_pressed : bool) -> void:
	var index : int = 1 if is_pressed else 0
	if index == pointing_pressed:
		return
	pointing_pressed = index
	var row_frames : Array = frames.get(POINTING_ROW, [])
	if index < row_frames.size():
		Input.set_custom_mouse_cursor(row_frames[index], Input.CURSOR_POINTING_HAND, POINTING_HOTSPOT * pixel_scale)


## The window's whole pixel scale (the game is 640x360 stretched by whole steps).
static func scale_for(window_size : Vector2i) -> int:
	return maxi(1, floori(minf(window_size.x / BASE_SIZE.x, window_size.y / BASE_SIZE.y)))


func _rebuild() -> void:
	var new_scale : int = scale_for(get_window().size)
	if new_scale == pixel_scale:
		return
	pixel_scale = new_scale
	frames.clear()
	var sheet : Image = SHEET.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	var counts : Array[int] = []
	for durations in FRAME_SECONDS:
		counts.append(durations.size())
	counts.append(2)  #the pointing claw: open, pressed
	counts.append(1)  #the pressed arrow
	for row in counts.size():
		var row_frames : Array[ImageTexture] = []
		for i in counts[row]:
			var image : Image = sheet.get_region(Rect2i(i * CELL, row * CELL, CELL, CELL))
			image.resize(CELL * pixel_scale, CELL * pixel_scale, Image.INTERPOLATE_NEAREST)
			row_frames.append(ImageTexture.create_from_image(image))
		frames[row] = row_frames
	shown_mode = -1
	pointing_pressed = -1


#every button points: its shape is the pointing hand, which shows the claw
func _on_node_added(node : Node) -> void:
	var button : BaseButton = node as BaseButton
	if button != null and button.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_cursor_mode_requested(source : StringName, mode : int) -> void:
	if mode == Mode.POINTER:
		requests.erase(source)
	else:
		requests[source] = mode as Mode


func _on_mouse_on_gui(is_on : bool) -> void:
	is_cursor_on_gui = is_on


#a new scene: whatever asked before is gone
func _on_level_changed(_level : Level) -> void:
	_clear()


func _clear() -> void:
	requests.clear()
	is_cursor_on_gui = false
