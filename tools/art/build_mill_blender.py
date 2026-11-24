import bpy, math, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
art_dir = Path(__file__).resolve().parent
out = art_dir / "frozen_mill_render"
out.mkdir(exist_ok=True)
scene=bpy.context.scene
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
def mat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);return m
wood=mat("Cedar",(.40,.27,.16));plank=mat("Plank",(.49,.34,.21));edge=mat("Timber",(.23,.18,.14));metal=mat("Iron",(.20,.25,.29));stone=mat("Stone",(.34,.40,.45));snow=mat("Snow",(.80,.88,.94));glass=mat("Amber",(.73,.56,.27));door=mat("Teal",(.25,.35,.37))
house=[];wheel=[]
def box(n,p,d,m,g=house):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p)
 o=bpy.context.object;o.name=n;o.dimensions=d
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(m)
 b=o.modifiers.new("Cut edges","BEVEL");b.width=.025;b.segments=1
 o.modifiers.new("Normals","WEIGHTED_NORMAL");g.append(o);return o
box("Foundation",(0,0,.18),(3,2.4,.36),stone)
box("Walls",(0,0,1.28),(2.8,2.2,2),wood)
for z in [.5,.78,1.06,1.34,1.62,1.9,2.17]:
 box("Front board",(0,-1.115,z),(2.75,.055,.235),plank)
 box("Side board",(1.415,0,z),(.055,2.15,.235),plank)
for x in [-1.34,1.34]:box("Post",(x,-1.16,1.27),(.13,.12,2.1),edge)
for y in [-1.03,1.03]:box("Side post",(1.46,y,1.27),(.1,.13,2.1),edge)
v=[(-1.4,-1.1,2.28),(1.4,-1.1,2.28),(0,-1.1,3.25),(-1.4,1.1,2.28),(1.4,1.1,2.28),(0,1.1,3.25)]
me=bpy.data.meshes.new("Gable");me.from_pydata(v,[],[(0,1,2),(3,5,4),(0,3,4,1),(0,2,5,3),(1,4,5,2)]);me.update()
o=bpy.data.objects.new("Gable",me);scene.collection.objects.link(o);o.data.materials.append(wood);house.append(o)
angle=math.atan2(.97,1.4)
for side in [-1,1]:
 o=box("Snow roof",(side*.79,0,2.82),(1.94,2.7,.19),snow);o.rotation_euler.y=side*angle
 o=box("Fascia",(side*.79,-1.38,2.77),(1.94,.09,.15),metal);o.rotation_euler.y=side*angle
box("Door frame",(-.35,-1.19,.93),(.88,.12,1.45),edge)
box("Door",(-.35,-1.27,.91),(.70,.07,1.32),door)
box("Latch",(-.13,-1.34,.93),(.06,.035,.09),glass)
for x in [-.9,.85]:
 box("Window frame",(x,-1.2,1.78),(.49,.13,.56),edge)
 box("Glass",(x,-1.28,1.78),(.38,.04,.44),glass)
 box("Mullion",(x,-1.31,1.78),(.035,.03,.45),edge)
 box("Snow sill",(x,-1.27,1.49),(.58,.22,.065),snow)
box("Side frame",(1.48,.4,1.65),(.13,.65,.6),edge)
box("Side glass",(1.56,.4,1.65),(.04,.52,.47),glass)
box("Side mullion",(1.59,.4,1.65),(.025,.035,.48),edge)
for i in range(2):box("Step",(-.35,-1.48-i*.18,.13-i*.05),(.98,.35,.12),stone)
box("Chimney",(.6,.6,3.12),(.45,.48,.8),stone)
box("Cap",(.6,.6,3.56),(.58,.61,.12),snow)
pivot=Vector((1.82,0,.95))
def ring(x):
 verts=[];faces=[]
 for axial in [x-.045,x+.045]:
  for radius in [.76,.91]:
   for i in range(24):
    a=i*math.tau/24;verts.append((axial,math.sin(a)*radius,math.cos(a)*radius))
 for i in range(24):
  j=(i+1)%24
  faces.extend([(i,j,24+j,24+i),(48+i,72+i,72+j,48+j),(i,48+i,48+j,j),(24+i,24+j,72+j,72+i)])
 me=bpy.data.meshes.new("Rim");me.from_pydata(verts,[],faces);me.update()
 o=bpy.data.objects.new("Rim",me);scene.collection.objects.link(o);o.location=pivot;o.data.materials.append(edge);wheel.append(o)
ring(-.24);ring(.24)
for i in range(8):
 o=box("Spoke",pivot,(.54,.105,1.62),plank,wheel);o.rotation_euler.x=i*math.tau/8
for i in range(12):
 a=i*math.tau/12
 o=box("Paddle",pivot+Vector((0,math.sin(a)*.88,math.cos(a)*.88)),(.59,.28,.10),wood,wheel);o.rotation_euler.x=-a
 for side in [-1,1]:
  o=box("Bucket side",pivot+Vector((side*.285,math.sin(a)*.85,math.cos(a)*.85)),(.045,.28,.21),metal,wheel);o.rotation_euler.x=-a
bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.17,depth=.7,location=pivot,rotation=(0,math.pi/2,0))
o=bpy.context.object;o.data.materials.append(metal);wheel.append(o)
bpy.ops.object.empty_add(location=pivot);rotator=bpy.context.object
bpy.context.view_layer.update()
for o in wheel:
 m=o.matrix_world.copy();o.parent=rotator;o.matrix_world=m
bpy.ops.object.camera_add(location=(7,-7,6.9))
cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.3))-cam.location).to_track_quat("-Z","Y").to_euler();cam.data.type="ORTHO";cam.data.ortho_scale=6.1;scene.camera=cam
scene.render.engine="BLENDER_WORKBENCH"
sh=scene.display.shading;sh.light="STUDIO";sh.studio_light="paint.sl";sh.color_type="MATERIAL";sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type="BOTH";sh.show_object_outline=True;sh.object_outline_color=(.07,.09,.12)
scene.render.film_transparent=True
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA";scene.view_settings.view_transform="Standard";scene.view_settings.exposure=0.6
bpy.context.view_layer.update()
ground=world_to_camera_view(scene,cam,Vector((0,0,0)));anchor=(ground.x*512,(1-ground.y)*512)
for o in wheel:o.hide_render=True
scene.render.filepath=str(out/"mill_house.png");bpy.ops.render.render(write_still=True)
for o in house:o.hide_render=True
for o in wheel:o.hide_render=False
for i in range(24):
 rotator.rotation_euler.x=i*math.tau/24
 scene.render.filepath=str(out/f"wheel_{i:02d}.png");bpy.ops.render.render(write_still=True)
for o in house:o.hide_render=False
rotator.rotation_euler.x=0
bpy.ops.wm.save_as_mainfile(filepath=str(art_dir / "frozen_mill.blend"))
(out/"render_metadata.json").write_text(json.dumps({"anchor":anchor,"frames":24}))
print("BLENDER MILL RENDER PASS",anchor)



