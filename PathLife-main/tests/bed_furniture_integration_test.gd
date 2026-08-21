extends SceneTree

const BED_SCENES: Array[String] = [
	"res://gameplay/furniture/bed/bed_r0.tscn",
	"res://gameplay/furniture/bed/bed_r1.tscn",
	"res://gameplay/furniture/bed/bed_r2.tscn",
	"res://gameplay/furniture/bed/bed_r3.tscn",
]
const ANIMATION_DIRECTIONS: Array[StringName] = [&"ne", &"nw", &"sw", &"se"]
const EXPECTED_ROOT_ROTATIONS: Array[float] = [PI / 2.0, -PI / 2.0, -PI / 2.0, PI / 2.0]

var _failures: int = 0


func _init() -> void:
	for index: int in BED_SCENES.size():
		_validate_bed(BED_SCENES[index], index)

	_validate_sleep_animations("res://presentation/characters/cutout/animation/animacoes_masc.tres")
	_validate_sleep_animations("res://presentation/characters/cutout/animation/animacoes_fem.tres")
	_validate_main_scene()
	quit(_failures)


func _validate_bed(scene_path: String, index: int) -> void:
	var packed_scene := load(scene_path) as PackedScene
	_expect(packed_scene != null, "%s precisa carregar." % scene_path)
	if packed_scene == null:
		return

	var bed := packed_scene.instantiate() as BedFurniture
	_expect(bed != null, "%s precisa instanciar BedFurniture." % scene_path)
	if bed == null:
		return

	_expect(bed.get_sleep_direction() in ANIMATION_DIRECTIONS,
		"Direção de sono inválida em %s." % scene_path)
	_expect(bed.get_sleep_animation_direction() == bed.get_sleep_direction(),
		"%s precisa usar as texturas da direção configurada." % scene_path)
	_expect(bed.z_index == 0,
		"A cama precisa usar o mesmo plano Z do Player para participar do Y Sort.")
	_expect(bed.collision_layer == 8, "A cama precisa estar na camada Furniture.")
	_expect(bed.collision_mask == 2, "A cama precisa detectar a camada Player.")
	_expect(bed.sleep_center != null, "SleepCenter precisa estar configurado.")
	_expect(bed.pillow_anchor != null, "PillowAnchor precisa estar configurado.")
	_expect(bed.exit_anchor != null, "ExitAnchor precisa estar configurado.")

	var bed_back := bed.get_node("Visual/BedBack") as Sprite2D
	_expect(bed_back != null, "BedBack precisa existir.")
	if bed_back != null:
		_expect(bed_back.z_index == 0,
			"O sprite da cama precisa permanecer no mesmo Z do Player.")
		_expect(bed_back.texture != null, "A orientação precisa possuir textura.")
		if bed_back.texture != null:
			_expect(bed_back.texture.resource_path.ends_with("cama_r%d.png" % index),
				"A textura de %s não corresponde à orientação." % scene_path)

	var blanket := bed.get_node("Visual/BedFront") as Sprite2D
	_expect(blanket != null, "BedFront precisa existir para apresentar o lençol.")
	if blanket != null:
		_expect(not blanket.visible, "O lençol precisa começar escondido.")
		_expect(blanket.z_index > 2, "O lençol precisa ficar acima do Player dormindo.")
		_expect(blanket.texture != null, "A orientação precisa possuir um lençol.")
		if blanket.texture != null:
			_expect(blanket.texture.resource_path.ends_with("lencol_r%d.png" % index),
				"O lençol de %s não corresponde à orientação." % scene_path)

	var sleeping_headboard := bed.get_node("Visual/SleepingHeadboard") as Sprite2D
	_expect(sleeping_headboard != null, "A camada opcional SleepingHeadboard precisa existir.")
	if sleeping_headboard != null:
		_expect(not sleeping_headboard.visible,
			"A cabeceira de sono precisa começar escondida.")
		_expect(sleeping_headboard.z_index > blanket.z_index,
			"A cabeceira de sono precisa ficar acima do lençol.")
		if index >= 2:
			_expect(sleeping_headboard.texture != null,
				"R%d precisa possuir uma cabeceira de sono." % index)
			if sleeping_headboard.texture != null:
				_expect(sleeping_headboard.texture.resource_path.ends_with(
					"cabeceira_r%d.png" % index
				), "A cabeceira de R%d não corresponde à orientação." % index)
		else:
			_expect(sleeping_headboard.texture == null,
				"R%d não deve possuir cabeceira de sono." % index)

	bed.set_occupied(true)
	_expect(blanket.visible, "O lençol precisa aparecer ao ocupar a cama.")
	_expect(sleeping_headboard.visible == (index >= 2),
		"A cabeceira opcional possui visibilidade incorreta em R%d." % index)
	bed.set_occupied(false)
	_expect(not blanket.visible and not sleeping_headboard.visible,
		"As camadas de sono precisam sumir ao liberar a cama.")

	var interaction_area := bed.get_node("InteractionArea") as Area2D
	_expect(interaction_area.collision_layer == 4,
		"InteractionArea precisa estar na camada Interactable.")
	_expect(interaction_area.collision_mask == 2,
		"InteractionArea precisa detectar o Player.")

	var top_occlusion_area := bed.get_node("TopOcclusionArea") as FurnitureTopOccluder
	_expect(top_occlusion_area != null,
		"A cama precisa possuir o sensor da borda superior.")
	if top_occlusion_area != null:
		_expect(top_occlusion_area.visual_target == bed.get_node("Visual"),
			"O sensor superior precisa controlar o Visual da cama.")
		_expect(top_occlusion_area.normal_z_index == 0,
			"O Z normal da cama precisa ser 0.")
		_expect(top_occlusion_area.occluding_z_index > top_occlusion_area.normal_z_index,
			"O Z de sobreposição precisa ficar acima do Z normal.")
		var top_shape := top_occlusion_area.get_node("TopOcclusionShape") as CollisionPolygon2D
		_expect(top_shape.polygon.size() == 6,
			"Cada orientação precisa possuir uma faixa superior de seis pontos.")

	bed.free()


