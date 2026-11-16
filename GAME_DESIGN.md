# Tap N Go: Design (revised)

## Core loop
- Hold anywhere on screen to move **up** the portrait track. Release to freeze instantly.
- Two steering buttons sit in the bottom corners. They move the player left / right at any time, even while frozen, and work together with a second finger holding "forward". (Desktop: click = forward, A/D or arrows = steer, W/Up/Space = forward.)
- Hazards hurt on any overlap, moving or frozen. Freezing is for timing gaps, not for hiding.
- Reach the glowing finish line at the top to clear the level.
- Fixed 720x1280 portrait viewport. Single-finger input only.

## Track shape: straight lanes first
- Levels are a straight vertical lane. No curves, no path-following, no wall collisions.
- All difficulty comes from hazards, which sweep left/right across the lane.
- Hazards are deterministic (fixed speed and pattern, no random timing) so every death is the player's fault.
- Winding tracks are a post-launch idea, only if the straight-lane loop proves fun.

## Progression
- Level 1: eight sweeping bars, all one size (256px). Teaches hold = move, release = stop.
- Levels 2-5: sweeping bars in four sizes (96 / 160 / 208 / 256px), more bars and more speed each level.
- Levels 6-10: same bars plus 2 fire and 2 ice patches per level (rules below).
- Levels 8-10: some bars (3, 4, 5) stop sweeping and become fixed purple walls at the left, middle or right of the lane, so the player must steer around them.
- Length grows by about 300px per level: level 1 is the shortest (3600px), level 10 about 6300px. Bars get slightly closer together as levels get longer.
- Levels 11-50 of the Jungle follow a difficulty curve that continues from level 10 (up to 34 bars, spacing down to 275px, up to 4 fire + 4 ice patches, up to 10 walls).
- Level data lives in `level_data.gd`. Jungle level 1 is hand-written; every other level is built from a fixed seed, so they are identical every run.
- Fairness rule: a bar must leave the player's lane clear for at least 0.5s each time it swings out (measured for a player standing in the middle of the lane; 0.6s in Pyramids and Frostbite, where steering or stopping is looser). `level_data.gd` caps bar speed by width to guarantee it (the 256px bar is the slowest, 320 px/s in the Jungle), and `campaign.gd` warns in the Output panel if a generated bar ever drops below it. Jungle level 1 is hand-tuned and exempt.

## Worlds
Four worlds, 50 levels each, defined in `world_data.gd`. Each world has its own art folder (`assets/themes/<id>/`), movement rules and hazards. Until real art exists, `world_art.gd` draws placeholders; a PNG at the same path replaces one with no code change.

| World | Hazards | Movement |
|---|---|---|
| Jungle | logs / bamboo, walls (from level 8), fire + ice patches (from level 6) | normal |
| Sun-Baked Pyramids | stone pillars, swinging scarabs (level 3+), spiked trapdoors (8+), walls (12+), quicksand (5+) | steering is loose (builds up and fades, 1500 px/s^2) |
| Cyber Grid | laser bars, pulse barriers (4+), walls (15+), glitch zones (7+) | forward speed 1.2x (480 px/s); rows spaced 1.2x further apart |
| Frostbite Summit | frozen bars, avalanche debris (3+), walls (14+), frost patches (6+) | letting go slides ~50px (0.25s) instead of stopping |

- Hazard motions (`hazard.gd`): sweep, pendulum, fixed wall, blink (full-lane row, deadly only while ON; flashes red 0.35s before turning on; safe time is at least 0.9s), fall (a chunk drops onto a spot marked by a shadow, rests 0.3s, vanishes 1.4s).
- Zones (`status_zone.gd`): fire and ice as above; **quicksand** slows to 0.55x while inside and 2s after; **glitch** swaps left and right for 2s; **frost patch** pushes the player about 120px forward or back (random), at most once per 1.5s.
- Numbers per world (difficulty curve, intro levels, movement) are all in `world_data.gd` and tunable.

