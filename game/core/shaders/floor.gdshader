// Trash-is-Fun style floor: small glossy tiles, white with scattered soft-teal ones, thin grout lines.
shader_type spatial;

uniform vec3 white : source_color = vec3(0.96, 0.98, 0.98);
uniform vec3 teal : source_color = vec3(0.42, 0.77, 0.80);
uniform vec3 deep : source_color = vec3(0.27, 0.62, 0.69);
uniform vec3 grout : source_color = vec3(0.70, 0.80, 0.82);
uniform float tile = 0.6;  // two floor tiles per 1.2 m game tile
uniform float teal_share = 0.46;
uniform vec2 lane = vec2(7.8, 4.2);  // outer walk lane (half extents): darker teal beyond it

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / tile + 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = 1.0 - smoothstep(0.03, 0.06, edge);
	float h = hash(cell);
	vec3 col = h < teal_share ? mix(teal, deep, step(0.85, hash(cell + 7.0))) : white;
	vec2 a = abs(world_pos.xz);
	if (a.x > lane.x || a.y > lane.y) {
		col = mix(col, deep, 0.55);
	}
	col *= 0.97 + 0.03 * hash(cell + 3.0);
	ALBEDO = mix(col, grout, seam);
	ROUGHNESS = mix(0.7, 0.95, seam);  // satin, not gloss: a glossy floor glares under the sun
	SPECULAR = 0.35;
}
