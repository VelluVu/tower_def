# Tooltip system

Richer tooltips from plain `tooltip_text`: the first line is a bold title in its own colour,
the rest is the body, wrapped at a max width (shorter text keeps its own width). Parts of the
text that match the highlight patterns (key hints such as `[Q]`, gold amounts) are coloured.
The panel around it is the theme's `TooltipPanel`, as for Godot's own tooltips.

## Interface

| Piece | What it does |
|---|---|
| `RichTooltip.build(text)` | The tooltip control for `text`; null for empty text. Return it from `_make_custom_tooltip` |
| `RichTooltip.to_bbcode(line)` | One line as BBCode: highlights coloured, other `[` escaped |
| `RichTooltipButton` | A `Button` that shows its `tooltip_text` this way (scene script or `.new()`) |
| `RichTooltipBox` | An `HBoxContainer` row that owns one tooltip for all its children; call `pass_children_to_row()` after adding them |

Any other Control gets the same look with:

```gdscript
func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltip.build(for_text)
```

## Use it in a new project

1. Copy this folder (keep the `.uid` files).
2. Edit **`tooltip_wiring.gd`**: the theme type, max width, title colour and the highlight patterns.
3. Add the theme type to the project theme: a `RichTextLabel` variation with `normal_font`,
   `bold_font`, their sizes and `default_color` (here `TooltipText` in `puffe_theme.tres`).
