class_name AudioBank
extends Resource

## The game's music and its global sounds, so swapping one means reassigning it here.
## Attack sounds live on each unit's Skill (activate_sound), next to its sprite.


@export_group("Music")
@export var menu_music : AudioStream
@export var world_map_music : AudioStream
## Shuffled while building, before the first wave and between waves.
@export var build_music : Array[AudioStream] = []
## Shuffled while a wave runs.
@export var battle_music : Array[AudioStream] = []
## Played once.
@export var victory_music : AudioStream
@export var defeat_music : AudioStream

@export_group("UI")
@export var ui_click : AudioStream
@export var level_up : AudioStream
@export var upgrade_bought : AudioStream
@export var element_chosen : AudioStream

@export_group("Waves")
@export var wave_start : AudioStream
@export var wave_cleared : AudioStream
## An enemy reaching the castle costs life.
@export var castle_hit : AudioStream

@export_group("World")
@export var building_placed : AudioStream
@export var building_sold : AudioStream
@export var building_destroyed : AudioStream
## One is picked at random for each death.
@export var enemy_deaths : Array[AudioStream] = []
