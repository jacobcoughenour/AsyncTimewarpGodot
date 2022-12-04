shader_type spatial;
render_mode unshaded;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
	ALBEDO = vec3(depth);
}
