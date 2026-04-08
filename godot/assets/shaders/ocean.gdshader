shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 mid_color : source_color = vec4(0.08, 0.25, 0.50, 1.0);
uniform vec4 foam_color : source_color = vec4(0.6, 0.8, 0.9, 0.4);
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_scale : hint_range(1.0, 50.0) = 15.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.7;
uniform vec2 scroll_offset = vec2(0.0, 0.0);

void fragment() {
    vec2 uv = UV + scroll_offset * 0.001;
    
    // Layered waves
    float wave1 = sin(uv.x * wave_scale + TIME * wave_speed) * 0.5 + 0.5;
    float wave2 = sin(uv.y * wave_scale * 0.7 + TIME * wave_speed * 0.6 + 1.5) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y) * wave_scale * 0.5 + TIME * wave_speed * 1.2) * 0.5 + 0.5;
    
    float combined = (wave1 + wave2 + wave3) / 3.0;
    
    // Color blend
    vec4 water = mix(deep_color, mid_color, combined);
    
    // Foam on wave peaks
    float foam = smoothstep(foam_threshold, foam_threshold + 0.1, combined);
    water = mix(water, foam_color, foam * 0.5);
    
    // Subtle shimmer
    float shimmer = sin(uv.x * 80.0 + TIME * 2.0) * sin(uv.y * 80.0 + TIME * 1.5);
    water.rgb += vec3(shimmer * 0.02);
    
    COLOR = water;
}
