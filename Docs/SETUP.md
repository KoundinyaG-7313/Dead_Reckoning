# Setup & First-Tasks Checklist

Unity project path: `/home/koundinyag/DeadReckoning/Dead-Reckoning/`

## 1. Verify Project & Git Settings
- **Edit -> Project Settings -> Version Control:** Mode = `Visible Meta Files`
- **Edit -> Project Settings -> Editor:** Asset Serialization Mode = `Force Text`
- **Edit -> Project Settings -> Player (Linux/Windows):** Confirm Vulkan / DX11/DX12 settings (no ray tracing).
- **Input:** Confirm Unity Input System package setup and store `.inputactions` under `Dead-Reckoning/Assets/_Project/Settings/Input/`.
- **Assembly Definitions:** Once you add your first scripts, add `DeadReckoning.Runtime.asmdef` in `Dead-Reckoning/Assets/_Project/Scripts/` and `DeadReckoning.Editor.asmdef` (Editor-only) in `Dead-Reckoning/Assets/_Project/Scripts/Editor/` to keep compile times fast.

## 2. Early Compatibility & Perf Gates (Do During Greybox)
- [ ] **Git LFS check:** Verify `git lfs status` and commit initial template + `.meta` files cleanly.
- [ ] **Steam Audio check:** Import Steam Audio into `Dead-Reckoning/Assets/ThirdParty/` in a test scene and verify it works in both Editor and a Linux standalone build on Unity `6.6`.
- [ ] **MX450 baseline check (~hour 10–15):** Build a greybox scene with HDRP Water + volumetric fog + 2 realtime spotlights, run a Linux standalone build on the MX450 laptop at `1080p` Low, and confirm `>= 30 FPS` headroom.
- [ ] **Greybox tension test:** First-person controller, spiral stairs, rotating lamp spotlight, and radar UI with moving blips—verify the core loop feels tense with gray boxes before building art.
