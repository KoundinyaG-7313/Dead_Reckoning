# DeadReckoning — Night Forest World Generation

A dense, atmospheric nocturnal horror woodland environment built in **Godot 4.7.2 (Forward+)** using 100% downloaded **CC0 3D models and 1K PBR textures** (Quaternius, Poly Haven, and Kenney Nature Kit).

> **Scope:** World generation and environmental storytelling only — no player controller, HUD, AI enemies, or gameplay loop yet.

## Scene & Scripts Layout

- **`scenes/ForestWorld.tscn`** — Main procedural forest world scene with `ForestWorldBuilder` (`@tool` + runtime generation), volumetric fog night `WorldEnvironment`, directional moonlight, and `StaticForestCamera` + inspection `Marker3D` viewpoints under `CameraViewpoints/`.
- **`scripts/world/forest_noise.gd` (`ForestTerrainData`)** — Deterministic seeded terrain heightfield (`world_seed`), serpentine logging dirt trail with wheel ruts, off-trail spur path, sunken woodland creek channel, and flattened pads for the Forestry Relay Outpost and Abandoned Campsite.
- **`shaders/forest_terrain.gdshader`** & **`scripts/world/forest_mesh_builder.gd` (`ForestMeshBuilder`)** — 216x216 subdivided terrain mesh with trimesh collision, 3-layer PBR texture splatting (`forest_ground_04`, `brown_mud_02`, `forest_leaves_04` Diffuse + Normal + ARM), wet rut/creek roughness modulation, and dark creek water ribbon.
- **`scripts/world/forest_materials.gd` (`ForestMaterials`)** — PBR material loaders and nocturnal tree/foliage shaders with alpha-scissor cutouts and bark normal maps.
- **`scripts/world/forest_foliage_scatter.gd` (`ForestFoliageScatter`)** — GPU-instanced `MultiMeshInstance3D` scattering for conifers, hardwoods, birches, deadwood, bushes, twisted scrub, ferns, low twigs, tall grass tufts, moss clumps, boulders, rocks, fallen trunks, stumps, roots, and dry branches, with selective trunk colliders.
- **`scripts/world/forest_landmarks.gd` (`ForestLandmarks`)** — Hand-crafted *Signal Lost*-inspired landmarks:
  - Timber creek culvert bridge (`bridge_wood.glb`, pilings, warning sign, split-rail fencing)
  - Creosote utility power line with catenary cables, a splintered leaning pole, dangling cable spark, and storm lanterns
  - **Forestry Signal Relay Outpost** featuring a 29m steel-lattice radio tower with pulsing crimson beacon & standing tripod floodlights, plus a dilapidated wooden relay shack (`brown_planks_03`, `corrugated_iron_02`, `concrete_moss`) with ajar door and detailed desk/cassette recorder/chair/crowbar/caged light interior
  - **Overgrown Abandoned Campsite** with weathered open tent, stone/charcoal ember firepit, firewood bench, drum, and tipped storm lantern

## Assets & Licensing

See [`Docs/ASSET_LICENSES.md`](Docs/ASSET_LICENSES.md) for the full CC0 inventory.
