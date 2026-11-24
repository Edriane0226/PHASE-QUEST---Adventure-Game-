"""Build action art with separate head/body landmarks and immutable idle/walk."""
from player_preview import *
import shutil, hashlib
DEST=ROOT/'output/player-actions-v2';DEST.mkdir(exist_ok=True)
ASSETS=ROOT/'assets/characters/cast/explorer/actions_v2'
ACTIONS=['run','carry_walk','carry_idle','jump','lift','place','touch','operate']
pattern=r'"frames": \[(.*?)\],\s*"loop": (\d+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)'

def collar(im):
    a=np.array(im); r,g,b=a[:,:,:3].astype(float).transpose(2,0,1)
    box=im.getbbox(); h=box[3]-box[1]
    mask=(a[:,:,3]>200)&(r>135)&(g>95)&(g>b*1.7)&(r>g*1.05)&(r<g*1.9)
    mask[:int(box[1]+h*.3)]=False;mask[int(box[1]+h*.65):]=False
    yy,xx=np.where(mask)
    return int(np.median(yy)) if len(yy) else round(box[1]+h*.48)

def isolate(im):
    im=clean_islands(im)
    a=np.array(im); a[a[:,:,3]<180]=0
    return Image.fromarray(a)

def palette_from_references():
    pixels=np.concatenate([np.array(im)[np.array(im)[:,:,3]>220,:3] for k,(frames,_) in anims.items() if k.startswith(('idle_','walk_')) for im in frames])
    return Image.fromarray(pixels.reshape(1,-1,3)).quantize(colors=240)

def hand(im):
    a=np.array(im); r,g,b=a[:,:,:3].astype(float).transpose(2,0,1)
    cy=collar(im)
    mask=(a[:,:,3]>200)&(r>180)&(g>115)&(b>75)&(r>g*1.1)&(r<g*1.6)
    mask[:cy+7]=False
    yy,xx=np.where(mask)
    if len(xx):return [round(float(np.median(xx))),round(float(np.median(yy)))]
    return [96,cy+15]

