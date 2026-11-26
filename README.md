# Dead Reckoning (Working Title)

Solo first-person horror game built for Hack Club's **Taiyaki** event.

You are the relief keeper of **Harrow Point Lighthouse**, surviving each night until the dawn horn sounds. The previous keeper vanished, leaving torn instructions—and the ships creeping through the fog are not looking for rescue.

## Tech Stack
- **Engine:** Unity 6 LTS (`6.6`), High Definition Render Pipeline (HDRP), C#
- **Lighting & Look:** Low-poly gritty aesthetic; baked lighting (Adaptive Probe Volumes), SSGI, SSAO, SSR, volumetric fog, HDRP Water, and realtime lights strictly for the lighthouse beam, flashlight, and flickering lamps (**no ray tracing**)
- **Audio:** Custom SFX + layered music stems, binaural spatial audio (Steam Audio, pending Unity 6 verification)
- **Targets:** Windows + Linux (`1080p` Low @ `30 FPS` min spec on GTX 1050 / MX450, 4 cores, 8 GB RAM)
- **VCS:** Git + Git LFS

## Repository Layout
- `Dead-Reckoning/` — Unity 6 (`6.6`) HDRP project root (`Assets/`, `Packages/`, `ProjectSettings/`)
  - `Dead-Reckoning/Assets/_Project/` — All game-owned scenes, scripts, prefabs, materials, audio, data, and UI
  - `Dead-Reckoning/Assets/ThirdParty/` — External SDKs / plugins (e.g., Steam Audio)
- `SourceAssets/` — Raw `.blend`, texture source, and DAW project files (excluded from Unity import, tracked via Git LFS)
- `Docs/` — Design brief, technical budget, and setup checklists
