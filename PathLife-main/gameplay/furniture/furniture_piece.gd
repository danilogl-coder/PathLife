## Um móvel colocado no mundo. É a cena-base de TODA mobília do jogo.
##
## [b]O problema que ela resolve[/b]: o personagem anda de célula em célula numa
## grade isométrica de 128 × 64 px. Quem decide se um passo acontece é a física:
## o corpo do Player (uma cápsula minúscula) é varrido do centro da célula atual
## até o centro da célula de destino. Ou seja, [b]o polígono do móvel É a regra
## de movimento[/b]. Um polígono maior que o desenho tranca o cômodo sem motivo
## visível; um menor deixa o personagem andar por dentro do móvel.
##
## Por isso aqui nada é desenhado no olho:
##
## 1. a arte declara quantas células ocupa ([member FurnitureDefinition.footprint_cells]);
## 2. o script MEDE a base do sprite (as duas arestas de baixo da silhueta, que
##    no isométrico têm inclinação ±1/2) e usa esse losango como colisão;
## 3. a arte é encaixada no centro do footprint, então o que bloqueia é
##    exatamente o que se vê e todas as células vizinhas continuam livres.
##
## [b]A célula pintada é a da FRENTE[/b] (a mais próxima da câmera). O footprint
## cresce para trás. Isso não é gosto: a âncora de Y-Sort do móvel é a célula
## pintada, e o piso das células da frente é desenhado depois — com a arte
## crescendo para trás, nenhum tile de chão passa por cima do móvel.
##
## Para criar um móvel novo veja `docs/tutorial_mobilia.md`.
@tool
class_name FurniturePiece
extends StaticBody2D

## Alpha mínimo para um pixel contar como parte da silhueta.
const OPAQUE_THRESHOLD: float = 0.35
## Fração das colunas usada para ajustar cada aresta da base.
const EDGE_SAMPLE_RATIO: float = 0.3

@export_category("Móvel")
@export var definition: FurnitureDefinition:
	set(value):
		if definition == value:
			return
		definition = value
		# Durante o carregamento da cena os valores já vêm assados do disco;
		# remontar aqui só gastaria tempo (e leitura de imagem) à toa.
		if is_node_ready():
			build()

## Índice em [enum FurnitureDefinition.Orientation]: NE, NW, SE, SW.
@export_enum("ne", "nw", "se", "sw") var orientation: int = 0:
	set(value):
		if orientation == value:
			return
		orientation = value
		if is_node_ready():
			build()

@export_category("Referências da cena")
@export var sprite: Sprite2D
@export var solid_collision: CollisionPolygon2D
@export var interaction_area: Area2D
@export var interaction_shape: CollisionPolygon2D

@export_category("Editor")
## Desenha o footprint, a base medida e as células ocupadas.
@export var draw_gizmo: bool = true:
	set(value):
		draw_gizmo = value
		queue_redraw()
## Marque e desmarque para remontar a peça depois de trocar a arte.
@export var rebuild: bool = false:
	set(value):
		rebuild = false
		if is_node_ready():
			build()

var _measured_base: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	if Engine.is_editor_hint():
		build()
		return
	# Em jogo a cena já vem pronta do disco. Só reconstrói o que ficou vazio —
	# assim medir a imagem não custa nada durante a partida.
	if definition == null:
		return
	if sprite != null and sprite.texture == null:
		build()
	elif solid_collision != null and solid_collision.polygon.is_empty() and definition.blocks_movement:
		build()
	elif solid_collision != null:
		solid_collision.disabled = not definition.blocks_movement


## Células que este móvel ocupa, relativas à célula pintada.
func occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if definition == null:
		return result
	var footprint := definition.footprint_for(orientation)
	for i in maxi(footprint.x, 1):
		for j in maxi(footprint.y, 1):
			result.append(Vector2i(-i, -j))
	return result


## Centro do footprint em pixels locais. Com 1 × 1 é a própria célula pintada.
func footprint_center() -> Vector2:
	if definition == null:
		return Vector2.ZERO
	var footprint := definition.footprint_for(orientation)
	return -(
		float(footprint.x - 1) * _axis_x() + float(footprint.y - 1) * _axis_y()
	) * 0.5


