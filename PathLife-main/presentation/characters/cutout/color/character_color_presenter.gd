class_name CharacterColorPresenter
extends Node

@export var catalog: CharacterColorCatalog
@export var palette_shader: Shader
@export var skin_profile: RecolorProfile
@export var hair_profile: RecolorProfile

var _material_cache: Dictionary = {}


func get_skin_material(color_id: StringName) -> ShaderMaterial:
	return get_material(skin_profile, CharacterColorCatalog.SKIN, color_id)


func get_hair_material(color_id: StringName) -> ShaderMaterial:
	return get_material(hair_profile, CharacterColorCatalog.HAIR, color_id)


func get_clothing_material(profile: RecolorProfile, color_id: StringName) -> ShaderMaterial:
	return get_material(profile, CharacterColorCatalog.CLOTHING, color_id)


func get_material(profile: RecolorProfile, category: StringName, color_id: StringName) -> ShaderMaterial:
	if catalog == null or palette_shader == null or profile == null or not profile.is_valid():
		push_error("CharacterColorPresenter está sem catálogo, shader ou perfil válido")
		return null
	var normalized := catalog.normalize_id(category, color_id)
	var palette := catalog.get_palette(category, normalized)
	if palette == null:
		return null
	var cache_key := "%s|%s|%s" % [profile.resource_path, category, normalized]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = palette_shader
	material.set_shader_parameter("color_count", profile.source_colors.size())
	material.set_shader_parameter("source_colors", profile.source_colors)
	material.set_shader_parameter("tone_positions", profile.tone_positions)
	material.set_shader_parameter("target_shadow", palette.shadow_color)
	material.set_shader_parameter("target_base", palette.base_color)
	material.set_shader_parameter("target_highlight", palette.highlight_color)
	_material_cache[cache_key] = material
	return material
