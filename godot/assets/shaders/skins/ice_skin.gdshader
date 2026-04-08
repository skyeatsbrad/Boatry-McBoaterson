shader_type canvas_item;

uniform float frost_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float sparkle_rate : hint_range(0.0, 10.0) = 4.0;
uniform vec4 base_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Simple voronoi-like pattern for crystalline facets
float voronoi(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 frac_uv = fract(uv);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = vec2(hash(cell + neighbor), hash(cell + neighbor + vec2(37.0, 91.0)));
			float d = length(neighbor + point - frac_uv);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Crystalline facets via voronoi
	float crystal = voronoi(UV * 12.0);
	// Edge lines of facets
	float facet_edge = smoothstep(0.05, 0.12, crystal);
	float facet_line = 1.0 - facet_edge;

	// Pale blue ice tint
	vec3 ice_tint = mix(tex.rgb, base_color.rgb, 0.4 * frost_intensity);

	// Facet highlights: brighter at cell edges
	ice_tint += vec3(0.6, 0.8, 1.0) * facet_line * 0.3 * frost_intensity;

	// Frost sparkle: random bright spots that twinkle
	vec2 sparkle_cell = floor(UV * 50.0);
	float s_hash = hash(sparkle_cell);
	float s_time = hash(sparkle_cell + vec2(13.0, 7.0));
	float sparkle_blink = sin(TIME * sparkle_rate + s_time * TAU) * 0.5 + 0.5;
	float sparkle = step(0.96, s_hash) * step(0.8, sparkle_blink);
	ice_tint += vec3(0.9, 0.95, 1.0) * sparkle;

	// Cold mist at edges (blurred white border)
	float edge_x = min(UV.x, 1.0 - UV.x) * 2.0;
	float edge_y = min(UV.y, 1.0 - UV.y) * 2.0;
	float edge_dist = min(edge_x, edge_y);
	float mist = (1.0 - smoothstep(0.0, 0.2, edge_dist)) * frost_intensity;
	// Mist pulses subtly
	mist *= 0.8 + sin(TIME * 1.2) * 0.2;
	ice_tint += vec3(0.9, 0.95, 1.0) * mist * 0.4;

	COLOR = vec4(ice_tint, tex.a);
}
