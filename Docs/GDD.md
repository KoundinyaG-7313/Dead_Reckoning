# Dead Reckoning — Game Design Document

## Premise
- **Genre:** First-person survival horror, single location.
- **Setting:** Harrow Point Lighthouse.
- **Setup:** The previous keeper disappeared, leaving a torn, vague, ominous instruction sheet. Survive until dawn arrives (time-based).
- **Antagonists ("Nightcrawlers"):** Drowned zombie-pirate crews arriving by phantom/barely-visible vessels. The lighthouse beam drives them back under.
- **Narrative Arc:** Logs discovered across nights reveal the truth. The ending hinges on the real rule: **nothing that arrives before the dawn horn is help** (the final radar blip is the test).

## Opening / Night 1 (Diegetic Tutorial)
- Starts in a normally lit room with a desk, torn instruction sheets, and a radar.
- Player is **not** explicitly told to watch the radar.
- Alarms blare; diegetic guidance sends the player downstairs/up to the lamp to aim the light at near-invisible ships to neutralize them.
- Handwritten notes on the desk update dynamically as tutorial guidance (no pop-up modals).

## Core Loop
- **Radar Room (Lower Floor):** Slow sweep, unreliable readings, ghost blips, static in fog.
- **Lamp Room (Top Floor):** Lamp auto-sweeps and reveals ships, but auto-sweep alone cannot turn them away. Player manually holds the beam on a ship for `~2s` to drive it back. Some ships are only visible inside the beam.
- **Spatial Cost & Resource:** Player can only be in one room at a time; the spiral staircase is the travel cost. The main lamp overheats if held on too long and must be rationed.

## Breach Sequence (State Machine)
1. **Warning (`20–30s`):** Audio/radar telegraphs (hull groan, fog bell, solid radar blip, wet footsteps).
2. **Descent (`~15–20s` run):** Long spiral staircase; windows reveal silhouettes and echoing audio. Designed to be traversed twice per breach.
3. **Doors:** Bolt doors (some heavy) plus cellar hatch / shutters; prioritize based on directional sound cues.
4. **Scare Off:** Breaker / porch lamp makes nightcrawlers recoil, at the cost of draining power needed by the main lamp.
5. **Failure -> Dark Phase:** If they break in, lights flicker and fail in stages, triggering the Dark Phase.

### Dark Phase Rules
- **Flashlight:** Stuns for a few seconds and drains battery; does **not** kill.
- **Objective:** Complete an escape/recovery objective (restore generator, relight lamp, reach stairs).
- **Stealth:** Hiding with flashlight off is quieter.
- **Enemy Cap:** Max `1–2` nightcrawlers active at once, differing in speed, hearing, and search behavior.
- **Grabs & Failure:** First grab grants one struggle-free escape; second grab ends the run (respawn at start of the current night). Grabs must always be telegraphed first (breathing, cold draft, light flicker).
- **Pacing:** Cap breaches per night and preserve quiet gaps between them.

## Nights & Progression
- **Night 1:** Tutorial.
- **Nights 2–5:** `4–5` nights at `~8–12 min` each, escalating difficulty.
- **Hidden Rules:** Each night teaches a hidden rule through logs/observation before testing it (e.g., moves only when light is off; drawn to the radio; mimics a friendly voice).
- **Stretch Goal:** Endless mode.

## Cut Order (If Short on Time)
1. Endless mode
2. Extra nightcrawler types
3. macOS build
4. Water detail
5. 5th night

**Never Cut:** Radar, breach sequence, audio, tutorial.
