class_name SettingsWiring
extends SettingsStore

## This project's audio buses, display defaults and options: the one file to edit after
## copying the settings system. The game's SettingsManager autoload extends this.

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

const OPTION_VSYNC: String = "vsync"
## Frames per second cap, 0 for none.
const OPTION_MAX_FPS: String = "max_fps"
const OPTION_DAMAGE_NUMBERS: String = "damage_numbers"
## Multiplies the camera's key movement and edge scrolling speed.
const OPTION_CAMERA_SPEED: String = "camera_speed"
## The camera moves when the mouse touches the window edge.
const OPTION_EDGE_SCROLL: String = "edge_scroll"
## Alt-tab during a wave would otherwise let enemies walk in unseen.
const OPTION_PAUSE_ON_FOCUS_LOSS: String = "pause_on_focus_loss"

const MAX_FPS_CHOICES: Array[int] = [0, 30, 60, 120, 144, 240]


func _init() -> void:
	audio_buses = [BUS_MASTER, BUS_MUSIC, BUS_SFX]
	default_volume = 0.8
	# The project stretches in whole steps (window/stretch/scale_mode="integer").
	pixel_perfect = true
	option_defaults = {
		OPTION_VSYNC: true,
		OPTION_MAX_FPS: 0,
		OPTION_DAMAGE_NUMBERS: true,
		OPTION_CAMERA_SPEED: 1.0,
		OPTION_EDGE_SCROLL: false,
		OPTION_PAUSE_ON_FOCUS_LOSS: true,
	}
	save_path = "user://settings.cfg"
	supported_locales = ["en"]
	fallback_locale = "en"
	option_changed.connect(_on_option_changed)


func apply_all() -> void:
	super()
	_apply_vsync()
	_apply_max_fps()


func _on_option_changed(key: String, _value: Variant) -> void:
	if key == OPTION_VSYNC:
		_apply_vsync()
	elif key == OPTION_MAX_FPS:
		_apply_max_fps()


func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_ENABLED if get_option(OPTION_VSYNC) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func _apply_max_fps() -> void:
	Engine.max_fps = int(get_option(OPTION_MAX_FPS))
