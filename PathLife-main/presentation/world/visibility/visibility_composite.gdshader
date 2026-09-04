shader_type canvas_item;
render_mode unshaded;

uniform vec4 unknown_color : source_color = vec4(0.012, 0.016, 0.024, 1.0);
uniform vec4 remembered_color : source_color = vec4(0.035, 0.048, 0.065, 0.82);
uniform vec4 forced_hidden_color : source_color = vec4(0.008, 0.010, 0.016, 1.0);
uniform float edge_softness_texels : hint_range(0.0, 4.0, 0.1) = 1.5;

void fragment() {
	vec4 center_mask = texture(TEXTURE, UV);
	vec2 radius = TEXTURE_PIXEL_SIZE * edge_softness_texels;

	// Uma amostragem fixa funciona no renderer Compatibility e suaviza somente
	// a fronteira. A topologia continua discreta e conservadora no solver.
	float visible_coverage = center_mask.r * 4.0;
	visible_coverage += texture(TEXTURE, UV + vec2(radius.x, 0.0)).r;
	visible_coverage += texture(TEXTURE, UV - vec2(radius.x, 0.0)).r;
	visible_coverage += texture(TEXTURE, UV + vec2(0.0, radius.y)).r;
	visible_coverage += texture(TEXTURE, UV - vec2(0.0, radius.y)).r;
	visible_coverage *= 0.125;
	visible_coverage = smoothstep(0.0, 1.0, visible_coverage);

	// Suavidade não pode sangrar visão de uma célula vizinha para uma célula
	// estruturalmente selada. O próprio texel ainda pode ser VISIBLE, que é a
	// prioridade máxima do contrato.
	float forced_hidden = center_mask.b * (1.0 - center_mask.r);
	visible_coverage = mix(visible_coverage, center_mask.r, forced_hidden);
	float remembered = center_mask.g * (1.0 - forced_hidden);
	vec4 fog_color = mix(unknown_color, remembered_color, remembered);
	fog_color = mix(fog_color, forced_hidden_color, forced_hidden);

	// Visibilidade atual sempre vence ocultação forçada e memória.
	fog_color.a *= 1.0 - visible_coverage;
	COLOR = fog_color;
}
