extends Node
## Local context only. Host rechecks permission, position, carry and landing at invocation/arrival.
var world: Node
var chunk: Node
var ends: Array=[]
func world_context() -> Dictionary:
	var best: Dictionary={};var distance:=INF
	for endpoint in ends:
		var gap: float=world.player.position.distance_to(endpoint.ground)
		if gap<distance and gap<=80:best=endpoint;distance=gap
	if best.is_empty():return {}
	var id: String=best.connection.id;var reverse: bool=best.reverse
	return {"target":best.anchor,"key":id+(".return" if reverse else ".forward"),"caption":"Return" if reverse else ("Board boat" if best.connection.kind=="crafted boat passage" else "Ride lift"),"enabled":world.can_transit(id,reverse),"allowed":func():return world.can_transit(id,reverse),"invoke":func():return world.start_transit(id,reverse)}
