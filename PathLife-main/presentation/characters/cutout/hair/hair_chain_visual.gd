class_name HairChainVisual
extends Skeleton2D

@export var segment_scene: PackedScene


func build(chain_data: Dictionary, definition: HairDefinition, color_material: Material) -> HairChain:
	var result := HairChain.new()
	result.nome = StringName(chain_data.get("nome", name))
	result.perfil = definition.perfil_de(result.nome)
	var parent: Node = self
	# A camada absoluta do JSON servia ao protótipo isolado. No personagem real,
	# HairBack/HairFront definem a pilha inteira; os segmentos ficam relativos.
	var visual_z := 0
	var segments: Array = chain_data.get("ossos", [])
	for index: int in segments.size():
		var bone := segment_scene.instantiate() as HairSegment
		bone.name = "Segment_%02d" % index
		parent.add_child(bone)
		bone.configure(segments[index], definition.pasta_texturas, visual_z, color_material)
		result.ossos.append(bone)
		parent = bone
	result.preparar(result.perfil, definition.escala_limite, hash(String(result.nome)))
	return result
