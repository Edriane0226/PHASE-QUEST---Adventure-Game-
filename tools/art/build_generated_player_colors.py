"""Slice generated sprite artwork; never recolor pixels or change the player controller."""
from player_preview import *
import shutil, zipfile
import hashlib
DEST=ROOT/'output/player-black-hair-sprites';DEST.mkdir(exist_ok=True)
BEFORE=SOURCES/'player-black-hair-sprites/before-install.tres'
TARGET=ROOT/'assets/characters/cast/explorer/Animation Sprites Player/Animation Sprites Player/black_hair_generated'
pattern=r'"frames": \[(.*?)\],\s*"loop": (\d+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)'
directions=['east','south_east','south','north_east','north']

def build(install=False):
    manifest=json.loads((SOURCES/'player-black-hair-sprites/generation.json').read_text())
    clips={}; report=[]
    for action,info in manifest.items():
        n=info['frames'];src=Image.open(info['source']).convert('RGBA')
        (DEST/'sources').mkdir(exist_ok=True)
        shutil.copy2(info['source'],DEST/'sources'/f'{action}.png')
        for row,d in enumerate(directions):
            frames=[]
            for col in range(n):
                gx=round(src.width/n*.1);gy=round(src.height/5*.12)
                tile=src.crop((max(0,round(col*src.width/n)-gx),max(0,round(row*src.height/5)-gy),min(src.width,round((col+1)*src.width/n)+gx),min(src.height,round((row+1)*src.height/5)+gy)))
                tile=clean_islands(tile)
                arr=np.array(tile);arr[arr[:,:,3]<230]=0;tile=Image.fromarray(arr)
                box=tile.getbbox();assert box,(action,d,col,'empty')
                reference=anims[action+'_'+d][0][col]
                rb=reference.getbbox()
                pose=tile.crop(box).resize((rb[2]-rb[0],rb[3]-rb[1]),Image.Resampling.LANCZOS)
                out=Image.new('RGBA',(192,192));out.alpha_composite(pose,(rb[0],rb[1]))
                a=np.array(out)[:,:,3]>230;b=np.array(reference)[:,:,3]>230
                overlap=float((a&b).sum()/max(1,(a|b).sum()))
                report.append({'clip':action+'_'+d,'frame':col,'silhouette_overlap':round(overlap,3),'height':rb[3]-rb[1]})
                frames.append(out)
            clips[action+'_'+d]=frames
            # Preserve authored duplicate holds instead of introducing generated jitter.
            holds={}
            for i,reference in enumerate(anims[action+'_'+d][0]):
                key=hashlib.sha256(reference.tobytes()).hexdigest()
                if key in holds:frames[i]=frames[holds[key]].copy()
                else:holds[key]=i
            mirror={'east':'west','south_east':'south_west','north_east':'north_west'}.get(d)
            if mirror:clips[action+'_'+mirror]=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
    # Identical neutral endpoints across actions avoid near-match face/color pops.
    for d in DIRS:
        idle=clips['idle_'+d][0]
        for action in ['jump','lift','touch']:clips[action+'_'+d][0]=idle.copy()
        for action in ['jump','place','touch']:clips[action+'_'+d][-1]=idle.copy()
        clips['lift_'+d][-1]=clips['carry_idle_'+d][0].copy()
        clips['place_'+d][0]=clips['carry_idle_'+d][0].copy()
    (DEST/'frames').mkdir(exist_ok=True);(DEST/'gifs').mkdir(exist_ok=True)
    for name,frames in clips.items():
        folder=DEST/'frames'/name;folder.mkdir(exist_ok=True)
        for i,im in enumerate(frames):im.save(folder/f'{i:02d}.png')
    for action in manifest:
        film=[];n=manifest[action]['frames']
        for frame in range(n):
            canvas=Image.new('RGB',(768,440),(43,48,55));draw=ImageDraw.Draw(canvas)
            draw.text((6,4),action+' / generated black-hair sprites',fill='white')
            for j,d in enumerate(DIRS):
                im=clips[action+'_'+d][frame];x=(j%4)*192;y=28+(j//4)*202
                canvas.paste(im,(x,y),im);draw.text((x+5,y),d,fill='white')
            film.append(canvas)
        film[0].save(DEST/'gifs'/f'{action}.gif',save_all=True,append_images=film[1:],duration=90 if action=='run' else 160,loop=0,optimize=False)
    canvas=Image.new('RGB',(768,len(manifest)*195),(43,48,55));draw=ImageDraw.Draw(canvas)
    for row,action in enumerate(manifest):
        draw.text((4,row*195+2),action+' / original reference left',fill='white')
        for col,im in enumerate([anims[action+'_south'][0][0]]+clips[action+'_south'][:3]):canvas.paste(im,(col*192,row*195+15),im)
    canvas.save(DEST/'color-review.png')
    (DEST/'checks.json').write_text(json.dumps(report,indent=2))
    with zipfile.ZipFile(DEST/'generated-color-gifs.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in (DEST/'gifs').glob('*.gif'):z.write(p,p.name)
    print('Prepared',len(clips),'clips; minimum silhouette overlap',min(r['silhouette_overlap'] for r in report))
    if install:install_clips(clips)

def install_clips(clips):
    path=ROOT/'assets/characters/cast/explorer/frames.tres';original=path.read_text()
    if not BEFORE.exists():shutil.copy2(path,BEFORE)
    source=re.sub(r'\[ext_resource[^\n]*id="black_hair_[^"]+"\]\n','',original)
    source=re.sub(r'\[sub_resource[^\n]*id="black_hair_[^"]+"\]\n.*?(?=\n\[)','',source,flags=re.S)
    # Remove obsolete shader-only metadata, keeping animation timing/geometry intact.
    source=re.sub(r'\nmetadata/hair_cutoff = [^\n]+','',source)
    ext=[];sub=[]
    TARGET.mkdir(exist_ok=True)
    for name,frames in clips.items():
        strip=Image.new('RGBA',(len(frames)*192,192))
        for i,im in enumerate(frames):
            strip.alpha_composite(im,(i*192,0))
            # Retain existing authored hand anchors and registration metadata.
            oldmatch=next(m for m in re.finditer(pattern,original,re.S) if m[3]==name)
            oldid=re.findall(r'SubResource\("([^"]+)"\)',oldmatch[1])[i]
            metadata='\n'.join(line for line in subs[oldid].splitlines() if line.startswith('metadata/') and 'hair_cutoff' not in line and 'mirror_walk' not in line)
            if name.startswith(('idle_','walk_')):metadata+='\nmetadata/mirror_walk = false'
            sub.append(f'[sub_resource type="AtlasTexture" id="black_hair_{name}_{i}"]\natlas = ExtResource("black_hair_{name}")\nregion = Rect2({i*192}, 0, 192, 192)\nfilter_clip = true\n{metadata}\n')
        strip.save(TARGET/f'{name}.png')
        rel=(TARGET/f'{name}.png').relative_to(ROOT).as_posix()
        ext.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="black_hair_{name}"]\n')
    def replace(m):
        body,loop,name,speed=m.groups()
        if name not in clips:return m[0]
        refs=iter(range(len(clips[name])))
        body=re.sub(r'SubResource\("[^"]+"\)',lambda _:f'SubResource("black_hair_{name}_{next(refs)}")',body)
        return '"frames": ['+body+'],\n"loop": '+loop+',\n"name": &"'+name+'",\n"speed": '+speed
    updated=re.sub(pattern,replace,source,flags=re.S)
    updated=updated.replace('[sub_resource','\n'.join(ext)+'\n[sub_resource',1).replace('[resource]','\n'.join(sub)+'\n[resource]',1)
    path.write_text(updated,encoding='utf-8')
    print('Installed actual generated PNG sprites for all 80 clips. No runtime recoloring.')

if __name__=='__main__':build('--install' in sys.argv)
