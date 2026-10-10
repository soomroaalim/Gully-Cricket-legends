extends Node
## Autoload: Career. Stages, unlocking, tournaments, random events.

const StagesData = preload("res://scripts/data/stages.gd")
const EventsData = preload("res://scripts/data/events.gd")


func stages() -> Array:
	return StagesData.all()


func stage_by_id(sid: String) -> Dictionary:
	return StagesData.by_id(sid)


func current_stage() -> Dictionary:
	var idx: int = clampi(int(SaveSystem.data["career"].get("stage_index", 0)), 0, stages().size() - 1)
	return stages()[idx]


func is_unlocked(sid: String) -> bool:
	return SaveSystem.data["career"]["unlocked"].has(sid)


func is_completed(sid: String) -> bool:
	return SaveSystem.data["career"]["completed"].has(sid)


func tournament_state(tid: String) -> Dictionary:
	var t: Dictionary = SaveSystem.data["career"]["tournaments"].get(tid, {})
	if t.is_empty():
		return {"round": 0, "wins": 0}
	return t


func _stage_for_tournament(tid: String) -> Dictionary:
	for s in stages():
		if str(s["tournament"].get("id", "")) == tid:
			return s
	return {}


func record_tournament_match(tid: String, won: bool) -> Dictionary:
	var stage: Dictionary = _stage_for_tournament(tid)
	if stage.is_empty():
		return {"champion": false, "next_round_name": "", "eliminated": false}
	var rounds: Array = stage["tournament"]["rounds"]
	var ts: Dictionary = tournament_state(tid)
	var round_idx: int = int(ts.get("round", 0))
	if not won:
		# Losing never destroys progress: retry the same round.
		SaveSystem.save_game()
		return {"champion": false, "next_round_name": str(rounds[round_idx]), "eliminated": false}
	round_idx += 1
	var champion: bool = round_idx >= rounds.size()
	ts["round"] = round_idx
	ts["wins"] = int(ts.get("wins", 0)) + 1
	SaveSystem.data["career"]["tournaments"][tid] = ts
	SaveSystem.save_game()
	var next_name: String = "" if champion else str(rounds[round_idx])
	return {"champion": champion, "next_round_name": next_name, "eliminated": false}


func on_tournament_won(stage_id: String) -> Dictionary:
	var stage: Dictionary = stage_by_id(stage_id)
	var coins_r: int = 0
	var xp_r: int = 0
	if not stage.is_empty():
		coins_r = int(stage["tournament"].get("prize", 0))
		xp_r = int(stage["tournament"].get("prize_xp", 0))
		Economy.add_coins(coins_r, "tournament")
		Economy.add_xp(xp_r)
		var tid: String = str(stage["tournament"].get("id", ""))
		if tid != "" and not SaveSystem.data["career"]["trophies"].has(tid):
			SaveSystem.data["career"]["trophies"].append(tid)
		Economy.unlock_achievement("first_trophy")
		if stage_id == "championship":
			Economy.unlock_achievement("champion")
		complete_stage(stage_id)
	SaveSystem.save_game()
	return {"coins": coins_r, "xp": xp_r}


func complete_stage(sid: String) -> Dictionary:
	var career: Dictionary = SaveSystem.data["career"]
	var first_time: bool = not career["completed"].has(sid)
	if first_time:
		career["completed"].append(sid)
	var stage: Dictionary = stage_by_id(sid)
	var unlocked_next: bool = false
	var coins_r: int = 0
	if not stage.is_empty():
		var next_idx: int = int(stage.get("index", 0)) + 1
		if next_idx < stages().size():
			var next_id: String = str(stages()[next_idx].get("id", ""))
			if not career["unlocked"].has(next_id):
				career["unlocked"].append(next_id)
				unlocked_next = true
			career["stage_index"] = maxi(int(career.get("stage_index", 0)), next_idx)
		if first_time:
			coins_r = int(stage.get("unlock_reward", 0))
			if coins_r > 0:
				Economy.add_coins(coins_r, "stage_unlock")
	SaveSystem.save_game()
	return {"unlocked_next": unlocked_next, "coins": coins_r}


func maybe_event(rng: GCLRng) -> Dictionary:
	var events: Array = EventsData.all()
	if events.is_empty():
		return {}
	if rng.next() > 0.25:
		return {}
	var seen: Array = SaveSystem.data["career"]["events_seen"]
	var last: String = str(seen.back()) if not seen.is_empty() else ""
	var pick: Dictionary = events[rng.int_range(0, events.size() - 1)]
	if str(pick.get("id", "")) == last and events.size() > 1:
		pick = events[rng.int_range(0, events.size() - 1)]
	return pick


func add_active_effect(key: String) -> void:
	var eff: Array = SaveSystem.data["career"]["active_effects"]
	if not eff.has(key):
		eff.append(key)
	SaveSystem.save_game()


func active_effects() -> Array:
	return SaveSystem.data["career"]["active_effects"]


func clear_active_effect(key: String) -> void:
	var eff: Array = SaveSystem.data["career"]["active_effects"]
	eff.erase(key)
	SaveSystem.save_game()
