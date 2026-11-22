// Soft dark corners that pull the eye to the middle of the room.
shader_type canvas_item;

uniform float strength = 0.35;

void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.8)) * 1.3);
	COLOR = vec4(0.02, 0.03, 0.08, v * strength);
}
