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
		# Optional: dismiss a random event modal a few frames before shooting.
		if bool(cap.get("dismiss_modal", false)) and not bool(cap.get("_dismissed", false)):
			cap["_dismissed"] = true
			_dismiss_ok(current_scene)
			_frames = int(cap["wait"]) - 5
			return false
		# Optional: scroll the screen's ScrollContainer to the bottom a few
		# frames before shooting, so below-fold sections get inspected.
		if bool(cap.get("scroll_bottom", false)) and not bool(cap.get("_scrolled", false)):
			cap["_scrolled"] = true
			var sc := _find_scroll(current_scene)
			if sc != null:
				sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
			_frames = int(cap["wait"]) - 3
			return false
		# Optional: scroll to a fraction of max (0.0-1.0) for mid-page sections.
		if cap.has("scroll_frac") and not bool(cap.get("_sfrac", false)):
			cap["_sfrac"] = true
			var sc2 := _find_scroll(current_scene)
			if sc2 != null:
				sc2.scroll_vertical = int(float(cap["scroll_frac"]) * sc2.get_v_scroll_bar().max_value)
			_frames = int(cap["wait"]) - 3
			return false
		# Optional: tap a button by text a few frames before shooting
		# (e.g. dismiss an intro to reveal the screen underneath).
		if str(cap.get("tap", "")) != "" and not bool(cap.get("_tapped", false)):
			cap["_tapped"] = true
			_tap_button(current_scene, str(cap["tap"]))
			_frames = int(cap["wait"]) - 20
			return false
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
	# Seed the recent-results feed so the career hub shows real entries.
	State.set("match_config", {})
	var seed_res := {"player_won": true, "tied": false, "player_runs": 145,
		"player_wickets": 6, "ai_runs": 140, "ai_wickets": 8,
		"perf": {"sixes": 3, "fours": 8, "wickets": 2}}
	Econ.finalize_match(seed_res.duplicate(true), "1v1", "EASY")
	var seed_res2 := {"player_won": false, "tied": false, "player_runs": 110,
		"player_wickets": 9, "ai_runs": 125, "ai_wickets": 5,
		"perf": {"sixes": 1, "fours": 6, "wickets": 3}}
	Econ.finalize_match(seed_res2.duplicate(true), "2v2", "NORMAL")
	# v2.0: mid-journey selection state so the new cards show real content.
	_setup_selection_mid()
	if OS.get_environment("GCL_SHOT_FILTER") != "":
		var want: String = OS.get_environment("GCL_SHOT_FILTER")
		var kept: Array = []
		for c in _captures_all():
			if str(c["name"]).contains(want):
				kept.append(c)
		_captures = kept
	else:
		_captures = _captures_all()


func _captures_all() -> Array:
	return [
		{"name": "onboarding", "scene": "res://scenes/onboarding.tscn",
			"wait": 60, "setup": _setup_onboarding},
		{"name": "main_menu", "scene": "res://scenes/main_menu.tscn",
			"wait": 60, "setup": _setup_menu},
		{"name": "match_toss", "scene": "res://scenes/match.tscn",
			"wait": 70, "setup": _setup_toss, "tap": "Start Match"},
		{"name": "match_play", "scene": "res://scenes/match.tscn",
			"wait": 300, "setup": _setup_match},
		{"name": "result", "scene": "res://scenes/result.tscn",
			"wait": 90, "setup": _setup_result},
		{"name": "result_selection", "scene": "res://scenes/result.tscn",
			"wait": 90, "setup": _setup_result_selection, "dismiss_modal": true},
		{"name": "career_hub", "scene": "res://scenes/career_map.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "career_hub_low", "scene": "res://scenes/career_map.tscn",
			"wait": 60, "setup": _setup_none, "scroll_bottom": true},
		{"name": "career_hub_mid", "scene": "res://scenes/career_map.tscn",
			"wait": 60, "setup": _setup_none, "scroll_frac": 0.45},
		{"name": "team", "scene": "res://scenes/team.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "player", "scene": "res://scenes/player.tscn",
			"wait": 60, "setup": _setup_player_own},
		{"name": "player_compare", "scene": "res://scenes/player.tscn",
			"wait": 90, "setup": _setup_player_compare},
		{"name": "shop", "scene": "res://scenes/shop.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "settings", "scene": "res://scenes/settings.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "practice", "scene": "res://scenes/practice.tscn",
			"wait": 60, "setup": _setup_practice},
		{"name": "tournament_map", "scene": "res://scenes/tournament_map.tscn",
			"wait": 60, "setup": _setup_none},
		{"name": "player_dev", "scene": "res://scenes/player.tscn",
			"wait": 60, "setup": _setup_player_dev, "scroll_frac": 0.35},
	]


