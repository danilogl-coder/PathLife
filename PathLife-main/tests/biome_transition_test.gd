extends SceneTree
## Verifica a escolha da peça de fronteira e a presença das 48 peças no atlas.
## godot --headless --path . --script res://tests/biome_transition_test.gd

const CATALOGO_TILES := "res://data/world/tiles/ground_catalog.tres"
const CATALOGO_TRANSICOES := "res://data/world/tiles/biome_transitions.tres"

const CAMPO: StringName = &"campo"
const FLOR: StringName = &"floresta"

var _falhas: int = 0


func _init() -> void:
	var transitions := _catalogo_de_teste()

	# --- um lado: a borda cobre a metade daquele lado
	_esperar(transitions, [FLOR, CAMPO, CAMPO, CAMPO], "campo_para_musgo_aresta_tras_esq")
	_esperar(transitions, [CAMPO, FLOR, CAMPO, CAMPO], "campo_para_musgo_aresta_tras_dir")
	_esperar(transitions, [CAMPO, CAMPO, FLOR, CAMPO], "campo_para_musgo_aresta_frente_dir")
	_esperar(transitions, [CAMPO, CAMPO, CAMPO, FLOR], "campo_para_musgo_aresta_frente_esq")

	# --- dois lados que se encontram: a união daquele canto
	_esperar(transitions, [FLOR, FLOR, CAMPO, CAMPO], "campo_para_musgo_uniao_tras")
	_esperar(transitions, [CAMPO, FLOR, FLOR, CAMPO], "campo_para_musgo_uniao_dir")
	_esperar(transitions, [CAMPO, CAMPO, FLOR, FLOR], "campo_para_musgo_uniao_frente")
	_esperar(transitions, [FLOR, CAMPO, CAMPO, FLOR], "campo_para_musgo_uniao_esq")

	# --- sem lado, só a diagonal: a pontinha do canto
	_esperar(transitions, [CAMPO, CAMPO, CAMPO, CAMPO], "campo_para_musgo_ponta_tras",
		[FLOR, CAMPO, CAMPO, CAMPO])
	_esperar(transitions, [CAMPO, CAMPO, CAMPO, CAMPO], "campo_para_musgo_ponta_dir",
		[CAMPO, FLOR, CAMPO, CAMPO])
	_esperar(transitions, [CAMPO, CAMPO, CAMPO, CAMPO], "campo_para_musgo_ponta_frente",
		[CAMPO, CAMPO, FLOR, CAMPO])
	_esperar(transitions, [CAMPO, CAMPO, CAMPO, CAMPO], "campo_para_musgo_ponta_esq",
		[CAMPO, CAMPO, CAMPO, FLOR])

	# --- casos sem arte: cai na peça mais próxima, nunca no corte seco
	_esperar(transitions, [FLOR, CAMPO, FLOR, CAMPO], "campo_para_musgo_aresta_tras_esq")
	_esperar(transitions, [FLOR, FLOR, FLOR, CAMPO], "campo_para_musgo_uniao_tras")
	_esperar(transitions, [FLOR, FLOR, FLOR, FLOR], "campo_para_musgo_uniao_tras")

	# --- sem vizinho diferente: nenhuma transição
	_esperar(transitions, [CAMPO, CAMPO, CAMPO, CAMPO], "")

	# --- a arte é de um lado só: a floresta encostando no campo não vira nada,
	# porque não existe `musgo_para_campo`.
	var do_lado_da_floresta := transitions.resolve(
		FLOR, _lados([CAMPO, CAMPO, CAMPO, CAMPO]), _lados([CAMPO, CAMPO, CAMPO, CAMPO])
	)
	_conferir(do_lado_da_floresta == &"", "Floresta nao pode receber peca de campo")

	# --- desligar volta ao corte seco sem desfazer dado nenhum
	transitions.enabled = false
	_conferir(
		transitions.resolve(CAMPO, _lados([FLOR, CAMPO, CAMPO, CAMPO]), _lados([])) == &"",
		"enabled=false ainda devolveu transicao"
	)
	transitions.enabled = true

	# --- máscara de lados, direto
	_conferir(BiomeTransitionCatalog.forma_por_lados(0) == &"", "mascara vazia")
	_conferir(BiomeTransitionCatalog.forma_por_lados(0b0001) == &"aresta_tras_esq", "bit 0")
	_conferir(BiomeTransitionCatalog.forma_por_lados(0b1001) == &"uniao_esq", "bits 0 e 3")

	_run.call_deferred()


