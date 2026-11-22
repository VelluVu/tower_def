class_name RichTooltipButton
extends Button

## A Button whose tooltip_text shows as a RichTooltip. Use it as the script of a scene's
## Button, or RichTooltipButton.new() in code.


func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltip.build(for_text)
