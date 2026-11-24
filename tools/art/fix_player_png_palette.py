"""Bake idle-matched material palettes into PNGs; no runtime changes.

User authorized direct PNG color/scale edits. Geometry is preserved except for
uniformly shrinking diagonal walks and installing the separately generated north run.
"""
from player_preview import *
from build_player_actions_v2 import collar
from measure_current_player import bounds,stats
from collections import deque
import hashlib,shutil,zipfile,math

DEST=ROOT/'output/player-palette-size-fix'
FROZEN=SOURCES/'player-palette-size-fix'
ACTIONS=['walk','run','carry_idle','carry_walk','jump','lift','place','touch','operate']
TARGET=ROOT/'assets/characters/cast/explorer/Animation Sprites Player/Animation Sprites Player/black_hair_generated'

def biggest(mask):
    seen=np.zeros(mask.shape,bool);best=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]:continue
        q=deque([(int(y),int(x))]);seen[y,x]=True;part=[]
        while q:
            yy,xx=q.popleft();part.append((yy,xx))
            for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
                ny,nx=yy+dy,xx+dx
                if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;q.append((ny,nx))
        if len(part)>len(best):best=part
    out=np.zeros(mask.shape,bool)
    for y,x in best:out[y,x]=True
    return out

def materials(im):
    a=np.array(im);rgb=a[:,:,:3].astype(float);r,g,b=rgb.transpose(2,0,1);valid=a[:,:,3]>0
    neck=collar(im)
    # Include warm/brown highlight tufts, while excluding dark facial skin.
    # The upper scalp is unambiguously hair, including unusually bright tips.
    top=bounds(im)[1];upper=np.indices(a.shape[:2])[0]<(top+(neck-top)*.55)
    skin_shadow=(r>120)&(g>65)&(b>r*.4)&(r-g>15)&(g-b>10)&((r-g)>(g-b)*.85)
    dark=valid&(((rgb.max(axis=2)<170)&((rgb.max(axis=2)-rgb.min(axis=2))<95)&~skin_shadow)|(upper&(rgb.max(axis=2)<200)))
    gold=(r-b>40)&((g-b)>(r-g)*1.7)
    dark&=(~gold|upper)
    dark[neck+1:]=False
    # Thin highlight tips can be disconnected from the main dark mass by bright
    # antialias pixels; they are still hair in the upper scalp area.
    hair=biggest(dark)|(dark&upper)
    skin=valid&(r>145)&(g>90)&(b>r*.43)&(r<g*1.7)&(r-g>20)&(g-b>12)&((r-g)>(g-b)*.85)
    skin&=~hair
    shirt=valid&(r>35)&(r<165)&(g>30)&(g<160)&(r<g*1.26)&(r>g*.85)&(g>b*1.3)&(g<b*2.25)
    shirt[:neck+2]=False;shirt&=~(hair|skin)
    return {'hair':hair,'skin':skin,'shirt':shirt}

def luminance(rgb):return rgb@np.array([.2126,.7152,.0722])

def match_materials(im,ref):
    a=np.array(im);out=a.copy();ra=np.array(ref);sm=materials(im);rm=materials(ref);record={}
    for name in ['hair','skin','shirt']:
        opaque=sm[name]&(a[:,:,3]>230);target=rm[name]&(ra[:,:,3]>230)
        source=a[opaque,:3];reference=ra[target,:3]
        if name=='hair':
            # Ear/scarf boundary antialias pixels are warm, not hair paint.
            # Use only the actual neutral black ramp from idle as the palette.
            neutral=(reference.max(axis=1).astype(int)-reference.min(axis=1).astype(int))<18
            reference=reference[neutral]
        if len(source)<8 or len(reference)<8:continue
        sl=luminance(source);rl=luminance(reference)
        values,counts=np.unique(sl,return_counts=True)
        ranks=(np.cumsum(counts)-counts*.5)/counts.sum()
        ordered=reference[np.argsort(rl,kind='stable')]
        quantiles=np.interp(luminance(a[sm[name],:3]),values,ranks)
        indices=np.clip(np.rint(quantiles*(len(ordered)-1)).astype(int),0,len(ordered)-1)
        out[sm[name],:3]=ordered[indices]
        before=np.percentile(source,[15,50,85],axis=0)
        after=np.percentile(out[opaque,:3],[15,50,85],axis=0)
        desired=np.percentile(reference,[15,50,85],axis=0)
        record[name]={'before':before.tolist(),'after':after.tolist(),'idle':desired.tolist(),'max_quantile_error':float(abs(after-desired).max()),'pixels':int(opaque.sum())}
    assert np.array_equal(out[:,:,3],a[:,:,3]),'Palette edit changed alpha'
    return Image.fromarray(out),record

