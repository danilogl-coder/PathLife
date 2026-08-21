## Decoração decidida pelos dados. Quem instancia a cena é o renderer.
class_name DecorationPlacement
extends RefCounted

var definition: DecorationDefinition
var world_pos: Vector3i = Vector3i.ZERO
var flip_h: bool = false
var scale_factor: float = 1.0
## Id determinístico, usado pelo save para lembrar "esta árvore foi cortada".
var object_id: int = 0
