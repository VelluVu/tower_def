extends RefCounted

## A huge mixed wave on one level, no towers: how the crowd moves and what it costs per frame
## (the clumping worry before the level pass, 2026-11-26).
## `python tools/gd.py run tools/reports/stress_wave.gd [level=13] [count=250] [every=0.1] [seconds=120]
##   [mix=weakling,fastling,beefling,scout,soldier,swarmling] --raw`
## Prints, every 10 s: enemies alive, the most in one 16 px cell, how many stand in a cell with 4+ others,
## the average and worst physics frame time (ms, real time), and at the end the walk time per kind.

const BUCKET : float = 16.0
const REPORT_EVERY : float = 10.0
const CROWDED : int = 5

var options : Dictionary[String, String] = {"level": "13", "count": "250", "every": "0.1", "seconds": "120",
	"mix": "weakling,fastling,beefling,scout,soldier,swarmling"}
var walk_times : Dictionary[String, Array] = {}
var born : Dictionary[int, float] = {}
var kinds : Dictionary[int, String] = {}
var clock : float = 0.0


func run(kit : TestKit, args : PackedStringArray) -> void:
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	var level : Level = await kit.load_level(int(options.level))
	level.player_stats.life = 999999.0
	GameSignals.enemy_reached_end_point.connect(_on_reached_end)
	var mix : PackedStringArray = options.mix.split(",", false)
	var count : int = int(options.count)
	var every : float = float(options.every)
	var spawners : int = level.get_spawners().size()
	var spawned : int = 0
	var next_spawn : float = 0.0
	var next_report : float = REPORT_EVERY
	var frame_ms : Array[float] = []
	print("STRESS level %s, %d enemies every %s s from %d spawners: %s" % [options.level, count, every, spawners, options.mix])
	print("  %5s %6s %8s %8s %8s %8s" % ["time", "alive", "max/cell", "crowded", "avg ms", "worst ms"])
	while clock < float(options.seconds):
		while spawned < count and clock >= next_spawn:
			var kind : String = mix[spawned % mix.size()]
			var enemy : Enemy = kit.spawn_enemy(kind, spawned % spawners)
			born[enemy.get_instance_id()] = clock
			kinds[enemy.get_instance_id()] = kind
			spawned += 1
			next_spawn += every
		var start : int = Time.get_ticks_usec()
		await kit.root.get_tree().physics_frame
		frame_ms.append((Time.get_ticks_usec() - start) / 1000.0)
		clock += kit.root.get_physics_process_delta_time()
		if clock >= next_report:
			next_report += REPORT_EVERY
			_report(level, frame_ms)
			frame_ms.clear()
		if spawned >= count and level.existing_enemies.is_empty():
			break
	_report(level, frame_ms)
	print("  walk time per kind (s): avg / max")
	for kind in mix:
		var times : Array = walk_times.get(kind, [])
		if times.is_empty():
			print("    %-12s none arrived" % kind)
			continue
		var total : float = 0.0
		for time : float in times:
			total += time
		print("    %-12s %6.1f / %6.1f  (%d)" % [kind, total / times.size(), times.max(), times.size()])
	GameSignals.enemy_reached_end_point.disconnect(_on_reached_end)
	kit.free_level()


func _report(level : Level, frame_ms : Array[float]) -> void:
	var cells : Dictionary[Vector2i, int] = {}
	for enemy in level.existing_enemies:
		if not is_instance_valid(enemy) or enemy.is_deactivated or enemy.is_flying:
			continue
		var cell : Vector2i = Vector2i(floori(enemy.global_position.x / BUCKET), floori(enemy.global_position.y / BUCKET))
		cells[cell] = cells.get(cell, 0) + 1
	var most : int = 0
	var crowded : int = 0
	for cell in cells:
		most = maxi(most, cells[cell])
		if cells[cell] >= CROWDED:
			crowded += cells[cell]
	var total : float = 0.0
	var worst : float = 0.0
	for ms in frame_ms:
		total += ms
		worst = maxf(worst, ms)
	print("  %5.0f %6d %8d %8d %8.2f %8.2f" % [clock, level.existing_enemies.size(), most, crowded,
		total / maxf(frame_ms.size(), 1), worst])


func _on_reached_end(enemy : Enemy) -> void:
	var id : int = enemy.get_instance_id()
	if not born.has(id):
		return
	var kind : String = kinds[id]
	if not walk_times.has(kind):
		walk_times[kind] = []
	walk_times[kind].append(clock - born[id])
