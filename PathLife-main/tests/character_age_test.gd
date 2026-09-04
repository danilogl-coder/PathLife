extends SceneTree
## Verifica o sistema de idades: catálogo, ordem, proporção e contato com o chão.
## godot --headless --path . --script res://tests/character_age_test.gd

const CATALOG_PATH := "res://data/character_customization/age/default_age_catalog.tres"
const APPEARANCE_PATH := "res://data/character_customization/default_character_appearance.tres"
const VISUAL_PATH := "res://presentation/characters/cutout/character_visual.tscn"

const ESPERADAS: Array[StringName] = [&"bebe", &"crianca", &"adolescente", &"adulto", &"idoso"]


func _init() -> void:
	var catalog := load(CATALOG_PATH) as AgeCatalog
	assert(catalog != null, "default_age_catalog.tres não carregou")

	var sorted_profiles := catalog.get_sorted_profiles()
	assert(sorted_profiles.size() == ESPERADAS.size(), "Esperava %d idades, achei %d" % [
		ESPERADAS.size(), sorted_profiles.size()])
	for index: int in ESPERADAS.size():
		assert(sorted_profiles[index].id == ESPERADAS[index],
			"Ordem errada na posição %d: %s" % [index, sorted_profiles[index].id])

	assert(catalog.normalize_id(&"inexistente") == &"adulto")
	assert(catalog.normalize_id(&"bebe") == &"bebe")
	assert(catalog.next_id(&"bebe") == &"crianca")
	assert(catalog.next_id(&"adulto") == &"idoso")
	assert(catalog.next_id(&"idoso") == &"idoso")
	assert(catalog.is_last(&"idoso"))
	assert(not catalog.is_last(&"bebe"))

	var adulto := catalog.get_profile(&"adulto")
	# O adulto é a referência: com tudo em 1.0 o jogo continua idêntico.
	assert(is_equal_approx(adulto.escala_global, 1.0))
	assert(is_equal_approx(adulto.escala_cabeca, 1.0))
	assert(is_equal_approx(adulto.fator_tronco, 1.0))
	assert(is_equal_approx(adulto.fator_pernas, 1.0))
	assert(is_equal_approx(adulto.fator_bracos, 1.0))
	assert(is_equal_approx(adulto.fator_largura, 1.0))
	assert(is_equal_approx(adulto.curvatura_tronco, 0.0))

	_run.call_deferred()


func _run() -> void:
	var catalog := load(CATALOG_PATH) as AgeCatalog
	var appearance := load(APPEARANCE_PATH) as CharacterAppearance
	var visual_scene := load(VISUAL_PATH) as PackedScene
	assert(appearance != null and visual_scene != null)

	var visual := visual_scene.instantiate() as CharacterVisual
	root.add_child(visual)
	await process_frame

	var alturas: Dictionary = {}
	var chaos: Dictionary = {}
	for profile: AgeProfile in catalog.get_sorted_profiles():
		var aged := appearance.snapshot()
		aged.age = profile.id
		visual.present_appearance(aged)
		visual.present_locomotion(&"se", false, false)
		await process_frame

		var pe := visual.rig.find_child("ponta_pe_e", true, false) as Marker2D
		var cabeca := visual.rig.find_child("ponta_cabeca", true, false) as Marker2D
		assert(pe != null and cabeca != null, "Marcadores de ponta não encontrados")
		# to_local do CharacterVisual já embute a escala e a posição do rig.
		var chao: float = visual.to_local(pe.global_position).y
		var topo: float = visual.to_local(cabeca.global_position).y
		alturas[profile.id] = absf(chao - topo)
		chaos[profile.id] = chao

	# O pé fica onde estava: encolher não pode fazer o personagem flutuar. A
	# folga de 2.5 px cobre a pose de idle, que não deixa os dois pés retos.
	for age_id: StringName in chaos:
		var desvio: float = absf(float(chaos[age_id]) - float(chaos[&"adulto"]))
		assert(desvio < 2.5, "Pé fora do chão em %s: %.2f px" % [age_id, desvio])

	# Crescimento monotônico até o adulto, e o idoso encolhe um pouco.
	assert(alturas[&"bebe"] < alturas[&"crianca"], "Bebê não é menor que criança")
	assert(alturas[&"crianca"] < alturas[&"adolescente"], "Criança não é menor que adolescente")
	assert(alturas[&"adolescente"] < alturas[&"adulto"], "Adolescente não é menor que adulto")
	assert(alturas[&"idoso"] < alturas[&"adulto"], "Idoso não é menor que adulto")

	var razao: float = float(alturas[&"bebe"]) / float(alturas[&"adulto"])
	assert(razao > 0.40 and razao < 0.55, "Bebê com %.0f%% da altura do adulto" % (razao * 100.0))

	# A cabeça do bebê tem que ser proporcionalmente MAIOR que a do adulto.
	var bebe_profile := catalog.get_profile(&"bebe")
	assert(bebe_profile.escala_cabeca > 1.4, "Bebê sem cabeça de bebê")

	print("CHARACTER_AGE_OK alturas=%s razao_bebe=%.2f" % [alturas, razao])
	quit()
