shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float speed : hint_range(0.1, 5.0) = 2.0;
uniform vec4 base_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Fire flicker: perturb UV.y with layered sin waves
	float flicker1 = sin(UV.x * 12.0 + TIME * speed * 3.0) * 0.04;
	float flicker2 = sin(UV.x * 20.0 - TIME * speed * 5.0) * 0.02;
	float flicker3 = sin(UV.x * 8.0 + TIME * speed * 1.5) * 0.03;
	float distorted_y = UV.y + (flicker1 + flicker2 + flicker3) * intensity;

	// Fire rises from bottom: stronger effect near y=1.0
	float fire_mask = smoothstep(0.3, 1.0, distorted_y);
	fire_mask *= (1.0 + sin(TIME * speed * 2.0) * 0.2); // pulse

	// Orange-red gradient from bottom to top
	vec4 fire_top = vec4(1.0, 0.9, 0.2, 1.0);   // yellow tip
	vec4 fire_mid = base_color;                    // orange
	vec4 fire_bot = vec4(0.8, 0.1, 0.0, 1.0);    // deep red
	float grad = clamp(distorted_y, 0.0, 1.0);
	vec4 fire_color = mix(fire_top, fire_mid, smoothstep(0.0, 0.5, grad));
	fire_color = mix(fire_color, fire_bot, smoothstep(0.5, 1.0, grad));

	// Edge glow: distance from edge (0 at edge, 1 at center)
	float edge_x = min(UV.x, 1.0 - UV.x) * 2.0;
	float edge_y = min(UV.y, 1.0 - UV.y) * 2.0;
	float edge_dist = min(edge_x, edge_y);
	float edge_glow = (1.0 - smoothstep(0.0, 0.25, edge_dist)) * intensity;

	// Combine
	vec3 result = mix(tex.rgb, fire_color.rgb, fire_mask * intensity * 0.7);
	result += vec3(1.0, 0.6, 0.2) * edge_glow * 0.5;

	COLOR = vec4(result, tex.a);
}
