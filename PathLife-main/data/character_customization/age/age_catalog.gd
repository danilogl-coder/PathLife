class_name AgeCatalog
extends Resource
## Todas as fases da vida, em ordem. Mesmo formato do HairCatalog de propósito:
## quem já leu um lê o outro.

@export var profiles: Array[AgeProfile] = []
@export var default_id: StringName = &"adulto"

var _by_id: Dictionary = {}


func get_profile(age_id: StringName) -> AgeProfile:
	_ensure_index()
	return _by_id.get(age_id) as AgeProfile


func has_age(age_id: StringName) -> bool:
	return get_profile(age_id) != null


func normalize_id(age_id: StringName) -> StringName:
	return age_id if get_profile(age_id) != null else default_id


func get_sorted_profiles() -> Array[AgeProfile]:
	var result: Array[AgeProfile] = []
	for profile: AgeProfile in profiles:
		if profile != null and profile.id != &"":
			result.append(profile)
	result.sort_custom(func(a: AgeProfile, b: AgeProfile) -> bool: return a.ordem < b.ordem)
	return result


## Próxima fase da vida. Na última, devolve ela mesma — quem decide o que
## acontece no fim da linha é o gameplay, não o catálogo.
func next_id(age_id: StringName) -> StringName:
	var sorted_profiles := get_sorted_profiles()
	for index: int in sorted_profiles.size():
		if sorted_profiles[index].id != age_id:
			continue
		var next_index := index + 1
		return sorted_profiles[next_index].id if next_index < sorted_profiles.size() else age_id
	return normalize_id(age_id)


func is_last(age_id: StringName) -> bool:
	return next_id(age_id) == age_id


func get_display_name(age_id: StringName) -> String:
	var profile := get_profile(age_id)
	return profile.display_name if profile != null else String(age_id).capitalize()


func _ensure_index() -> void:
	if _by_id.size() == profiles.size():
		return
	_by_id.clear()
	for profile: AgeProfile in profiles:
		if profile != null and profile.id != &"":
			_by_id[profile.id] = profile
