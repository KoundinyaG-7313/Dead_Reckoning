class_name BiomeRegistry
extends RefCounted

enum Family {
	SUNKEN_TIMBER = 0,
	ASH_DEADWOOD = 1,
	INDUSTRIAL_RAIL = 2,
	HIGH_RIDGE = 3,
	QUARANTINE_SUBSURFACE = 4,
}

enum Id {
	HEMLOCK_HOLLOW = 0,
	CEDAR_FOG_BOTTOM = 1,
	ALDER_SLOUGH = 2,
	MOSS_CREEK_BASIN = 3,
	BURN_SCAR = 4,
	MYCORRHIZAL_SINKHOLE = 5,
	PALE_BONEWOOD = 6,
	SULFUR_RAVINE = 7,
	LUMBER_MILL_GROUNDS = 8,
	RAIL_SPUR_YARD = 9,
	QUARRY_CUT = 10,
	LOGGING_DEPOT = 11,
	GRANITE_ESCARPMENT = 12,
	WINDFALL_SADDLE = 13,
	SUBALPINE_CREST = 14,
	LOOKOUT_RIDGE = 15,
	QUARANTINE_PERIMETER = 16,
	TELEMETRY_SWATH = 17,
	CULVERT_DRAIN = 18,
	GREEN_ISLAND = 19,
}

const COUNT: int = 20

# Each entry: id, family, code, display_name, map_color, tree_density, deadwood_ratio, undergrowth, anomaly, elev_pref, moist_pref, blight_pref
static var _SPECS: Array[Dictionary] = []


