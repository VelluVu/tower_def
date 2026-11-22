class_name TooltipWiring
extends RefCounted

## This project's tooltip look: the file to edit after copying the tooltip system.
## The fonts, sizes and text colour come from the theme type THEME_TYPE (a RichTextLabel
## variation in the project theme: normal_font, bold_font, their sizes, default_color);
## the panel is the theme's TooltipPanel, as for Godot's own tooltips.

const THEME_TYPE: StringName = &"TooltipText"
## Pixels at the 640x360 UI size; longer lines wrap.
const MAX_WIDTH: float = 176.0
## Endesga 32 on the parchment panel: wing green.
const TITLE_COLOR: Color = Color("265c42")
## [regex, colour]: key hints such as "[Q]" or "[Space]", and gold amounts such as "12g"
## or "+3 gold".
const HIGHLIGHTS: Array = [
	["\\[[^\\]]{1,12}\\]", Color("124e89")],
	["[+-]?\\d+(\\.\\d+)?g\\b|[+-]?\\d+ (bonus )?gold", Color("be4a2f")],
]
