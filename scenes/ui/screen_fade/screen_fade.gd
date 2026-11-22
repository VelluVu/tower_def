class_name ScreenFade
extends CanvasLayer

## A dithered fade-in whenever a new screen appears (the main menu, the world map, a level), so
## screens never just cut (polish, 2026-11-22). Made by Main. It covers the new screen on the
## frame it is added, then dissolves in pixel steps; it runs while the game is paused too.

const SHADER : Shader = preload("res://assets/shaders/screen_fade.gdshader")
## Above the UI and damage numbers, under the developer console.
const LAYER : int = 90
const FADE_SECONDS : float = 0.4
## Covering the old screen is quicker: the player is waiting on their click.
const FADE_OUT_SECONDS : float = 0.2
const PROGRESS : StringName = &"progress"
const HEADLESS : String = "headless"

var cover : ColorRect = null
var tween : Tween = null


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	cover = ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	cover.material = material
	add_child(cover)
	_set_progress(0.0)
	get_tree().node_added.connect(_on_node_added)
	GameSignals.level_loaded.connect(_on_level_loaded)


func _on_node_added(node : Node) -> void:
	if node is Menu or node is GameWorldMap:
		fade_in()


func _on_level_loaded(_level : Level) -> void:
	fade_in()


## Covers the old screen over FADE_OUT_SECONDS; await it, then switch. A headless run has no
## screen to cover and returns at once, so tests and the bot keep their instant loads.
func fade_out() -> void:
	if DisplayServer.get_name() == HEADLESS:
		return
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, FADE_OUT_SECONDS)
	await tween.finished


## Covers the screen now and clears it over FADE_SECONDS.
func fade_in() -> void:
	if tween != null:
		tween.kill()
	_set_progress(1.0)
	tween = create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, FADE_SECONDS)


func _set_progress(value : float) -> void:
	(cover.material as ShaderMaterial).set_shader_parameter(PROGRESS, value)
	cover.visible = value > 0.0
