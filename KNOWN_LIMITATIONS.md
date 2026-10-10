# Gully Cricket Legends v1.0.0 — Known Limitations

Honest list of what v1.0.0 does not do, by design or by constraint.

## Simplified gully rules
- **No wides, no-balls, or leg-byes.** Every delivery counts as a legal ball;
  extras do not exist. This is the documented gully-rules simplification
  (`GCLInnings`, `MatchEngine`).
- **1v1 "lives" rule:** with a one-player batting order, the batter keeps
  striking after dismissal until `max_wickets` fall (street rule, by design).
- **No DLS, no super overs.** Ties stand as ties.
- **No innings declarations, retirements, or rain rules.**

## AI & simulation
- **AI fielding is animation-level.** Ball outcomes are resolved statistically
  by `FieldingAI` (drops/misfields/run-outs from difficulty params); the
  fielders you see chasing are cosmetic and do not affect the result.
- **AI difficulty is skill knobs only** (timing error, shot choice, delivery
  choice, fielding mistakes, stat boosts ≤ 1.22×). The AI never manipulates
  results — but it also never learns or adapts mid-match.
- **No ball-by-ball commentary variety beyond the template pool**; descriptions
  repeat over long sessions.
- Opponent teams are generated per match from stage overall ranges — no
  persistent rival squads or player form/injuries.

## Presentation
- **Music is a single synthesized loop** (`assets/sfx/music_loop.wav`); no
  licensed tracks, no dynamic/adaptive music.
- **All art is procedural** (flat-color vector-style drawing, system fonts).
  Emoji are used for icons and render via the device's system emoji font —
  verified as tofu in font-less containers, fine on real Android.
- **Landscape only.** The match field view centers the 960×540 design and
  fills wider canvases, but portrait is not supported.

## Platform & scope
- **Offline only — no online multiplayer**, no leaderboards, no cloud saves.
  Saves are local JSON (`user://gcl_save_v1.json`).
- **No real money.** Coins/XP are fictional and earned only through play.
- **No analytics or tracking** of any kind.
- **One language** (English). The language setting exists but only English is
  available.
- **Accessibility:** no color-blind mode, no text-size option, no screen-reader
  labels beyond defaults.

## Testing caveats (this environment)
- All QA was done headless or under Xvfb (llvmpipe). **On-device verification
  (install, launch, touch feel, audio, emoji rendering, performance on low-end
  phones) has not been done** — no Android emulator is possible here (no KVM)
  and no APK has been built from this tree yet.
- `GameState.match_config["debug_autoplay"]` is a shipped debug seam that plays
  matches automatically; harmless, but it is a dev affordance left in v1.0.0.
- `player.tscn` (My Player detail) and `scoreboard.tscn` were not screenshot-
  reviewed in this pass.
