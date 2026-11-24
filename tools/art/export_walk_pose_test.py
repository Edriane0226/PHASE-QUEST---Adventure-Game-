"""Slice generated artwork and encode review GIFs using one uniform scale."""
from player_preview import *
import shutil
DEST=ROOT/'output/player-walk-pose-test';DEST.mkdir(exist_ok=True)
meta=json.loads((SOURCES/'player-walk-pose-test/generation.json').read_text())
shutil.copy2(meta['source'],DEST/'generated-sheet.png')
src=Image.open(meta['source']).convert('RGBA')
tiles=[src.crop((round(c*src.width/4),round(r*src.height/2),round((c+1)*src.width/4),round((r+1)*src.height/2))) for r in range(2) for c in range(4)]
def visible_box(im):
    a=np.array(im);ys,xs=np.where(a[:,:,3]>200)
    return (int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
ref=anims['idle_east'][0][0];rb=visible_box(ref)
boxes=[visible_box(t) for t in tiles]
assert all(boxes),'empty cell'
scale=(rb[3]-rb[1])/float(np.median([b[3]-b[1] for b in boxes]))
ground=float(np.median([b[3] for b in boxes]))
frames=[];film=[]
(DEST/'frames').mkdir(exist_ok=True)
for i,t in enumerate(tiles):
    pose=t.resize((round(t.width*scale),round(t.height*scale)),Image.Resampling.LANCZOS)
    frame=Image.new('RGBA',(192,192))
    frame.alpha_composite(pose,(round(96-pose.width/2),round(rb[3]-ground*scale)))
    frame.save(DEST/'frames'/f'{i:02d}.png');frames.append(frame)
    c=Image.new('RGB',(192,192),(43,48,55));c.paste(frame,(0,0),frame);film.append(c)
film[0].save(DEST/'walk-east.gif',save_all=True,append_images=film[1:],duration=110,loop=0,optimize=False)
large=[c.resize((576,576),Image.Resampling.NEAREST) for c in film]
large[0].save(DEST/'walk-east-large.gif',save_all=True,append_images=large[1:],duration=110,loop=0,optimize=False)
c=Image.new('RGB',(5*192,2*214),(43,48,55));d=ImageDraw.Draw(c)
for row in range(2):
    c.paste(ref,(0,row*214+20),ref);d.text((4,row*214+2),'IDLE reference',fill='white')
    for col in range(4):
        i=row*4+col;c.paste(frames[i],((col+1)*192,row*214+20),frames[i]);d.text(((col+1)*192+4,row*214+2),f'Walk {i+1}',fill='white')
c.save(DEST/'frame-review.png')
print('Encoded eight frames with uniform scale',round(scale,4),'and fixed registration; no game assets changed.')
