shader_type canvas_item;

// Analytical metaball shader: computes the metaball field per-pixel
// from letter positions passed as uniforms.
// Uses gradient texture lookup (2DMetaballs style) + animated Voronoi caustics.

uniform int ball_count = 0;
uniform vec2 ball_positions[16];
uniform float ball_radius = 24.0;
uniform vec2 rect_size = vec2(200.0, 200.0);
uniform float threshold = 1.0;

// Gradient texture: maps normalized field value to color (edge -> interior)
uniform sampler2D gradient_tex : filter_linear;

// Caustic parameters
uniform float caustic_strength = 0.5;
uniform float caustic_scale = 0.05;
uniform float caustic_speed = 0.4;

// Hover effect: green tint spreading from cursor
uniform vec2 hover_center = vec2(0.0);
uniform float hover_amount = 0.0;

// Dent effect: temporary indentation at impact point
uniform vec2 dent_pos = vec2(0.0);
uniform float dent_strength = 0.0;
uniform float dent_radius = 30.0;

// Voronoi helper: returns vec2(d1, d2) — distances to nearest and second-nearest cell
vec2 voronoi(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 frac_part = fract(uv);
	float d1 = 1e10;
	float d2 = 1e10;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			// Pseudo-random point in each cell
			vec2 point = fract(sin(vec2(
				dot(cell + neighbor, vec2(127.1, 311.7)),
				dot(cell + neighbor, vec2(269.5, 183.3))
			)) * 43758.5453);
			vec2 diff = neighbor + point - frac_part;
			float dist = length(diff);
			if (dist < d1) {
				d2 = d1;
				d1 = dist;
			} else if (dist < d2) {
				d2 = dist;
			}
		}
	}
	return vec2(d1, d2);
}

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

	// Gradient lookup: normalize field from threshold..threshold*3 -> 0..1
	float norm = clamp((field - threshold) / (threshold * 2.0), 0.0, 1.0);
	COLOR = texture(gradient_tex, vec2(norm, 0.5));

	// Voronoi caustics: two layers at different scales, animated
	float t = TIME * caustic_speed;
	vec2 caustic_uv = pos * caustic_scale;

	vec2 v1 = voronoi(caustic_uv + vec2(t * 0.7, t * 0.5));
	vec2 v2 = voronoi(caustic_uv * 1.6 + vec2(-t * 0.4, t * 0.8));

	// Edge-detect via d2 - d1 product of both layers
	float c = (v1.y - v1.x) * (v2.y - v2.x);
	c = pow(c, 0.8);

	// Mask caustics to interior: fade out near bubble edge
	float interior_mask = smoothstep(0.0, 0.3, norm);
	COLOR.rgb += vec3(c * caustic_strength * interior_mask);

	// Hover: green tint spreading from cursor, lighter at edges like real bubbles
	if (hover_amount > 0.01) {
		float hover_dist = length(pos - hover_center);
		float max_spread = length(rect_size);
		float spread_radius = hover_amount * max_spread;
		float hover_factor = 1.0 - smoothstep(spread_radius * 0.7, spread_radius, hover_dist);
		// Deeper green in interior, lighter/brighter at edges
		float edge_mix = 1.0 - norm; // 1.0 at edge, 0.0 deep inside
		vec3 deep_green = vec3(0.25, 0.85, 0.40);
		vec3 light_green = vec3(0.55, 1.0, 0.65);
		vec3 green_tint = mix(deep_green, light_green, edge_mix);
		float intensity = mix(0.15, 0.45, edge_mix);
		COLOR.rgb = mix(COLOR.rgb, green_tint, hover_factor * hover_amount * intensity);
	}
}
