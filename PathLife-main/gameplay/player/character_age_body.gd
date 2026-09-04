class_name CharacterAgeBody
extends Node
## O corpo físico da idade: colisão, sombra e altura de câmera. Não lê teclado,
## não anima, não conhece Sprite2D do rig. Recebe a aparência por sinal e
## reemite para o controlador o que ele precisa saber.

signal age_body_changed(profile: AgeProfile)

@export var catalog: AgeCatalog
@export var collision_shape: CollisionShape2D
## Opcional: a sombra do personagem encolhe junto.
@export var shadow: Node2D
## Opcional: o nó que carrega a Camera2D, para ela não ficar no chão num bebê.
@export var camera_pivot: Node2D
@export_range(0.0, 1.0, 0.01) var camera_na_altura: float = 0.45

var _profile: AgeProfile


func _ready() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return
	# Sem duplicar, todos os personagens que usam esta cena compartilham a MESMA
	# CapsuleShape2D — envelhecer um encolheria a colisão de todos. É o mesmo
	# cuidado que o projeto já toma com ShaderMaterial.
	collision_shape.shape = collision_shape.shape.duplicate()


## Conecte aqui o sinal appearance_changed do AppearanceState.
func present_appearance(appearance: CharacterAppearance) -> void:
	if appearance == null or catalog == null:
		return
	var profile := catalog.get_profile(catalog.normalize_id(appearance.age))
	if profile == null or profile == _profile:
		return
	_profile = profile
	_aplicar_colisao(profile)
	if shadow != null:
		shadow.scale = Vector2.ONE * profile.escala_global
	if camera_pivot != null:
		camera_pivot.position.y = -profile.altura_colisao * 2.0 * camera_na_altura
	age_body_changed.emit(profile)


func get_profile() -> AgeProfile:
	return _profile


func _aplicar_colisao(profile: AgeProfile) -> void:
	if collision_shape == null:
		return
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule == null:
		return
	capsule.radius = profile.raio_colisao
	capsule.height = maxf(profile.altura_colisao, profile.raio_colisao * 2.0)
	# A cápsula cresce para cima a partir dos pés, que ficam na origem do Player.
	collision_shape.position.y = -capsule.height * 0.5