### Stars and unlocking
- Each level gives 1-3 stars (best is kept): **1** finish, **2** finish without using the revive, **3** also finish within the par time (level length / forward speed x 1.5; time spent paused or in the intro doesn't count).
- Level n opens when level n-1 of the same world has at least 1 star. A world opens when the previous world has 50 stars (of its 150). `UNLOCK_ALL_LEVELS` in `game_data.gd` opens everything for testing.
- Old saves with `levels_cleared` are migrated to 1 star on those Jungle levels.

### Fire and ice patches (levels 6-10)
- Fixed and always on. Each patch is 300px wide in the 720px lane, sitting at the left, middle or right (fixed per level, picked from the level's seed), so the player steers around it with the side buttons.
- **Fire:** touching an active patch starts a 10-second burn that kills the player when it runs out. Touching an active ice patch puts the fire out. Reaching the finish line first also saves you.
- **Ice:** puts out a burn, freezes the player in place for 1s, then movement speed (forward and sideways) is 0.8x for 5s. The freeze and slow can't be re-applied while frozen or slowed, but the fire-extinguishing always works.
- Reviving clears all effects.
- Endless mode: the world changes every 500 m (Jungle, Pyramids, Cyber Grid, Frostbite, repeat). All worlds are available. The floor, hazards and the player's movement rules switch at each boundary; speed keeps rising until 2000 m. The server accepts up to 9.6 m/s (Cyber Grid speed) when checking scores.
- Ideas for later: narrow corridors, collapsing floors, moving checkpoints.

## Checkpoints and revive
- Every level has checkpoints at roughly every third of its length.
- Levels: **one revive per run** (watch a rewarded ad), offered every time. Respawn at the last checkpoint with ~2s of invulnerability.
- Endless: **up to three revives per run**, each a bigger ad: 1 = rewarded ad, 2 = rewarded interstitial, 3 = rewarded interstitial + rewarded ad (`Ads.show_revive_ad`). If a revive ad has no fill the player gets a "no ad available" message and can retry or restart.
- Declining, or having no revives left, restarts the level instantly (under 1 second).

## Coins
- Local currency in `GameData.coins`. Spent on characters; never sold for real money.
- **Levels:** 10 coins per star, only for stars not earned before (1 -> 3 stars on a replay pays 20). Replaying for the same stars pays nothing.
- **Endless:** 1 coin per 10 m, only for distance past the all-time best. Total coins from Endless = best / 10, whatever the number of runs or revives (200 m best, then a 280 m run = +8).
- Old saves are paid once for what they already earned (stars x 10 + best / 10), and keep the character they were wearing.
- **Daily calendar** (`daily_rewards.gd`): Day 1 50, Day 2 75, Day 3 125, Day 4 100, Day 5 150, Day 6 200, Day 7 exclusive character (400 coins until a reward-only character, `"price": -1`, is added to the roster). Missing one day: watch a rewarded ad to keep the streak, or start over. Missing two or more days restarts.
- **Characters:** `price` in `character_roster.gd` (only the Cyber Agent remains, free).
- **Bust or Boom:** after an Endless run of 100 m or more, three boxes; a rewarded ad opens one. Hidden x5 / x2 / x1 of the run's base coins (1 per 10 m, at least 10). Coins only; the leaderboard score is untouched.

## Ads (rewarded-first)
- **Rewarded ads (always opt-in):** revives, daily-streak recovery, Bust-or-Boom chests.
- **Interstitials (`ads.gd`)** have no timer or per-level schedule. They show only (a) when the same campaign level was failed 3 times in a row, on the next Restart tap (level 3 or later), or (b) when returning to the menu after 10 minutes without any ad. Never within 2 minutes of any other ad, never in the middle of a run, never after Remove Ads.
- **Remove All Ads** (one-time purchase, `remove_ads`, about $1.99): removes interstitials. Rewarded ads stay, since the player chooses them.
- **No banner ads.** The screen is small and the controls are "tap anywhere", so banners cause accidental taps and policy penalties.
- Audience: general (13+). Setup steps are in `ADS_SETUP.md`.

## Look and feel
- Dark neon: charcoal/black background, glowing cyan / hot pink / electric lime accents. Use a WorldEnvironment with glow.
- Juice: dust kicked up by the runner (`run_dust.gd`), screen shake and vibration on crash, short sounds for start/stop/crash.
- Store the best scores and level progress locally.

## Open items
- Built (verify in the editor): menu with level select (levels 1-10, `campaign.gd`; all unlocked while `UNLOCK_ALL_LEVELS` is true in `game_data.gd`), endless mode (`endless.gd`), finish line, checkpoints, revive, camera bounds, deterministic hazards, neon glow (`neon_env.tres`), run dust, screen shake, vibration, sounds (`sfx/`), local save (`game_data.gd`), portrait + `keep_width` stretch.
- Ads: `ads.gd` (rules) + `ads_admob.gd` (AdMob plugin adapter) + `ads_config.gd` (unit ids, test mode). Purchases: `store.gd` + `store_billing.gd`. Both adapters are inactive until their plugins are installed (see `ADS_SETUP.md`); debug builds then grant rewards at once so the game can be tested in the editor.
- Not run yet: this session's coin / daily / chest / ad code was written without the Godot editor; open the project and check the Output panel.
- Not built: more than one hand-built level / level select, a pause button, settings (mute, vibration off), tuning the difficulty ramp.
- Android export needs the VIBRATE permission ticked in the export preset, or vibration does nothing.
- Android export (templates, JDK, SDK, keystore, AAB) and Play Store closed-testing requirements: check current rules early.