def scale_walk(frames,factor):
    ground=float(np.median([bounds(f)[3] for f in frames]));result=[]
    for im in frames:
        scaled=im.resize((round(192*factor),round(192*factor)),Image.Resampling.LANCZOS)
        c=Image.new('RGBA',(192,192));c.alpha_composite(scaled,(round(96*(1-factor)),round(ground*(1-factor))));result.append(c)
    return result

def north_run():
    repaired=SOURCES/'player-north-run-repair/approved-run-north.png'
    if repaired.exists():
        strip=Image.open(repaired).convert('RGBA')
        return [strip.crop((i*192,0,(i+1)*192,192)) for i in range(8)],0
    source=ROOT/'output/player-walking-material-fix/north-run-frames'
    fs=[Image.open(source/f'{i:02d}.png').convert('RGBA') for i in range(8)]
    ref=anims['idle_north'][0][0]
    def center(im):
        mask=materials(im)['hair']&(np.array(im)[:,:,3]>230);y,x=np.where(mask);return (x.min()+x.max())/2
    shift=round(center(ref)-float(np.median([center(f) for f in fs])))
    result=[]
    for im in fs:
        # Remove generated, detached low-alpha specks; keep a one-pixel antialias edge.
        a=np.array(im);core=biggest(a[:,:,3]>200);keep=core.copy()
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                moved=np.roll(np.roll(core,dy,axis=0),dx,axis=1);keep|=moved
        a[~keep]=0;im=Image.fromarray(a)
        c=Image.new('RGBA',(192,192));c.alpha_composite(im,(shift,0));result.append(c)
    return result,shift

