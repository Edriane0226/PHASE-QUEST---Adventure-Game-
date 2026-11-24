extends SceneTree
const BASE="res://assets/characters/cast/explorer/"
const ROWS={"east":0,"west":0,"south":2,"north":4,"south_east":1,"south_west":1,"north_east":3,"north_west":3}
func bounds(img:Image)->Rect2i:
	var lo=img.get_size()
	var hi=Vector2i.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x,y).a>0.97:
				lo=lo.min(Vector2i(x,y))
				hi=hi.max(Vector2i(x,y))
	return Rect2i(lo,hi-lo+Vector2i.ONE)
func collar(img:Image,b:Rect2i)->float:
	var ys=[]
	for y in range(b.position.y+int(b.size.y*0.28),b.position.y+int(b.size.y*0.63)):
		for x in range(b.position.x,b.end.x):
			var c=img.get_pixel(x,y)
			if c.a>0.97 and c.r>0.55 and c.g>0.33 and c.g>c.b*2 and c.r>c.g*1.12:ys.append(y)
	ys.sort()
	return float(ys[ys.size()/2]-b.position.y) if not ys.is_empty() else b.size.y*0.45
func _initialize():
	var f:SpriteFrames=load(BASE+"frames.tres")
	for dir in ROWS:
		var side=dir in ["east","west"]
		var front_back=dir in ["north","south"]
		var atlas=Image.load_from_file(BASE+("run_front_back_short_stride_source.png" if front_back else ("run_eight_side_source.png" if side else "run_eight_views_source.png")))
		var path=BASE+"run_current_model/"+dir+".png"
		if "--install" in OS.get_cmdline_user_args():
			f.clear("run_"+dir)
			for i in 8:
				var t=AtlasTexture.new()
				t.atlas=load(path)
				t.region=Rect2(i*192,0,192,192)
				t.filter_clip=true
				f.add_frame("run_"+dir,t)
			continue
		var walk_texture=f.get_frame_texture("walk_"+dir,1)
		var walk=walk_texture.get_image()
		if walk_texture.get_meta("mirror_walk",false):walk.flip_x()
		var wb=bounds(walk)
		var tiles=[]
		var boxes=[]
		var heights=[]
		for i in 8:
			var column=i
			var x=roundi(atlas.get_width()*column/8.0)
			var rows=2 if front_back else 5
			var row=0 if dir=="south" else (1 if dir=="north" else ROWS[dir])
			var y=0 if side else roundi(atlas.get_height()*row/rows)
			var tile=atlas.get_region(Rect2i(x,y,roundi(atlas.get_width()*(column+1)/8.0)-x,atlas.get_height() if side else roundi(atlas.get_height()*(row+1)/rows)-y))
			remove_haze(tile)
			var box=bounds(tile)
			tiles.append(tile)
			boxes.append(box)
			heights.append(float(box.size.y))
		heights.sort()
		var uniform_scale=float(wb.size.y)/((heights[1]+heights[2])*0.5)
		var out=Image.create(1536,192,false,Image.FORMAT_RGBA8)
		for i in 8:
			var tile:Image=tiles[i]
			var box:Rect2i=boxes[i]
			var center_x=0.0
			var head_pixels=0
			for y in range(box.position.y,box.position.y+int(box.size.y*0.35)):
				for x in range(box.position.x,box.end.x):
					if tile.get_pixel(x,y).a>0.97:
						center_x+=x
						head_pixels+=1
			center_x/=maxi(1,head_pixels)
			var pose_scale=collar(walk,wb)/collar(tile,box)
			var src=tile.get_region(box.grow(2))
			var width_scale=head_width(walk,wb)/head_width(tile,box)
			src.resize(roundi(src.get_width()*width_scale),roundi(src.get_height()*pose_scale),Image.INTERPOLATE_LANCZOS)
			var anchor_x=(center_x-box.position.x+2)*width_scale
			if dir in ["west","south_west","north_west"]:
				src.flip_x()
				anchor_x=src.get_width()-anchor_x
			match_palette(src,walk)
			var width_correction=head_width(walk,wb)/head_width(src,bounds(src))
			src.resize(roundi(src.get_width()*width_correction),src.get_height(),Image.INTERPOLATE_LANCZOS)
			anchor_x*=width_correction
			var height_correction=collar(walk,wb)/collar(src,bounds(src))
			src.resize(src.get_width(),roundi(src.get_height()*height_correction),Image.INTERPOLATE_LANCZOS)
			var visible=bounds(src)
			var offset=Vector2i(roundi(96-anchor_x),roundi(wb.position.y+collar(walk,wb)-visible.position.y-collar(src,visible)))
			assert(offset.x>=0 and offset.x+src.get_width()<=192,"Run frame clips horizontally")
			out.blit_rect(src,Rect2i(Vector2i.ZERO,src.get_size()),Vector2i(i*192,0)+offset)
		assert(out.save_png(path)==OK)
	if "--install" in OS.get_cmdline_user_args():assert(ResourceSaver.save(f,BASE+"frames.tres")==OK)
	quit()

