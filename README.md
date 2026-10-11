# Gully Cricket Legends v4.0

Offline 2D arcade street-cricket game for Android, built with **Godot 4.3-stable + GDScript**.

Start with friends in a Soomra Colony street, win matches, earn coins + XP, recruit and
upgrade players, buy equipment, unlock new areas (Mithi → Badin → Larkana → Hyderabad → Karachi),
win tournaments, and become the **Sindh Gully Cricket Champion**.

**v4.0 — Six Offline Career Events**: rain-affected matches (real engine effects:
shortened overs, slower outfield, extra swing, toss-screen warning), team challenges
with scaled rewards + rematch offers, persistent rival teams (W/L records, difficulty
scales with your tier, decisive rivalry matches), six target-challenge types (chase,
defend, boundaries, wickets, wicketless runs, bowling economy) with claim-once rewards,
tournament invitations that start REAL playable tournaments, and legendary-player
training granting an explicitly-labeled bonus practice session. All on a deterministic
scheduler (same save + day → same event; loading never rerolls).

- 100% offline: no accounts, no internet, no AI APIs, no analytics, no real money.
- All progress saves locally (`user://gcl_save_v1.json`).
- Landscape 960×540, stretch `canvas_items` / `expand` (covers 16:9 → 20:9 phones).

## Run it

Needs the Godot 4.3-stable editor (see `~/tools/godot/` on the dev machine):

```bash
# Play in the editor (windowed)
/tools/godot/Godot_v4.3-stable_linux.x86_64 --path .

# Headless smoke check (validates all scripts)
/tools/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . --quit
```

## Tests

```bash
# Headless unit tests (269 assertions: batting, bowling, innings, match engine,
# AI difficulty, economy, save round-trip, career unlocks, selection, tiers,
# development, + 52 new v4.0 career-event checks: determinism, cooldowns,
# rain engine effects, reward idempotency, save/load round-trips, target
# evaluation, rival records, legendary bonus, unlock chain, migration safety)
/tools/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/test_runner.gd

# Scripted full-match playthrough
/tools/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/playthrough.gd
```

See [TEST_REPORT.md](TEST_REPORT.md) for counts and the manual QA checklist.

## Build the Android APK

Prereqs (dev machine): Android SDK (`~/android-sdk`), JDK 17, release keystore at
`~/.keystores/gully-cricket-release.keystore` (never committed; password in
`~/.keystores/gully-cricket-release.pwd`, never committed).

```bash
~/apkbuild/gcl-release.sh
# → build/gully-cricket-legends-v1.0.0.apk (aligned, release-signed, verified)
```

The script injects the keystore password into a temporary copy of
`export_presets.cfg` and restores the repo file afterwards, so no secret ever
lands in git. Package id: `com.soomroaalim.gullycricket`.

## Project structure

```
project.godot            # 960x540 landscape, autoloads, GL Compatibility
export_presets.cfg       # Android preset (passwords injected at export time only)
CONTRACTS.md             # integration contracts between modules
scripts/
  core/      # save_system, game_state, rng (seeded), config  [autoloads: SaveSystem, GameState]
  gameplay/  # batting_system, bowling_system, fielding_ai, innings, match_engine (pure logic)
  ai/        # ai_director (EASY/NORMAL/HARD/LEGEND param tables, seeded)
  data/      # stages, players, shop_items, achievements, challenges, events
  career/    # career_manager (stages, unlocking, tournaments, events)  [autoload: Career]
  economy/   # economy (coins/XP/shop/upgrades/recruit/rewards)          [autoload: Economy]
  ui/        # router [autoload: Router] + all screens + theme helpers
  audio/     # audio_manager (synthesized SFX)                            [autoload: AudioMan]
scenes/      # main_menu, onboarding, match, scoreboard, result, career_map,
             # team, player, shop, settings
assets/sfx/  # 13 WAVs synthesized by tools/make_sfx.py (no audio files shipped in)
tools/       # make_sfx.py (stdlib-only WAV synthesizer)
tests/       # test_runner.gd, playthrough.gd, screenshot.gd
screenshots/ # 18 captures, 960x540 + 915x412
```

## Game design (condensed)

- **Batting**: tap / swipe-left / swipe-right / swipe-up; timing vs ball arrival —
  PERFECT (±60ms) / GOOD (±120ms) / EARLY / LATE / MISS. Timing dominates outcomes.
- **Bowling**: pick line (Off/Middle/Leg), length (Yorker/Good/Short), delivery
  (Normal/Fast/Bouncer/Slower/Yorker), then a timing-needle minigame for accuracy.
- **Fielding**: AI-only, with difficulty-scaled mistakes.
- **Modes**: 1v1 (2 overs), 2v2 (3 overs), 5v5 / 6-over gully (6 overs).
- **AI**: rule-based, seeded, four difficulties; never manipulates results.
- **Career**: 7 stages (Soomra Colony → Mithi → Badin → Larkana → Hyderabad →
  Karachi → Sindh Championship) with themed grounds, QF→SF→F tournaments,
  locked/unlocked visuals; losing never destroys progress.
- **Career events (v4.0)**: deterministic scheduler — at most one major event
  pending, per-type cooldowns, no back-to-back repeats, accept/decline/outcome
  persisted. Rain shortens overs and slows the outfield (toss warning shown).
  Team challenges and rivalries pay coins/XP/reputation scaled by difficulty;
  losses earn a consolation + rematch offer. Target challenges (chase, defend,
  boundaries, wickets, wicketless, economy) pay claim-once rewards. Tournament
  invitations start real tournaments (entry requirements enforced). Legendary
  training grants +1 explicitly-labeled bonus practice session beyond the
  3/day budget.
- **Economy**: fictional coins + XP; shop (bats/balls/jerseys/shoes/caps),
  recruitment tiers (50/60/70/80+), player upgrades, challenges, achievements.

## Known limitations

See [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).
