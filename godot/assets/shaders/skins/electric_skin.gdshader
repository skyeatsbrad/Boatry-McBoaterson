shader_type canvas_item;

uniform float pulse_speed : hint_range(0.5, 10.0) = 3.0;
uniform float bolt_frequency : hint_range(0.0, 1.0) = 0.5;
uniform vec4 glow_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);

// Hash-based noise (no texture needed)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

// Stepped noise for jagged bolt lines
float bolt_noise(vec2 uv, float t) {
	vec2 cell = floor(uv * 20.0);
	float h = hash(cell + floor(t * 8.0));
	return step(1.0 - bolt_frequency * 0.15, h);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = TIME;

	// Lightning bolts: bright lines that appear/disappear rapidly
	float bolt = 0.0;

	// Horizontal bolt traces
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float offset_y = hash(vec2(fi, floor(t * 6.0))) ;
		float bolt_y = fract(offset_y + fi * 0.33);
		float y_dist = abs(UV.y - bolt_y);

		// Jagged horizontal path
		float jag = hash(vec2(floor(UV.x * 30.0), fi + floor(t * 10.0)));
		float line_width = 0.008 + jag * 0.006;

		float active = step(1.0 - bolt_frequency, hash(vec2(fi + 0.5, floor(t * 5.0))));
		bolt += active * smoothstep(line_width, 0.0, y_dist);
	}

	// Vertical bolt traces
	for (int i = 0; i < 2; i++) {
		float fi = float(i) + 10.0;
		float bolt_x = hash(vec2(fi, floor(t * 4.0)));
		float x_dist = abs(UV.x - bolt_x);
		float jag = hash(vec2(floor(UV.y * 25.0), fi + floor(t * 8.0)));
		float line_width = 0.006 + jag * 0.005;
		float active = step(1.0 - bolt_frequency, hash2(vec2(fi, floor(t * 7.0))));
		bolt += active * smoothstep(line_width, 0.0, x_dist);
	}

	bolt = clamp(bolt, 0.0, 1.0);

	// Pulse glow that throbs at ~3Hz (controlled by pulse_speed)
	float pulse = (sin(t * pulse_speed * TAU) * 0.5 + 0.5);
	pulse = pulse * 0.3 + 0.1;

	// Random crackling sparks
	float spark = step(0.992, hash(floor(UV * 60.0) + floor(t * 15.0)));

	// Combine: bolts + pulse glow + sparks over original texture
	vec3 electric = glow_color.rgb * (bolt + spark);
	vec3 glow = glow_color.rgb * pulse;
	vec3 result = tex.rgb + electric * 0.9 + glow;

	COLOR = vec4(result, tex.a);
}
