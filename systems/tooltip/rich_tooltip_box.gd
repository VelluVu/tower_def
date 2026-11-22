class_name RichTooltipBox
extends HBoxContainer

## A row whose tooltip_text shows as a RichTooltip over all of it: give its children no tooltip of
## their own and MOUSE_FILTER_PASS, so Godot looks the tooltip up on the row (pass_children_to_row).


func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltip.build(for_text)


## Lets the row's tooltip show over every child: clears theirs and passes the mouse up
## (a passed click still works the child).
func pass_children_to_row() -> void:
	for child: Node in get_children():
		if child is Control:
			(child as Control).tooltip_text = ""
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
