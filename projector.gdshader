shader_type canvas_item;
render_mode skip_vertex_transform;

uniform bool is_enabled = false;

uniform sampler2D cam_texture : hint_default_white;
uniform sampler2D depth_texture : hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 clear_color : source_color = vec4(0.0);

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

uniform int reprojection_steps : hint_range(10, 500) = 100;
uniform float reprojection_distance : hint_range(2, 100) = 30;
uniform float reprojection_ray_distance = 10;

void vertex() {
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 world_to_screen_pos(vec3 pos, mat4 proj_matrix, mat4 view_matrix, vec3 cam_origin) {
	pos = pos - cam_origin;
	vec4 p = proj_matrix * vec4((view_matrix * vec4(pos, 0.0f)).xyz, 1.0f);
	vec3 pd = p.xyz / p.w;
	return vec2(
		pd.x * 0.5 + 0.5,
		-pd.y * 0.5 + 0.5
	);
}

float get_depth(vec2 uv) {
	float b = texture(depth_texture, uv).r;
	// this is how LinearEyeDepth() from unity works
	float d = 1.0 / (((1.0 - far_clip / near_clip) / far_clip) * b + ((far_clip / near_clip) / far_clip));
	return d * 0.1f;
}

vec3 get_world_pos(vec3 camera_vector, vec3 camera_forward, vec3 camera_pos, vec2 uv) {
	float d = dot(camera_forward, camera_vector);
	float dist = get_depth(uv) / d;
	return camera_pos + camera_vector * dist;
}

void fragment() {
	
	if (is_enabled) {
		
		// map the screen pos to world space
		vec3 cam_ray = mix(mix(top_left, top_right, UV.x), mix(bottom_left, bottom_right, UV.x), UV.y);
		bool occluded = false;
		
		vec2 uv3 = world_to_screen_pos(
					frozen_cam_pos + cam_ray, 
					frozen_projection_matrix, 
					frozen_world_to_camera_matrix, 
					frozen_cam_pos);
		
		if (reproject_movement) {
			
			vec3 ray_pos = cam_pos;
			vec3 ray_end = cam_pos + cam_forward * reprojection_ray_distance;
			
			float step_size = reprojection_distance / float(reprojection_steps);
			float distance_from_world_to_pos;
			
			for (int i = 0; i < reprojection_steps; i++) {
				
				// step ray forward
				ray_pos += cam_ray * step_size;
				
				vec2 uv4 = world_to_screen_pos(
								ray_pos, 
								frozen_projection_matrix, 
								frozen_world_to_camera_matrix, 
								frozen_cam_pos);
								
				// sample depth texture for point
				vec3 traced_pos = get_world_pos(
								normalize(ray_pos - frozen_cam_pos),
								frozen_cam_forward,
								frozen_cam_pos,
								uv4);
				
				float distance_to_ray = distance(frozen_cam_pos, ray_pos);
				float distance_to_world = distance(frozen_cam_pos, traced_pos);
				
				distance_from_world_to_pos = distance_to_ray - distance_to_world;
				
				if (distance_from_world_to_pos > step_size) {
					occluded = true;
				}
				if (distance_from_world_to_pos > 0.0f) {
					break;
				}
			}
			
			uv3 = world_to_screen_pos(
					ray_pos, 
					frozen_projection_matrix, 
					frozen_world_to_camera_matrix, 
					frozen_cam_pos);
			
		}
		
		COLOR = vec4(texture(cam_texture, uv3).rgb, 1.0);
		
		if ((uv3.x < 0.0 || uv3.y < 0.0 || uv3.x > 1.0 || uv3.y > 1.0) && !stretch_borders) {
			COLOR = vec4(clear_color.rgb, 1.0);
		}
		
		if (occluded) {
			float offset = 0.1f;
			vec2 offset_uv_left  = uv3 + vec2( 1, 0) * offset;
			vec2 offset_uv_right = uv3 + vec2( 0, 1) * offset;
			vec2 offset_uv_up    = uv3 + vec2(-1, 0) * offset;
			vec2 offset_uv_down  = uv3 + vec2( 0,-1) * offset;

			vec3 main_tex_left  = texture(cam_texture, offset_uv_left ).rgb;
			vec3 main_tex_right = texture(cam_texture, offset_uv_right).rgb;
			vec3 main_tex_up    = texture(cam_texture, offset_uv_up   ).rgb;
			vec3 main_tex_down  = texture(cam_texture, offset_uv_down ).rgb;

			float depth       = get_depth(uv3);
			float depth_left  = get_depth(offset_uv_left );
			float depth_right = get_depth(offset_uv_right);
			float depth_up    = get_depth(offset_uv_up   );
			float depth_down  = get_depth(offset_uv_down );

			// Find the furthest away one of these five samples
			float max_depth = max(max(max(max(depth, depth_left), depth_right), depth_up), depth_down);
			if (max_depth == depth_left)
				COLOR = vec4(main_tex_left, 1.0f);
			if (max_depth == depth_right)
				COLOR = vec4(main_tex_right, 1.0f);
			if (max_depth == depth_up)
				COLOR = vec4(main_tex_up, 1.0f);
			if (max_depth == depth_down)
				COLOR = vec4(main_tex_down, 1.0f);
		}
		
	} else {
		COLOR = texture(cam_texture, UV);
	}
	
	
}
