## Losango do footprint, opcionalmente inflado em células.
func footprint_polygon(expand_cells: float = 0.0) -> PackedVector2Array:
	if definition == null:
		return PackedVector2Array()
	var footprint := definition.footprint_for(orientation)
	var half_x := _axis_x() * (float(footprint.x) * 0.5 + expand_cells)
	var half_y := _axis_y() * (float(footprint.y) * 0.5 + expand_cells)
	var center := footprint_center()
	return PackedVector2Array([
		center - half_x - half_y,
		center + half_x - half_y,
		center + half_x + half_y,
		center - half_x + half_y,
	])


## Base do sprite medida na última montagem, em pixels locais.
func measured_base() -> PackedVector2Array:
	return _measured_base


func _axis_x() -> Vector2:
	return Vector2(float(definition.tile_size.x), float(definition.tile_size.y)) * 0.5


func _axis_y() -> Vector2:
	return Vector2(-float(definition.tile_size.x), float(definition.tile_size.y)) * 0.5


## Remonta a peça a partir da definição: textura, encaixe no footprint, colisão
## e área de interação. O editor chama sozinho; em jogo os valores já vêm
## assados na cena.
func build() -> void:
	if definition == null or sprite == null:
		update_configuration_warnings()
		queue_redraw()
		return

	var texture := definition.texture_for(orientation)
	sprite.texture = texture
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	_measured_base = _measure_sprite_base(texture)

	# Encaixa a arte: o centro da base cai no centro do footprint.
	#
	# `floor` em vez de `round`: a arte costuma ficar meio pixel fora do centro
	# da tela, e arredondar jogaria uma orientação para um lado e a espelhada
	# para o outro. Descer sempre mantém as quatro orientações simétricas.
	if not _measured_base.is_empty():
		var base_center := (_measured_base[1] + _measured_base[3]) * 0.5
		sprite.position = (footprint_center() - base_center).floor()
		_measured_base = _shift(_measured_base, sprite.position)

	if solid_collision != null:
		solid_collision.polygon = _build_collision_polygon()
		solid_collision.disabled = not definition.blocks_movement
	if interaction_shape != null:
		interaction_shape.polygon = footprint_polygon(definition.interaction_margin_cells)

	update_configuration_warnings()
	queue_redraw()


func _build_collision_polygon() -> PackedVector2Array:
	match definition.collision_source:
		FurnitureDefinition.CollisionSource.MANUAL:
			return solid_collision.polygon
		FurnitureDefinition.CollisionSource.FOOTPRINT:
			return _inset(footprint_polygon(), definition.collision_inset)
		_:
			if _measured_base.is_empty():
				return _inset(footprint_polygon(), definition.collision_inset)
			return _inset(_measured_base, definition.collision_inset)


## Mede o losango que encosta no chão.
##
## A silhueta de um objeto isométrico termina embaixo em duas arestas de
## inclinação +1/2 (esquerda) e -1/2 (direita). Ajustando as duas retas pela
## MEDIANA das colunas (imune a um pixel solto de sombra ou de lençol) e
## cruzando-as, saem os quatro cantos da base — sem depender da parte alta do
## desenho, que não ocupa chão nenhum.
func _measure_sprite_base(texture: Texture2D) -> PackedVector2Array:
	if texture == null:
		return PackedVector2Array()
	var image := texture.get_image()
	if image == null:
		return PackedVector2Array()
	if image.is_compressed():
		image.decompress()

	var width := image.get_width()
	var height := image.get_height()
	var bottom := PackedInt32Array()
	bottom.resize(width)
	bottom.fill(-1)
	var first_x := -1
	var last_x := -1
	for x in width:
		for y in range(height - 1, -1, -1):
			if image.get_pixel(x, y).a >= OPAQUE_THRESHOLD:
				bottom[x] = y
				if first_x < 0:
					first_x = x
				last_x = x
				break
	if first_x < 0 or last_x - first_x < 4:
		return PackedVector2Array()

	var span := maxi(2, int(round(float(last_x - first_x) * EDGE_SAMPLE_RATIO)))
	var left_terms: Array[float] = []
	for x in range(first_x, mini(first_x + span, width)):
		if bottom[x] >= 0:
			left_terms.append(float(bottom[x]) - float(x) * 0.5)
	var right_terms: Array[float] = []
	for x in range(maxi(last_x - span + 1, 0), last_x + 1):
		if bottom[x] >= 0:
			right_terms.append(float(bottom[x]) + float(x) * 0.5)
	if left_terms.is_empty() or right_terms.is_empty():
		return PackedVector2Array()

	var left_intercept := _median(left_terms)
	var right_intercept := _median(right_terms)
	# Cruza y = x/2 + a com y = -x/2 + b.
	var front := Vector2(
		right_intercept - left_intercept,
		(right_intercept - left_intercept) * 0.5 + left_intercept
	)
	var left := Vector2(float(first_x), float(first_x) * 0.5 + left_intercept)
	var right := Vector2(float(last_x), -float(last_x) * 0.5 + right_intercept)
	var back := left + right - front

	# Da textura para o local do nó: o Sprite2D é centralizado.
	var to_local := -Vector2(float(width), float(height)) * 0.5
	return PackedVector2Array([
		front + to_local, right + to_local, back + to_local, left + to_local
	])


