extends RefCounted

## PlaytestLog: one JSON line per played level run, nothing for a level left before the first wave.

const LOG_PATH : String = "user://test_playtest_log.jsonl"


func test_a_run_is_written_once_and_an_unplayed_one_not(kit : TestKit) -> void:
	PlaytestLog.is_enabled = true
	PlaytestLog.log_path = LOG_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))

	await kit.load_level(1)
	kit.free_level()
	kit.check(not FileAccess.file_exists(LOG_PATH), "leaving before the first wave writes nothing")

	await kit.load_level(1)
	await kit.place("wall", kit.find_cell(func(cell : Vector2i) -> bool: return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(cell))))
	UISignals.start_wave_pressed.emit()
	await kit.frames(2)
	UISignals.resign_level.emit()
	kit.free_level()

	var lines : PackedStringArray = FileAccess.get_file_as_string(LOG_PATH).strip_edges().split("\n")
	kit.check(lines.size() == 1, "one line for one run, resigning and leaving count once (%d)" % lines.size())
	var record : Dictionary = JSON.parse_string(lines[0])
	kit.check(record.get("result") == PlaytestLog.RESULT_RESIGNED, "the run was resigned")
	kit.check(int(record.get("wave", 0)) == 1, "it reached wave 1")
	kit.check(int(record.get("placed", {}).get("wall", 0)) == 1, "the wall is counted")
	kit.check(record.has("life_by_wave") and record.has("spent_on") and record.has("talents"), "the balance fields are there")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
	PlaytestLog.is_enabled = false
	PlaytestLog.log_path = TestKit.TEST_PLAYTEST_LOG_PATH
