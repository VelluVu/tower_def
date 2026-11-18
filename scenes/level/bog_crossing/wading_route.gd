class_name WadingRoute
extends RefCounted

## A path for an enemy that can wade: the road, or the road to a crossing, the stones and the road on.

var path : PackedVector2Array = []
## The index of the crossing's exit in `path` (the waypoint reached by wading); -1 = no crossing.
var exit_index : int = -1
var crossing : BogCrossing = null
