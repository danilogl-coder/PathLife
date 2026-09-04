## Contrato do sistema de mobília.
##
## Uso:
## godot --headless --path . --script res://tests/furniture_piece_test.gd
##
## O que é garantido aqui:
## 1. a colisão assada na cena é exatamente a que a medição da arte produz —
##    se alguém trocar o PNG e esquecer de remontar, o teste acusa;
## 2. o móvel bloqueia todas as células do footprint declarado;
## 3. NENHUMA célula vizinha é bloqueada, que é o que mantém o personagem livre
##    para circular em volta do móvel.
extends SceneTree

const PIECES: Array[String] = [
	"res://gameplay/furniture/pieces/cama_r0.tscn",
	"res://gameplay/furniture/pieces/cama_r1.tscn",
	"res://gameplay/furniture/pieces/cama_r2.tscn",
	"res://gameplay/furniture/pieces/cama_r3.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r0.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r1.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r2.tscn",
	"res://gameplay/furniture/pieces/pia_banheiro_r3.tscn",
	"res://gameplay/furniture/pieces/espelho_r0.tscn",
	"res://gameplay/furniture/pieces/espelho_r1.tscn",
	"res://gameplay/furniture/pieces/espelho_r2.tscn",
	"res://gameplay/furniture/pieces/espelho_r3.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r0.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r1.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r2.tscn",
	"res://gameplay/furniture/pieces/bancada_armario_r3.tscn",
	"res://gameplay/furniture/pieces/bancada_r0.tscn",
	"res://gameplay/furniture/pieces/bancada_r1.tscn",
	"res://gameplay/furniture/pieces/bancada_r2.tscn",
	"res://gameplay/furniture/pieces/bancada_r3.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r0.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r1.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r2.tscn",
	"res://gameplay/furniture/pieces/cadeira_jantar_r3.tscn",
	"res://gameplay/furniture/pieces/fogao_r0.tscn",
	"res://gameplay/furniture/pieces/fogao_r1.tscn",
	"res://gameplay/furniture/pieces/fogao_r2.tscn",
	"res://gameplay/furniture/pieces/fogao_r3.tscn",
	"res://gameplay/furniture/pieces/geladeira_r0.tscn",
	"res://gameplay/furniture/pieces/geladeira_r1.tscn",
	"res://gameplay/furniture/pieces/geladeira_r2.tscn",
	"res://gameplay/furniture/pieces/geladeira_r3.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r0.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r1.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r2.tscn",
	"res://gameplay/furniture/pieces/mesa_jantar_r3.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r0.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r1.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r2.tscn",
	"res://gameplay/furniture/pieces/pia_cozinha_r3.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r0.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r1.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r2.tscn",
	"res://gameplay/furniture/pieces/criado_mudo_r3.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r0.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r1.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r2.tscn",
	"res://gameplay/furniture/pieces/escrivaninha_r3.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r0.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r1.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r2.tscn",
	"res://gameplay/furniture/pieces/tapete_quarto_r3.tscn",
	"res://gameplay/furniture/pieces/armario_r0.tscn",
	"res://gameplay/furniture/pieces/armario_r1.tscn",
	"res://gameplay/furniture/pieces/armario_r2.tscn",
	"res://gameplay/furniture/pieces/armario_r3.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r0.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r1.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r2.tscn",
	"res://gameplay/furniture/pieces/cadeira_giratoria_r3.tscn",
	"res://gameplay/furniture/pieces/quadro_r0.tscn",
	"res://gameplay/furniture/pieces/quadro_r1.tscn",
	"res://gameplay/furniture/pieces/quadro_r2.tscn",
	"res://gameplay/furniture/pieces/quadro_r3.tscn",
]
const TILE := Vector2(128.0, 64.0)

var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in PIECES:
		await _check_piece(path)
	if _failures == 0:
		print("FURNITURE_PIECE_OK")
	quit(_failures)


func _check_piece(path: String) -> void:
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s precisa carregar." % path)
	if packed == null:
		return
	var piece := packed.instantiate() as FurniturePiece
	_expect(piece != null, "%s precisa instanciar FurniturePiece." % path)
	if piece == null:
		return
	root.add_child(piece)
	await process_frame

	_expect(piece.definition != null, "%s precisa de uma FurnitureDefinition." % path)
	_expect(
		piece.sprite != null and piece.sprite.texture != null,
		"%s precisa da textura assada na cena." % path
	)
	_expect(piece.solid_collision != null, "%s precisa do nó SolidCollision." % path)
	if piece.definition == null or piece.sprite == null or piece.solid_collision == null:
		piece.queue_free()
		return

	# 1. o que está assado é o que a medição produz
	var baked_polygon := piece.solid_collision.polygon
	var baked_position := piece.sprite.position
	piece.build()
	_expect(
		piece.sprite.position == baked_position,
		"%s: sprite assado em %s, medição pede %s." % [
			path, baked_position, piece.sprite.position
		]
	)
	_expect(
		_same_polygon(baked_polygon, piece.solid_collision.polygon),
		"%s: a colisão assada não bate com a base medida da arte." % path
	)

	# 2. e 3. footprint bloqueado, vizinhança livre
	var polygon := piece.solid_collision.polygon
	_expect(polygon.size() >= 3, "%s: colisão vazia." % path)
	var occupied := piece.occupied_cells()
	for cell: Vector2i in occupied:
		_expect(
			Geometry2D.is_point_in_polygon(_cell_center(cell), polygon),
			"%s: a célula %s do footprint não bloqueia o passo." % [path, cell]
		)
	for i in range(-3, 4):
		for j in range(-3, 4):
			var cell := Vector2i(i, j)
			if occupied.has(cell):
				continue
			_expect(
				not Geometry2D.is_point_in_polygon(_cell_center(cell), polygon),
				"%s: a célula vizinha %s ficou bloqueada — o cômodo perde espaço." % [
					path, cell
				]
			)

	_expect(
		piece._get_configuration_warnings().is_empty(),
		"%s: %s" % [path, ", ".join(piece._get_configuration_warnings())]
	)
	piece.queue_free()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x - cell.y), float(cell.x + cell.y)) * TILE * 0.5


func _same_polygon(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for index in a.size():
		if a[index].distance_to(b[index]) > 1.0:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[FALHA] ", message)
