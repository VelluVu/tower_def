class_name ProgressData
extends Resource

## The saved player progress. Bump SaveWiring.SAVE_VERSION and add a _migrate step
## when a field is renamed, removed or changes meaning.

@export var save_version : int = 0
## The highest unlocked level.
@export var level_progress : int = 1
