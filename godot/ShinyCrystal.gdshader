// NOTE: Shader automatically converted from Godot Engine 3.5.1.stable's SpatialMaterial.

shader_type spatial;
render_mode cull_disabled, depth_draw_alpha_prepass, vertex_lighting;//, ensure_correct_normals;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular;
uniform float metallic;
uniform float grow;
uniform float roughness : hint_range(0,1);
uniform float flash : hint_range(0,1);
uniform float point_size : hint_range(0,128);
uniform sampler2D texture_emission : hint_black_albedo;
uniform vec4 emission : hint_color;
uniform float emission_energy;
uniform sampler2D texture_refraction;
uniform float refraction : hint_range(-16,16);
uniform vec4 refraction_texture_channel;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16);
uniform float rim : hint_range(0,1);
uniform float rim_tint : hint_range(0,1);
uniform sampler2D texture_rim : hint_white;
uniform float clearcoat : hint_range(0,1);
uniform float clearcoat_gloss : hint_range(0,1);
uniform sampler2D texture_clearcoat : hint_white;
uniform float anisotropy_ratio : hint_range(0,256);
uniform sampler2D texture_flowmap : hint_aniso;
uniform sampler2D texture_ambient_occlusion : hint_white;
uniform vec4 ao_texture_channel;
uniform float ao_light_affect;
uniform sampler2D texture_detail_albedo : hint_albedo;
uniform sampler2D texture_detail_normal : hint_normal;
uniform sampler2D texture_detail_mask : hint_white;
uniform vec4 transmission : hint_color;
uniform sampler2D texture_transmission : hint_black;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;


void vertex() {
	ROUGHNESS=0.7;
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	VERTEX+=NORMAL*grow;
}




void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	//SPECULAR = specular;
	NORMALMAP = texture(texture_normal,base_uv).rgb;
	NORMALMAP_DEPTH = normal_scale;
	vec3 emission_tex = texture(texture_emission,base_uv).rgb;
	EMISSION = (emission.rgb+emission_tex)*emission_energy;
	vec3 unpacked_normal = NORMALMAP;
	unpacked_normal.xy = unpacked_normal.xy * 2.0 - 1.0;
	unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * dot(texture(texture_refraction,base_uv),refraction_texture_channel) * refraction;
	float ref_amount = 1.0 - albedo.a * albedo_tex.a;
	//EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
	vec2 rim_tex = texture(texture_rim,base_uv).xy;
	RIM = rim*rim_tex.x;	RIM_TINT = rim_tint*rim_tex.y;
	vec2 clearcoat_tex = texture(texture_clearcoat,base_uv).xy;
	CLEARCOAT = clearcoat*clearcoat_tex.x;	CLEARCOAT_GLOSS = clearcoat_gloss*clearcoat_tex.y;
	vec3 anisotropy_tex = texture(texture_flowmap,base_uv).rga;
	ANISOTROPY = anisotropy_ratio*anisotropy_tex.b;
	ANISOTROPY_FLOW = anisotropy_tex.rg*2.0-1.0;
	AO = dot(texture(texture_ambient_occlusion,base_uv),ao_texture_channel);
	AO_LIGHT_AFFECT = ao_light_affect;
	vec3 transmission_tex = texture(texture_transmission,base_uv).rgb;
	TRANSMISSION = (transmission.rgb+transmission_tex);
	vec4 detail_tex = texture(texture_detail_albedo,base_uv);
	vec4 detail_norm_tex = texture(texture_detail_normal,base_uv);
	vec4 detail_mask_tex = texture(texture_detail_mask,base_uv);
	vec3 detail = mix(ALBEDO.rgb,ALBEDO.rgb+detail_tex.rgb,detail_tex.a);
	vec3 detail_norm = mix(NORMALMAP,detail_norm_tex.rgb,detail_tex.a);
	NORMALMAP = mix(NORMALMAP,detail_norm,detail_mask_tex.r);
	ALBEDO.rgb = mix(ALBEDO.rgb,detail,detail_mask_tex.r);
	ALPHA = 0.5;
}