func _validate_sleep_animations(library_path: String) -> void:
	var library := load(library_path) as AnimationLibrary
	_expect(library != null, "%s precisa carregar." % library_path)
	if library == null:
		return
	for index: int in ANIMATION_DIRECTIONS.size():
		var animation_name := StringName("sleep_%s" % ANIMATION_DIRECTIONS[index])
		var animation := library.get_animation(animation_name)
		_expect(animation != null, "%s precisa conter %s." % [library_path, animation_name])
		if animation == null:
			continue
		var root_track := animation.find_track(
			NodePath("Skeleton2D/quadril:rotation"),
			Animation.TYPE_VALUE
		)
		_expect(root_track >= 0, "%s precisa controlar a rotação do quadril." % animation_name)
		if root_track >= 0:
			_expect(is_equal_approx(
				float(animation.track_get_key_value(root_track, 0)),
				EXPECTED_ROOT_ROTATIONS[index]
			), "%s possui rotação horizontal incorreta." % animation_name)


func _validate_main_scene() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	_expect(main_scene != null, "A cena Main precisa carregar.")
	if main_scene == null:
		return

	var main := main_scene.instantiate()
	var test_bed := main.get_node_or_null("World/DepthSort/Entities/TestBedAnchor/TestBed") as BedFurniture
	_expect(test_bed != null, "Main precisa possuir a instância TestBed.")
	var visual_composite := main.get_node_or_null(
		"World/DepthSort/Entities/PlayerAnchor/Player/VisualAnchor"
	) as CharacterViewportComposite
	_expect(visual_composite != null,
		"O visual do Player precisa ser composto em um SubViewport para o Y Sort tratá-lo como uma unidade.")
	var player := main.get_node_or_null("World/DepthSort/Entities/PlayerAnchor/Player") as PlayerController
	_expect(player != null and player.is_in_group(&"depth_actor"),
		"O Player precisa pertencer ao grupo depth_actor.")
	main.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
