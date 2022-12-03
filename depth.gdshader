shader_type spatial;
render_mode unshaded;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	// Place fragment code here.
	
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	ALBEDO = vec3(depth);
}