func remove_haze(image:Image)->void:
	var visited={}
	var largest=[]
	for y in image.get_height():
		for x in image.get_width():
			var start=Vector2i(x,y)
			if visited.has(start) or image.get_pixelv(start).a<0.97:continue
			var group=[]
			var queue=[start]
			visited[start]=true
			while not queue.is_empty():
				var p=queue.pop_back()
				group.append(p)
				for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var q=p+step
					if q.x<0 or q.y<0 or q.x>=image.get_width() or q.y>=image.get_height() or visited.has(q):continue
					if image.get_pixelv(q).a<0.97:continue
					visited[q]=true
					queue.append(q)
			if group.size()>largest.size():largest=group
	var clean=Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8)
	for p in largest:clean.set_pixelv(p,image.get_pixelv(p))
	image.copy_from(clean)
func color_group(c:Color, fraction:float)->int:
	if c.a<0.97:return -1
	if fraction<0.42 and c.r>c.g*1.2 and c.r>0.25:return 0
	if fraction>0.25 and fraction<0.65 and c.r>0.55 and c.g>0.33 and c.g>c.b*2.0:return 1
	if fraction>0.25 and fraction<0.80 and c.r>0.64 and c.g>0.4 and c.b>0.25:return 2
	if fraction>0.35 and fraction<0.76 and c.g>c.r*0.65 and c.g<c.r*1.15 and c.g>c.b*1.35:return 3
	if fraction>0.62 and c.r>0.18 and c.r>c.b*1.3:return 4
	return -1

func color_means(image:Image)->Array:
	var box=bounds(image)
	var sums=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	var counts=[0,0,0,0,0]
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			var c=image.get_pixel(x,y)
			var group=color_group(c,float(y-box.position.y)/box.size.y)
			if group<0:continue
			sums[group]+=Vector3(c.r,c.g,c.b)
			counts[group]+=1
	for i in 5:
		if counts[i]>0:sums[i]/=counts[i]
	return sums

func match_palette(image:Image,reference:Image)->void:
	var source=color_means(image)
	var target=color_means(reference)
	var box=bounds(image)
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			var c=image.get_pixel(x,y)
			var group=color_group(c,float(y-box.position.y)/box.size.y)
			if group<0 or source[group].length()<0.01 or target[group].length()<0.01:continue
			var gain:Vector3=target[group]/source[group]
			gain=gain.clamp(Vector3.ONE*0.75,Vector3.ONE*1.25)
			image.set_pixel(x,y,Color(c.r*gain.x,c.g*gain.y,c.b*gain.z,c.a))
func head_width(image:Image,box:Rect2i)->float:
	var left=image.get_width()
	var right=0
	var bottom=box.position.y+roundi(collar(image,box)*0.84)
	for y in range(box.position.y,bottom):
		for x in range(box.position.x,box.end.x):
			if image.get_pixel(x,y).a>0.97:
				left=mini(left,x)
				right=maxi(right,x)
	return float(maxi(1,right-left+1))