extends Node
## Autoload: GameState. Session-scoped state (not persisted): screen params,
## active match config, navigation helpers.

var screen_params: Dictionary = {}
var match_config: Dictionary = {}
var last_result: Dictionary = {}


func vibrate(ms: int = 40) -> void:
	if not bool(SaveSystem.data["settings"].get("vibration", true)):
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(ms)
