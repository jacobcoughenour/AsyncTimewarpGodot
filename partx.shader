shader_type spatial;
render_mode unshaded, cull_disabled;
//render_mode unshaded, world_vertex_coords; // to raymarch in world space

uniform float chunk_size: hint_range(2,32);
uniform sampler3D signed_texture;

varying vec3 world_camera;
varying vec3 world_position;

const int MAX_STEPS = 100;
const float MAX_DIST = 100.0;
const float SURF_DIST = 1e-3;

float sdBox(vec3 p, float b){
	vec3 q = abs(p) - vec3(textureSize(signed_texture, 0));
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float waves(vec2 p) {
	return sin(p.x) * sin(p.y);
}

vec4 SampleVolume(vec3 p) {
	vec3 size = normalize(vec3(textureSize(signed_texture, 0))).xzy;
	p.x *= size.x;
	p.y *= -size.y;
	p.z *= size.z;
	
	return textureLod(signed_texture, p.xzy + size * 0.5, 0);
}

float RayMarch(vec3 ro, vec3 rd) {
	float dO = 0.0;
	float dS;
	
	float dt = 0.005f;
	
	for (float i = 0.001f; i < 4.0f; i += dt) {
		vec3 p = ro + i * rd;
		
		// bounding box
		float dist = sdBox(p, 1.0);
		if (dist > SURF_DIST)
			continue;
		
		dist = 1.0 - SampleVolume(p).a;
		
		if (dist < 0.01) {
			return i;
		}
	}
	return MAX_DIST;
}

vec3 GetNormal(vec3 p) {
	vec2 e = vec2(1.0, 0);
	
	vec3 n = SampleVolume(p).a - vec3(
		SampleVolume(p - e.xyy).a,
		SampleVolume(p - e.yxy).a,
		SampleVolume(p - e.yyx).a
	);
	
	return normalize(n);
}

void vertex() {
	world_position = VERTEX;
	world_camera = (inverse(MODELVIEW_MATRIX) * vec4(0, 0, 0, 1)).xyz; //object space
	//world_camera = ( CAMERA_MATRIX  * vec4(0, 0, 0, 1)).xyz; //uncomment this to raymarch in world space
}

void fragment() {
	
	vec3 ro = world_camera;
	vec3 rd = normalize(world_position - ro);
	
	vec3 col;
	
	float d = RayMarch(ro, rd);

	if (d >= MAX_DIST)
		discard;
	else
	{
		vec3 hit_point = ro + rd * d;
		vec3 n = GetNormal(hit_point);
		
		vec3 color = SampleVolume(hit_point).rgb;
		
		
		n = abs(n) + 0.5;
		float light = n.x + n.y + n.z / 3.0;

//		col = vec3(1.0);
		ALBEDO = color * light;
//		ALBEDO = color * (abs(n) * vec3(1.0, 1.0, 1.0));
		
//		ALBEDO = n.rgb;
	}
	
//	ALBEDO = vec3(1.0 - clamp(d * 0.5 - 0.2, 0.0, 1.0));
}