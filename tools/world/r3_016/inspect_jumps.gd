extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://Scripts/World/Zone1/zone1_geometry.gd").new();g.load_data();g.prefix=6;g.science_open=true
 for source in g.data.sources:
  var origin: Vector2=g.v(source.origin)
  for jump in source.jumps:
   var start: Vector2=g.v(jump.from)+origin;var target: Vector2=g.v(jump.toward)+origin;var count=0;var from_count=0;var end_count=0;var best=[]
   for dx in range(-28,29,2):
    for dy in range(-28,29,2):
     var p: Vector2=start+Vector2(dx,dy)
     if not g.standable(p,false,true,true) or not Geometry2D.is_point_in_polygon(p-origin,g.polygon(jump.takeoff)):continue
     from_count+=1
     for angle in range(-25,26,5):
      var end: Vector2=p+(target-start).normalized().rotated(deg_to_rad(angle))*103.6
      if g.standable(end,false,true,true) and Geometry2D.is_point_in_polygon(end-origin,g.polygon(jump.landing)):count+=1;best=[p,end]
   print(jump.id," start=",start," target=",target," takeoffs=",from_count," pairs=",count," best=",best," h=",g.height_record(start))
  for pt in [g.v(g.data.regions[int(source.subregion.right(1))-1].entry),g.v(g.data.regions[int(source.subregion.right(1))-1].exit)]:print("ANCHOR ",pt," support=",g.supported_box(Rect2(pt-Vector2(10,11),Vector2(20,22)))," blocked=",g.blocked_box(Rect2(pt-Vector2(10,11),Vector2(20,22))))
 quit()
