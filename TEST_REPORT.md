# Gully Cricket Legends v1.0.0 — QA Test Report

Date: 2026-10-08. Engine: Godot 4.3-stable (4.3.stable.official.77dcf97d8).
Project builds clean headless (`--headless --path . --quit` → zero script errors).

## How to run

```bash
GODOT=~/tools/godot/Godot_v4.3-stable_linux.x86_64
PROJ=~/workspace/gully-cricket-legends

# Unit / integration suites (headless, deterministic)
$GODOT --headless --path $PROJ --script tests/test_runner.gd

# Scripted full-match playthrough (headless, deterministic)
$GODOT --headless --path $PROJ --script tests/playthrough.gd

# Screenshots, 960x540
xvfb-run -a -s "-screen 0 960x540x24" $GODOT --path $PROJ \
  --rendering-driver opengl3 --resolution 960x540 --script tests/screenshot.gd

# Screenshots, 915x412 (phone landscape)
GCL_SHOT_SUFFIX=_phone xvfb-run -a -s "-screen 0 915x412x24" $GODOT --path $PROJ \
  --rendering-driver opengl3 --resolution 915x412 --script tests/screenshot.gd
```

Note: in a `--script` SceneTree context, bare autoload identifiers (`SaveSystem`,
`Economy`, …) do **not** compile — the runners reach autoloads via
`get_root().get_node("SaveSystem")` etc. (verified: all 6 autoloads present on
frame 1). `class_name` globals (`GCLRng`, `BattingSystem`, …) resolve normally.
`tests/screenshot.gd` avoids `GCLUI` (it references the `AudioMan` autoload and
likewise fails to compile in this context) and builds the match config inline.

## Test counts

**`tests/test_runner.gd`: 79/79 passed** (all suites seeded/deterministic)

| Suite | Assertions | Result |
|---|---|---|
| Timing grades (null→MISS, ±60 PERFECT, ±120 GOOD, ±250 EARLY/LATE, ±251/±900 MISS) | 14 | 14/14 |
| Batting stats (600 balls each: PERFECT vs MISS; GOOD vs EARLY/LATE) | 6 | 6/6 |
| Bowling (400 balls: 0.95 vs 0.20 accuracy Yorker) | 2 | 2/2 |
| Innings (scripted [1,4,W,6,2,0]; all-out; chase ends on target) | 13 | 13/13 |
| MatchEngine (AI-vs-AI 1v1, determinism, chase target) | 8 | 8/8 |
| AI (PARAMS monotonicity; LEGEND outscores EASY over 200 balls) | 6 | 6/6 |
| Economy (spend/purchase/upgrade/rewards/XP/finalize) | 20 | 20/20 |
| Save round-trip (coins + player_name) | 2 | 2/2 |
| Career (stage lock/unlock; tournament win→champion, loss→retry) | 8 | 8/8 |

**`tests/playthrough.gd`: 30/30 passed** — scripted 2-over 1v1 mixing
`resolve_batting` (varied shots/timing, incl. no-input MISS) and
`resolve_bowling` (varied line/length/type/accuracy), then
`Economy.finalize_match` + `Career.record_tournament_match`. Final: 18/1 vs
19/0 in 23 balls, rewards coins=25 xp=32, tournament advanced. No script errors.

**Total: 109/109 assertions passing.**

## Bugs found and fixed (all minimal, verified)

1. **`scripts/ui/field_view.gd` `set_stage()`** — `var feats: Array = g.get("features", [])`
   threw `Trying to assign value of type 'String' to a variable of type 'Array'`
   on every match load (stage data stores `features` as a comma-separated
   String). Fixed to `String.contains("stands"/"stadium")` — same intent,
   verified against all 6 stages' feature strings.
2. **`scripts/ui/match.gd` `_refresh_hud()`** — `int(view.get("target", 0))` threw
   `Invalid call. Nonexistent 'int' constructor` on **every ball of innings 1**
   because `view["target"]` is `null` when no chase is on (`int(null)` throws).
   Fixed with `int(view.get("target", 0) or 0)`. Other `int(get())` call sites
   audited — only `target` is nullable.
3. **`scripts/ui/result.gd`** — coin/XP count-up labels stacked one character
   per line. Root cause: `ThemeHelpers.title_label` sets autowrap, and an
   autowrap Label inside a centered HBox collapses to ~1px min-width (probed:
   min size was literally `(1, 123)`). Fixed with `AUTOWRAP_OFF` on the two
   labels.
4. **`scripts/ui/main_menu.gd`** — 6 nav buttons overflowed 540px height;
   **Shop and Settings were unreachable** (no scroll). Wrapped in a
   ScrollContainer with a centered inner column (verified centered + scrollable
   at both resolutions).
5. **`scripts/ui/settings.gd`** — CheckButton labels rendered **white on cream**
   (unreadable): `make_check` only overrode `font_color`, but a pressed
   CheckButton uses `font_pressed_color` (default-theme white). Now overrides
   all state font colors. Also wrapped the panel in a ScrollContainer — Danger
   Zone was unreachable at 412px height.
