# Setup & First-Tasks Checklist

Follow these steps once Unity `6.6` finishes installing in Unity Hub.

## 1. Initialize Unity 6.6 HDRP into This Repo
Unity Hub requires an empty/non-existent folder when creating a project from a template:

1. In **Unity Hub**, create a new **High Definition 3D (HDRP)** project on Unity `6.6` at a temporary path, e.g. `/home/koundinyag/DeadReckoning_Temp`.
2. Let Unity finish generating the template, then close Unity.
3. Copy the template project files into `/home/koundinyag/DeadReckoning` without overwriting `.git`, `.gitignore`, `.gitattributes`, `.editorconfig`, `README.md`, `Docs/`, or `SourceAssets/`:
   - Copy `Packages/` and `ProjectSettings/` into `/home/koundinyag/DeadReckoning/`.
   - Merge the generated `Assets/` files (such as `Settings/`, `HDRPDefaultResources/`, default scene/settings) into `/home/koundinyag/DeadReckoning/Assets/` (keep `Assets/_Project/` and `Assets/ThirdParty/` intact).
4. Delete `/home/koundinyag/DeadReckoning_Temp`.
5. In **Unity Hub**, choose **Add -> Add project from disk** and select `/home/koundinyag/DeadReckoning`.

## 2. Verify Project & Git Settings on First Launch
- **Edit -> Project Settings -> Version Control:** Mode = `Visible Meta Files`
- **Edit -> Project Settings -> Editor:** Asset Serialization Mode = `Force Text`
- **Edit -> Project Settings -> Player (Linux/Windows):** Confirm Vulkan / DX11/DX12 settings (no ray tracing).
- **Input:** Confirm Unity Input System package setup and store `.inputactions` under `Assets/_Project/Settings/Input/`.
- **Assembly Definitions:** Once you add your first scripts, add `DeadReckoning.Runtime.asmdef` in `Assets/_Project/Scripts/` and `DeadReckoning.Editor.asmdef` (Editor-only) in `Assets/_Project/Scripts/Editor/` to keep compile times fast.

## 3. Early Compatibility & Perf Gates (Do During Greybox)
- [ ] **Git LFS check:** Verify `git lfs status` and commit initial template + `.meta` files cleanly.
- [ ] **Steam Audio check:** Import Steam Audio into `Assets/ThirdParty/` in a test scene and verify it works in both Editor and a Linux standalone build on Unity `6.6`.
- [ ] **MX450 baseline check (~hour 10–15):** Build a greybox scene with HDRP Water + volumetric fog + 2 realtime spotlights, run a Linux standalone build on the MX450 laptop at `1080p` Low, and confirm `>= 30 FPS` headroom.
- [ ] **Greybox tension test:** First-person controller, spiral stairs, rotating lamp spotlight, and radar UI with moving blips—verify the core loop feels tense with gray boxes before building art.