## Segunda metade: confere a arte de verdade, se ela já foi gerada.
func _run() -> void:
	if not ResourceLoader.exists(CATALOGO_TILES):
		print("BIOME_TRANSITION_PARCIAL: rode tools/build_world_resources.gd primeiro.")
		_terminar()
		return
	var catalog := load(CATALOGO_TILES) as TileCatalog
	if catalog == null:
		_conferir(false, "ground_catalog.tres nao carregou como TileCatalog")
		_terminar()
		return

	var transitions := catalog.transitions
	_conferir(transitions != null, "TileCatalog sem catalogo de transicoes")
	if transitions == null:
		_terminar()
		return

	_conferir(transitions.rules.size() == 4, "Esperava 4 pares, achei %d" % transitions.rules.size())
	_conferir(transitions.grupo_de(&"campo_claro") == &"campo", "campo_claro fora do grupo campo")
	_conferir(transitions.grupo_de(&"campo_florido") == &"campo", "campo_florido fora do grupo campo")
	_conferir(transitions.grupo_de(&"floresta") == &"floresta", "floresta sem grupo")
	_conferir(transitions.grupo_de(&"savana") == &"savana", "savana sem grupo")
	_conferir(transitions.prefixo_para(&"campo", &"floresta") == &"campo_para_musgo", "par campo>floresta")
	_conferir(transitions.prefixo_para(&"campo", &"savana") == &"campo_para_savana", "par campo>savana")
	_conferir(transitions.prefixo_para(&"floresta", &"campo") == &"", "par invertido nao existe")

	# As 12 peças de cada par precisam estar no atlas, senão a borda some.
	var formas: Array[StringName] = [
		&"aresta_tras_esq", &"aresta_tras_dir", &"aresta_frente_dir", &"aresta_frente_esq",
		&"uniao_tras", &"uniao_dir", &"uniao_frente", &"uniao_esq",
		&"ponta_tras", &"ponta_dir", &"ponta_frente", &"ponta_esq",
	]
	var catalogadas := 0
	for rule: BiomeTransitionRule in transitions.rules:
		for forma: StringName in formas:
			var tile := BiomeTransitionCatalog.tile_id(rule.prefixo, forma)
			if not catalog.has(tile):
				_conferir(false, "Peca fora do catalogo: %s" % tile)
				continue
			var entry := catalog.find(tile)
			_conferir(entry.directional, "Peca %s nao esta marcada como direcional" % tile)
			catalogadas += 1
	_conferir(catalogadas == 48, "Esperava 48 pecas catalogadas, achei %d" % catalogadas)

	# Uma peça direcional jamais pode sair espelhada.
	var espelhado := catalog.alternative_for(0, true)
	var reto := catalog.alternative_for(0, false)
	_conferir(espelhado != reto, "alternative_for ignorou o espelhamento")

	_terminar()


func _catalogo_de_teste() -> BiomeTransitionCatalog:
	var rule := BiomeTransitionRule.new()
	rule.de_grupo = CAMPO
	rule.para_grupo = FLOR
	rule.prefixo = &"campo_para_musgo"
	var transitions := BiomeTransitionCatalog.new()
	var rules: Array[BiomeTransitionRule] = [rule]
	transitions.rules = rules
	var grupos: Dictionary[StringName, StringName] = {CAMPO: CAMPO, FLOR: FLOR}
	transitions.grupos = grupos
	return transitions


func _lados(valores: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for valor: Variant in valores:
		result.append(StringName(valor))
	return result


func _esperar(
	transitions: BiomeTransitionCatalog,
	lados: Array,
	esperado: String,
	diagonais: Array = [CAMPO, CAMPO, CAMPO, CAMPO]
) -> void:
	var obtido := transitions.resolve(CAMPO, _lados(lados), _lados(diagonais))
	_conferir(
		obtido == StringName(esperado),
		"lados=%s diagonais=%s -> esperava '%s', veio '%s'" % [lados, diagonais, esperado, obtido]
	)


func _conferir(condicao: bool, mensagem: String) -> void:
	if condicao:
		return
	_falhas += 1
	printerr("FALHA: ", mensagem)


func _terminar() -> void:
	if _falhas > 0:
		printerr("BIOME_TRANSITION_FALHOU: %d verificacao(oes)" % _falhas)
		quit(1)
		return
	print("BIOME_TRANSITION_OK")
	quit(0)
