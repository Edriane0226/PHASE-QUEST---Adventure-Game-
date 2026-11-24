"""Repair a missing generated key and register north-run artwork, not runtime code."""
from fix_player_png_palette import *
import fix_player_png_palette as palette
DEST=ROOT/'output/player-north-run-repair';DEST.mkdir(exist_ok=True)

def hair_axis(im):
    a=np.array(im);mask=materials(im)['hair']&(a[:,:,3]>230);ys,xs=np.where(mask)
    return float((xs.min()+xs.max())/2),int(xs.max()-xs.min()+1)

def extra_materials(im):
    a=np.array(im);r,g,b=a[:,:,:3].astype(float).transpose(2,0,1);ys,xs=np.indices(a.shape[:2]);valid=a[:,:,3]>0;neck=collar(im)
    return {'brown':valid&(ys>neck+20)&(r>65)&(r<190)&(r>g*1.25)&(g>b*1.15),
            'scarf':valid&(r>135)&(g>85)&(r-g>15)&(g-b>45)&(r<g*1.7)&(g>b*1.8),
            'cuffs':valid&(r>175)&(g>155)&(b>110)&((r-g)<(g-b)*.85)}

def match_extras(im,reference):
    a=np.array(im);ra=np.array(reference);sm=extra_materials(im);rm=extra_materials(reference);out=a.copy()
    for name in sm:
        opaque=sm[name]&(a[:,:,3]>230);target=rm[name]&(ra[:,:,3]>230)
        src=a[opaque,:3];ref=ra[target,:3]
        if min(len(src),len(ref))<8:continue
        vals,counts=np.unique(luminance(src),return_counts=True);ranks=(np.cumsum(counts)-counts*.5)/counts.sum()
        ordered=ref[np.argsort(luminance(ref),kind='stable')]
        qs=np.interp(luminance(a[sm[name],:3]),vals,ranks);idx=np.clip(np.rint(qs*(len(ordered)-1)).astype(int),0,len(ordered)-1)
        out[sm[name],:3]=ordered[idx]
    return Image.fromarray(out)

def export_motion_gifs(frames,before):
    scene=(ROOT/'Actors/Player/Player.tscn').read_text()
    model=(ROOT/'Actors/Player/player_model.gd').read_text()
    controller=(ROOT/'Actors/Player/campaign_player.gd').read_text()
    def setting(name,default_text):
        override=re.search(r'^'+name+r' = ([\d.]+)',scene,re.M)
        if override:return float(override[1])
        return float(re.search(r'@export var '+name+r'(?::\s*\w+)?\s*:?=\s*([\d.]+)',default_text)[1])
    speed=setting('move_speed',model)*setting('sprint_multiplier',model)
    cycle_ms=1000*setting('run_cycle_distance',controller)/speed
    timing=[round((i+1)*cycle_ms/8/10)*10-round(i*cycle_ms/8/10)*10 for i in range(8)]
    for name,duration in [('game-speed.gif',timing),('slow-review.gif',100)]:
        film=[]
        for i,f in enumerate(frames):
            bg=Image.new('RGB',(384,214),(43,48,55));d=ImageDraw.Draw(bg)
            bg.paste(before[i],(0,20),before[i]);bg.paste(f,(192,20),f)
            d.text((5,3),'Before / '+str(i+1),fill='white');d.text((197,3),'Repaired / '+str(i+1),fill='white')
            film.append(bg.resize((768,428),Image.Resampling.NEAREST))
        film[0].save(DEST/name,save_all=True,append_images=film[1:],duration=duration,loop=0,optimize=False)
    return timing

