extends RefCounted
const ADAPTER=preload("res://Scripts/World/Learning/subregion_adapter.gd")
static var catalogs: Dictionary={}
static func asset(zone: int,id: String) -> Dictionary:
	if not catalogs.has(zone):
		catalogs[zone]={}
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zones/zone_%d/world_v1/kit_catalog.json"%zone))
		for entry in data.entries:catalogs[zone][entry.id]=entry
	var entry: Dictionary=catalogs[zone][id]
	return {"path":entry.path,"pivot_px":entry.pivot_px,"scale":entry.world_scale}
static func part(id: String,offset: Array,size: Array,pivot: Array,initial: Dictionary,variants: Dictionary,collision: Array=[],interaction: Array=[]) -> Dictionary:
	return {"id":id,"offset_cubes":offset,"footprint_cubes":size,"ground_pivot_cubes":pivot,"height_layers":1,"initial":initial,"variants":variants,"collision_bounds":collision,"support_bounds":[],"interaction_bounds":interaction,"collision_layer":1}
static func definition(origin: Vector2,region: String="Z1L5") -> Dictionary:
	var components: Array=[]
	var floor_visual: Dictionary={"path":"res://assets/world/modular_v1/snow.floor.svg","pivot_px":[64,96],"scale":1.0}
	for i in range(4):
		var base:=part("base%d"%i,[1+i%2,1+floori(i/2.0),0],[1,1],[0,0],{"phase":"default"},{"default":floor_visual});base.z_index=-1;base.height_layers=0;components.append(base)
	components.append(part("vessel",[2.6,2.6,0],[3.2,3.2],[1.6,1.6],{"phase":"default"},{"default":asset(1,"cooling_tray_empty")},[[-32,-13],[32,-13],[32,13],[-32,13]]))
	var sample:=part("sample",[2.6,2.6,.3],[1,1],[.5,.5],{"phase":"solid"},{"solid":{"polygon":[[-12,0],[0,-7],[12,0],[0,7]],"color":"#c9e6ea"},"liquid":{"polygon":[[-12,1],[0,-4],[12,1],[0,6]],"color":"#528d9b"}});sample.kind="state_effect";sample.height_layers=.6;sample.z_index=1;components.append(sample)
	var control:=part("control",[4.8,1.2,0],[2.4,2.4],[1.2,1.2],{"enabled":false},{"false":asset(1,"receiver_off"),"true":asset(1,"receiver_on")},[[-20,-10],[20,-10],[20,10],[-20,10]],[[-55,-45],[55,-45],[55,45],[-55,45]]);control.visual_field="enabled";control.height_layers=2;components.append(control)
	var pipe:=part("pipe",[5.5,2.5,.5],[1,1],[.5,.5],{"open":false},{"false":{"polygon":[[-8,-2],[8,-2],[8,2],[-8,2]],"color":"#8c9e9f"},"true":{"polygon":[[-8,-2],[8,-2],[8,2],[-8,2]],"color":"#66b6cb"}},[],[[-40,-32],[40,-32],[40,32],[-40,32]]);pipe.kind="state_effect";pipe.visual_field="open";components.append(pipe)
	var gear:=part("gear",[1.0,4.8,0],[1.8,1.8],[.9,.9],{"phase":"default"},{"default":asset(1,"gear_part")},[[-12,-7],[12,-7],[12,7],[-12,7]],[[-50,-42],[50,-42],[50,42],[-50,42]]);gear.item_id="review-part";gear.collision_layer=2;gear.height_layers=2;components.append(gear)
	components.append(part("socket",[4.5,4.5,0],[2.9,2.9],[1.45,1.45],{"phase":"default"},{"default":asset(1,"gear_tray_empty")},[[-25,-10],[25,-10],[25,10],[-25,10]],[[-55,-45],[55,-45],[55,45],[-55,45]]))
	var row=preload("res://Scripts/Content/world_subregions.gd").definition(region)
	return {"subregion":region,"assemblies":[{"id":"work","origin_ground":[origin.x,origin.y],"footprint_cubes":[6,6],"components":components}],"items":{"review-part":{"source":"work/gear","initial_owner":"world:work/gear"}},"introductions":[],"guide_topics":["melting","professor"],"actions":{
		"power":{"component":"work/control","kind":"set","field":"enabled","value":true,"caption":"Connect heat"},
		"flow":{"component":"work/pipe","kind":"set","field":"open","value":true,"caption":"Open pipe","requires":[{"component":"work/control","field":"enabled","value":true}]},
		"pickup":{"component":"work/gear","kind":"pickup","item":"review-part","caption":"Carry review part"},
		"place":{"component":"work/socket","kind":"place","item":"review-part","caption":"Place review part","requires":[{"component":"work/sample","field":"phase","value":"liquid"}],"events":[{"id":"hands_on","event":"matching-delivery","members":[]}]}
	},"targets":{"review-water":{"component":"work/sample","occlusion_component":"work/vessel","puzzle":"review-worksite","spec":{"zone":row.zone_id,"level":int(row.level),"material":"water","process":"melting","allowed_modes":["thermal"],"required_exposure":.25,"max_range":100.0,"required_flags":["power","flow"]},"sample":{"material":"water","state":"solid","amount":1.0,"phase_region":"melting","heat_flow":"in"},"flags":{"power":{"component":"work/control","field":"enabled","value":true},"flow":{"component":"work/pipe","field":"open","value":true}},"checkpoint":"C1"}}}
static func complete(state: Dictionary) -> bool:
	return state.components["work/control"].enabled and state.components["work/pipe"].open and state.components["work/sample"].phase=="liquid" and state.items["review-part"]=="installed:work/socket"
static func mount(world: Node2D,definition: Dictionary) -> Node:
	var chunk=world.chunks[definition.subregion+".shell"];var adapter=ADAPTER.new();adapter.name="ReviewAdapter023";chunk.add_child(adapter)
	if not adapter.bind(world,chunk,definition,complete):adapter.queue_free();return null
	return adapter
