extends Node

## Headless entry point for `python tools/gd.py`: `-- --test <file or folder>...` runs every
## test_* method of the test scripts, `-- --run <file> [args]` awaits that script's run(kit, args).
## Prints PASS/FAIL lines and quits with exit code 1 on any failure.

const TEST_METHOD_PREFIX : String = "test_"
const SCRIPT_EXTENSION : String = ".gd"
const USAGE_ERROR : String = "usage: -- [--deadline <s>] --test <file or folder>... | --run <file> [args]"
const DEADLINE_ARG : String = "--deadline"
const DEADLINE_MESSAGE : String = "TIMEOUT in %s: a script error after an await stops a coroutine for good"
const DEFAULT_DEADLINE_SECONDS : float = 240.0

#real time, not game time: --fixed-fps runs the game faster than the clock
var deadline_msec : int = 0
var current_name : String = "startup"


#a coroutine stopped by a script error never returns, so the runner would wait forever
func _process(_delta : float) -> void:
	if Time.get_ticks_msec() > deadline_msec:
		print(DEADLINE_MESSAGE % current_name)
		get_tree().quit(124)


func _ready() -> void:
	var args : PackedStringArray = OS.get_cmdline_user_args()
	var deadline_seconds : float = DEFAULT_DEADLINE_SECONDS

	if args.size() >= 2 and args[0] == DEADLINE_ARG:
		deadline_seconds = args[1].to_float()
		args = args.slice(2)

	deadline_msec = Time.get_ticks_msec() + int(deadline_seconds * 1000.0)

	if args.size() < 2:
		push_error(USAGE_ERROR)
		get_tree().quit(1)
		return

	match args[0]:
		"--test":
			get_tree().quit(await _run_tests(args.slice(1)))
		"--run":
			current_name = args[1]
			var instance : Object = load(args[1]).new()
			await instance.run(TestKit.new(self), args.slice(2))
			get_tree().quit(0)
		_:
			push_error(USAGE_ERROR)
			get_tree().quit(1)


func _run_tests(paths : PackedStringArray) -> int:
	var passed : int = 0
	var failed : int = 0

	for script_path in _collect_scripts(paths):
		var script : GDScript = load(script_path)
		for method in script.get_script_method_list():
			if not method.name.begins_with(TEST_METHOD_PREFIX):
				continue

			var test_name : String = "%s::%s" % [script_path.get_file().get_basename(), method.name]
			current_name = test_name
			var kit : TestKit = TestKit.new(self)
			await Callable(script.new(), method.name).call(kit)
			kit.free_level()

			if kit.failures.is_empty():
				passed += 1
				print("PASS ", test_name, " (", kit.checks, " checks)")
			else:
				failed += 1
				for failure in kit.failures:
					print("FAIL ", test_name, ": ", failure)

	print("RESULT %d passed, %d failed" % [passed, failed])
	return 1 if failed > 0 else 0


func _collect_scripts(paths : PackedStringArray) -> PackedStringArray:
	var scripts : PackedStringArray = []

	for path in paths:
		if path.ends_with(SCRIPT_EXTENSION):
			scripts.append(path)
			continue

		for file in DirAccess.get_files_at(path):
			if file.begins_with(TEST_METHOD_PREFIX) and file.ends_with(SCRIPT_EXTENSION):
				scripts.append(path.path_join(file))

	return scripts
