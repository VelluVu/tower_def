class_name PuffeLine
extends Resource

#one line Puffe says during a level; a level's lines play in order, each waiting for its trigger

enum Trigger {LevelStart, AfterPrevious, BuildingPlaced, WaveStarted, WaveCleared, GoldUpgradeBought, LevelUp, CastleHit}
## Puffe's face while he says it (2026-11-23; new moods go at the end, the .tres files store the number).
enum Mood {Neutral, Happy, Worried, Angry, Smug}

@export var trigger : Trigger = Trigger.AfterPrevious
## For WaveStarted and WaveCleared: the wave number, 0 = any wave.
@export var wave_number : int = 0
@export_multiline var text : String = ""
@export var mood : Mood = Mood.Neutral
