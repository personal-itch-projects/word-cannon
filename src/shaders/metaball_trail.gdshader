shader_type canvas_item;

// Viewport-based metaball trail shader.
// Maps accumulated brightness from overlapping radial gradients
// to a color gradient, creating merging metaball shapes.
// Technique from: https://godotshaders.com/shader/2d-metaballs/

uniform sampler2D gradient_tex : filter_linear;

void fragment() {
	float b = texture(TEXTURE, UV).r;
	COLOR = texture(gradient_tex, vec2(b, 0.0));
}