static func _ensure_init() -> void:
	if not _SPECS.is_empty():
		return
	_SPECS = [
		# 0..3: Sunken Timberlands
		{
			"id": Id.HEMLOCK_HOLLOW, "family": Family.SUNKEN_TIMBER, "code": "hemlock_hollow",
			"name": "Deep Hemlock Hollow", "color": Color(0.11, 0.27, 0.16),
			"tree_density": 1.0, "deadwood": 0.12, "undergrowth": 0.90, "anomaly": 0.05,
			"elev": 0.35, "moist": 0.58, "blight": 0.12
		},
		{
			"id": Id.CEDAR_FOG_BOTTOM, "family": Family.SUNKEN_TIMBER, "code": "cedar_fog_bottom",
			"name": "Fog Cedar Bottom", "color": Color(0.08, 0.23, 0.18),
			"tree_density": 0.92, "deadwood": 0.18, "undergrowth": 1.0, "anomaly": 0.10,
			"elev": 0.22, "moist": 0.78, "blight": 0.18
		},
		{
			"id": Id.ALDER_SLOUGH, "family": Family.SUNKEN_TIMBER, "code": "alder_slough",
			"name": "Flooded Alder Slough", "color": Color(0.14, 0.29, 0.25),
			"tree_density": 0.55, "deadwood": 0.36, "undergrowth": 0.85, "anomaly": 0.18,
			"elev": 0.14, "moist": 0.92, "blight": 0.22
		},
		{
			"id": Id.MOSS_CREEK_BASIN, "family": Family.SUNKEN_TIMBER, "code": "moss_creek_basin",
			"name": "Moss-Choked Creek Basin", "color": Color(0.15, 0.34, 0.20),
			"tree_density": 0.85, "deadwood": 0.15, "undergrowth": 0.95, "anomaly": 0.08,
			"elev": 0.26, "moist": 0.72, "blight": 0.10
		},
		# 4..7: Ash & Deadwood Barrens
		{
			"id": Id.BURN_SCAR, "family": Family.ASH_DEADWOOD, "code": "burn_scar",
			"name": "Blackened Burn Scar", "color": Color(0.24, 0.20, 0.19),
			"tree_density": 0.38, "deadwood": 0.96, "undergrowth": 0.14, "anomaly": 0.62,
			"elev": 0.42, "moist": 0.28, "blight": 0.80
		},
		{
			"id": Id.MYCORRHIZAL_SINKHOLE, "family": Family.ASH_DEADWOOD, "code": "mycorrhizal_sinkhole",
			"name": "Mycorrhizal Rot Sinkhole", "color": Color(0.36, 0.21, 0.27),
			"tree_density": 0.30, "deadwood": 0.92, "undergrowth": 0.22, "anomaly": 0.95,
			"elev": 0.20, "moist": 0.66, "blight": 0.96
		},
		{
			"id": Id.PALE_BONEWOOD, "family": Family.ASH_DEADWOOD, "code": "pale_bonewood",
			"name": "Pale Stripped Bonewood", "color": Color(0.45, 0.43, 0.39),
			"tree_density": 0.52, "deadwood": 0.90, "undergrowth": 0.18, "anomaly": 0.74,
			"elev": 0.50, "moist": 0.38, "blight": 0.76
		},
		{
			"id": Id.SULFUR_RAVINE, "family": Family.ASH_DEADWOOD, "code": "sulfur_ravine",
			"name": "Sulfur Drainage Ravine", "color": Color(0.42, 0.38, 0.20),
			"tree_density": 0.26, "deadwood": 0.94, "undergrowth": 0.12, "anomaly": 0.88,
			"elev": 0.18, "moist": 0.82, "blight": 0.90
		},
		# 8..11: Industrial & Rail Corridors
		{
			"id": Id.LUMBER_MILL_GROUNDS, "family": Family.INDUSTRIAL_RAIL, "code": "lumber_mill",
			"name": "Overgrown Lumber Mill", "color": Color(0.42, 0.31, 0.22),
			"tree_density": 0.22, "deadwood": 0.40, "undergrowth": 0.48, "anomaly": 0.25,
			"elev": 0.28, "moist": 0.48, "blight": 0.35
		},
		{
			"id": Id.RAIL_SPUR_YARD, "family": Family.INDUSTRIAL_RAIL, "code": "rail_spur_yard",
			"name": "Rusted Spur Rail Yard", "color": Color(0.37, 0.33, 0.31),
			"tree_density": 0.28, "deadwood": 0.35, "undergrowth": 0.52, "anomaly": 0.20,
			"elev": 0.30, "moist": 0.45, "blight": 0.30
		},
		{
			"id": Id.QUARRY_CUT, "family": Family.INDUSTRIAL_RAIL, "code": "quarry_cut",
			"name": "Gravel Quarry Cut", "color": Color(0.48, 0.48, 0.46),
			"tree_density": 0.12, "deadwood": 0.45, "undergrowth": 0.20, "anomaly": 0.30,
			"elev": 0.44, "moist": 0.24, "blight": 0.32
		},
		{
			"id": Id.LOGGING_DEPOT, "family": Family.INDUSTRIAL_RAIL, "code": "logging_depot",
			"name": "Abandoned Logging Depot", "color": Color(0.36, 0.27, 0.19),
			"tree_density": 0.34, "deadwood": 0.30, "undergrowth": 0.55, "anomaly": 0.15,
			"elev": 0.36, "moist": 0.46, "blight": 0.24
		},
		# 12..15: High Ridge & Watch Chain
		{
			"id": Id.GRANITE_ESCARPMENT, "family": Family.HIGH_RIDGE, "code": "granite_escarpment",
			"name": "Granitic Escarpment", "color": Color(0.39, 0.42, 0.45),
			"tree_density": 0.24, "deadwood": 0.38, "undergrowth": 0.22, "anomaly": 0.18,
			"elev": 0.84, "moist": 0.22, "blight": 0.20
		},
		{
			"id": Id.WINDFALL_SADDLE, "family": Family.HIGH_RIDGE, "code": "windfall_saddle",
			"name": "Windfall Saddle", "color": Color(0.24, 0.32, 0.22),
			"tree_density": 0.58, "deadwood": 0.56, "undergrowth": 0.62, "anomaly": 0.22,
			"elev": 0.64, "moist": 0.44, "blight": 0.34
		},
		{
			"id": Id.SUBALPINE_CREST, "family": Family.HIGH_RIDGE, "code": "subalpine_crest",
			"name": "Sub-Alpine Scrub Crest", "color": Color(0.30, 0.39, 0.34),
			"tree_density": 0.42, "deadwood": 0.40, "undergrowth": 0.45, "anomaly": 0.15,
			"elev": 0.92, "moist": 0.34, "blight": 0.16
		},
		{
			"id": Id.LOOKOUT_RIDGE, "family": Family.HIGH_RIDGE, "code": "lookout_ridge",
			"name": "Fire-Lookout Ridge", "color": Color(0.27, 0.38, 0.26),
			"tree_density": 0.66, "deadwood": 0.25, "undergrowth": 0.56, "anomaly": 0.12,
			"elev": 0.74, "moist": 0.36, "blight": 0.18
		},
		# 16..19: Quarantine, Utility & Enclave Zones
		{
			"id": Id.QUARANTINE_PERIMETER, "family": Family.QUARANTINE_SUBSURFACE, "code": "quarantine_perimeter",
			"name": "Breached Quarantine Perimeter", "color": Color(0.45, 0.28, 0.18),
			"tree_density": 0.45, "deadwood": 0.42, "undergrowth": 0.50, "anomaly": 0.40,
			"elev": 0.38, "moist": 0.42, "blight": 0.42
		},
		{
			"id": Id.TELEMETRY_SWATH, "family": Family.QUARANTINE_SUBSURFACE, "code": "telemetry_swath",
			"name": "Telemetry Power-Line Swath", "color": Color(0.22, 0.32, 0.24),
			"tree_density": 0.20, "deadwood": 0.35, "undergrowth": 0.80, "anomaly": 0.46,
			"elev": 0.48, "moist": 0.46, "blight": 0.38
		},
		{
			"id": Id.CULVERT_DRAIN, "family": Family.QUARANTINE_SUBSURFACE, "code": "culvert_drain",
			"name": "Collapsed Culvert Drain", "color": Color(0.27, 0.30, 0.33),
			"tree_density": 0.48, "deadwood": 0.52, "undergrowth": 0.64, "anomaly": 0.58,
			"elev": 0.28, "moist": 0.68, "blight": 0.54
		},
		{
			"id": Id.GREEN_ISLAND, "family": Family.QUARANTINE_SUBSURFACE, "code": "green_island",
			"name": "Protected Green Island Enclave", "color": Color(0.16, 0.48, 0.22),
			"tree_density": 0.96, "deadwood": 0.04, "undergrowth": 0.96, "anomaly": 0.0,
			"elev": 0.44, "moist": 0.64, "blight": 0.0
		},
	]


