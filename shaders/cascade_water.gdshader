shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D wave_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 shallow_color : source_color = vec4(0.020, 0.044, 0.056, 1.0);
uniform vec4 deep_color : source_color = vec4(0.008, 0.018, 0.026, 1.0);

void fragment() {
	vec2 uv_a = UV * 1.45 + vec2(TIME * 0.022, TIME * 0.014);
	vec2 uv_b = UV * 2.35 + vec2(-TIME * 0.017, TIME * 0.026);

	vec3 n_a = texture(wave_normal, uv_a).rgb;
	vec3 n_b = texture(wave_normal, uv_b).rgb;
	vec3 n_mix = normalize(vec3(n_a.xy + n_b.xy - 1.0, (n_a.z + n_b.z) * 0.5)) * 0.5 + 0.5;

	float r_tex = texture(rough_tex, uv_a * 0.7).r;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);

	// Opaque depth-drawn water surface so Godot Forward+ SSR & SSIL capture clean nocturnal reflections
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, fresnel * 0.65);
	NORMAL_MAP = n_mix;
	NORMAL_MAP_DEPTH = 0.28;
	ROUGHNESS = clamp(0.025 + r_tex * 0.045, 0.02, 0.12);
	METALLIC = 0.12;
	SPECULAR = 0.92;
}