func _median(values: Array[float]) -> float:
	values.sort()
	var count := values.size()
	if count == 0:
		return 0.0
	if count % 2 == 1:
		return values[count / 2]
	return (values[count / 2 - 1] + values[count / 2]) * 0.5


func _shift(polygon: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		result.append(point + delta)
	return result


## Encolhe o polígono na direção do centro, com a folga que mantém a célula
## vizinha caminhável.
func _inset(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if polygon.is_empty() or amount <= 0.0:
		return polygon
	var center := Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	center /= float(polygon.size())
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		var direction := center - point
		if direction.length() <= amount:
			result.append(point)
			continue
		result.append((point + direction.normalized() * amount).round())
	return result


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if definition == null:
		warnings.append("Ligue uma FurnitureDefinition no Inspector.")
		return warnings
	if definition.texture_for(orientation) == null:
		warnings.append("A definição não tem textura para esta orientação.")
	if sprite == null or solid_collision == null:
		warnings.append("As referências de cena (Sprite / SolidCollision) estão vazias.")
	if not _measured_base.is_empty() and not _base_fits_footprint():
		warnings.append(
			"A base do sprite transborda o footprint %s. Aumente o footprint ou "
			% str(definition.footprint_for(orientation))
			+ "redesenhe a arte: do jeito que está, o móvel invade a célula vizinha."
		)
	return warnings


## A base precisa caber nas células declaradas — é o que garante que o
## personagem circule em volta.
func _base_fits_footprint() -> bool:
	var cells := occupied_cells()
	for point: Vector2 in _measured_base:
		var fits := false
		for cell: Vector2i in cells:
			var center := Vector2(cell.x - cell.y, cell.x + cell.y) * Vector2(
				float(definition.tile_size.x), float(definition.tile_size.y)
			) * 0.5
			var delta := point - center
			var distance := (
				absf(delta.x) / (float(definition.tile_size.x) * 0.5)
				+ absf(delta.y) / (float(definition.tile_size.y) * 0.5)
			)
			if distance <= 1.02:
				fits = true
				break
		if not fits:
			return false
	return true


func _draw() -> void:
	if not Engine.is_editor_hint() or not draw_gizmo or definition == null:
		return
	var footprint := footprint_polygon()
	if not footprint.is_empty():
		var closed := footprint.duplicate()
		closed.append(footprint[0])
		draw_polyline(closed, Color(0.2, 1.0, 0.6, 0.7), 1.0)
	if not _measured_base.is_empty():
		var base := _measured_base.duplicate()
		base.append(_measured_base[0])
		draw_polyline(base, Color(1.0, 0.75, 0.2, 0.9), 1.0)
	for cell: Vector2i in occupied_cells():
		var center := Vector2(cell.x - cell.y, cell.x + cell.y) * Vector2(
			float(definition.tile_size.x), float(definition.tile_size.y)
		) * 0.5
		draw_circle(center, 3.0, Color(0.2, 1.0, 0.6, 0.5))
