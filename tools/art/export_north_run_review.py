"""Cut a generated north run and review its phase order; no game mutations."""
from player_preview import *
from measure_current_player import bounds,stats
import shutil
DEST=ROOT/'output/player-walking-material-fix';DEST.mkdir(exist_ok=True)
meta=json.loads((SOURCES/'player-walking-material-fix/north-run-generation.json').read_text())
src=Image.open(meta['source']).convert('RGBA');shutil.copy2(meta['source'],DEST/'north-run-generated-sheet.png')
tiles=[src.crop((round(c*src.width/4),round(r*src.height/2),round((c+1)*src.width/4),round((r+1)*src.height/2))) for r in range(2) for c in range(4)]
# Source cell4 repeats left support instead of right landing; discard that cell.
# Landing and support share the next authored key pose, a deliberate two-frame hold.
order=[0,1,2,4,4,5,6,7]
ref=anims['idle_north'][0][0];rb=bounds(ref);boxes=[bounds(t) for t in tiles]
scale=(rb[3]-rb[1])/float(np.median([b[3]-b[1] for b in boxes]))
ground=boxes[0][3];frames=[];film=[]
folder=DEST/'north-run-frames';folder.mkdir(exist_ok=True)
for i,source_index in enumerate(order):
    tile=tiles[source_index];pose=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
    frame=Image.new('RGBA',(192,192));frame.alpha_composite(pose,(round(96-pose.width/2),round(rb[3]-ground*scale)))
    frame.save(folder/f'{i:02d}.png');frames.append(frame)
    bg=Image.new('RGB',(192,192),(43,48,55));bg.paste(frame,(0,0),frame);film.append(bg.resize((384,384),Image.Resampling.NEAREST))
film[0].save(DEST/'north-run.gif',save_all=True,append_images=film[1:],duration=90,loop=0,optimize=False)
c=Image.new('RGB',(9*192,214),(43,48,55));draw=ImageDraw.Draw(c)
c.paste(ref,(0,20),ref);draw.text((4,3),'IDLE reference',fill='white')
for i,f in enumerate(frames):c.paste(f,((i+1)*192,20),f);draw.text(((i+1)*192+4,3),f'{i+1} / source {order[i]+1}',fill='white')
c.save(DEST/'north-run-frame-review.png')
(DEST/'north-run-checks.json').write_text(json.dumps({'order':order,'scale':scale,'frames':[stats(f) for f in frames],'installed':False},indent=2))
print('North run preview exported; eight frames, seven distinct keys, landing/support hold; no game changes.')
