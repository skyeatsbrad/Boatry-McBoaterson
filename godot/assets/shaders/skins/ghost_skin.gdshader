shader_type canvas_item;

uniform float transparency : hint_range(0.0, 1.0) = 0.5;
uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform float tendril_speed : hint_range(0.1, 5.0) = 1.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Wispy tendrils at bottom via UV distortion
	vec2 uv = UV;
	float tendril_mask = smoothstep(0.5, 1.0, UV.y); // stronger at bottom
	float wave1 = sin(UV.x * 15.0 + TIME * tendril_speed * 2.0) * 0.03;
	float wave2 = sin(UV.x * 25.0 - TIME * tendril_speed * 3.0) * 0.02;
	float wave3 = sin(UV.x * 10.0 + TIME * tendril_speed) * 0.015;
	uv.x += (wave1 + wave2 + wave3) * tendril_mask;
	uv.y += sin(UV.x * 20.0 + TIME * tendril_speed * 1.5) * 0.02 * tendril_mask;

	vec4 tex = texture(TEXTURE, uv);

	// Fresnel-like edge glow using UV distance from center
	vec2 center_dist = UV - vec2(0.5, 0.5);
	float dist = length(center_dist) * 2.0; // 0 at center, ~1.414 at corners
	float fresnel = smoothstep(0.3, 1.0, dist);

	// Eerie edge glow
	vec3 edge_glow = glow_color.rgb * fresnel * 0.6;
	// Subtle inner glow pulsing
	float glow_pulse = sin(TIME * 1.5) * 0.15 + 0.85;

	// Fade in and out slowly
	float fade = sin(TIME * 0.8) * 0.15 + 0.85;
	float final_alpha = tex.a * transparency * fade;

	// Ghostly desaturation
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(tex.rgb, vec3(luma), 0.5);

	// Tint toward ghost color
	vec3 ghost_tint = mix(desaturated, glow_color.rgb * 0.5, 0.2);
	ghost_tint += edge_glow * glow_pulse;

	// Wispy bottom fade
	float bottom_wisps = tendril_mask * (sin(UV.x * 30.0 + TIME * tendril_speed * 4.0) * 0.5 + 0.5);
	final_alpha *= mix(1.0, 0.3, bottom_wisps * 0.5);

	COLOR = vec4(ghost_tint, final_alpha);
}
