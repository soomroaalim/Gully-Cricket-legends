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

## v1.1 — Main Menu Redesign (2026-10-10)

Scope: main menu only. No gameplay, economy, career, or save-format changes.
Reference video never arrived; design follows the PRD's written direction.

- Project opens headless with **0 script errors**.
- Existing suites re-run after the change: **79/79** (`tests/test_runner.gd`)
  and **30/30** (`tests/playthrough.gd`) — no regressions.
- Screenshots captured under xvfb (opengl3) at **960x540** and **915x412**,
  inspected by hand: no clipped text/controls, no overlap, no horizontal
  scroll, all touch targets >= 52px, layout balanced on both aspects.
- New art is 100% procedural GDScript (`scripts/ui/menu_art.gd`):
  drawn vector icons (no emoji), animated stadium-vista backdrop
  (dusk sky, floodlights, grandstand crowd, striped outfield, boundary rope,
  distant pitch), profile medallion, sports buttons, feature cards.
- Navigation verified by code path: Play -> mode cards -> match scene;
  Career/Player/Team/Shop -> existing scenes; Settings via gear button;
  Android back closes overlay first, exits at root; double-tap guarded.
- No APK/AAB generated for this task (per PRD); source-only change.

## v1.2 — Main Menu Redesign & Career Navigation Architecture (2026-10-10)

Scope: menu + navigation + Career hub + Team/Profile/Comparison UI +
display-layout root-cause fix. No batting/bowling/AI/physics/match-rules/
economy-balancing/tournament-balancing changes. No APK/AAB generated (per
PRD). Reference video/screenshot from the user never arrived; the display
investigation below is from fresh xvfb captures, not the user's media.

### Menu changes
- `scripts/ui/main_menu.gd`: hero PLAY GULLY CRICKET + exactly 3 nav cards
  (Career, Shop, Settings). Top-level My Player / My Team buttons removed —
  both now live inside the Career hub. Profile strip kept (avatar, name,
  Lv, stage, coins, trophies, gear) with real save data only; fixed the
  trophies chip to read `career.trophies` (it previously read a missing
  top-level `trophies` key, so it always showed 0).
- Content column changed from fixed 404px (`offset_right=452`) to
  proportional anchors (`anchor_right≈0.47`, expand-fill children) so
  ultrawide aspects get real content width.

### Display root cause + fix
- User symptom (reported, media never arrived): menu as narrow horizontal
  strip with black regions + clipped cards.
- Reproduced on xvfb at 1200x540 (20:9) with v1.1 code: the vista fills the
  screen (project.godot is canvas_items + expand — no letterboxing, no
  black bars on desktop), but the fixed 404px menu column strands all
  content in a narrow left strip, and the bottom card row clips below the
  viewport edge (column content taller than the 412px available at 540px
  height with the 108px top offset). These are the verified real causes;
  fixed by the proportional column + expand-fill cards/hero above.
- The on-device "black regions" could not be reproduced in this environment
  (no device, emulator impossible — no KVM); desktop captures at 16:9,
  18:9, 19.5:9 and 20:9 are full-bleed with no black regions. Export preset
  already sets immersive_mode=true with no aspect caps.
- Acceptance: viewport filled at all 4 aspects, all cards visible/unclipped,
  touch targets ≥48px, readable type (verified by hand-inspection below).

### Career hierarchy
- Career hub (`scripts/ui/career_map.gd`, scene id "career" unchanged): one
  scrollable screen — header (‹ Back, Career, coins pill), OVERVIEW card
  (current stage name/icon, level + XP bar, team name, stages completed/
  total, trophies count, W/L/T record from stats), NAV cards (My Team →
  "team", My Player → "player" with own id, Stages / Challenges scroll to
  their sections), STAGES section (existing stage cards + detail/bracket
  panels, logic untouched), CHALLENGES section (existing rows), MATCHES &
  RESULTS (real `recent_results` feed; "No matches played yet" when empty),
  PROGRESSION (achievements unlocked count + list, trophies with names).
- Back hierarchy: player → team → career → main_menu (Router stack);
  comparison overlay closes to player; any modal closes before its parent
  navigates; Android back follows the same order on every touched screen.
  Verified: no code outside the career hub / team cards navigates directly
  to "team"/"player" anymore.

### Roster + comparison
- Team screen (`scripts/ui/team.gd`): roster cards with AvatarMedallion
  (initial + jersey color), name + [YOU] badge (own card highlighted),
  role, OVR, mini BAT/BOWL/FIELD bars, Lv, lineup position, captain star.
  Tap → `Router.show("player", {"player_id": pid})` (changes nothing).
  Recruit section unchanged. Upgrade/Make Captain/Move Up/Down relocated
  to the player profile screen (not removed).
