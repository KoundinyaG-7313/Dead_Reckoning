# DeadReckoning — Signal Lost Deep Forest

A dense, atmospheric nocturnal horror woodland environment with a full high-poly third-person explorer built in **Godot 4.7.2 (Forward+)** using 100% downloaded **CC0 3D models and PBR textures** (MakeHuman/CharacterCreator CC0 output assets, Quaternius, Poly Haven, and Kenney Nature Kit).

## Controls

- **`W A S D` / Arrow Keys** — Walk across terrain and trails
- **`Shift`** — Sprint
- **`Space`** — Jump
- **`Mouse`** — Third-person over-shoulder orbit camera (`Esc` toggles cursor capture)
- **`F`** — Toggle chest flashlight
- **`V`** — Cycle camera framing (`OverShoulder` / `MediumChase` / `WideForest`)

## Scene & Scripts Layout

- **`scenes/ForestWorld.tscn`** & **`scripts/world/forest_world_builder.gd`** (`ForestWorldBuilder`) — Volumetric fog night `WorldEnvironment`, directional moonlight, terrain/foliage/landmarks generation, and runtime spawn of `PlayerCharacter`.
- **`scenes/PlayerCharacter.tscn`**, **`scripts/player/third_person_player.gd`** (`ThirdPersonPlayer`), & **`scripts/player/character_rig.gd`** (`CharacterRig`) — 53-bone rigged explorer assembled from CC0 base body + shirt, jeans, boots, field jacket, and hair GLBs (`base_body_anim.glb`, ~21.7k combined triangles), smooth locomotion blending (`idle`, `idle_look`, `walk`, `run`, `jump`, `fall`, `land`), `SpringArm3D` third-person chase camera, and chest flashlight.
- **`scripts/world/forest_noise.gd`** (`ForestTerrainData`), **`shaders/forest_terrain.gdshader`**, & **`scripts/world/forest_mesh_builder.gd`** (`ForestMeshBuilder`) — Deterministic terrain heightfield, serpentine logging dirt trail with wheel ruts, off-trail spur, creek ravine, and 3-layer PBR splatting (`forest_ground_04`, `brown_mud_02`, `forest_leaves_04`).
- **`scripts/world/forest_foliage_scatter.gd`** (`ForestFoliageScatter`) — GPU-instanced `MultiMeshInstance3D` scattering (`3,140` trees, `14,680` total foliage/geology instances).
- **`scripts/world/forest_landmarks.gd`** (`ForestLandmarks`) — Timber culvert bridge, creosote utility power line with snapped pole, Forestry Signal Relay Outpost (`29m` steel-lattice radio tower + detailed shack interior), and overgrown campsite.

## Assets & Licensing

See [`Docs/ASSET_LICENSES.md`](Docs/ASSET_LICENSES.md) for the full CC0 inventory (`assets/characters/asset_licenses.json` for character/garment sources).
