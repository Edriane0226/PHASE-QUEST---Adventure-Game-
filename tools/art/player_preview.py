"""Extract engine-resolved references and assemble review-only player previews."""
import sys, re, json
from pathlib import Path
sys.path.insert(0,str(Path('.art-tools/python').resolve()))
from PIL import Image, ImageDraw
import numpy as np
ROOT=Path.cwd()
OUT=ROOT/'output/player-animation-review'
OUT.mkdir(parents=True,exist_ok=True)
(ROOT/'output/.gdignore').touch()
# Committed inputs; output/ is generated and not in git.
SOURCES=ROOT/'tools/art/player_sources'
text=(ROOT/'assets/characters/cast/explorer/frames.tres').read_text()
ext=dict((i,p.replace('res://','')) for p,i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)" id="([^"]+)"',text))
subs=dict(re.findall(r'\[sub_resource[^\n]*id="([^"]+)"\]\n(.*?)(?=\n\[)',text,re.S))
anims={}
for body,name,speed in re.findall(r'"frames": \[(.*?)\],\s*"loop": \d+,\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)',text,re.S):
    frames=[]
    for typ,i in re.findall(r'"texture": (SubResource|ExtResource)\("([^"]+)"\)',body):
        if typ=='ExtResource': im=Image.open(ROOT/ext[i]).convert('RGBA')
        else:
            sub=subs[i]; eid=re.search(r'atlas = ExtResource\("([^"]+)"',sub)[1]
            im=Image.open(ROOT/ext[eid]).convert('RGBA')
            x,y,w,h=map(lambda s:int(float(s)),re.search(r'region = Rect2\(([^)]+)\)',sub)[1].split(','))
            im=im.crop((x,y,x+w,y+h))
        frames.append(im)
        if typ=='SubResource' and 'metadata/mirror_walk = true' in subs[i]:
            frames[-1]=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    anims[name]=(frames,float(speed))
DIRS=['east','south_east','south','south_west','west','north_west','north','north_east']
def sheet(names, filename, count=4):
    canvas=Image.new('RGB',(count*192,len(names)*218),(43,48,55)); d=ImageDraw.Draw(canvas)
    for row,name in enumerate(names):
        frames=anims[name][0]
        d.text((6,row*218+4),name,fill='white')
        for col,im in enumerate(frames[:count]): canvas.paste(im,(col*192,row*218+22),im)
    canvas.save(OUT/filename)

def hairbox(im):
    a=np.array(im); r,g,b=a[:,:,:3].astype(float).transpose(2,0,1)
    mask=(a[:,:,3]>180)&(r>g*1.35)&(r>b*1.5)&(r>65)&(g>25)&(g<140)
    yy,xx=np.where(mask)
    # Hair lies above the torso; remove similarly coloured boots.
    if len(yy):
        mask[int(yy.min()+max(20,(yy.max()-yy.min())*.6)):]=False
    yy,xx=np.where(mask)
    return (int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))

def clean_islands(tile):
    from collections import deque
    a=np.array(tile); mask=a[:,:,3]>170
    seen=np.zeros(mask.shape,bool); largest=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]: continue
        q=deque([(int(y),int(x))]); seen[y,x]=True; component=[]
        while q:
            yy,xx=q.popleft(); component.append((yy,xx))
            for ny,nx in ((yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)):
                if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True; q.append((ny,nx))
        if len(component)>len(largest):largest=component
    keep=np.zeros(mask.shape,bool)
    for y,x in largest: keep[y,x]=True
    a[~keep]=0
    return Image.fromarray(a)

