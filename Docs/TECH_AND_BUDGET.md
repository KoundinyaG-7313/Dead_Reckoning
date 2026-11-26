# Technical Targets & Hour Budget

## Engine & Rendering Constraints
- **Unity Version:** Unity 6 LTS (`6.6`) + HDRP, C#
- **Ray Tracing:** **Disabled / Not Used** (Linux/Vulkan does not support HDRP RT)
- **Platforms:** Windows + Linux (dev on Arch Linux laptop & Ubuntu desktop; macOS untested; no WebGL)
- **Lighting Pipeline:**
  - Baked lighting via Adaptive Probe Volumes (APV)
  - Screen-space effects: SSGI, SSAO, SSR (scaled by quality tier)
  - Volumetric fog + HDRP Water
  - Realtime lights strictly restricted to: lighthouse beam, flashlight, flickering lamps
- **Quality Tiers (Settings Menu):** Low / Medium / High / Ultra (no RT)
- **Minimum Spec Target:**
  - GPU: GTX 1050 / MX450 class (2 GB VRAM budget-conscious: keep texture sizes modest)
  - CPU: 4 cores
  - RAM: 8 GB
  - Performance target: `1080p` Low @ `30 FPS` (profile regularly on the MX450 laptop)

## Audio Architecture
- Custom-made music and SFX
- Binaural spatial audio: Steam Audio (verify Unity `6.6` + Linux compatibility in a blank project first)
- Layered music stems reactive to threat/breach state
- Deliberate use of silence

## Hour Budget (`220h` Total)
Taiyaki benchmark: `75h` to qualify, `36h` for flight stipends, remainder is margin.

| Phase / System | Budget (h) | Logged (h) | Notes |
| --- | ---: | ---: | --- |
| Greybox (movement, stairs, lamp, radar) | 30 | 0 | Verify tension with boxes before art |
| Scene / lighting / fog / water | 40 | 0 | Keep within budget; profile MX450 early |
| Enemies, ship AI, breach system | 40 | 0 | State machine + 1 base nightcrawler first |
| Story, tutorial, nights, rules | 30 | 0 | Diegetic notes + logs + Night 1–5 |
| Audio + music | 30 | 0 | Layered stems + SFX + spatial audio |
| UI, menus, settings, saves | 15 | 0 | Low/Med/High/Ultra tiers + save/night select |
| Playtest & balance | 20 | 0 | Pacing, breach caps, Dark Phase fairness |
| Release & bugfixing | 15 | 0 | Windows + Linux builds |
| **Total** | **220** | **0** | **Vertical slice target: ~hour 60** |

## Vertical Slice Milestone (~Hour 60)
One complete, ugly-but-playable night from start to dawn:
- First-person movement + spiral staircase traversal
- Radar room with moving/ghost blips
- Lamp room manual beam aiming + overheat
- Complete breach state machine + Dark Phase escape loop

## Open Items (Verify Before Committing)
- [ ] Taiyaki theme, rules, asset policy, and submission deadline
- [ ] Whether Lapse hours count toward Taiyaki
- [ ] Hackatime plugin compatibility with Unity on Linux