6. **`scripts/ui/shop.gd`** — item icon label (autowrap, same collapse as #3)
   painted **over the item name**. Fixed with `AUTOWRAP_OFF` + min width.
7. **`scripts/ui/team.gd`** — lineup position label wrapped as `#` over `1`.
   Fixed with `AUTOWRAP_OFF` + right-align + min width.
8. **`scripts/ui/field_view.gd`** — background painted only the 960px design
   width; on wider-than-16:9 screens (915×412 capture, and real 20:9 phones like
   the Galaxy A52s → 1200×540 canvas) a dark unpainted strip appeared on the
   right. The play area now stays centered and sky/ground/houses/stands paint
   the full visible canvas (derived from the canvas transform, so it is correct
   under any stretch/aspect).

One test-expectation bug (mine, not the game's): I initially asserted
`finalize_match` credits exactly the match coins, but it legitimately also
credits achievement payouts (first_match 50 + first_win 100 + first_six 80).
The test now asserts match coins + achievement bonuses, which is stronger.

## Screenshots (all inspected; `screenshots/`)

Captured under Xvfb + opengl3 at **960×540** and **915×412** (phone landscape),
zero script errors during capture:

| File | 960×540 | 915×412 | Notes |
|---|---|---|---|
| onboarding | ✅ | ✅ | Step 1/9 card, clean, readable |
| main_menu | ✅ (fixed) | ✅ (fixed) | Was: Settings unreachable. Now scrollable, centered |
| match_toss | ✅ | ✅ | Toss/intro renders, HUD correct |
| match_play | ✅ | ✅ (fixed) | Was: dark strip on wide screens. Now fills; PERFECT badge, recent-ball chips, input prompt all render |
| result | ✅ (fixed) | ✅ (fixed) | Was: coin/XP stacked per-character. Now `+40` / `+37 XP` single-line |
| career_map | ✅ | ✅ | Stage cards + challenges, scrolls |
| team | ✅ (fixed) | ✅ (fixed) | Was: `#`/`1` wrapped. Now single line |
| shop | ✅ (fixed) | ✅ (fixed) | Was: icon over name. Now clean rows |
| settings | ✅ (fixed) | ✅ (fixed) | Was: white-on-cream labels + no scroll. Now readable + scrollable |

Not captured: `player.tscn` (My Player detail) and `scoreboard.tscn` — not in the
required list; recommend adding on the next pass.

Environment caveat: this container has **no emoji font**, so all emoji
(🏏🪙🏆…) render as tofu boxes in these screenshots. This is a container
limitation, **not** a game bug — Android renders emoji natively. Emoji
legibility on a real device still needs one on-device check.

## Manual QA checklist

| Check | Status |
|---|---|
| Menu buttons all reachable | ✅ verified headless (scroll); tap-through needs device |
| Onboarding flow (9 steps) | ✅ step 1 verified headless; full tap-through needs device |
| Batting feel (timing windows, gestures) | ✅ logic verified (timing grades + autoplay screenshots); touch feel needs device |
| Bowling feel (needle/length/line) | ✅ logic verified; needle touch feel needs device |
| Career stage unlock | ✅ verified headless |
| Tournament win → champion / loss → retry | ✅ verified headless |
| Shop purchase / equip | ✅ verified headless |
| Save / restore round-trip | ✅ verified headless |
| Offline (no network calls) | ✅ verified by grep over scripts + scenes (zero network refs) |
| Audio (SFX + music loop) | ⚠️ code-reviewed (synthesized WAV, dummy driver headless); audible check needs device |
| On-device install / launch / play | ❌ needs device (no emulator possible in this env: no KVM) |

## Balance notes (measured, deterministic seeds)

- Timing dominates as designed (NORMAL, even 50/50 stats): avg/ball
  PERFECT **2.86**, GOOD **2.01**, EARLY **1.35**, LATE **1.31**, MISS **0.30**;
  wicket rate MISS **26.2%** vs PERFECT **2.5%**. Hard rule holds with margin.
- Bowling accuracy matters: Yorker at 0.95 → **1.45** runs/ball, **14.0%**
  wickets; at 0.20 → **1.94** runs/ball, **5.5%** wickets.
- AI difficulty is skill-only (no result manipulation): LEGEND outscores EASY
  **2.71 vs 2.03** avg/ball over 200 balls (paired seed); PARAMS strictly
  monotonic EASY→LEGEND on timing_error, fielding_error, mistake_rate
  (decreasing) and aggression (increasing).
- Economy: 1v1 EASY win ≈ 100 coins, loss ≈ 20; LEGEND win ≈ 180 (diff mult
  2.0×). Upgrade cost 150 × level; XP curve 100/250/400… per level.
- Full AI-vs-AI 1v1 (EASY, seed 424242): 24 balls, AI won 32→31; deterministic
  across runs; chase target correctly set to innings-1 + 1.

No gameplay-balance code was changed — all fixes above are bug/layout fixes.
