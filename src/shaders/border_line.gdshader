shader_type canvas_item;

void fragment() {
	float center_dist = abs(UV.x - 0.5) * 2.0;

	// Thin white core
	float core = smoothstep(0.15, 0.0, center_dist);

	// Very subtle blue glow
	float glow = smoothstep(1.0, 0.2, center_dist) * 0.08;

	vec3 col = mix(vec3(0.6, 0.78, 1.0), vec3(1.0), core);
	float alpha = max(core * 0.35, glow);

	COLOR = vec4(col, alpha);
}
