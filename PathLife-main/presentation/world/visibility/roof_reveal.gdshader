shader_type canvas_item;
render_mode unshaded;

// Uma textura R8 por estrutura. Cada texel representa uma célula do Piso.
uniform sampler2D reveal_mask : filter_nearest, repeat_disable;
uniform vec2 mask_size = vec2(1.0);
uniform vec2 used_rect_position = vec2(0.0);
uniform vec2 tile_size = vec2(128.0, 64.0);
uniform vec2 roof_to_floor_offset = vec2(0.0);
uniform vec2 roof_to_floor_x = vec2(1.0, 0.0);
uniform vec2 roof_to_floor_y = vec2(0.0, 1.0);
uniform float visual_reveal_height_px : hint_range(0.0, 512.0, 1.0) = 192.0;
uniform float revealed_alpha : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool mask_valid = false;

varying vec2 floor_local_position;


void vertex() {
	// VERTEX está no espaço local da camada Telhado. O controlador fornece o
	// deslocamento até o espaço local da camada Piso.
	floor_local_position = roof_to_floor_offset
		+ roof_to_floor_x * VERTEX.x
		+ roof_to_floor_y * VERTEX.y;
}


float cell_reveal_at(vec2 local_position) {
	vec2 half_tile = tile_size * 0.5;
	vec2 point = local_position - half_tile;
	float logical_x = (point.x / half_tile.x + point.y / half_tile.y) * 0.5;
	float logical_y = (point.y / half_tile.y - point.x / half_tile.x) * 0.5;
	vec2 cell = floor(vec2(logical_x, logical_y) + vec2(0.5));
	vec2 relative_cell = cell - used_rect_position;
	if (
		relative_cell.x < 0.0 || relative_cell.y < 0.0
		|| relative_cell.x >= mask_size.x || relative_cell.y >= mask_size.y
	) {
		return 0.0;
	}
	vec2 mask_uv = (relative_cell + vec2(0.5)) / mask_size;
	return texture(reveal_mask, mask_uv).r;
}


void fragment() {
	if (mask_valid) {
		// Um telhado isométrico ocupa pixels acima da célula que ele cobre. As
		// amostras verticais encontram essa célula sem depender do atlas usado pela
		// estrutura e continuam restritas à máscara exclusiva desta construção.
		float reveal = 0.0;
		for (int sample_index = 0; sample_index < 9; sample_index++) {
			float amount = float(sample_index) / 8.0;
			vec2 sample_position = floor_local_position
				+ vec2(0.0, visual_reveal_height_px * amount);
			reveal = max(reveal, cell_reveal_at(sample_position));
		}
		COLOR.a *= mix(1.0, revealed_alpha, reveal);
	}
}
