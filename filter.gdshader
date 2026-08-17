shader_type canvas_item;
// Full-screen display filter for the pause-menu "FILTER" option.
//   mode 0 = REGULAR (rect is hidden, so this never actually runs)
//   mode 1 = CRT      (scanlines + RGB aperture mask + vignette)
//   mode 2 = INVERTED (colour negative)
// Reads the already-rendered frame via the screen texture and rewrites it.

uniform int mode = 0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 screen_size = vec2(256.0, 240.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;

	if (mode == 2) {
		// colour negative
		col = vec3(1.0) - col;
	} else if (mode == 1) {
		// --- scanlines: gently darken the gap between every source row ---
		float line = 0.5 + 0.5 * sin(uv.y * screen_size.y * 3.14159265);
		col *= mix(0.82, 1.0, line);

		// --- RGB aperture grille: light tint on successive columns R / G / B ---
		int c = int(mod(floor(uv.x * screen_size.x), 3.0));
		vec3 mask = vec3(0.92);
		if (c == 0) mask.r = 1.0;
		else if (c == 1) mask.g = 1.0;
		else mask.b = 1.0;
		col *= mask;

		// --- brightness compensation for the mild darkening above ---
		col *= 1.12;

		// --- subtle vignette toward the edges ---
		vec2 d = uv - vec2(0.5);
		col *= 1.0 - dot(d, d) * 0.35;
	}

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
