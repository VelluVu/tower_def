extends SceneTree

## `python tools/gd.py icon <grid.txt> <out.png> [reference.png...]`: draws a pixel icon from a text grid
## and saves <out>.preview.png (8x, on the card's dark background, next to the references).
## Grid file: "key = rrggbb" palette lines (use Endesga 32 colours), a "---" line, then one text row per
## pixel row; "." and unknown keys are transparent. Runs with -s, so no autoloads.

const PREVIEW_SCALE : int = 8
const PREVIEW_GAP : int = 16
const PREVIEW_BACKGROUND : String = "1a2f2a"
const SEPARATOR : String = "---"


func _initialize() -> void:
	var args : PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <grid.txt> <out.png> [reference.png...]")
		quit(1)
		return

	var icon : Image = _draw(FileAccess.get_file_as_string(args[0]))
	icon.save_png(args[1])

	var images : Array[Image] = [icon]
	for path in args.slice(2):
		var reference : Image = Image.load_from_file(path)
		reference.convert(Image.FORMAT_RGBA8)
		images.append(reference)
	var preview_path : String = args[1].get_basename() + ".preview.png"
	_preview(images).save_png(preview_path)
	print("saved ", args[1], " (", icon.get_width(), "x", icon.get_height(), ") and ", preview_path)
	quit(0)


func _draw(text : String) -> Image:
	var palette : Dictionary = {}
	var rows : PackedStringArray = []
	var in_grid : bool = false

	for line in text.split("\n"):
		line = line.strip_edges(false, true)
		if line == SEPARATOR:
			in_grid = true
		elif in_grid:
			if not line.is_empty():
				rows.append(line)
		elif " = " in line:
			var parts : PackedStringArray = line.split(" = ")
			palette[parts[0].strip_edges()] = Color.html(parts[1].strip_edges())

	var width : int = 0
	for row in rows:
		width = maxi(width, row.length())
	var image : Image = Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)

	for y in rows.size():
		for x in rows[y].length():
			image.set_pixel(x, y, palette.get(rows[y][x], Color(0, 0, 0, 0)))

	return image


func _preview(images : Array[Image]) -> Image:
	var height : int = 0
	var width : int = 0
	for image in images:
		height = maxi(height, image.get_height() * PREVIEW_SCALE)
		width += image.get_width() * PREVIEW_SCALE + PREVIEW_GAP

	var preview : Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	preview.fill(Color.html(PREVIEW_BACKGROUND))
	var x : int = 0
	for image in images:
		var big : Image = image.duplicate()
		big.resize(image.get_width() * PREVIEW_SCALE, image.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
		preview.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, 0))
		x += big.get_width() + PREVIEW_GAP
	return preview
