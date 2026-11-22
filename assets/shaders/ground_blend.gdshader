shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap, repeat_enable;

uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_roughness : filter_linear_mipmap, repeat_enable;

uniform vec4 grass_tint : source_color = vec4(0.85, 1.05, 0.72, 1.0);
uniform vec4 dirt_tint : source_color = vec4(1.0, 0.94, 0.84, 1.0);
uniform float uv_scale = 26.0;
uniform float path_half_width = 0.036;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
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
	vec2 tiled_uv = UV * uv_scale;
	// Organic meandering dirt shooting lane centered at UV.x = 0.5
	float edge_noise = (vnoise(UV * vec2(22.0, 48.0)) - 0.5) * 0.028;
	float dist_from_center = abs(UV.x - 0.5) + edge_noise;
	float dirt_mask = 1.0 - smoothstep(path_half_width * 0.65, path_half_width * 1.45, dist_from_center);
	// Fade out dirt path far behind the range
	dirt_mask *= smoothstep(0.08, 0.22, UV.y) * (1.0 - smoothstep(0.74, 0.88, UV.y));

	vec3 g_col = texture(grass_albedo, tiled_uv).rgb * grass_tint.rgb;
	vec3 d_col = texture(dirt_albedo, tiled_uv * 1.15).rgb * dirt_tint.rgb;
	ALBEDO = mix(g_col, d_col, dirt_mask);

	vec3 g_n = texture(grass_normal, tiled_uv).rgb;
	vec3 d_n = texture(dirt_normal, tiled_uv * 1.15).rgb;
	NORMAL_MAP = mix(g_n, d_n, dirt_mask);
	NORMAL_MAP_DEPTH = 0.85;

	float g_r = texture(grass_roughness, tiled_uv).r;
	float d_r = texture(dirt_roughness, tiled_uv * 1.15).r;
	ROUGHNESS = clamp(mix(g_r, d_r, dirt_mask), 0.55, 0.98);
}