def build():
    meta=json.loads((SOURCES/'player-north-run-repair/landing-generation.json').read_text());src=Image.open(meta['source']).convert('RGBA')
    shutil.copy2(meta['source'],DEST/'generated-landing.png')
    a=np.array(src);core=biggest(a[:,:,3]>200);keep=core.copy()
    for dy in (-1,0,1):
        for dx in (-1,0,1):keep|=np.roll(np.roll(core,dy,0),dx,1)
    a[~keep]=0;src=Image.fromarray(a)
    ref=anims['idle_north'][0][0];axis,width=hair_axis(ref)
    before=[Image.open(SOURCES/f'player-north-run-repair/before-{i:02d}.png').convert('RGBA') for i in range(8)]
    _,source_width=hair_axis(src);scale=width/source_width
    box=bounds(src);crop=src.crop((box[0]-2,box[1]-2,box[2]+2,box[3]+2))
    resized=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
    landing=Image.new('RGBA',(192,192));landing.alpha_composite(resized,(round(axis-hair_axis(resized)[0]),round(bounds(before[4])[3]-bounds(resized)[3])))
    landing,_=match_materials(landing,ref);landing=match_extras(landing,before[4])
    frames=[];shifts=[]
    for i,old in enumerate(before):
        im=landing if i==3 else old;dx=round(axis-hair_axis(im)[0]);out=Image.new('RGBA',(192,192));out.alpha_composite(im,(dx,0))
        frames.append(out);shifts.append(dx)
    (DEST/'frames').mkdir(exist_ok=True);strip=Image.new('RGBA',(1536,192))
    for i,f in enumerate(frames):f.save(DEST/'frames'/f'{i:02d}.png');strip.alpha_composite(f,(192*i,0))
    strip.save(DEST/'candidate-run-north.png')
    c=Image.new('RGB',(1728,230),(43,48,55));draw=ImageDraw.Draw(c);c.paste(ref,(0,20),ref);draw.text((4,2),'IDLE reference',fill='white')
    for i,f in enumerate(frames):c.paste(f,((i+1)*192,20),f);draw.text(((i+1)*192+4,2),str(i+1),fill='white')
    c.save(DEST/'after-all-frames.png')
    timing=export_motion_gifs(frames,before)
    record={'horizontal_registration':shifts,'landing_scale':scale,'head_axes':[hair_axis(f)[0] for f in frames],
            'head_widths':[hair_axis(f)[1] for f in frames],'stats':[stats(f) for f in frames],
            'unique_frames':len(set(hashlib.sha256(f.tobytes()).hexdigest() for f in frames)),'game_cycle_ms':sum(timing),'installed':False}
    (DEST/'repair-checks.json').write_text(json.dumps(record,indent=2));print(json.dumps(record,indent=2))
if __name__=='__main__':
    if '--refresh-previews' in sys.argv:
        fs=[Image.open(DEST/'frames'/f'{i:02d}.png').convert('RGBA') for i in range(8)]
        old=[Image.open(SOURCES/f'player-north-run-repair/before-{i:02d}.png').convert('RGBA') for i in range(8)]
        timing=export_motion_gifs(fs,old)
        record=json.loads((DEST/'repair-checks.json').read_text());record['game_cycle_ms']=sum(timing)
        (DEST/'repair-checks.json').write_text(json.dumps(record,indent=2))
        if record.get('installed'):
            film=[]
            for f in fs:
                c=Image.new('RGB',(192,192),(43,48,55));c.paste(f,(0,0),f);film.append(c.resize((384,384),Image.Resampling.NEAREST))
            film[0].save(palette.DEST/'gifs/run-north.gif',save_all=True,append_images=film[1:],duration=timing,loop=0,optimize=False)
            with zipfile.ZipFile(palette.DEST/'review-gifs.zip','w',zipfile.ZIP_DEFLATED) as z:
                for p in (palette.DEST/'gifs').glob('*.gif'):z.write(p,p.name)
                z.write(DEST/'game-speed.gif','north-run-game-speed-before-after.gif')
                z.write(DEST/'slow-review.gif','north-run-slow-before-after.gif')
        print('Refreshed GIFs from scene speed. Cycle ms:',sum(timing))
    else:build()
