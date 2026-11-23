class_name AudioPlayback
extends Node

## Sound effects, music and UI clicks. Effects share a pool so overlaps don't cut off; music
## loops one track or shuffles a playlist. Both play on while menus pause the tree.

var sfx_bus: StringName = &"SFX"
var music_bus: StringName = &"Music"
var sfx_pool_size: int = 6
## Positional sounds (play_sfx_at()) have their own pool, heard from the current
## AudioListener2D, or the screen centre without one.
var world_pool_size: int = 8
## Past this distance in pixels a world sound is silent.
var world_max_distance: float = 900.0
var world_attenuation: float = 1.0
var world_panning_strength: float = 0.6
var click_stream: AudioStream
## Every button that enters the tree plays the click when pressed, so none is left silent.
var click_all_buttons: bool = true
## Seconds a new track takes to fade in while the old one fades out; 0 cuts at once.
var music_fade_time: float = 1.2
## The volume a fade starts from and ends at, quiet enough to count as silent.
const MUSIC_SILENT_DB: float = -40.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_player_index: int = 0
var _world_pool: Array[AudioStreamPlayer2D] = []
var _next_world_player_index: int = 0

## The playing track's player; the other one fades the previous track out during a switch.
var _music_player: AudioStreamPlayer
var _fading_music_player: AudioStreamPlayer
var _music_tweens: Dictionary[AudioStreamPlayer, Tween] = {}
## Nothing starts playing while on (silent test runs): a headless run's dummy driver never mixes, so a
## stream once started was never let go, and the exit reported it as leaked.
var is_silent: bool = false
var _playlist: Array[AudioStream] = []
var _playlist_index: int = 0
var _looping: bool = false

var _click_pending: bool = false
## The frame a sound other than the click last played, so the click can give way to it.
var _specific_sfx_frame: int = -1


func _ready() -> void:
	for i in range(sfx_pool_size):
		# A sound that is playing when a window pauses the tree would freeze until it
		# closes, which silences the click of every button that opens one.
		_sfx_pool.append(_add_player(sfx_bus))
	for i in range(world_pool_size):
		_world_pool.append(_add_world_player())
	_music_player = _add_music_player()
	_fading_music_player = _add_music_player()
	if click_all_buttons:
		get_tree().node_added.connect(_on_node_added)


## Stops every sound and the music and lets go of their streams. The audio thread frees a stopped
## stream's playback on its next mix, so call this a frame or two before quitting (the window's close
## does it here); at exit itself the engine would report the playing streams as leaked.
func stop_all() -> void:
	_playlist.clear()
	_looping = false
	var players: Array[Node] = []
	players.append_array(_sfx_pool)
	players.append_array(_world_pool)
	players.append(_music_player)
	players.append(_fading_music_player)
	for tween: Tween in _music_tweens.values():
		if tween != null:
			tween.kill()
	_music_tweens.clear()
	for player: Node in players:
		if player == null:
			continue
		player.call(&"stop")
		player.set(&"stream", null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_all()


func _exit_tree() -> void:
	stop_all()


## One-shot sound. A click requested in the same frame gives way to it.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	_specific_sfx_frame = Engine.get_process_frames()
	_play_stream(stream, volume_db, pitch_scale)


## One-shot sound at a place in the world, panned and faded by its distance to the listener.
## An empty `bus` plays on the effects bus.
func play_sfx_at(stream: AudioStream, world_position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0, bus: StringName = &"") -> void:
	if stream == null or is_silent:
		return
	var player := _world_pool[_next_world_player_index]
	_next_world_player_index = (_next_world_player_index + 1) % _world_pool.size()
	player.global_position = world_position
	player.bus = bus if bus != &"" else sfx_bus
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## Deferred to the end of the frame: one press can ask twice (the button and the signal
## it sends), and a more specific sound in the same frame replaces the click.
func play_click() -> void:
	if _click_pending:
		return
	_click_pending = true
	_flush_click.call_deferred()


## Loops one track. Keeps going, without restarting, if it is already the looping track.
func play_music_loop(stream: AudioStream) -> void:
	if _looping and _music_player.stream == stream and _music_player.playing:
		return
	_looping = true
	_switch_music(stream)


## Plays one track once (a victory or defeat theme), then stays silent.
func play_music_once(stream: AudioStream) -> void:
	_looping = false
	_playlist.clear()
	_switch_music(stream)


## Plays the tracks in a shuffled order, over and over.
func play_playlist(tracks: Array[AudioStream]) -> void:
	_looping = false
	_playlist = tracks.duplicate()
	_playlist.shuffle()
	_playlist_index = 0
	_play_playlist_track()


func is_playlist_playing() -> bool:
	return not _looping and _music_player.playing


func _add_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _add_music_player() -> AudioStreamPlayer:
	var player := _add_player(music_bus)
	# The web's default sample playback lost track of a looping song, so the menu music
	# kept playing under the run's. Streamed, the engine's own mixer plays it as on desktop.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.finished.connect(_on_music_finished.bind(player))
	return player


func _add_world_player() -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = sfx_bus
	player.max_distance = world_max_distance
	player.attenuation = world_attenuation
	player.panning_strength = world_panning_strength
	add_child(player)
	return player


func _play_stream(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or is_silent:
		return
	var player := _sfx_pool[_next_sfx_player_index]
	_next_sfx_player_index = (_next_sfx_player_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _flush_click() -> void:
	_click_pending = false
	if _specific_sfx_frame != Engine.get_process_frames():
		_play_stream(click_stream)


## A button moved to a new parent enters the tree again; connect it only once.
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(play_click):
		(node as BaseButton).pressed.connect(play_click)


func _play_playlist_track() -> void:
	if _playlist.is_empty():
		return
	_switch_music(_playlist[_playlist_index])


## Crossfades: the old track fades out on the spare player while the new one fades in, so
## a switch is never a hard cut. A track still fading out from an earlier switch stops.
func _switch_music(stream: AudioStream) -> void:
	_stop_music_player(_fading_music_player)
	var old_player := _music_player
	_music_player = _fading_music_player
	_fading_music_player = old_player
	if is_silent or music_fade_time <= 0.0:
		_stop_music_player(old_player)
	elif old_player.playing:
		_fade_music(old_player, MUSIC_SILENT_DB, true)
	if is_silent or stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_SILENT_DB if music_fade_time > 0.0 else 0.0
	_music_player.play()
	if music_fade_time > 0.0:
		_fade_music(_music_player, 0.0, false)


func _fade_music(player: AudioStreamPlayer, to_db: float, stop_at_end: bool) -> void:
	_kill_music_tween(player)
	var tween := player.create_tween()
	# Menus pause the tree, and the music keeps playing under them; so does the fade.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(player, ^"volume_db", to_db, music_fade_time)
	if stop_at_end:
		tween.tween_callback(_stop_music_player.bind(player))
	_music_tweens[player] = tween


func _kill_music_tween(player: AudioStreamPlayer) -> void:
	var tween: Tween = _music_tweens.get(player)
	if tween != null and tween.is_valid():
		tween.kill()
	_music_tweens.erase(player)


func _stop_music_player(player: AudioStreamPlayer) -> void:
	_kill_music_tween(player)
	player.stop()
	player.stream = null
	player.volume_db = 0.0


func _on_music_finished(player: AudioStreamPlayer) -> void:
	# The fading player's track ending mid-fade is not the current track ending.
	if player != _music_player:
		return
	if _looping:
		_music_player.play()
		return
	if _playlist.is_empty():
		return
	_playlist_index = (_playlist_index + 1) % _playlist.size()
	_play_playlist_track()
