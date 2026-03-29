shader_type canvas_item;

// Analytical metaball shader: computes the metaball field per-pixel
// from letter positions passed as uniforms.

uniform int ball_count = 0;
uniform vec2 ball_positions[16];
uniform float ball_radius = 24.0;
uniform vec2 rect_size = vec2(200.0, 200.0);
uniform float threshold = 1.0;
uniform float edge_width = 0.4;
uniform vec4 fill_color : source_color = vec4(0.7, 0.85, 1.0, 0.3);
uniform vec4 edge_color : source_color = vec4(0.85, 0.93, 1.0, 0.55);

// Dent effect: temporary indentation at impact point
uniform vec2 dent_pos = vec2(0.0);
uniform float dent_strength = 0.0;
uniform float dent_radius = 30.0;

void fragment() {
	// Convert UV (0-1) to local coordinates centered on the sprite
	vec2 pos = (UV - 0.5) * rect_size;

	// Compute metaball field: sum of r^2 / (dist^2 + softness)
	float field = 0.0;
	for (int i = 0; i < ball_count; i++) {
		vec2 diff = pos - ball_positions[i];
		float dist_sq = dot(diff, diff);
		field += (ball_radius * ball_radius) / (dist_sq + ball_radius * 0.5);
	}

	// Apply dent: subtract from field near impact point
	if (dent_strength > 0.01) {
		vec2 dent_diff = pos - dent_pos;
		float dent_dist = length(dent_diff);
		float dent_falloff = exp(-dent_dist * dent_dist / (dent_radius * dent_radius));
		field -= dent_strength * dent_falloff;
	}

	if (field < threshold) {
		discard;
	}

	// Edge glow near the threshold boundary
	float edge_factor = 1.0 - smoothstep(threshold, threshold + edge_width, field);

	COLOR = mix(fill_color, edge_color, edge_factor * 0.6);
	COLOR.a = mix(fill_color.a, max(edge_color.a, fill_color.a), edge_factor);
}