static func get_spec(biome_id: int) -> Dictionary:
	_ensure_init()
	var idx: int = clampi(biome_id, 0, COUNT - 1)
	return _SPECS[idx]


static func get_all_specs() -> Array[Dictionary]:
	_ensure_init()
	return _SPECS


static func classify_base_biome(elev_norm: float, moist: float, blight: float, human: float) -> int:
	# Maps continuous warped environmental fields into any of the natural 16 non-enclave biomes
	_ensure_init()
	if blight > 0.62:
		if moist > 0.72 and elev_norm < 0.38:
			return Id.SULFUR_RAVINE
		if moist > 0.55 and elev_norm < 0.44:
			return Id.MYCORRHIZAL_SINKHOLE
		if elev_norm > 0.50:
			return Id.PALE_BONEWOOD
		return Id.BURN_SCAR

	if elev_norm > 0.68:
		if elev_norm > 0.85:
			return Id.SUBALPINE_CREST
		if human > 0.56 and elev_norm < 0.78:
			return Id.LOOKOUT_RIDGE
		if moist > 0.48:
			return Id.WINDFALL_SADDLE
		return Id.GRANITE_ESCARPMENT

	if human > 0.68 and elev_norm < 0.55:
		if blight > 0.42:
			return Id.QUARANTINE_PERIMETER
		if elev_norm > 0.40 and moist < 0.34:
			return Id.QUARRY_CUT
		if moist < 0.48:
			return Id.LOGGING_DEPOT
		return Id.LUMBER_MILL_GROUNDS

	if elev_norm > 0.54:
		if blight > 0.44:
			return Id.WINDFALL_SADDLE
		return Id.LOOKOUT_RIDGE if human > 0.45 else Id.HEMLOCK_HOLLOW

	# Low/mid valley Sunken Timberlands variants driven by moisture & micro-elevation
	if moist > 0.80 and elev_norm < 0.30:
		return Id.ALDER_SLOUGH
	if moist > 0.66:
		return Id.CEDAR_FOG_BOTTOM if elev_norm < 0.36 else Id.MOSS_CREEK_BASIN
	if moist > 0.52 and elev_norm < 0.42:
		return Id.MOSS_CREEK_BASIN
	return Id.HEMLOCK_HOLLOW
