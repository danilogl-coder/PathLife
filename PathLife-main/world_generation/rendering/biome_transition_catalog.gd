## Qual tile desenhar na FRONTEIRA entre dois biomas.
##
## [b]A arte é direcional[/b]: cada peça mostra o bioma de destino invadindo a
## célula por um lado. Quem recebe o tile misto é sempre a célula do bioma de
## ORIGEM — o vizinho continua puro. Não existe peça `musgo_para_campo`: a borda
## é desenhada de um lado só, e é assim que ela deve ser lida.
##
## [b]São 12 peças por par[/b], e elas cobrem os três casos que aparecem numa
## grade isométrica: um lado, dois lados que se encontram num canto, e só a
## diagonal. Os casos restantes (dois lados opostos, três, quatro) não têm arte;
## o catálogo cai na peça mais próxima em vez de devolver o corte seco.
##
## Este recurso não conhece TileSet nem célula: recebe os grupos dos vizinhos e
## devolve um id lógico de chão. É o [TileCatalog] que traduz esse id em tile, e
## o [ChunkView] que pergunta.
class_name BiomeTransitionCatalog
extends Resource

## Lados da célula, na ordem que o resto do arquivo assume.
##
## +X é a face da frente-direita e +Y a da frente-esquerda: é a mesma convenção
## que o [ChunkView] já usa para decidir qual lateral do bloco desenhar.
const LADOS: Array[Vector2i] = [
	Vector2i(-1, 0),   # tras_esq
	Vector2i(0, -1),   # tras_dir
	Vector2i(1, 0),    # frente_dir
	Vector2i(0, 1),    # frente_esq
]
const NOMES_LADO: Array[StringName] = [
	&"tras_esq", &"tras_dir", &"frente_dir", &"frente_esq"
]
## Canto entre o lado i e o lado i+1 — e a diagonal que encosta nele.
const NOMES_CANTO: Array[StringName] = [&"tras", &"dir", &"frente", &"esq"]
const DIAGONAIS: Array[Vector2i] = [
	Vector2i(-1, -1),  # tras
	Vector2i(1, -1),   # dir
	Vector2i(1, 1),    # frente
	Vector2i(-1, 1),   # esq
]

## Bioma -> grupo de transição.
##
## Vários biomas podem compartilhar um grupo: campo, campo claro e campo florido
## são todos `campo`, então a arte de borda do campo serve para os três. Bioma
## fora deste mapa simplesmente não ganha transição.
@export var grupos: Dictionary[StringName, StringName] = {}
@export var rules: Array[BiomeTransitionRule] = []
## Desligue para voltar ao corte seco sem desfazer nada.
@export var enabled: bool = true

var _por_par: Dictionary = {}


func grupo_de(biome_id: StringName) -> StringName:
	return grupos.get(biome_id, &"")


func prefixo_para(de_grupo: StringName, para_grupo: StringName) -> StringName:
	if de_grupo == &"" or para_grupo == &"" or de_grupo == para_grupo:
		return &""
	_ensure_index()
	return _por_par.get(_chave(de_grupo, para_grupo), &"")


func tem_par(de_grupo: StringName, para_grupo: StringName) -> bool:
	return prefixo_para(de_grupo, para_grupo) != &""


static func tile_id(prefixo: StringName, forma: StringName) -> StringName:
	return StringName("%s_%s" % [String(prefixo), String(forma)])


## Id de chão para uma célula do grupo informado, dados os grupos dos 4 lados e
## das 4 diagonais (na ordem de [constant LADOS] e [constant DIAGONAIS]).
## Devolve `&""` quando não há transição a desenhar.
func resolve(
	grupo: StringName,
	lados: Array[StringName],
	diagonais: Array[StringName]
) -> StringName:
	if not enabled or grupo == &"" or lados.size() != 4:
		return &""

	# 1) Lados. Se dois vizinhos diferentes encostam na mesma célula, ganha o
	# que ocupa mais lados — é ele que domina a silhueta da borda.
	var alvo: StringName = &""
	var mascara := 0
	var melhor := 0
	for i in 4:
		var vizinho: StringName = lados[i]
		if vizinho == grupo or not tem_par(grupo, vizinho):
			continue
		var conta := 0
		var bits := 0
		for j in 4:
			if lados[j] == vizinho:
				conta += 1
				bits |= 1 << j
		if conta > melhor:
			melhor = conta
			alvo = vizinho
			mascara = bits
	if alvo != &"":
		return tile_id(prefixo_para(grupo, alvo), forma_por_lados(mascara))

	# 2) Nenhum lado, mas uma diagonal: a pontinha evita o degrau no canto.
	if diagonais.size() != 4:
		return &""
	for canto in 4:
		var vizinho: StringName = diagonais[canto]
		if vizinho == grupo:
			continue
		var prefixo := prefixo_para(grupo, vizinho)
		if prefixo != &"":
			return tile_id(prefixo, StringName("ponta_%s" % NOMES_CANTO[canto]))
	return &""


## Peça para uma máscara de lados (bit i = lado i é do bioma de destino).
static func forma_por_lados(mascara: int) -> StringName:
	var conta := 0
	for i in 4:
		if mascara & (1 << i):
			conta += 1
	if conta == 0:
		return &""
	if conta == 1:
		for i in 4:
			if mascara & (1 << i):
				return StringName("aresta_%s" % NOMES_LADO[i])
	# Dois lados que se encontram, três ou quatro: a união daquele canto é a
	# peça mais próxima que existe. Com três lados sobra um corte seco; com
	# quatro a célula estava cercada e a união some no meio dos vizinhos.
	for i in 4:
		var j := (i + 1) % 4
		if (mascara & (1 << i)) != 0 and (mascara & (1 << j)) != 0:
			return StringName("uniao_%s" % NOMES_CANTO[i])
	# Dois lados OPOSTOS: não existe arte para isso. Suavizar um dos dois é
	# melhor que devolver os dois ao corte seco.
	for i in 4:
		if mascara & (1 << i):
			return StringName("aresta_%s" % NOMES_LADO[i])
	return &""


func rebuild() -> void:
	_por_par.clear()
	_ensure_index()


static func _chave(de_grupo: StringName, para_grupo: StringName) -> String:
	return "%s>%s" % [String(de_grupo), String(para_grupo)]


func _ensure_index() -> void:
	if _por_par.size() == rules.size():
		return
	_por_par.clear()
	for rule: BiomeTransitionRule in rules:
		if rule != null and rule.prefixo != &"":
			_por_par[_chave(rule.de_grupo, rule.para_grupo)] = rule.prefixo