def build():
    import shutil, zipfile
    meta=json.loads((SOURCES/OUT.name/'generation.json').read_text())
    (OUT/'sources').mkdir(exist_ok=True)
    (OUT/'frames').mkdir(exist_ok=True)
    (OUT/'gifs').mkdir(exist_ok=True)
    # One fixed quantizer, derived only from the approved idle/walk colors.
    pixels=np.concatenate([np.array(im)[np.array(im)[:,:,3]>220,:3] for k,(frames,_) in anims.items() if k.startswith(('idle_','walk_')) for im in frames])
    pal=Image.fromarray(pixels.reshape(1,-1,3)).quantize(colors=240)
    palette=pal.getpalette()
    all_frames={}; reports=[]
    rowdirs=['east','south_east','south','north_east','north']
    for action,info in meta.items():
        shutil.copy2(info['source'],OUT/'sources'/f'{action}.png')
        src=Image.open(info['source']).convert('RGBA')
        for row,direction in enumerate(rowdirs):
            ref=anims['idle_'+direction][0][0]
            rh=hairbox(ref); rb=ref.getbbox()
            frames=[]; measures=[]
            for col in range(4):
                tile=src.crop((round(col*src.width/4),round(row*src.height/5),round((col+1)*src.width/4),round((row+1)*src.height/5)))
                if row==3 and action in ['carry_idle','lift']:
                    tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                tile=clean_islands(tile)
                box=tile.getbbox(); hb=hairbox(tile)
                scale=(rh[2]-rh[0])/(hb[2]-hb[0])
                crop=tile.crop(box)
                crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
                # Shared palette prevents frame-dependent GIF color flicker.
                alpha=crop.getchannel('A').point(lambda v:255 if v>150 else 0)
                crop=crop.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA'); crop.putalpha(alpha)
                cx=((hb[0]+hb[2])/2-box[0])*scale
                x=round((rh[0]+rh[2])/2-cx)
                jump=[0,9,21,0][col] if action=='jump' else 0
                bounce=[0,2,0,2][col] if action=='run' else 0
                y=rb[3]-crop.height-jump-bounce
                frame=Image.new('RGBA',(192,192)); frame.alpha_composite(crop,(x,y))
                bb=frame.getbbox()
                clipping=x<0 or y<0 or x+crop.width>192 or y+crop.height>192
                assert not clipping,(action,direction,col,'CLIPPING')
                frames.append(frame)
                measures.append({'frame':col,'bounds':bb,'hair_width':hairbox(frame)[2]-hairbox(frame)[0],'ground':bb[3],'clipped':clipping})
            all_frames[action+'_'+direction]=frames
            mirror={'east':'west','south_east':'south_west','north_east':'north_west'}.get(direction)
            if mirror: all_frames[action+'_'+mirror]=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
            mask=[np.array(f)[:,:,3]>0 for f in frames]
            transitions=[round(float(np.logical_xor(mask[i],mask[(i+1)%4]).sum()/max(1,np.logical_or(mask[i],mask[(i+1)%4]).sum())),3) for i in range(4)]
            reports.append({'action':action,'direction':direction,'frames':measures,'silhouette_change':transitions,'review_flags':['large silhouette transition' for t in transitions if t>.6]})
    for name,frames in all_frames.items():
        folder=OUT/'frames'/name; folder.mkdir(exist_ok=True)
        for i,f in enumerate(frames): f.save(folder/f'{i:02d}.png')
        fps=8 if name.startswith('run_') else anims[name][1]
        rendered=[]
        for f in frames:
            c=Image.new('RGB',(192,192),(43,48,55)); c.paste(f,(0,0),f); rendered.append(c)
        rendered[0].save(OUT/'gifs'/f'{name}.gif',save_all=True,append_images=rendered[1:],duration=round(1000/fps),loop=0,optimize=False)
    # Each action preview displays all eight directions simultaneously.
    for action in meta:
        films=[]
        for i in range(4):
            c=Image.new('RGB',(768,452),(43,48,55)); draw=ImageDraw.Draw(c)
            draw.text((12,8),action+' | all eight directions | review draft',fill='white')
            for j,d in enumerate(DIRS):
                im=all_frames[action+'_'+d][i]
                c.paste(im,((j%4)*192,38+(j//4)*202),im)
                draw.text(((j%4)*192+8,28+(j//4)*202),d,fill=(195,200,208))
            films.append(c)
        fps=8 if action=='run' else anims[action+'_south'][1]
        # One-shots include engine-resolved idle/carry endpoints for honest transition review.
        if action in ['jump','lift','place','touch','operate']:
            for is_end in [False,True]:
                c=Image.new('RGB',(768,452),(43,48,55)); draw=ImageDraw.Draw(c)
                draw.text((12,8),action+' | '+('exit' if is_end else 'entry')+' reference',fill='white')
                for j,d in enumerate(DIRS):
                    kind='carry_idle' if (action=='lift' and is_end) or (action=='place' and not is_end) else 'idle'
                    im=all_frames.get(kind+'_'+d,anims['idle_'+d][0])[0]
                    c.paste(im,((j%4)*192,38+(j//4)*202),im)
                    draw.text(((j%4)*192+8,28+(j//4)*202),d,fill=(195,200,208))
                if is_end: films.append(c)
                else: films.insert(0,c)
        durations=[round(1000/fps)]*len(films)
        if len(films)==6: durations[0]=durations[-1]=400
        films[0].save(OUT/'gifs'/f'{action}.gif',save_all=True,append_images=films[1:],duration=durations,loop=0,optimize=False)
        Image.open(OUT/'gifs'/f'{action}.gif').verify()
    # Compact visual QA filmstrip: SE view of each action, same scale as reference.
    c=Image.new('RGB',(960,218*len(meta)),(43,48,55)); dr=ImageDraw.Draw(c)
    for row,action in enumerate(meta):
        dr.text((8,row*218+4),action+' (idle reference at left)',fill='white')
        for col,im in enumerate([anims['idle_south_east'][0][0]]+all_frames[action+'_south_east']):c.paste(im,(col*192,row*218+22),im)
    c.save(OUT/'review-filmstrip.png')
    (OUT/'checks.json').write_text(json.dumps({'status':'review drafts, not engine installed','palette':'single 240-color palette derived from active idle and walk','checks':reports},indent=2))
    with zipfile.ZipFile(OUT/'player-gifs.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in (OUT/'gifs').glob('*.gif'): z.write(p,'gifs/'+p.name)
    print('Created',len(meta),'action GIFs;',len(all_frames),'directional clips; no canvas clipping.')
if __name__=='__main__':
    if '--build' in sys.argv:
        build(); sys.exit()
    sheet(['walk_'+d for d in DIRS],'reference-walk.png')
    sheet(['idle_'+d for d in DIRS],'reference-idle.png')
    sheet([a+'_south_east' for a in ['carry_idle','carry_walk','run','jump','lift','place','touch','operate']],'old-actions.png')
    print(json.dumps({k:{'frames':len(v[0]),'fps':v[1]} for k,v in anims.items()},indent=2))
