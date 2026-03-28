shader_type canvas_item;

uniform float wobble_amount : hint_range(-1.0, 1.0) = 0.0;
uniform float recoil_amount : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.0, 20.0) = 8.0;
uniform vec4 base_color : source_color = vec4(0.25, 0.22, 0.2, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.45, 0.4, 0.35, 1.0);
uniform float metallic_strength : hint_range(0.0, 1.0) = 0.4;

void vertex() {
	// Pudding wobble: shear vertices based on height
	float wobble = wobble_amount * sin(TIME * time_scale) * 0.06;
	// Vertices higher up wobble more (using local UV.y)
	float height_factor = 1.0 - UV.y;
	VERTEX.x += wobble * height_factor * 40.0;

	// Recoil: push vertices down along barrel direction
	VERTEX.y += recoil_amount * UV.y * 12.0;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Fake metallic shading based on horizontal position
	float gradient = smoothstep(0.2, 0.8, UV.x);
	float highlight = sin(UV.x * 3.14159) * metallic_strength;

	vec3 shaded = tex_color.rgb * (1.0 + highlight * 0.3);

	// Subtle noise-like variation for stone/metal texture
	float noise = fract(sin(dot(UV * 50.0, vec2(12.9898, 78.233))) * 43758.5453);
	shaded += (noise - 0.5) * 0.04;

	// Recoil flash
	shaded += vec3(0.15, 0.08, 0.02) * recoil_amount;

	COLOR = vec4(shaded, tex_color.a);
}
