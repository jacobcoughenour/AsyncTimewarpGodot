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

uniform int reprojection_steps : hint_range(10, 500) = 500;
uniform float reprojection_distance : hint_range(2, 100) = 10;

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

float depth(vec2 uv) {
	float b = texture(depth_texture, uv).r;
	// this is how LinearEyeDepth() from unity works
	return 1.0 / (((1.0 - far_clip / near_clip) / far_clip) * b + ((far_clip / near_clip) / far_clip));
}

void fragment() {
	
	if (is_enabled) {
		// map the screen pos to world space
		vec3 cam_ray = mix(mix(top_left, top_right, UV.x), mix(bottom_left, bottom_right, UV.x), UV.y);
		vec3 cam_ray_frozen = mix(mix(frozen_top_left, frozen_top_right, UV.x), mix(frozen_bottom_left, frozen_bottom_right, UV.x), UV.y);
		vec2 uv3;
		
		bool occluded = false;
		
		if (reproject_movement) {
			
			vec3 ray_pos = cam_pos;
			vec3 ray_end = cam_pos + cam_forward * 10.0f;
			
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
								
				vec3 cam_norm = normalize(ray_pos - frozen_cam_pos);
								
				// trace depth texture
				float d = dot(frozen_cam_forward, cam_norm);
				float dist = depth(UV) / d;
				vec3 world_pos = frozen_cam_pos + cam_norm * dist;
				
				float distance_to_ray = distance(frozen_cam_pos, ray_pos);
				float distance_to_world = distance(frozen_cam_pos, world_pos);
				
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
			
		} else {
		 	uv3 = world_to_screen_pos(
					frozen_cam_pos + cam_ray, 
					frozen_projection_matrix, 
					frozen_world_to_camera_matrix, 
					frozen_cam_pos);
		}
		
		
		COLOR = texture(cam_texture, uv3);
		
		if ((uv3.x < 0.0 || uv3.y < 0.0 || uv3.x > 1.0 || uv3.y > 1.0) && !stretch_borders) {
			COLOR = vec4(clear_color.rgb, 1.0);
		}
		
		if (occluded) {
			vec2 OffsetUVLeft     = uv3 + vec2(1, 0)  * 0.01f;
			vec2 OffsetUVRight    = uv3 + vec2(0, 1)  * 0.01f;
			vec2 OffsetUVTop      = uv3 + vec2(-1, 0) * 0.01f;
			vec2 OffsetUVDown     = uv3 + vec2(0, -1) * 0.01f;

			vec3 MainTexLeft      = texture(cam_texture, OffsetUVLeft ).rgb;
			vec3 MainTexRight     = texture(cam_texture, OffsetUVRight).rgb;
			vec3 MainTexTop       = texture(cam_texture, OffsetUVTop  ).rgb;
			vec3 MainTexDown      = texture(cam_texture, OffsetUVDown ).rgb;

			float Depth             = depth(uv3);
			float DepthLeft         = depth(OffsetUVLeft );
			float DepthRight        = depth(OffsetUVRight);
			float DepthTop          = depth(OffsetUVTop  );
			float DepthDown         = depth(OffsetUVDown );

			// Find the furthest away one of these five samples
			float FurthestDepth = max(max(max(max(Depth, DepthLeft), DepthRight), DepthTop), DepthDown);
			if (FurthestDepth == DepthLeft)
				COLOR = vec4(MainTexLeft, 1.0f);
			if (FurthestDepth == DepthRight)
				COLOR = vec4(MainTexRight, 1.0f);
			if (FurthestDepth == DepthTop)
				COLOR = vec4(MainTexTop, 1.0f);
			if (FurthestDepth == DepthDown)
				COLOR = vec4(MainTexDown, 1.0f);
		}
		
	} else {
		COLOR = texture(cam_texture, UV);
	}
	
	
}
















