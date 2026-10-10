# Gully Cricket Legends — Integration Contracts (Godot 4.3 / GDScript)

Project: `~/workspace/gully-cricket-legends/`. Godot 4.3-stable, GDScript only,
GL Compatibility renderer, 960×540 landscape, stretch `canvas_items`/`expand`.
100% offline. No AI APIs, no network, no real money, no secrets in repo.

## Autoloads (registered in project.godot — DO NOT rename)

| Name | Script | Purpose |
|---|---|---|
| `SaveSystem` | `res://scripts/core/save_system.gd` | `data: Dictionary`, `load_game()`, `save_game()`, `reset_game()`, `coins()`, `add_coins(n)`, `setting(key)` |
| `GameState` | `res://scripts/core/game_state.gd` | `screen_params`, `match_config`, `last_result`, `vibrate(ms)` |
| `Economy` | `res://scripts/economy/economy.gd` | coins/XP/shop/upgrades/recruit/rewards |
| `Career` | `res://scripts/career/career_manager.gd` | stages/unlocking/tournaments/events |
| `AudioMan` | `res://scripts/audio/audio_manager.gd` | `play(name)`, `set_music_enabled(b)`, `set_sfx_enabled(b)`, `start_music()`, `stop_music()` |
| `Router` | `res://scripts/ui/router.gd` | `show(id, params)`, `replace(id, params)`, `back() -> bool`, `reset_to(id)` |

Helpers with `class_name`: `GCLConfig` (scripts/core/config.gd), `GCLRng`
(scripts/core/rng.gd — seeded RNG, `GCLRng.new(seed)`).

## Player Dictionary schema

```
{ id, name, role ("Batter"|"Bowler"|"AllRounder"|"Wicketkeeper"),
  batting, bowling, fielding, speed, stamina (1..99),
  overall, level, xp, avatar (int index), is_user (bool),
  jersey, cap, shoes, bat_skin (int cosmetic indexes) }
```

## MatchEngine (`scripts/gameplay/match_engine.gd`, `class_name MatchEngine extends RefCounted`)

Signals: `ball_completed(outcome: Dictionary, view: Dictionary)`,
`innings_ended(view: Dictionary)`, `match_ended(result: Dictionary)`.

- `setup(config: Dictionary)` — config keys: `mode`, `overs`, `max_wickets`,
  `stage_id`, `stage_name`, `difficulty`, `player_team_name`, `ai_team_name`,
  `player_team: Array[Dictionary]`, `ai_team: Array[Dictionary]`,
  `user_player_id: String`, `user_bats_first: bool`, `seed: int`,
  optional `tournament_id`, `challenge_id`.
- `ai_bowl_delivery() -> Dictionary` `{line, length, type, flight_ms, drift, bounce}`
- `resolve_batting(shot: String, timing_offset_ms: float) -> Dictionary`
  shot ∈ "tap"|"swipeLeft"|"swipeRight"|"swipeUp"|"" ("" = no input → MISS).
- `resolve_bowling(delivery: Dictionary) -> Dictionary`
  delivery `{line, length, type, accuracy 0..1}`.
- `simulate_ai_ball() -> Dictionary`
- `is_player_striker() -> bool`, `is_player_bowling() -> bool`
- `current_view() -> Dictionary` `{innings, runs, wickets, balls, overs_total,
  max_wickets, overs_text, target, striker_name, striker_runs, striker_balls,
  non_striker_name, bowler_name, batting_team_name, bowling_team_name,
  recent_balls: PackedStringArray}`
- `is_innings_over() -> bool`, `is_match_over() -> bool`
- `start_next_innings()`
- `get_result() -> Dictionary` `{winner ("player"|"ai"|"tie"), player_runs,
  player_wickets, ai_runs, ai_wickets, player_overs, ai_overs, player_won,
  tied, coins (0 — filled by Economy), xp (0), new_unlocks: [],
  achievements_unlocked: [], top_scorer {name,runs,balls},
  best_bowler {name,wickets,runs}, player_of_match,
  perf {sixes, fours, wickets}}`
- `scorecard() -> Dictionary` `{innings: [{team_name, batters: [{name,runs,balls,fours,sixes,out_str}],
  bowlers: [{name, overs_text, runs, wickets}], total, wickets, overs_text}]}`

Outcome Dictionary: `{runs: int (0|1|2|3|4|6), wicket: bool, timing: String
("PERFECT"|"GOOD"|"EARLY"|"LATE"|"MISS"), description: String,
shot_quality: float, lofted: bool}`.

Timing: `BattingSystem.grade_timing(offset_ms: Variant) -> String`
(null → "MISS"; |offset| ≤ 60 PERFECT; ≤ 120 GOOD; ≤ 250 EARLY/LATE by sign).
HARD RULE: good timing must consistently beat bad timing (tests assert this
statistically over 600 balls).

