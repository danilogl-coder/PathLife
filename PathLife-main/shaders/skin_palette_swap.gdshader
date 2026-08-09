shader_type canvas_item;
// PathLife — troca de rampa de cor (chroma swap).
// Os sprites-base usam 4 verdes-chave. Este shader substitui cada um
// pela cor correspondente da rampa alvo, preservando o sombreamento.
// Serve para pele, mas também para cabelo e roupas (basta pintar a
// camada com os mesmos 4 verdes-chave).

// Rampa alvo (padrão: pele clara)
uniform vec4 target_highlight : source_color = vec4(1.0, 0.8667, 0.7451, 1.0);
uniform vec4 target_base      : source_color = vec4(0.9216, 0.7412, 0.5922, 1.0);
uniform vec4 target_shade     : source_color = vec4(0.7490, 0.5529, 0.4157, 1.0);
uniform vec4 target_dark      : source_color = vec4(0.4706, 0.3137, 0.2353, 1.0);

// Verdes-chave dos sprites-base (NÃO alterar sem regerar os assets)
const vec3 KEY_HIGHLIGHT = vec3(0.5490, 0.9020, 0.4314); // 140,230,110
const vec3 KEY_BASE      = vec3(0.3529, 0.7451, 0.2745); //  90,190, 70
const vec3 KEY_SHADE     = vec3(0.2157, 0.5490, 0.2157); //  55,140, 55
const vec3 KEY_DARK      = vec3(0.1176, 0.3333, 0.1569); //  30, 85, 40

const float TOLERANCE = 0.02;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 rgb = tex_color.rgb;
	if (distance(rgb, KEY_HIGHLIGHT) < TOLERANCE) {
		COLOR = vec4(target_highlight.rgb, tex_color.a);
	} else if (distance(rgb, KEY_BASE) < TOLERANCE) {
		COLOR = vec4(target_base.rgb, tex_color.a);
	} else if (distance(rgb, KEY_SHADE) < TOLERANCE) {
		COLOR = vec4(target_shade.rgb, tex_color.a);
	} else if (distance(rgb, KEY_DARK) < TOLERANCE) {
		COLOR = vec4(target_dark.rgb, tex_color.a);
	} else {
		COLOR = tex_color;
	}
}