def preview(clips,actions=None,directions=None):
    selected=ACTIONS if actions is None else actions
    selected_directions=DIRS if directions is None else directions
    (DEST/'gifs').mkdir(exist_ok=True);(DEST/'review').mkdir(exist_ok=True)
    for action in selected:
        n=len(clips[action+'_east']);film=[]
        for i in range(n):
            c=Image.new('RGB',(768,428),(43,48,55));draw=ImageDraw.Draw(c)
            for j,d in enumerate(DIRS):
                f=clips[action+'_'+d][i];x=(j%4)*192;y=(j//4)*214
                c.paste(f,(x,y+20),f);draw.text((x+4,y+3),d,fill='white')
            film.append(c)
        film[0].save(DEST/'gifs'/f'{action}.gif',save_all=True,append_images=film[1:],duration=90 if action=='run' else 150,loop=0,optimize=False)
    for d in selected_directions:
        c=Image.new('RGB',(1728,2050),(43,48,55));draw=ImageDraw.Draw(c)
        for row,action in enumerate(['idle']+ACTIONS):
            fs=anims['idle_'+d][0] if action=='idle' else clips[action+'_'+d]
            for col,f in enumerate([anims['idle_'+d][0][0]]+fs):
                x=col*192;y=row*205;c.paste(f,(x,y+13),f)
                draw.text((x+4,y),('IDLE reference' if col==0 else action+' '+str(col)),fill='white')
        c.save(DEST/'review'/f'{d}-all-frames.png')
    for action in ['walk','run']:
        if action not in selected:continue
        film=[]
        for tick in range(128):
            angle=tick/128*math.tau;direction=DIRS[int(math.floor((angle+math.pi/8)/(math.pi/4)))%8]
            fs=clips[action+'_'+direction];f=fs[(tick//2)%len(fs)]
            c=Image.new('RGB',(640,512),(43,48,55));draw=ImageDraw.Draw(c)
            draw.text((12,10),action+' / circular direction changes / idle reference at left',fill='white')
            draw.ellipse((290,190,510,410),outline=(90,95,100),width=1)
            px=round(400+110*math.sin(angle));py=round(300-110*math.cos(angle))
            c.paste(f,(px-96,py-161),f)
            ref=anims['idle_'+direction][0][0];c.paste(ref,(4,125),ref)
            draw.text((20,335),'idle '+direction,fill='white');draw.text((20,355),'same display scale',fill=(180,185,190))
            film.append(c)
        film[0].save(DEST/'gifs'/f'{action}-circle.gif',save_all=True,append_images=film[1:],duration=65,loop=0,optimize=False)
    if 'run' not in selected:return
    fs=clips['run_north'];film=[]
    for f in fs:
        c=Image.new('RGB',(192,192),(43,48,55));c.paste(f,(0,0),f);film.append(c.resize((384,384),Image.Resampling.NEAREST))
    film[0].save(DEST/'gifs'/'run-north.gif',save_all=True,append_images=film[1:],duration=90,loop=0,optimize=False)

def protected_files():
    names=['assets/characters/cast/explorer/frames.tres','Actors/Player/campaign_player.gd','assets/shaders/world/player_idle_breath.gdshader']
    names += [(TARGET/f'idle_{d}.png').relative_to(ROOT).as_posix() for d in DIRS]
    return {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in names}

def freeze_sources():
    folder=FROZEN/'source-originals';folder.mkdir(exist_ok=True)
    for name in anims:
        path=folder/f'{name}.png'
        if not path.exists():shutil.copy2(TARGET/path.name,path)
        strip=Image.open(path).convert('RGBA');n=len(anims[name][0])
        anims[name]=([strip.crop((i*192,0,(i+1)*192,192)) for i in range(n)],anims[name][1])
    record=FROZEN/'protected-files.json'
    if not record.exists():record.write_text(json.dumps(protected_files(),indent=2))

def install_staged():
    expected=json.loads((FROZEN/'protected-files.json').read_text())
    assert protected_files()==expected,'Protected idle/controller/shader/resource changed; inspect before installing'
    paths=list((DEST/'strips').glob('*.png'));assert len(paths)==72
    backup=DEST/'before-install';backup.mkdir(exist_ok=True)
    for path in paths:
        active=TARGET/path.name
        if not (backup/path.name).exists():shutil.copy2(active,backup/path.name)
        shutil.copy2(path,active)
    assert protected_files()==expected,'A protected file changed'
    checks=json.loads((DEST/'checks.json').read_text());checks['installed']=True
    checks['installed_sha256']={p.name:hashlib.sha256((TARGET/p.name).read_bytes()).hexdigest() for p in paths}
    (DEST/'checks.json').write_text(json.dumps(checks,indent=2))
    print('Installed 72 PNG strips. Idle, SpriteFrames, controller and shader byte-identical. Backups:',backup)

def build(install=False):
    DEST.mkdir(exist_ok=True);freeze_sources();clips={};report={};north,shift=north_run()
    cardinal=[stats(f)['height'] for d in ['east','south','west','north'] for f in anims['walk_'+d][0]]
    targetheight=float(np.median(cardinal));idlehash={d:hashlib.sha256((TARGET/f'idle_{d}.png').read_bytes()).hexdigest() for d in DIRS}
    for action in ACTIONS:
        for d in DIRS:
            name=action+'_'+d;original=anims[name][0];fs=original;factor=1.0
            if action=='walk' and '_' in d:
                factor=targetheight/float(np.median([stats(f)['height'] for f in original]));fs=scale_walk(original,factor)
            if name=='run_north':fs=north
            ref=anims['idle_'+d][0][0];result=[];rows=[]
            for i,im in enumerate(fs):
                corrected,materials_report=match_materials(im,ref)
                unchanged_geometry=np.array_equal(np.array(corrected)[:,:,3],np.array(original[i])[:,:,3])
                if factor==1 and name!='run_north':assert unchanged_geometry,name
                result.append(corrected);rows.append({'frame':i,'materials':materials_report,'geometry_unchanged':unchanged_geometry,'stats':stats(corrected)})
            clips[name]=result;report[name]={'uniform_scale':factor,'frames':rows}
    (DEST/'strips').mkdir(exist_ok=True);(DEST/'frames').mkdir(exist_ok=True)
    for name,fs in clips.items():
        folder=DEST/'frames'/name;folder.mkdir(exist_ok=True);strip=Image.new('RGBA',(192*len(fs),192))
        for i,f in enumerate(fs):f.save(folder/f'{i:02d}.png');strip.alpha_composite(f,(192*i,0))
        strip.save(DEST/'strips'/f'{name}.png')
    preview(clips)
    checks={'clips':len(clips),'frames':sum(map(len,clips.values())),'idle_sha256':idlehash,'diagonal_target_height':targetheight,'north_run_registration_shift':shift,'animations':report,'installed':install}
    (DEST/'checks.json').write_text(json.dumps(checks,indent=2))
    with zipfile.ZipFile(DEST/'review-gifs.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in (DEST/'gifs').glob('*.gif'):z.write(p,p.name)
    if install:
        backup=DEST/'before-install';backup.mkdir(exist_ok=True)
        for name in clips:
            active=TARGET/f'{name}.png'
            if not (backup/active.name).exists():shutil.copy2(active,backup/active.name)
            shutil.copy2(DEST/'strips'/active.name,active)
        assert all(hashlib.sha256((TARGET/f'idle_{d}.png').read_bytes()).hexdigest()==idlehash[d] for d in DIRS)
    for d in DIRS:
        rows=report['walk_'+d]['frames'];print('walk_'+d,'scale',round(report['walk_'+d]['uniform_scale'],4),'height',[r['stats']['height'] for r in rows],'hair',[r['materials'].get('hair',{}).get('after',[[],[],[]])[1] for r in rows])
    print('Prepared',len(clips),'clips /',sum(map(len,clips.values())),'frames. Installed:',install)
if __name__=='__main__':
    if '--install-staged' in sys.argv:install_staged()
    else:build('--install' in sys.argv)
