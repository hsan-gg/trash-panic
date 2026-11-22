// Conveyor belt top: grey with dark chevrons scrolling along local +X (dir flips them). Jammed belts stop and flash red.
shader_type spatial;

uniform float dir = 1.0;
uniform float speed = 1.0;  // tiles per second
uniform float tiles = 1.0;  // belt length in tiles, so chevrons stay one per tile
uniform float jam = 0.0;
uniform float offset = 0.0;  // the scroll position, advanced by the script so speed changes don't jump

void fragment() {
	vec2 uv = UV;
	float x = uv.x * tiles * 2.0 * dir - offset * 2.0;
	float y = abs(uv.y - 0.5);
	float c = fract(x + y * 1.1);
	float chevron = step(0.5, c);
	vec3 base = vec3(0.62, 0.64, 0.68);
	vec3 dark = vec3(0.20, 0.21, 0.24);
	vec3 col = mix(base, dark, chevron);
	float rim = step(0.43, y);
	col = mix(col, vec3(0.13, 0.13, 0.15), rim);
	col = mix(col, vec3(0.95, 0.2, 0.15), jam * (0.35 + 0.25 * sin(TIME * 10.0)));
	ALBEDO = col;
	ROUGHNESS = 0.7;
}