`BattingSystem.resolve(params: Dictionary) -> Dictionary` with params
`{batter, bowler, delivery {line,length,type}, shot, timing, rng: GCLRng,
fielding_avg: float, difficulty: String}`.
`BowlingSystem.resolve(params) -> Dictionary` with params
`{delivery {line,length,type,accuracy}, batter, bowler, rng, difficulty}`.
`AIDirector` (`class_name`, scripts/ai/ai_director.gd):
`const PARAMS: Dictionary` keyed by difficulty with
`{timing_error_ms, shot_skill, bowling_accuracy, fielding_error,
mistake_rate, aggression, ai_batting_boost, ai_bowling_boost}` (monotonic
EASY→LEGEND; AI never manipulates results, only plays via these params);
`static func choose_delivery(difficulty, rng, bowler) -> Dictionary`;
`static func ai_batting_offset(difficulty, rng) -> float`;
`static func ai_shot(difficulty, rng, delivery) -> String`.

## Economy autoload API

`coins() -> int`, `add_coins(n, reason := "")`, `spend(n) -> bool`,
`add_xp(n) -> int` (returns levels gained),
`upgrade_cost(player) -> int` (= 150 × level),
`upgrade_player(id) -> bool`, `purchase(item_id) -> bool`,
`equip(item_id)`, `recruit_player(def_id) -> bool`,
`effective_stats(p) -> Dictionary`, `apply_effective(p) -> Dictionary`,
`rewards_for_match(result, mode, difficulty) -> Dictionary {coins, xp}`,
`finalize_match(result, mode, difficulty) -> Dictionary`,
`unlock_achievement(id) -> bool`.

## Career autoload API

`stages() -> Array[Dictionary]`, `stage_by_id(id) -> Dictionary`,
`current_stage() -> Dictionary`, `is_unlocked(id) -> bool`,
`is_completed(id) -> bool`,
`tournament_state(tid) -> Dictionary {round, wins}`,
`record_tournament_match(tid, won) -> Dictionary {champion, next_round_name, eliminated}`,
`on_tournament_won(stage_id) -> Dictionary {coins}`,
`complete_stage(id) -> Dictionary {unlocked_next, coins}`,
`maybe_event(rng: GCLRng) -> Dictionary` ({} if none),
`add_active_effect(key)`, `active_effects() -> Array`, `clear_active_effect(key)`.

Stage Dictionary: `{id, name, index, description, difficulty, ai_overall: [min,max],
team_names: [], ground: {sky: [c1,c2], ground: Color hex String, accent, label, features},
tournament: {id, name, rounds: [], prize, prize_xp}, unlock_reward, icon}`.
6 stages: soomra_colony → mithi → badin → larkana → hyderabad → championship.

## Data modules (class_name, static data)

- `GCLStages` (scripts/data/stages.gd): `static func all() -> Array`, `static func by_id(id)`.
- `GCLPlayers`: `static func make_starter_team(user_name, avatar) -> Array`,
  `static func generate_opponent_team(stage, rng) -> Array`,
  `static func recruits() -> Array` (defs `{id,name,role,overall,price,min_stage_index,avatar}`).
- `GCLShop`: `static func items() -> Array`, `static func by_id(id) -> Dictionary`
  (item `{id, category, name, price, description, bonus: Dictionary, tier, icon}`).
- `GCLAchievements`: `static func all() -> Array`, `by_id(id)`.
- `GCLChallenges`: `static func all() -> Array`.
- `GCLEvents`: `static func all() -> Array` (event `{id,title,text,icon,effect,apply}`).

## AudioMan autoload

`play(name: String)` — names: hit, bounce, wicket, crowd, click, win, loss,
coin, unlock, six, four, ball. `set_music_enabled(b)`, `set_sfx_enabled(b)`,
`start_music()`, `stop_music()`. Never errors; silent no-op before ready.
WAVs synthesized by `tools/make_sfx.py` into `assets/sfx/`.

## Scenes (`scenes/*.tscn`, 960×540, Control root)

main_menu, onboarding, match (gameplay Node2D + HUD CanvasLayer), scoreboard,
result, career_map, team, player, shop, settings. Screen scripts in
`scripts/ui/`. Router ids: "main_menu","onboarding","match","scoreboard",
"result","career","team","player","shop","settings".

Android back: in `_notification(what)` handle `NOTIFICATION_WM_GO_BACK_REQUEST`
(modal→close, screens→Router.back(), match→pause menu, main_menu→exit via
`get_tree().quit()` only if OS not web... on Android, finish()).

## Testing

`tests/test_runner.gd` — headless: `godot --headless --script tests/test_runner.gd`
or a SceneTree script printing PASS/FAIL counts. Covers: batting distribution
(good timing beats bad), bowling resolution, innings engine, AI difficulty
monotonicity, economy math, save round-trip, career unlocks.
