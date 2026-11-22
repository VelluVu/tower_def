class_name RichTooltip
extends RefCounted

## Builds a tooltip from plain text, for a Control's _make_custom_tooltip(for_text):
##   func _make_custom_tooltip(for_text: String) -> Object:
##       return RichTooltip.build(for_text)
## The first line is the title (bold, its own colour), the rest is the body. Lines wrap at
## TooltipWiring.MAX_WIDTH; shorter text keeps its own width. TooltipWiring.HIGHLIGHTS colour
## the parts of the text that match them (key hints, prices). Plain text in, so the same
## string still reads as a normal tooltip anywhere the custom one is not used.

const TITLE_FORMAT: String = "[b][color=#%s]%s[/color][/b]"
const COLOR_FORMAT: String = "[color=#%s]%s[/color]"
const OPEN_BRACKET: String = "["
const ESCAPED_BRACKET: String = "[lb]"
const NEW_LINE: String = "\n"
const NORMAL_FONT: StringName = &"normal_font"
const BOLD_FONT: StringName = &"bold_font"
const NORMAL_FONT_SIZE: StringName = &"normal_font_size"
const BOLD_FONT_SIZE: StringName = &"bold_font_size"



## Null for empty text, so the control shows no tooltip at all.
static func build(text: String) -> Control:
	if text.strip_edges().is_empty():
		return null

	var lines: PackedStringArray = text.split(NEW_LINE)
	var title: String = lines[0]
	lines.remove_at(0)

	var label: RichTextLabel = RichTextLabel.new()
	label.theme_type_variation = TooltipWiring.THEME_TYPE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.x = get_width(label, title, lines)

	var bbcode: String = TITLE_FORMAT % [TooltipWiring.TITLE_COLOR.to_html(false), to_bbcode(title)]
	for line: String in lines:
		bbcode += NEW_LINE + to_bbcode(line)
	label.text = bbcode
	return label


## The widest line in its font, capped at MAX_WIDTH (longer lines wrap). The label is not in
## the tree yet and would miss the theme type's fonts, so they come from the project theme.
static func get_width(label: RichTextLabel, title: String, body_lines: PackedStringArray) -> float:
	var bold: Font = _font(label, BOLD_FONT)
	var normal: Font = _font(label, NORMAL_FONT)
	var width: float = bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(label, BOLD_FONT_SIZE)).x
	var normal_size: int = _font_size(label, NORMAL_FONT_SIZE)
	for line: String in body_lines:
		width = maxf(width, normal.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, normal_size).x)
	#a pixel to spare: a line measured to its exact width can still wrap its last word
	return minf(ceilf(width) + 1.0, TooltipWiring.MAX_WIDTH)


## One line as BBCode: the highlights coloured, every other "[" escaped so text such as a
## key hint "[Q]" is never read as a tag.
static func to_bbcode(line: String) -> String:
	var spans: Array = []
	for highlight: Array in _get_highlights():
		for found: RegExMatch in (highlight[0] as RegEx).search_all(line):
			spans.append([found.get_start(), found.get_end(), highlight[1]])
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var result: String = ""
	var position: int = 0
	for span: Array in spans:
		#an overlapping match loses to the earlier one
		if span[0] < position:
			continue
		result += _escape(line.substr(position, span[0] - position))
		result += COLOR_FORMAT % [(span[2] as Color).to_html(false), _escape(line.substr(span[0], span[1] - span[0]))]
		position = span[1]
	return result + _escape(line.substr(position))


static func _font(label: RichTextLabel, font_name: StringName) -> Font:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme != null and theme.has_font(font_name, TooltipWiring.THEME_TYPE):
		return theme.get_font(font_name, TooltipWiring.THEME_TYPE)
	return label.get_theme_font(font_name)


static func _font_size(label: RichTextLabel, size_name: StringName) -> int:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme != null and theme.has_font_size(size_name, TooltipWiring.THEME_TYPE):
		return theme.get_font_size(size_name, TooltipWiring.THEME_TYPE)
	return label.get_theme_font_size(size_name)


static func _escape(text: String) -> String:
	return text.replace(OPEN_BRACKET, ESCAPED_BRACKET)


## [RegEx, Color] pairs from TooltipWiring.HIGHLIGHTS, compiled per tooltip: cheap at hover rate, and a
## static cache of RegEx objects outlived the scripts at exit (leaked).
static func _get_highlights() -> Array:
	var highlights: Array = []
	for pair: Array in TooltipWiring.HIGHLIGHTS:
		highlights.append([RegEx.create_from_string(pair[0]), pair[1]])
	return highlights
