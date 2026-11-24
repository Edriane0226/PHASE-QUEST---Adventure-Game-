extends "res://Scripts/World/Runtime/world_chunk.gd"
## Shell ownership only. No live puzzle, rewards, interactions or checkpoint/save writes.
@export_range(1,6) var shell_number:=1
var geometry: RefCounted
var anchors: Dictionary={}
func configure_geometry(shared: RefCounted) -> void:
	geometry=shared;subregion_id="Z1L%d"%shell_number;chunk_id=subregion_id+".shell";fixture_only=true
	var row=preload("res://Scripts/Content/world_subregions.gd").definition(subregion_id)
	ground_origin=Vector2(row.origin[0],row.origin[1]);position=ground_origin
func _ready() -> void:
	super._ready()
	if geometry==null:return
	var root_anchors:=Node2D.new();root_anchors.name="StationAnchors";add_child(root_anchors)
	for record in geometry.data.stations:
		if record.subregion!=subregion_id:continue
		var marker:=Marker2D.new();marker.name=record.id.validate_node_name();marker.position=geometry.v(record.ground_xy)-ground_origin
		marker.set_meta("station_id",record.id);marker.set_meta("required_groups",record.required_groups);marker.set_meta("kind",record.kind)
		root_anchors.add_child(marker);anchors[record.id]=marker
	for record in geometry.data.exploration_stops:
		if record.subregion!=subregion_id:continue
		var marker:=Marker2D.new();marker.name=record.id.validate_node_name();marker.position=geometry.v(record.ground_xy)-ground_origin
		marker.set_meta("optional",true);marker.set_meta("progression_effect","none");root_anchors.add_child(marker);anchors[record.id]=marker
	var access_path:="res://World/Data/zone1-access.json"
	if FileAccess.file_exists(access_path):
		var access_data=JSON.parse_string(FileAccess.get_file_as_string(access_path))
		if access_data is Dictionary and access_data.get("geometry_hash")==FileAccess.get_sha256(geometry.DATA):
			for record in access_data.access:
				if record.subregion!=subregion_id or not anchors.has(record.id):continue
				var marker:=Marker2D.new();marker.name="SafeApproach";marker.position=geometry.v(record.safe_ground)-geometry.v(record.anchor);anchors[record.id].add_child(marker)
	for source in geometry.data.sources:
		if source.subregion==subregion_id:
			var bodies=load(source.body_scene).instantiate();add_child(bodies)
			var details=load(source.visual_scene).instantiate();add_child(details)
			# Keep sort/contact anchors in logical XY; raise only legacy sign/checkpoint art.
			for anchor in details.get_children():
				if not anchor is Node2D:continue
				var grid=preload("res://Scripts/World/terrain_relief.gd")
				var point: Vector2=grid.center(grid.cell_at(ground_origin+anchor.position))
				var rise: float=geometry.terraces.offset_at(point)
				for visual in anchor.get_children():
					if visual is Node2D:visual.position.y-=rise
	quests=[{"text":str(geometry.data.regions[shell_number-1].name),"state":"active"},{"text":"Terrain shell · puzzles await integration","state":"blocked"}]
	tutorial="Developer traversal fixture. Geometry permissions do not grant campaign progress."
func height_record(local: Vector2,_margin:=0.0) -> Dictionary:
	if geometry and geometry.region_at(local+ground_origin)==subregion_id:return geometry.height_record(local+ground_origin)
	return {}
func ground_polygons() -> Array:
	var result: Array=[]
	if geometry:
		for f in geometry.floors:
			if f.region==subregion_id and (not f.conditional or geometry.science_open):result.append(f.polygon)
	return result
