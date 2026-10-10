extends Node
## Autoload: SaveSystem. Local JSON persistence, fully offline.
## Path: user://gcl_save_v1.json. No network, no accounts.

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://gcl_save_v1.json"

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": "",
		"avatar": 0,
		"coins": 150,
		"xp": 0,
		"level": 1,
		"team": [],
		"lineup": [],
		"captain_id": "",
		"equipment_owned": [],
		"equipped": {},
		"career": {
			"stage_index": 0,
			"unlocked": ["soomra_colony"],
			"completed": [],
			"trophies": [],
			"tournaments": {},
			"events_seen": [],
			"active_effects": [],
			# v3.0: deterministic career clock. +1 per match played; Rest
			# advances a day without a match. NEVER the device clock.
			"career_day": 1,
			# v3.0 practice budget: 3 sessions per career day.
			"practice": {"day": 0, "sessions": 0},
			"dev_migrated": false,
			# v2.0 selection journey: reserve -> debut -> main XI.
			# Old saves are grandfathered to MAIN_XI by Career.ensure_selection_migrated().
			"selection": {
				"status": "RESERVE",
				"selection_chance": 0.20,
				"reserve_matches": [],
				"mainxi_matches": 0,
				"debut": {},
				"form": [],
				"feedback": "",
				"migrated": false,
				"debut_announced": false,
			},
			# v2.0 competition ladder (tiers are data-driven; see GCLTiers).
			"ladder": {"tier": "colony", "promoted": []},
		},
		"achievements": [],
		"challenges_done": [],
		"recent_results": [],
		"settings": {"music": true, "sfx": true, "vibration": true, "language": "en"},
		"onboarding_done": false,
		"stats": {
			"matches": 0, "wins": 0, "losses": 0, "ties": 0,
			"runs": 0, "wickets": 0, "sixes": 0, "fours": 0,
			"best": 0, "coins_earned": 0,
		},
	}


func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k in over.keys():
		if over[k] is Dictionary and out.get(k) is Dictionary:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = default_data()
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		data = default_data()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		data = _merge(default_data(), parsed)
		data["version"] = SAVE_VERSION
	else:
		data = default_data()


func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func reset_game() -> void:
	data = default_data()
	save_game()


## Convenience accessors used across the game.
func coins() -> int:
	return int(data.get("coins", 0))


func add_coins(n: int) -> void:
	data["coins"] = int(data.get("coins", 0)) + n
	data["stats"]["coins_earned"] = int(data["stats"].get("coins_earned", 0)) + maxi(n, 0)


func setting(key: String) -> Variant:
	return data["settings"].get(key)
