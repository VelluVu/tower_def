class_name ErrorCatcher
extends Logger

## Collects the engine's errors and warnings (script errors, push_error, push_warning, engine checks such as a timer
## started out of the tree) so the test runner can fail the test that caused them; a test once passed while a retry
## bug printed an engine error (2026-11-25). Called from any thread, hence the mutex.

## Messages that are expected and harmless in headless runs.
const IGNORED : Array[String] = ["Capture not registered"]

var mutex : Mutex = Mutex.new()
var caught : PackedStringArray = []


func _log_error(function : String, file : String, line : int, code : String, rationale : String, _editor_notify : bool, error_type : int, script_backtraces : Array[ScriptBacktrace]) -> void:
	var text : String = rationale if not rationale.is_empty() else code
	for ignored in IGNORED:
		if text.contains(ignored):
			return
	var kind : String = "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR"
	var where : String = "%s (%s:%d)" % [function, file, line]
	#the script's own frame says more than the engine's C++ line
	for backtrace in script_backtraces:
		if backtrace.get_frame_count() > 0:
			where = "%s (%s:%d)" % [backtrace.get_frame_function(0), backtrace.get_frame_file(0), backtrace.get_frame_line(0)]
			break
	mutex.lock()
	caught.append("%s %s at %s" % [kind, text, where])
	mutex.unlock()


## The messages caught since the last call.
func take() -> PackedStringArray:
	mutex.lock()
	var messages : PackedStringArray = caught
	caught = []
	mutex.unlock()
	return messages
