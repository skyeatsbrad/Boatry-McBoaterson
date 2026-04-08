shader_type canvas_item;

uniform float scroll_speed : hint_range(0.1, 5.0) = 1.5;
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.5;
uniform vec4 gold_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Gold base tint
	vec3 gold_base = gold_color.rgb * 0.6;
	vec3 gold_bright = vec3(1.0, 0.95, 0.7);

	// Scrolling specular highlight band (diagonal across surface)
	float diag = UV.x + UV.y;
	float band_pos = fract(diag * 0.5 - TIME * scroll_speed * 0.3);
	float band = smoothstep(0.42, 0.48, band_pos) * smoothstep(0.58, 0.52, band_pos);
	// Secondary thinner band
	float band_pos2 = fract(diag * 0.5 - TIME * scroll_speed * 0.3 + 0.3);
	float band2 = smoothstep(0.46, 0.49, band_pos2) * smoothstep(0.54, 0.51, band_pos2);

	float highlight = band + band2 * 0.6;

	// Sparkle points: random bright pixels that flash
	vec2 sparkle_cell = floor(UV * 40.0);
	float sparkle_hash = hash(sparkle_cell);
	float sparkle_time = hash(sparkle_cell + vec2(0.5, 0.5));
	// Sparkle blinks on and off based on time
	float sparkle_phase = sin(TIME * 4.0 + sparkle_time * TAU) * 0.5 + 0.5;
	float sparkle = step(1.0 - sparkle_density * 0.08, sparkle_hash) * step(0.85, sparkle_phase);

	// Combine: gold-tinted original + highlight band + sparkles
	vec3 tinted = mix(tex.rgb, tex.rgb * gold_base + gold_base * 0.3, 0.6);
	tinted += gold_bright * highlight * 0.7;
	tinted += vec3(1.0, 1.0, 0.9) * sparkle * 0.8;

	COLOR = vec4(tinted, tex.a);
}
