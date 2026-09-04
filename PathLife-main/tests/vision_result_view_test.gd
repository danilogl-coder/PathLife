## Contrato isolado do adaptador entre VisionResult e apresentação.
##
## Uso:
##   godot --headless --path . --script res://tests/vision_result_view_test.gd
extends SceneTree

const ResultView = preload("res://presentation/world/visibility/vision_result_view.gd")
const State = preload("res://gameplay/vision/vision_state.gd")

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_explicit_overlap_priority()
	_test_domain_numeric_states()
	print("\n==== %d passaram, %d falharam ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_explicit_overlap_priority() -> void:
	print("\n[VisionResultView] prioridade de composição")
	var shared := Vector3i(1, 2, 0)
	var forced_only := Vector3i(2, 2, 0)
	var remembered_only := Vector3i(3, 2, 0)
	var sets := ResultView.extract({
		"visible_cells": {shared: true},
		"forced_hidden_cells": {shared: true, forced_only: true},
		"remembered_cells": {
			shared: true,
			forced_only: true,
			remembered_only: true,
		},
	})
	_check(ResultView.contains_cell(sets[&"visible"], shared), "VISIBLE vence sobreposição")
	_check(not ResultView.contains_cell(sets[&"forced_hidden"], shared), "VISIBLE remove forced redundante")
	_check(not ResultView.contains_cell(sets[&"remembered"], shared), "VISIBLE remove memória redundante")
	_check(ResultView.contains_cell(sets[&"forced_hidden"], forced_only), "FORCED_HIDDEN vence REMEMBERED")
	_check(not ResultView.contains_cell(sets[&"remembered"], forced_only), "FORCED_HIDDEN remove memória redundante")
	_check(ResultView.contains_cell(sets[&"remembered"], remembered_only), "REMEMBERED permanece sem estado superior")


func _test_domain_numeric_states() -> void:
	print("\n[VisionResultView] enums numéricos do domínio")
	var visible := Vector3i(7, 1, 0)
	var forced := Vector3i(8, 1, 0)
	var remembered := Vector3i(9, 1, 0)
	var result := VisionResult.new()
	result.states = {
		visible: State.VISIBLE,
		forced: State.FORCED_HIDDEN,
		remembered: State.REMEMBERED,
	}
	var sets := ResultView.extract(result)
	_check(ResultView.contains_cell(sets[&"visible"], visible), "inteiro VisionState.VISIBLE vira canal visível")
	_check(ResultView.contains_cell(sets[&"forced_hidden"], forced), "inteiro VisionState.FORCED_HIDDEN vira canal forçado")
	_check(ResultView.contains_cell(sets[&"remembered"], remembered), "inteiro VisionState.REMEMBERED vira canal de memória")
	_check(not ResultView.contains_cell(sets[&"visible"], forced), "FORCED_HIDDEN numérico nunca vira visível")
	_check(not ResultView.contains_cell(sets[&"forced_hidden"], visible), "VISIBLE numérico nunca vira ocultação forçada")


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FALHA %s %s" % [label, detail])
