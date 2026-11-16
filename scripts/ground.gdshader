shader_type spatial;
// Tanah pulau: 3 jenis rumput (segar, kering dekat pantai, gelap dekat hutan) + jalan tanah.

uniform sampler2D tex_fresh : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dry : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dark : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_path : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_size = 3.2;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec3 samp(sampler2D t, vec2 uv) {
	// dua skala dicampur supaya pola ulangan tidak terlihat
	return mix(texture(t, uv).rgb, texture(t, uv * 0.37 + vec2(0.31, 0.17)).rgb, 0.4);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p / tile_size;
	float r = length(p);
	float n = vnoise(p * 0.09);
	float w_dry = smoothstep(27.0, 38.0, r + (n - 0.5) * 9.0);
	float w_dark = smoothstep(0.58, 0.74, vnoise(p * 0.07 + 11.0)) * (1.0 - w_dry);
	vec3 col = mix(samp(tex_fresh, uv), samp(tex_dark, uv), w_dark);
	col = mix(col, samp(tex_dry, uv), w_dry);
	float d = min(min(seg(p, vec2(0.0, 12.0), vec2(0.0, -1.5)), seg(p, vec2(-9.0, 0.6), vec2(9.0, 0.6))),
			seg(p, vec2(0.0, 6.0), vec2(7.0, 8.5)));
	float w_path = 1.0 - smoothstep(0.55, 1.25, d + (n - 0.5) * 0.7);
	col = mix(col, samp(tex_path, uv * 0.9), w_path);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
