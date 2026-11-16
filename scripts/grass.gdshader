shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
// Rumpun rumput berdiri dengan efek tertiup angin (pangkal diam, ujung bergoyang).

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float wind_strength = 0.22;
uniform float wind_speed = 1.5;

void vertex() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	vec3 base = MODEL_MATRIX[3].xyz;
	float ph = base.x * 0.45 + base.z * 0.35;
	float gust = sin(TIME * wind_speed + ph) + 0.5 * sin(TIME * wind_speed * 2.3 + ph * 1.7);
	VERTEX.x += gust * wind_strength * h * h;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + ph) * wind_strength * 0.5 * h * h;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
