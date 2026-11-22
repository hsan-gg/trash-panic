// Cartoon harbour water: deep blue with drifting light ripples and white foam hugging the platform.
shader_type spatial;
render_mode unshaded;

uniform vec3 deep : source_color = vec3(0.10, 0.22, 0.42);
uniform vec3 shallow : source_color = vec3(0.16, 0.42, 0.66);
uniform vec3 foam : source_color = vec3(0.92, 0.97, 1.0);
uniform vec2 platform = vec2(9.6, 6.0);  // half extents of the platform the foam hugs

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wave(vec2 p, float t) {
	return sin(p.x * 1.3 + t * 0.9) * sin(p.y * 1.1 - t * 0.7) + 0.5 * sin((p.x + p.y) * 2.3 + t * 1.6);
}

void fragment() {
	vec2 p = world_pos.xz;
	float w = wave(p * 0.6, TIME);
	vec3 col = mix(deep, shallow, smoothstep(-0.6, 1.2, w));
	float ripple = smoothstep(0.92, 1.0, sin(w * 3.0 + p.x * 0.4 + TIME * 0.5));
	col = mix(col, shallow * 1.35, ripple * 0.5);
	vec2 d = abs(p) - platform;
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
	float band = 0.35 + 0.18 * sin(TIME * 1.8 + (p.x + p.y) * 0.8);
	float f = 1.0 - smoothstep(band * 0.6, band, dist);
	f = max(f, smoothstep(0.75, 0.95, sin(dist * 5.0 - TIME * 2.2)) * (1.0 - smoothstep(0.6, 2.4, dist)) * 0.8);
	ALBEDO = mix(col, foam, f);
}
