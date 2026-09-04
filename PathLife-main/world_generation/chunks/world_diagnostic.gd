## Relatório do chão sob as construções, escrito pelo jogo em execução.
##
## Existe para responder com DADO, e não com achismo, a duas perguntas que só o
## jogo rodando sabe responder: "este build aplicou a regra do chão nu?" e "o
## que exatamente ficou embaixo do piso desta casa?".
##
## Escreve na raiz do projeto, só em build de depuração, e para depois de
## algumas construções. É seguro deixar ligado: o arquivo é reescrito a cada
## execução e nunca entra num build exportado.
class_name WorldDiagnostic
extends RefCounted

const PATH := "res://diagnostico_chao_construcao.txt"
const MAX_STRUCTURES := 4
## Quantas células destoantes são listadas antes de o relatório resumir.
const MAX_EXAMPLES := 8

static var _written := 0
static var _started := false


static func reset() -> void:
	_written = 0
	_started = false


## Uma construção integrada ao mundo. Chamado pelo [ChunkManager].
static func report(chunk: ChunkData, placement: StructurePlacement, world_seed: int) -> void:
	if not OS.is_debug_build() or _written >= MAX_STRUCTURES:
		return
	var definition := placement.definition
	if definition == null:
		return
	var lines := PackedStringArray()
	if not _started:
		lines.append("PathLife — diagnóstico do chão sob construções")
		lines.append(Time.get_datetime_string_from_system(false, true))
		lines.append("semente do mundo: %d" % world_seed)
		lines.append("regra ativa neste build: piso da cena substitui o terreno")
		lines.append("")
	lines.append_array(_describe(chunk, placement, definition))
	_append(lines)
	_written += 1


static func _describe(
	chunk: ChunkData, placement: StructurePlacement, definition: StructureDefinition
) -> PackedStringArray:
	var floor_cells := StructureFloorMask.cells_for(definition)
	var lines := PackedStringArray()
	lines.append("== %s em %s (fundação %d)" % [
		definition.id, placement.origin_xy, placement.foundation_height
	])
	lines.append("   clears_ground_cover=%s  bare_ground_margin=%d  footprint=%s" % [
		definition.clears_ground_cover, definition.bare_ground_margin, definition.footprint
	])
	lines.append("   piso lido da cena: %d células" % floor_cells.size())

	var counts: Dictionary = {}
	var unlocked: Array[String] = []
	var missing := 0
	var checked := 0
	for local: Vector2i in _cells_to_check(placement, floor_cells):
		var cell := chunk.get_cell_world(local)
		if cell == null:
			missing += 1
			continue
		checked += 1
		counts[cell.ground_id] = int(counts.get(cell.ground_id, 0)) + 1
		if not cell.ground_locked and unlocked.size() < MAX_EXAMPLES:
			unlocked.append("%s=%s" % [local, cell.ground_id])
	lines.append("   células conferidas: %d (fora deste chunk: %d)" % [checked, missing])
	for ground_id: StringName in counts:
		lines.append("     chão %s: %d célula(s)" % [ground_id, counts[ground_id]])
	if unlocked.is_empty():
		lines.append("   todas trancadas (ground_locked)")
	else:
		lines.append("   DESTRANCADAS: %s" % ", ".join(unlocked))
	lines.append("")
	return lines


static func _cells_to_check(
	placement: StructurePlacement, floor_cells: Dictionary
) -> Array[Vector2i]:
	var cells: Dictionary = {}
	var rect := placement.rect()
	for y in rect.size.y:
		for x in rect.size.x:
			cells[rect.position + Vector2i(x, y)] = true
	for local: Vector2i in floor_cells:
		cells[placement.origin_xy + local] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell)
	return result


static func _append(lines: PackedStringArray) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE if not _started else FileAccess.READ_WRITE)
	if file == null:
		return
	if _started:
		file.seek_end()
	_started = true
	for line in lines:
		file.store_line(line)
	file.close()
