extends Node2D
## Shared cube mainland, tile-aligned trails, clipped coast/puzzle boundaries.
const STACK = preload("res://Scripts/World/stacked_ground.gd")
var geometry: RefCounted
var biome := "grass"
var coast=preload("res://Scripts/World/stacked_coast.gd").new()
var surface=preload("res://Scripts/World/cube_surface.gd").new()
var routes: Array=[]:
	set(value):
		routes=value;surface.set_routes(value);queue_redraw()

func configure(value: RefCounted, mainland: Array=[]) -> void:
	geometry=value;z_index=-100
	coast.configure(geometry,biome,mainland);surface.configure(geometry,biome);surface.set_routes(routes)
	for child in get_children():child.free()
	for region in geometry.data.regions:
		var stack=STACK.new();stack.name="Stacked_"+region.id;add_child(stack)
		stack.configure(geometry.relief,region.id,biome,float(region.elevation))
	queue_redraw()

func _draw() -> void:
	if geometry==null:return
	for region in geometry.data.regions:draw_colored_polygon(geometry.polygon(region.permission_polygon),Color("79a9b8"))
	coast.draw_faces(self)
	surface.draw_surface(self)
