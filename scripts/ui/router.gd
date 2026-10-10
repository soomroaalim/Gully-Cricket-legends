extends Node
## Autoload: Router. Scene switching with a back-stack for Android back-button
## handling. Scenes live in res://scenes/.

const SCENES: Dictionary = {
	"main_menu": "res://scenes/main_menu.tscn",
	"onboarding": "res://scenes/onboarding.tscn",
	"match": "res://scenes/match.tscn",
	"scoreboard": "res://scenes/scoreboard.tscn",
	"result": "res://scenes/result.tscn",
	"career": "res://scenes/career_map.tscn",
	"team": "res://scenes/team.tscn",
	"player": "res://scenes/player.tscn",
	"shop": "res://scenes/shop.tscn",
	"settings": "res://scenes/settings.tscn",
	"practice": "res://scenes/practice.tscn",
	"tournament_map": "res://scenes/tournament_map.tscn",
}

var _stack: Array[String] = []


func show(id: String, params: Dictionary = {}) -> void:
	if not SCENES.has(id):
		push_error("Router: unknown scene id '%s'" % id)
		return
	GameState.screen_params = params
	_stack.push_back(id)
	get_tree().change_scene_to_file(SCENES[id])


func replace(id: String, params: Dictionary = {}) -> void:
	if not _stack.is_empty():
		_stack.pop_back()
	show(id, params)


## Returns false when the stack is at root (caller may exit the app).
func back() -> bool:
	if _stack.size() <= 1:
		return false
	_stack.pop_back()
	var id: String = _stack.back()
	GameState.screen_params = {}
	get_tree().change_scene_to_file(SCENES[id])
	return true


func current() -> String:
	return _stack.back() if not _stack.is_empty() else ""


func reset_to(id: String) -> void:
	_stack.clear()
	show(id)
