extends Node2D
## Test context/checkpoint provider. No gameplay mutation or save consumer.
var key:="fixture.use.1"
var enabled:=true
var uses:=0
var travels:=0
var world: Node
var chunk: Node
func eligible() -> bool:return enabled and world.active_chunk()==chunk and global_position.distance_to(world.player.global_position)<100
func use() -> bool:
	if not eligible():return false
	uses+=1;return true
func world_context() -> Dictionary:return {"key":key,"target":self,"caption":"Inspect marker","enabled":enabled,"allowed":eligible,"invoke":use}
func travel_allowed() -> bool:return world.active_chunk()==chunk and not world.player.carrying
func world_checkpoints() -> Array:return [{"id":"C0","name":"Fixture C0","attuned":true,"ground_xy":chunk.ground_origin+Vector2(60,0),"allowed":travel_allowed},{"id":"C1","name":"Unattuned C1","attuned":false,"ground_xy":chunk.ground_origin+Vector2(-120,-80),"allowed":travel_allowed}]
func world_travel_checkpoint(id: String) -> bool:
	if id!="C0" or not travel_allowed():return false
	travels+=1;world.player.position=chunk.ground_origin+Vector2(60,0);world.safe_ground=world.player.position;return true