def build(install=False):
    meta=json.loads((SOURCES/'player-actions-v2/generation.json').read_text())
    pal=palette_from_references()
    clips={}; stats=[]
    for action in ACTIONS:
        info=meta[action]; n=info['frames']
        source=Image.open(info['source']).convert('RGBA')
        (DEST/'sources').mkdir(exist_ok=True)
        shutil.copy2(info['source'],DEST/'sources'/f'{action}.png')
        for row,direction in enumerate(['east','south_east','south','north_east','north']):
            ref=anims['idle_'+direction][0][0]; rb=ref.getbbox(); rc=collar(ref); rh=hairbox(ref)
            tiles=[]
            for col in range(n):
                source_id=hashlib.sha256(info['source'].encode()).hexdigest()[:8]
                cache=DEST/'isolated'/f'{action}_{direction}_{col}_{source_id}_gutter.png'
                if cache.exists():tile=Image.open(cache).convert('RGBA')
                else:
                    # Generated poses can cross nominal cell edges. Include gutters,
                    # then isolate the complete main character instead of cutting hair.
                    gx=round(source.width/n*.12);gy=round(source.height/5*.18)
                    tile=isolate(source.crop((max(0,round(col*source.width/n)-gx),max(0,round(row*source.height/5)-gy),min(source.width,round((col+1)*source.width/n)+gx),min(source.height,round((row+1)*source.height/5)+gy))))
                    cache.parent.mkdir(exist_ok=True);tile.save(cache)
                tiles.append(tile)
            # Torso/leg scale is measured from standing poses, never from head width.
            upright=[0,n-1] if action in ['jump','lift','place'] else list(range(n))
            body_scale=(rb[3]-rc)/float(np.median([tiles[i].getbbox()[3]-collar(tiles[i]) for i in upright]))
            frames=[]
            for i,tile in enumerate(tiles):
                box=tile.getbbox(); cy=collar(tile); hb=hairbox(tile)
                xscale=(rh[2]-rh[0])/(hb[2]-hb[0])
                width=round((box[2]-box[0])*xscale)
                head=tile.crop((box[0],box[1],box[2],cy))
                body=tile.crop((box[0],cy,box[2],box[3]))
                top_height=rc-rb[1]
                if action in ['carry_idle','touch','operate']: bottom_height=rb[3]-rc
                else: bottom_height=round(body.height*body_scale)
                head=head.resize((width,top_height),Image.Resampling.LANCZOS)
                body=body.resize((width,bottom_height),Image.Resampling.LANCZOS)
                joined=Image.new('RGBA',(width,top_height+bottom_height));joined.alpha_composite(head);joined.alpha_composite(body,(0,top_height))
                alpha=joined.getchannel('A').point(lambda v:255 if v>160 else 0)
                joined=joined.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');joined.putalpha(alpha)
                # Registered head axis when upright; planted-foot axis for crouches.
                anchor=(hb[0]+hb[2])/2
                x=round((rh[0]+rh[2])/2-(anchor-box[0])*xscale)
                y=rb[3]-joined.height
                assert x>=0 and y>=0 and x+width<=192,(action,direction,i,'clipping')
                out=Image.new('RGBA',(192,192));out.alpha_composite(joined,(x,y))
                if action in ['carry_idle','touch','operate','lift','place']:
                    def feet_center(frame):
                        arr=np.array(frame);bb=frame.getbbox()
                        ys,xs=np.where(arr[max(bb[1],bb[3]-8):bb[3],:,3]>180)
                        return float(np.median(xs))
                    dx=round(feet_center(ref)-feet_center(out))
                    registered=Image.new('RGBA',(192,192));registered.alpha_composite(out,(dx,0));out=registered
                frames.append(out)
            if action=='run' and direction in ['south','north']:
                # Keep each support-leg half-cycle together; source columns interleave contacts.
                frames=[frames[i] for i in [0,2,3,7,4,1,5,6]]
            # Reuse actual neutral endpoints instead of a near-match redraw.
            if action in ['jump','lift','touch']: frames[0]=ref.copy()
            if action in ['jump','place','touch']: frames[-1]=ref.copy()
            clips[action+'_'+direction]=frames
            mirror={'east':'west','south_east':'south_west','north_east':'north_west'}.get(direction)
            if mirror: clips[action+'_'+mirror]=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
    for d in DIRS:
        clips['lift_'+d][-1]=clips['carry_idle_'+d][0].copy()
        clips['place_'+d][0]=clips['carry_idle_'+d][0].copy()
        # Mirroring a neutral endpoint must not replace the original directional idle.
        for a in ['jump','lift','touch']:clips[a+'_'+d][0]=anims['idle_'+d][0][0].copy()
        for a in ['jump','place','touch']:clips[a+'_'+d][-1]=anims['idle_'+d][0][0].copy()
    for name,frames in clips.items():
        folder=DEST/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
        for i,im in enumerate(frames):im.save(folder/f'{i:02d}.png')
    for action in ACTIONS:
        frames=[]
        for i in range(len(clips[action+'_south'])):
            canvas=Image.new('RGB',(768,448),(43,48,55));draw=ImageDraw.Draw(canvas)
            draw.text((8,5),action+' | corrected proportions | frame '+str(i+1),fill='white')
            for j,d in enumerate(DIRS):
                im=clips[action+'_'+d][i];x=(j%4)*192;y=30+(j//4)*206
                canvas.paste(im,(x,y),im);draw.text((x+5,y),d,fill='white')
            frames.append(canvas)
        (DEST/'gifs').mkdir(exist_ok=True)
        frames[0].save(DEST/'gifs'/f'{action}.gif',save_all=True,append_images=frames[1:],duration=90 if action=='run' else 150,loop=0,optimize=False)
    canvas=Image.new('RGB',(9*192,len(ACTIONS)*210),(43,48,55));draw=ImageDraw.Draw(canvas)
    for row,action in enumerate(ACTIONS):
        draw.text((5,row*210+2),action+' / original idle at left',fill='white')
        for col,im in enumerate([anims['idle_south'][0][0]]+clips[action+'_south']):canvas.paste(im,(col*192,row*210+18),im)
    canvas.save(DEST/'front-filmstrip.png')
    # Before installing, enforce the actual previously failing standing-height condition.
    for d in DIRS:
        rb=anims['idle_'+d][0][0].getbbox(); target_height=rb[3]-rb[1]
        for action in ['carry_idle','touch','operate']:
            for i,im in enumerate(clips[action+'_'+d]):
                b=im.getbbox(); h=b[3]-b[1]
                assert abs(h-target_height)<=2,(action,d,i,h,target_height)
    if install:
        install_clips(clips)
    print('Built',len(clips),'clips; standing height/baseline gate passed.')

def install_clips(clips):
    resource=ROOT/'assets/characters/cast/explorer/frames.tres'
    original=resource.read_text()
    # Rebuilding must replace its resource declarations, not append duplicate IDs.
    original=re.sub(r'\[ext_resource[^\n]*id="action_v2_[^"]+"\]\n','',original)
    original=re.sub(r'\[sub_resource[^\n]*id="action_v2_[^"]+"\]\n.*?(?=\n\[)','',original,flags=re.S)
    saved=DEST/'before-install';saved.mkdir(exist_ok=True)
    for path in [resource,ROOT/'Actors/Player/campaign_player.gd']:
        if not (saved/path.name).exists():shutil.copy2(path,saved/path.name)
    ASSETS.mkdir(exist_ok=True)
    ext=[];sub=[]
    for name,frames in clips.items():
        strip=Image.new('RGBA',(192*len(frames),192))
        for i,im in enumerate(frames):
            strip.alpha_composite(im,(i*192,0))
            h=hand(im)
            sub.append(f'[sub_resource type="AtlasTexture" id="action_v2_{name}_{i}"]\natlas = ExtResource("action_v2_{name}")\nregion = Rect2({i*192}, 0, 192, 192)\nfilter_clip = true\nmetadata/preview_registered = true\nmetadata/hand_anchor = Vector2({h[0]}, {h[1]})\n')
        strip.save(ASSETS/f'{name}.png')
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/characters/cast/explorer/actions_v2/{name}.png" id="action_v2_{name}"]\n')
    def replace(m):
        body,loop,name,speed=m.groups()
        if name not in clips:return m[0]
        refs=['{\n"duration": 1.0,\n"texture": SubResource("action_v2_'+name+'_'+str(i)+'")\n}' for i in range(len(clips[name]))]
        fps={'run':12.0,'carry_walk':6.0,'carry_idle':3.0,'jump':10.0,'lift':8.0,'place':8.0,'touch':8.0,'operate':8.0}[next(a for a in ACTIONS if name.startswith(a+'_'))]
        return '"frames": ['+', '.join(refs)+'],\n"loop": '+loop+',\n"name": &"'+name+'",\n"speed": '+str(fps)
    updated=re.sub(pattern,replace,original,flags=re.S)
    updated=updated.replace('[sub_resource','\n'.join(ext)+'\n[sub_resource',1).replace('[resource]','\n'.join(sub)+'\n[resource]',1)
    for m in re.finditer(pattern,original,re.S):
        if m[3].startswith(('idle_','walk_')):
            after=next(n[0] for n in re.finditer(pattern,updated,re.S) if n[3]==m[3]);assert m[0]==after
    resource.write_text(updated,encoding='utf-8')
    print('Installed action v2; all idle/walk animation definitions retained exactly.')

if __name__=='__main__':build('--install' in sys.argv)
