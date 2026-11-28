shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D floor_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float uv_scale = 34.0;
uniform float detail_uv_scale = 11.0;

varying float v_world_ny;

void vertex() {
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
	vec2 uv_main = UV * uv_scale;
	vec2 uv_macro = UV * detail_uv_scale;
	float break_n = value_noise(uv_macro * 2.2) * 0.55 + value_noise(uv_macro * 5.7) * 0.45;

	float w_mud = clamp(COLOR.r + (break_n - 0.5) * 0.22 * step(0.04, COLOR.r), 0.0, 1.0);
	float w_leaf = clamp(COLOR.g + (break_n - 0.5) * 0.35 * step(0.05, COLOR.g), 0.0, 1.0);
	float w_wet = clamp(COLOR.b, 0.0, 1.0);
	float w_rock = smoothstep(0.90, 0.72, v_world_ny);

	vec3 a_floor = texture(floor_albedo, uv_main).rgb * 0.92;
	vec3 n_floor = texture(floor_normal, uv_main).rgb;
	vec3 arm_floor = texture(floor_arm, uv_main).rgb;

	vec3 a_leaf = texture(leaf_albedo, uv_main * 1.15).rgb * 0.88;
	vec3 n_leaf = texture(leaf_normal, uv_main * 1.15).rgb;
	vec3 arm_leaf = texture(leaf_arm, uv_main * 1.15).rgb;

	vec3 a_mud = texture(mud_albedo, uv_main * 1.25).rgb * 0.85;
	vec3 n_mud = texture(mud_normal, uv_main * 1.25).rgb;
	vec3 arm_mud = texture(mud_arm, uv_main * 1.25).rgb;

	vec3 a_rock = texture(rock_albedo, uv_main * 0.75).rgb * 0.86;
	vec3 n_rock = texture(rock_normal, uv_main * 0.75).rgb;
	vec3 arm_rock = texture(rock_arm, uv_main * 0.75).rgb;

	float total_leaf = clamp(w_leaf * (1.0 - w_mud * 0.75) * (1.0 - w_rock * 0.70), 0.0, 1.0);
	vec3 albedo_mix = mix(a_floor, a_leaf, total_leaf);
	albedo_mix = mix(albedo_mix, a_mud, w_mud * (1.0 - w_rock * 0.45));
	albedo_mix = mix(albedo_mix, a_rock, w_rock);

	vec3 normal_mix = mix(n_floor, n_leaf, total_leaf);
	normal_mix = mix(normal_mix, n_mud, w_mud * (1.0 - w_rock * 0.45));
	normal_mix = mix(normal_mix, n_rock, w_rock);

	vec3 arm_mix = mix(arm_floor, arm_leaf, total_leaf);
	arm_mix = mix(arm_mix, arm_mud, w_mud * (1.0 - w_rock * 0.45));
	arm_mix = mix(arm_mix, arm_rock, w_rock);

	// Standing rain puddles in muddy ruts and creek shoals for SSR light reflections
	float puddle_n = value_noise(UV * 42.0) * 0.6 + value_noise(UV * 115.0) * 0.4;
	float flat_mask = smoothstep(0.86, 0.97, v_world_ny);
	float puddle = smoothstep(0.54, 0.74, puddle_n) * smoothstep(0.38, 0.78, w_wet) * flat_mask;

	albedo_mix *= mix(1.0, 0.70, max(w_wet, puddle));
	float macro_var = mix(0.84, 1.12, value_noise(UV * 16.0));
	normal_mix = mix(normal_mix, vec3(0.5, 0.5, 1.0), puddle * 0.92);

	ALBEDO = albedo_mix * macro_var;
	NORMAL_MAP = normal_mix;
	NORMAL_MAP_DEPTH = mix(1.22, 0.14, puddle);
	AO = arm_mix.r;
	AO_LIGHT_AFFECT = 0.68;
	float base_rough = mix(arm_mix.g, 0.28, w_wet * 0.72);
	ROUGHNESS = clamp(mix(base_rough, 0.045, puddle), 0.04, 0.98);
	METALLIC = mix(0.0, 0.05, puddle);
	SPECULAR = mix(mix(0.38, 0.58, w_wet), 0.94, puddle);
}