## v2.0: result screen with a reserve selection context, so the selection
## outcome panel is exercised.
func _setup_result_selection() -> void:
	_setup_result()
	# The selection panel reads selection_context/selection from the result
	# dict (match.gd injects them there in the real flow).
	var res: Dictionary = (State.get("screen_params") as Dictionary).get("result", {})
	res["selection_context"] = "reserve"
	res["selection"] = {"selected": false, "chance": 0.34,
		"feedback": "Not selected: your recent match form needs improvement. Score runs or take wickets in reserve matches.",
		"reserve_matches": 3}
	State.set("screen_params", {"result": res, "from": "main_menu"})


## v2.0: mid-journey selection state so the new selection UI shows real,
## representative content in screenshots.
func _setup_selection_mid() -> void:
	State.set("screen_params", {})
	var sel: Dictionary = Save.data["career"]["selection"]
	sel["status"] = "DEBUT_ELIGIBLE"
	sel["selection_chance"] = 0.34
	sel["migrated"] = true
	sel["feedback"] = "Not selected: your recent match form needs improvement. Score runs or take wickets in reserve matches."
	sel["reserve_matches"] = [{"runs": 18, "balls": 14, "wickets": 1,
		"conceded": 20, "score": 0.55, "won": true}]
	sel["form"] = [0.55, 0.42]
	Save.save_game()


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


func _dismiss_ok(n: Node) -> bool:
	if n is Button and (n as Button).text == "OK":
		(n as Button).pressed.emit()
		return true
	for c in n.get_children():
		if _dismiss_ok(c):
			return true
	return false


func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var r := _find_scroll(c)
		if r != null:
			return r
	return null


func _tap_button(n: Node, text: String) -> bool:
	if n is Button and str((n as Button).text) == text:
		(n as Button).pressed.emit()
		return true
	for c in n.get_children():
		if _tap_button(c, text):
			return true
	return false


func _setup_none() -> void:
	State.set("screen_params", {})


func _setup_player_own() -> void:
	var team: Array = Save.data["team"]
	State.set("screen_params", {"player_id": str(team[0]["id"])})


## v3.0: enrich the user's dev data so the profile's Condition &
## Development section and the practice screen show real content.
func _setup_player_dev() -> void:
	_setup_player_own()
	CareerA.ensure_development_migrated()
	var u: Dictionary = CareerA.user_player()
	u["form"] = 0.72
	u["fitness"] = 82
	u["practice"] = [
		{"day": 3, "activity": "batting", "gains": {"batting": 2}},
		{"day": 3, "activity": "fitness", "gains": {}},
		{"day": 2, "activity": "batting", "gains": {"batting": 1}},
	]


func _setup_practice() -> void:
	CareerA.ensure_development_migrated()
	var u: Dictionary = CareerA.user_player()
	u["form"] = 0.72
	u["fitness"] = 82
	u["practice"] = [
		{"day": 3, "activity": "batting", "gains": {"batting": 2}},
	]


func _setup_player_compare() -> void:
	# Teammate profile with the comparison overlay opened (via the real
	# screen_params hook player.gd honors).
	var team: Array = Save.data["team"]
	State.set("screen_params", {"player_id": str(team[1]["id"]), "show_compare": true})


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


## v3.0: toss screen — same config but WITHOUT debug_autoplay, and with
## pitch/weather so the redesigned toss panel shows real conditions.
func _setup_toss() -> void:
	var cfg: Dictionary = _match_cfg()
	cfg.erase("debug_autoplay")
	var crng := GCLRng.new(31337)
	var cond: Dictionary = GCLDevelopment.pick_conditions(crng.next(), crng.next())
	cfg["pitch"] = cond["pitch"]
	cfg["weather"] = cond["weather"]
	State.set("match_config", cfg)


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
