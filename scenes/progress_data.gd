class_name ProgressData
extends Resource

## The saved player progress. Bump SaveWiring.SAVE_VERSION and add a _migrate step
## when a field is renamed, removed or changes meaning.

@export var save_version : int = 0
## The highest unlocked level.
@export var level_progress : int = 1
## Talent ranks per tree: tree id -> {node id: rank}.
@export var talent_ranks : Dictionary[StringName, Dictionary] = {}
## The best talent points earned per level number; replays only earn the difference.
@export var level_talent_points : Dictionary[int, int] = {}
