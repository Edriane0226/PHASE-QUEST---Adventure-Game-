extends "res://Scripts/World/Runtime/world_input.gd"
## Existing controls/panels stay shared; only geographic provider output is added.
func refresh() -> void:
	super.refresh()
	if is_instance_valid(view) and view.is_node_ready() and world.has_method("minimap_state"):
		var value: Dictionary=world.minimap_state()
		if not value.is_empty():view.minimap.present(value)
func action(id: String) -> void:
	if id=="pause" and world!=null and world.has_method("_cancel_transit") and not world._transit.is_empty():world._cancel_transit()
	super.action(id)
