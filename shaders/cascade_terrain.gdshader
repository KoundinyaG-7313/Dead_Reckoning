shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D floor_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_arm : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec4 terrain_extra;
varying float v_world_ny;

void vertex() {
	terrain_extra = CUSTOM0;
	v_world_ny = clamp(NORMAL.y, 0.0, 1.0);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// UV repeats cleanly at 8m periods (16 repeats per 128m chunk -> zero chunk seams & zero floating-origin UV shift)
	vec2 uv_fine = UV * 2.0;
	vec2 uv_macro = UV * 0.45;
	float break_n = value_noise(uv_macro * 2.4) * 0.55 + value_noise(uv_macro * 6.3) * 0.45;

	float w_mud = clamp(COLOR.r + (break_n - 0.5) * 0.20 * step(0.04, COLOR.r), 0.0, 1.0);
	float w_leaf = clamp(COLOR.g + (break_n - 0.5) * 0.30 * step(0.05, COLOR.g), 0.0, 1.0);
	float w_rock = clamp(COLOR.b + (break_n - 0.5) * 0.24 * step(0.05, COLOR.b), 0.0, 1.0);
	float w_wet = clamp(COLOR.a, 0.0, 1.0);
	float w_ash = clamp(UV2.x, 0.0, 1.0);
	float w_myco = clamp(UV2.y, 0.0, 1.0);
	float w_asphalt = clamp(terrain_extra.x, 0.0, 1.0);
	float w_gravel = clamp(terrain_extra.y, 0.0, 1.0);

	vec3 a_floor = texture(floor_albedo, uv_fine).rgb * 0.90;
	vec3 n_floor = texture(floor_normal, uv_fine).rgb;
	vec3 arm_floor = texture(floor_arm, uv_fine).rgb;

	vec3 a_leaf = texture(leaf_albedo, uv_fine * 1.12).rgb * 0.86;
	vec3 n_leaf = texture(leaf_normal, uv_fine * 1.12).rgb;
	vec3 arm_leaf = texture(leaf_arm, uv_fine * 1.12).rgb;

	vec3 a_mud = texture(mud_albedo, uv_fine * 1.25).rgb * 0.84;
	vec3 n_mud = texture(mud_normal, uv_fine * 1.25).rgb;
	vec3 arm_mud = texture(mud_arm, uv_fine * 1.25).rgb;

	vec3 a_rock = texture(rock_albedo, uv_fine * 0.72).rgb * 0.85;
	vec3 n_rock = texture(rock_normal, uv_fine * 0.72).rgb;
	vec3 arm_rock = texture(rock_arm, uv_fine * 0.72).rgb;

	vec3 a_asph = texture(asphalt_albedo, uv_fine * 1.35).rgb * 0.82;
	vec3 n_asph = texture(asphalt_normal, uv_fine * 1.35).rgb;
	vec3 arm_asph = texture(asphalt_arm, uv_fine * 1.35).rgb;

	float leaf_m = clamp(w_leaf * (1.0 - w_mud * 0.65) * (1.0 - w_rock * 0.70), 0.0, 1.0);
	float rock_blend = max(w_rock, w_gravel * 0.82);

	vec3 albedo_mix = mix(a_floor, a_leaf, leaf_m);
	albedo_mix = mix(albedo_mix, a_mud, w_mud * (1.0 - rock_blend * 0.55));
	albedo_mix = mix(albedo_mix, a_rock, rock_blend);

	vec3 normal_mix = mix(n_floor, n_leaf, leaf_m);
	normal_mix = mix(normal_mix, n_mud, w_mud * (1.0 - rock_blend * 0.55));
	normal_mix = mix(normal_mix, n_rock, rock_blend);

	vec3 arm_mix = mix(arm_floor, arm_leaf, leaf_m);
	arm_mix = mix(arm_mix, arm_mud, w_mud * (1.0 - rock_blend * 0.55));
	arm_mix = mix(arm_mix, arm_rock, rock_blend);

	// Blend cracked wet 2K asphalt cleanly onto paved highways and site pads
	float asph_m = clamp(w_asphalt * (1.0 - w_mud * 0.30), 0.0, 1.0);
	albedo_mix = mix(albedo_mix, a_asph, asph_m);
	normal_mix = mix(normal_mix, n_asph, asph_m);
	arm_mix = mix(arm_mix, arm_asph, asph_m);

	// Burn Scar & Pale Bonewood ash desaturation + charcoal variation (exclude fresh paved asphalt)
	float ash_eff = w_ash * (1.0 - asph_m * 0.72);
	float luma = dot(albedo_mix, vec3(0.299, 0.587, 0.114));
	vec3 ash_tone = mix(vec3(luma * 0.42), vec3(luma * 0.92, luma * 0.88, luma * 0.80), smoothstep(0.35, 0.78, break_n));
	albedo_mix = mix(albedo_mix, ash_tone, ash_eff * 0.85);

	// Mycorrhizal rot / sulfur taint shift
	vec3 myco_tone = vec3(luma * 0.78 + 0.04, luma * 0.48 + 0.01, luma * 0.58 + 0.03);
	albedo_mix = mix(albedo_mix, myco_tone, w_myco * (1.0 - asph_m * 0.65) * 0.72);

	// Standing rain-puddle mask on flat ground, asphalt highways & damp corridors -> mirror SSR reflections!
	float puddle_n = value_noise(UV * 1.9) * 0.58 + value_noise(UV * 5.1) * 0.42;
	float flat_mask = smoothstep(0.84, 0.97, v_world_ny);
	float damp_driver = max(w_wet, asph_m * 0.90);
	float puddle = smoothstep(0.55, 0.74, puddle_n) * smoothstep(0.45, 0.82, damp_driver) * flat_mask;

	// Rain-slick darkening and micro-macro tone breakup
	albedo_mix *= mix(1.0, 0.66, max(w_wet, puddle));
	albedo_mix *= mix(1.0, 0.78, puddle);
	float macro_var = mix(0.84, 1.12, value_noise(UV * 1.15));

	// Flatten normal map in standing rain puddles so Forward+ SSR produces clean beam/beacon reflections
	normal_mix = mix(normal_mix, vec3(0.5, 0.5, 1.0), puddle * 0.92);

	ALBEDO = albedo_mix * macro_var;
	NORMAL_MAP = normal_mix;
	NORMAL_MAP_DEPTH = mix(mix(1.15, 1.42, max(rock_blend, w_ash)), 0.12, puddle);
	AO = arm_mix.r;
	AO_LIGHT_AFFECT = 0.68;
	float base_rough = mix(arm_mix.g, 0.96, ash_eff * 0.45);
	base_rough = mix(base_rough, 0.24, w_wet * 0.72);
	ROUGHNESS = clamp(mix(base_rough, 0.045, puddle), 0.04, 0.98);
	METALLIC = mix(0.0, 0.06, puddle);
	SPECULAR = mix(mix(0.38, 0.62, max(w_wet, asph_m)), 0.94, puddle);
}