- Player screen (`scripts/ui/player.gd`): honors `screen_params["player_id"]`
  (defaults to the user's player). Own profile keeps rename/kit/equipment/
  stat bars + gains the management buttons. Teammate profile: identity card
  (no rename/kit), raw stat bars (equipment is the user's only — never
  folded into a mate's numbers), management buttons, "Compare with me".
  Opening a teammate profile changes nothing.
- Comparison overlay: OptionButton teammate picker ("Recruit teammates to
  compare" when the roster has only the user), side-by-side rows for
  Overall/Batting/Bowling/Fielding/Level with value + bar per side; leader
  marked "▲" + genuinely bold value (FontVariation embolden, never
  color-alone); ties "=". Read-only. Pure-logic
  `static func compare_rows(user, mate) -> Array` handles missing keys
  safely (leader "na").

### Files changed
- `scripts/core/save_system.gd`: new top-level default `recent_results: []`
  (backward compatible via `_merge()`).
- `scripts/economy/economy.gd`: `finalize_match` prepends
  `{outcome: W/L/T, line: "145/6 vs 140/8", mode}` to `recent_results`,
  capped at 5.
- `scripts/ui/main_menu.gd`, `career_map.gd`, `team.gd`, `player.gd`:
  rewrites per above.
- `tests/test_runner.gd`: +23 assertions (compare_rows leaders incl. ties
  and missing attrs; recent_results capping/W/L/T/line incl. old-save
  back-compat; exactly one `is_user` in the starter roster).
- `tests/screenshot.gd`: captures for career hub, team, player (own),
  player+comparison overlay (via real `screen_params`); recent-results feed
  seeded with two real `finalize_match` calls.

### Test results
- Project opens headless with 0 script errors (all 8 touched/related
  scripts parse-checked; fixed one warnings-as-errors parse failure in
  `career_map.gd`: `var mark := {...}.get(...)` inferring Variant).
- `tests/test_runner.gd`: **102/102 passed** (79 carried + 23 new).
- `tests/playthrough.gd`: **30/30 passed** — no regressions.

### Screenshots (all hand-inspected; `screenshots/`, suffixed by aspect)
- Captured under xvfb (opengl3) at **960x540 (16:9)**, **1080x540 (18:9)**,
  **1170x540 (19.5:9)**, **1200x540 (20:9)**: menu, career hub (top +
  scrolled-to-bottom), team, player (own), player + comparison overlay,
  plus the unchanged screens. 0 script errors on every run.
- Menu: full-bleed vista at all 4 aspects (no black regions on desktop);
  hero + 3 cards fully visible, no clipping; touch targets ≥ 48px.
  (v1.1 baseline at 20:9 showed the fixed 404px column stranding content in
  a narrow left strip with the bottom card row clipped — the reported
  symptom, now fixed by the proportional column + reduced vertical
  footprint.)
- Career hub: overview card (real stage/XP/team/progress/record), 4 nav
  cards, stages, challenges, Matches & Results with real seeded entries
  ("[W] 145/6 vs 140/8 — 1v1"), Progression with real achievements/trophies.
- Team: roster cards with medallions, [YOU] highlight, mini BAT/BOWL/FIELD
  bars, #pos + › chevron clear of the scrollbar (fixed: anchored children
  ignore StyleBox content margins, so the row is inset via offsets; also
  restored the old AUTOWRAP_OFF on the position label).
- Player: own profile (rename/kit/equipment/stats + management buttons);
  teammate profile + comparison overlay (picker, ▲ leaders bold, "= "
  ties, Close). Emoji tofu in headless captures is a missing-font artifact
  of xvfb only; outcome marks use plain [W]/[L]/[T] text so they render
  everywhere.

## v2.0 — Career Mode & Player Selection System (2026-10-10)

Date: 2026-10-10. Engine: Godot 4.3-stable. Project opens headless with
zero script errors. No APK generated (per PRD).

### New suites (tests/test_runner.gd): 147/147 pass (was 102)
- `_suite_selection` (21 checks): new career starts RESERVE at 20% base
  chance; chance is a pure read (stable across reads — never rerolled on
  screen open); great reserve performance raises it, poor lowers it; the
  seeded draw is deterministic from (player id, match index); role-fit
  respects XI vacancies; ~20% selection rate over 200 seeded rolls (no
  countdown/auto-select); debut records real performance and promotes to
  MAIN_XI; one bad match never drops (3+ matches with form < 0.25 does);
  pre-v2.0 saves migrate to MAIN_XI (grandfathered); brand-new saves start
  RESERVE; status + chance survive save/load round-trip; feedback names the
  actual weakest factor.
- `_suite_tiers` (17 checks): colony generates 20 unique teams, 5-player
  rosters, no team name equals its bare location, deterministic per seed;
  6 tiers defined with honest counts (colony/city/district/national 20,
  provincial 5, international men's + women's pathways); city+ scaffolded
  as not-playable; promotion checklist gates (MAIN_XI + Soomra Cup + 3
  main-XI matches) then advances colony -> city.
- `_suite_user_performance` (3 checks): engine's user_performance() (runs,
  balls, wickets, conceded) matches the innings bat/bowl stat tables.
- `_suite_compare_rows` extended: 7 rows (adds Speed, Stamina) with leaders.

### Screenshots (xvfb + opengl3, hand-inspected, no clipping/overlap)
- 960x540: 13 captures incl. new `result_selection` (selection outcome
  panel on the result screen).
- 915x412 (`_phone`): 12 captures.
- career_hub at 16:9 / 18:9 / 19.5:9 / 20:9: selection journey card,
  ladder card and promotion checklist render full-bleed, no overlap.
- Verified: team screen Main XI vs Reserves sections with the user's live
  status badge; comparison overlay with Form/Status rows + selection
  insight panel; debut announcement overlay hook in career hub.

### Notes
- The `--script` test context prints a pre-existing, non-fatal
  `Identifier not found: AudioMan` compile note for gcl_ui.gd (bare
  autoload identifiers don't resolve at compile time in script-main-loop
  mode; they resolve at runtime — the GCLUI-dependent suites pass). It
  predates v2.0 and does not affect results.
