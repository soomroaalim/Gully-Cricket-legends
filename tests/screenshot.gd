extends SceneTree
## Screenshot capture for Gully Cricket Legends UI review.
##
## Run (desktop 960x540):
##   xvfb-run -a -s "-screen 0 960x540x24" \
##     ~/tools/godot/Godot_v4.3-stable_linux.x86_64 --path . \
##     --rendering-driver opengl3 --resolution 960x540 \
##     --script tests/screenshot.gd
## Run (phone landscape 915x412): same with --resolution 915x412 and
##   GCL_SHOT_SUFFIX=_phone in the environment.
##
## Per capture: optional setup, load scene, wait N frames, save
## get_root().get_texture().get_image() to screenshots/<name><suffix>.png.

var Save: Node
var State: Node
var Econ: Node
var CareerA: Node

var _started: bool = false
var _idx: int = 0
var _frames: int = 0
var _suffix: String = ""
var _captures: Array = []


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_boot()
		_begin_capture()
		return false
	_frames += 1
	var cap: Dictionary = _captures[_idx]
	if _frames >= int(cap["wait"]):
		_shoot(str(cap["name"]))
		_idx += 1
		if _idx >= _captures.size():
			print("SHOTS: all %d captures done" % _captures.size())
			return true
		_begin_capture()
	return false


func _boot() -> void:
	Save = get_root().get_node_or_null("SaveSystem")
	State = get_root().get_node_or_null("GameState")
	Econ = get_root().get_node_or_null("Economy")
	CareerA = get_root().get_node_or_null("Career")
	_suffix = OS.get_environment("GCL_SHOT_SUFFIX")
	# Seeded, content-rich save so every screen has something to show.
	Save.reset_game()
	var team: Array = GCLPlayers.make_starter_team("Shutter", 0)
	Save.data["team"] = team
	Save.data["player_name"] = "Shutter"
	Save.data["lineup"] = [str(team[0]["id"])]
	Save.data["coins"] = 2000
	Save.data["onboarding_done"] = true
	Save.save_game()
	_captures = [
		{"name": "onboarding", "scene": "res://scenes/onboarding.tscn",
			"wait": 60, "setup": _setup_onboarding},
		{"name": "main_menu", "scene": "res://scenes/main_menu.tscn",
			"wait": 60, "setup": _setup_menu},
		{"name": "match_toss", "scene": "res://scenes/match.tscn",
			"wait": 45, "setup": _setup_match},
		{"name": "match_play", "scene": "res://scenes/match.tscn",
			"wait": 300, "setup": _setup_match},
		{"name": "result", "scene": "res://scenes/result.tscn",
			"wait": 90, "setup": _setup_result},
		{"name": "career_map", "scene": "res://scenes/career_map.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "team", "scene": "res://scenes/team.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "shop", "scene": "res://scenes/shop.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "settings", "scene": "res://scenes/settings.tscn",
			"wait": 60, "setup": _setup_none},
	]


func _begin_capture() -> void:
	var cap: Dictionary = _captures[_idx]
	_frames = 0
	(cap["setup"] as Callable).call()
	change_scene_to_file(str(cap["scene"]))
	print("SHOTS: capturing %s (wait %d frames)" % [str(cap["name"]), int(cap["wait"])])


func _shoot(stem: String) -> void:
	var img: Image = get_root().get_texture().get_image()
	var path: String = "res://screenshots/%s%s.png" % [stem, _suffix]
	var err: Error = img.save_png(path)
	print("SHOTS: saved %s (%dx%d) err=%d" % [path, img.get_width(), img.get_height(), err])


func _setup_none() -> void:
	pass


func _setup_onboarding() -> void:
	Save.data["onboarding_done"] = false
	Save.save_game()


func _setup_menu() -> void:
	Save.data["onboarding_done"] = true
	Save.save_game()


func _match_cfg() -> Dictionary:
	var stage: Dictionary = GCLStages.all()[0]
	var rng := GCLRng.new(777)
	var mc: Dictionary = GCLConfig.MODE_CONFIG["1v1"]
	var team: Array = Save.data["team"]
	var ai_names: Array = stage.get("team_names", ["Street XI"])
	return {
		"mode": "1v1", "overs": int(mc.get("overs", 2)),
		"max_wickets": int(mc.get("max_wickets", 3)),
		"stage_id": str(stage.get("id", "")), "stage_name": str(stage.get("name", "")),
		"difficulty": "EASY",
		"player_team_name": "Shutter XI",
		"ai_team_name": str(rng.pick(ai_names)),
		"player_team": (team as Array).slice(0, 1),
		"ai_team": GCLPlayers.generate_opponent_team(stage, GCLRng.new(4242)).slice(0, 1),
		"user_player_id": str(team[0]["id"]),
		"user_bats_first": true, "seed": 90210,
		"debug_autoplay": true,
	}


func _setup_match() -> void:
	State.set("match_config", _match_cfg())


func _setup_result() -> void:
	# Play a real AI-vs-AI match fast, then finalize, so the result screen
	# shows genuine data (scores, coins, xp, achievements).
	var cfg: Dictionary = _match_cfg()
	cfg.erase("debug_autoplay")
	State.set("match_config", cfg)
	var eng := MatchEngine.new()
	eng.setup(cfg)
	var guard: int = 0
	while not eng.is_match_over() and guard < 500:
		guard += 1
		if eng.is_innings_over():
			eng.start_next_innings()
		else:
			eng.simulate_ai_ball()
	var res: Dictionary = eng.get_result()
	res = Econ.finalize_match(res, "1v1", "EASY")
	State.set("screen_params", {"result": res, "from": "main_menu"})
	State.set("last_result", res)
