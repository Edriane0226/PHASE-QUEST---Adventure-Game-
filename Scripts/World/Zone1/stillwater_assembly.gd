extends RefCounted
## Accepted kit pieces; cube envelopes never infer physics from sprite dimensions.
const ROOT="res://assets/zones/zone_1/world_v1/"
static var catalog: Dictionary={}
static func visual(id: String,scale_factor:=1.0) -> Dictionary:
	if catalog.is_empty():
		for entry in JSON.parse_string(FileAccess.get_file_as_string(ROOT+"kit_catalog.json")).entries:catalog[entry.id]=entry
	var entry: Dictionary=catalog[id]
	return {"path":entry.path,"pivot_px":entry.pivot_px,"scale":entry.world_scale*scale_factor}
static func part(id: String,offset: Array,size: float,initial: Dictionary,variants: Dictionary,field: String="phase") -> Dictionary:
	return {"id":id,"offset_cubes":offset,"footprint_cubes":[size,size],"ground_pivot_cubes":[size/2,size/2],"height_layers":1,"initial":initial,"variants":variants,"visual_field":field,"collision_bounds":[],"support_bounds":[],"interaction_bounds":[[-42,-38],[42,-38],[42,38],[-42,38]]}
static func tray(id: String,offset: Array,amount: int) -> Dictionary:
	var variants: Dictionary={}
	for phase in ["empty","liquid","freezing","solid","latched"]:variants[phase]=visual("cooling_tray_"+phase,.78)
	return part(id,offset,2.4,{"phase":"liquid" if amount else "empty","amount":amount},variants)
static func site(id: String,at: Vector2,parts: Array) -> Dictionary:
	return {"id":id,"origin_ground":[at.x,at.y-60],"footprint_cubes":[6,6],"components":parts}
static func definition(points: Dictionary) -> Dictionary:
	var first:=site("first",points.court1,[tray("tray",[3,3,0],1)])
	var supply:=site("supply",points.court2,[part("water",[2.5,3.5,0],3.2,{"phase":"solid","amount":2},{"solid":visual("supply_solid"),"liquid":visual("supply_liquid"),"empty":visual("cooling_tray_drained")}),part("valve",[5,2,0],1.5,{"phase":"closed"},{"closed":visual("canal_diverter_main",.7),"open":visual("canal_diverter_side",.7)})])
	var crossing:=site("crossing",points.court3,[tray("left",[1.6,4.4,0],0),tray("right",[4.4,1.6,0],0),part("heater",[1,1,0],1.8,{"phase":"connected"},{"connected":visual("heater_active",.7),"isolated":visual("heater_isolated",.7)}),part("latch",[5,5,0],1.8,{"phase":"open"},{"open":visual("bridge_lock_repositioned",.65),"latched":visual("bridge_lock_latched",.65)})])
	crossing.components.append(part("shutter",[2.3,1,0],1.2,{"phase":"connected"},{"connected":visual("heat_shutter_connected",.5),"isolated":visual("heat_shutter_isolated",.5)}))
	return {"subregion":"Z1L3","assemblies":[first,supply,crossing],"items":{},"actions":{},"targets":{},"introductions":["z1l3_freezing"],"guide_topics":["freezing","melting"]}
