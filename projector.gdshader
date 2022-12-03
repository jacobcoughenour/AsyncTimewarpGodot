shader_type canvas_item;
render_mode skip_vertex_transform;

uniform bool is_enabled = false;

uniform sampler2D cam_texture : hint_default_white;
uniform sampler2D depth_texture : hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 clear_color : source_color = vec4(0.0);

//uniform vec3 debug_point = vec3(0);

uniform float near_clip = 0.0f;
uniform float far_clip = 0.0f;

uniform mat4 frozen_world_to_camera_matrix;
uniform mat4 frozen_projection_matrix;
uniform mat4 world_to_camera_matrix;
uniform mat4 projection_matrix;

uniform vec3 cam_pos;
uniform vec3 cam_forward;
uniform vec3 top_left;
uniform vec3 top_right;
uniform vec3 bottom_left;
uniform vec3 bottom_right;

uniform vec3 frozen_cam_pos;
uniform vec3 frozen_cam_forward;
uniform vec3 frozen_top_left;
uniform vec3 frozen_top_right;
uniform vec3 frozen_bottom_left;
uniform vec3 frozen_bottom_right;

uniform bool stretch_borders = true;
uniform bool reproject_movement = false;

varying vec3 vert;

void vertex() {
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 WorldToScreenPos(vec3 pos, mat4 CameraProjection, mat4 WorldToCamera, vec3 CameraPosition, vec2 TextureSize) {
	pos = pos - CameraPosition;
	vec4 p = CameraProjection * vec4((WorldToCamera * vec4(pos, 0.0f)).xyz, 1.0f);
	vec3 pd = p.xyz / p.w;
	return vec2(
		pd.x * 0.5 + 0.5,
		-pd.y * 0.5 + 0.5
	);
}

void fragment() {
	
	if (is_enabled) {
		// map the screen pos to world space
		vec3 cam_point = mix(mix(top_left, top_right, UV.x), mix(bottom_left, bottom_right, UV.x), UV.y);
		vec3 cam_point_frozen = mix(mix(frozen_top_left, frozen_top_right, UV.x), mix(frozen_bottom_left, frozen_bottom_right, UV.x), UV.y);
		
		vec3 ray_start = cam_pos;
		vec3 ray_pos = ray_start;
		vec3 ray_end = cam_pos + cam_forward * 10.0f;
		
		vec2 size = vec2(textureSize(cam_texture, 0));
		
		vec2 uv3 = WorldToScreenPos(frozen_cam_pos + cam_point, frozen_projection_matrix, frozen_world_to_camera_matrix, frozen_cam_pos, size);


		

		if ((uv3.x < 0.0 || uv3.y < 0.0 || uv3.x > 1.0 || uv3.y > 1.0) && !stretch_borders) {
			COLOR = vec4(clear_color.rgb, 1.0);
		} else {
			COLOR = texture(cam_texture, uv3);
		}
	} else {
		COLOR = texture(cam_texture, UV);
	}
	
	
}
















