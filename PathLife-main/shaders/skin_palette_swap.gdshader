shader_type canvas_item;

// Troca exata das cores discretas da pixel art. Cada perfil informa as cores
// realmente presentes nos PNGs e a posição tonal delas (0=sombra, 1=luz).
const int MAX_COLORS = 24;
// A comparação continua abaixo de dois níveis RGB. O pequeno espaço extra é
// necessário porque alguns drivers convertem sRGB e devolvem um canal a 1/255.
const float TOLERANCE = 0.005882353; // 1,5 / 255

uniform int color_count = 0;
uniform vec4 source_colors[MAX_COLORS];
uniform float tone_positions[MAX_COLORS];
uniform vec4 target_shadow : source_color;
uniform vec4 target_base : source_color;
uniform vec4 target_highlight : source_color;

vec3 color_at_tone(float tone) {
	if (tone <= 0.5) {
		return mix(target_shadow.rgb, target_base.rgb, tone * 2.0);
	}
	return mix(target_base.rgb, target_highlight.rgb, (tone - 0.5) * 2.0);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 replacement = tex_color.rgb;
	for (int index = 0; index < MAX_COLORS; index++) {
		if (index >= color_count) {
			break;
		}
		if (distance(tex_color.rgb, source_colors[index].rgb) <= TOLERANCE) {
			replacement = color_at_tone(tone_positions[index]);
			break;
		}
	}
	COLOR = vec4(replacement, tex_color.a);
}
