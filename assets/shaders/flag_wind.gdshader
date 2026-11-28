shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 flag_color : source_color = vec4(0.82, 0.18, 0.16, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.95, 0.80, 0.20, 1.0);
uniform float wind_strength = 0.0;

void vertex() {
	// UV.x == 0 is pinned to the flagpole; UV.x == 1 flutters freely downwind.
	// Note: flag PlaneMesh is rotated +90 deg on X, so +VERTEX.z points world -Y (downward).
	float pin = clamp(UV.x, 0.0, 1.0);
	float w = max(wind_strength, 0.0);
	float lift = smoothstep(0.0, 4.5, w);

	// Droop downward when wind is calm; lift horizontally as wind rises
	VERTEX.z += (1.0 - lift) * 0.68 * pin;
	VERTEX.x -= (1.0 - lift) * 0.42 * pin;

	float speed = 1.1 + w * 0.55;
	float wave1 = sin(TIME * speed - UV.x * 7.5 + UV.y * 1.8);
	float wave2 = cos(TIME * speed * 1.6 - UV.x * 13.0) * 0.35;
	float amp = (0.010 + min(w, 9.0) * 0.024) * pin * pin;
	VERTEX.y += (wave1 + wave2) * amp;
	VERTEX.z += sin(TIME * speed * 0.7 - UV.x * 4.5) * amp * 0.35;
}

void fragment() {
	// Heraldic horizontal stripe accent + subtle cloth fold shading
	float stripe = step(0.42, UV.y) * (1.0 - step(0.58, UV.y));
	vec3 col = mix(flag_color.rgb, stripe_color.rgb, stripe * 0.85);
	float sheen = 0.92 + 0.08 * sin(UV.x * 16.0);
	ALBEDO = col * sheen;
	ROUGHNESS = 0.82;
}
