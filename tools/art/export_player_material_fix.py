"""Export generated artwork uniformly per clip; never recolor or deform body parts."""
from player_preview import *
from measure_current_player import bounds,stats
import shutil,zipfile
DEST=ROOT/'output/player-walking-material-fix';DEST.mkdir(exist_ok=True)
ROWS=['east','south_east','south','north_east','north']
def build():
    manifest=json.loads((SOURCES/'player-walking-material-fix/generation.json').read_text());clips={};report={}
    for action,info in manifest.items():
        src=Image.open(info['source']).convert('RGBA');n=info.get('frames',len(anims[action+'_east'][0]))
        (DEST/'sources').mkdir(exist_ok=True);shutil.copy2(info['source'],DEST/'sources'/f'{action}.png')
        for row,direction in enumerate(ROWS):
            tiles=[]
            for i in range(n):
                tile=src.crop((round(i*src.width/n),round(row*src.height/5),round((i+1)*src.width/n),round((row+1)*src.height/5)))
                tiles.append(tile)
            old=anims[action+'_'+direction][0];boxes=[bounds(t) for t in tiles]
            if action=='walk':
                target=float(np.median([stats(f)['height'] for f in old])) if direction in ['east','south','north'] else 128.0
                scale=target/float(np.median([b[3]-b[1] for b in boxes]))
            else:
                scale=stats(anims['idle_'+direction][0][0])['hair_width']/float(np.median([stats(t)['hair_width'] for t in tiles]))
            ground=float(np.median([b[3] for b in boxes]));targetground=float(np.median([bounds(f)[3] for f in old]))
            frames=[]
            for i,tile in enumerate(tiles):
                pose=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
                frame=Image.new('RGBA',(192,192));frame.alpha_composite(pose,(round(96-pose.width/2),round(targetground-ground*scale)))
                frames.append(frame)
            name=action+'_'+direction;clips[name]=frames
            report[name]={'scale':scale,'frames':[stats(f) for f in frames]}
            mirror={'east':'west','south_east':'south_west','north_east':'north_west'}.get(direction)
            if mirror:
                clips[action+'_'+mirror]=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
                report[action+'_'+mirror]={'scale':scale,'frames':[stats(f) for f in clips[action+'_'+mirror]]}
    for name,frames in clips.items():
        folder=DEST/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
        strip=Image.new('RGBA',(192*len(frames),192))
        for i,f in enumerate(frames):f.save(folder/f'{i:02d}.png');strip.alpha_composite(f,(192*i,0))
        (DEST/'strips').mkdir(exist_ok=True);strip.save(DEST/'strips'/f'{name}.png')
    (DEST/'checks.json').write_text(json.dumps(report,indent=2))
    for action in manifest:
        n=len(clips[action+'_east']);film=[]
        for i in range(n):
            c=Image.new('RGB',(4*192,2*214),(43,48,55));draw=ImageDraw.Draw(c)
            for j,d in enumerate(DIRS):
                f=clips[action+'_'+d][i];x=(j%4)*192;y=(j//4)*214
                draw.text((x+4,y+3),d,fill='white');c.paste(f,(x,y+20),f)
            film.append(c)
        film[0].save(DEST/f'{action}-all-directions.gif',save_all=True,append_images=film[1:],duration=120 if action=='walk' else 90,loop=0,optimize=False)
        for d in ROWS:
            fs=clips[action+'_'+d];c=Image.new('RGB',((len(fs)+1)*192,214),(43,48,55));draw=ImageDraw.Draw(c)
            ref=anims['idle_'+d][0][0];c.paste(ref,(0,20),ref);draw.text((4,3),'IDLE reference',fill='white')
            for i,f in enumerate(fs):c.paste(f,((i+1)*192,20),f);draw.text(((i+1)*192+4,3),str(i+1),fill='white')
            c.save(DEST/f'{action}-{d}-frames.png')
    print('Exported',len(clips),'clips; preview only.')
    for name,entry in report.items():
        if name.startswith('walk_'):print(name,'height',[s['height'] for s in entry['frames']],'hair',[s['hair_rgb'] for s in entry['frames']])
if __name__=='__main__':build()
