"""Catch frozen consecutive poses in the active north-run artwork."""
from player_preview import *
from fix_player_png_palette import materials
import hashlib
frames=anims['run_north'][0]
if '--candidate' in sys.argv:
    strip=Image.open(ROOT/'output/player-north-run-repair/candidate-run-north.png').convert('RGBA')
    frames=[strip.crop((i*192,0,(i+1)*192,192)) for i in range(8)]
hashes=[hashlib.sha256(f.tobytes()).hexdigest() for f in frames]
duplicates=[(i+1,(i+1)%len(frames)+1) for i in range(len(frames)) if hashes[i]==hashes[(i+1)%len(frames)]]
print('Consecutive duplicate north-run frames (one-based):',duplicates)
centers=[]
for frame in frames:
    a=np.array(frame);mask=materials(frame)['hair']&(a[:,:,3]>230);yy,xx=np.where(mask)
    centers.append(float((xx.min()+xx.max())/2))
span=max(centers)-min(centers)
print('Head x positions:',centers,'span:',span)
problems=[]
if duplicates:problems.append('consecutive repeated pose freezes stride')
if span>3:problems.append('whole character shifts sideways between frames')
reference=anims['idle_north'][0][0];ra=np.array(reference);rm=materials(reference)
widths=[]
for i,frame in enumerate(frames):
    a=np.array(frame);mm=materials(frame);y,x=np.where(mm['hair']&(a[:,:,3]>230));widths.append(int(x.max()-x.min()+1))
    for m in ['hair','skin','shirt']:
        sm=mm[m]&(a[:,:,3]>230);tm=rm[m]&(ra[:,:,3]>230)
        if min(sm.sum(),tm.sum())<8:continue
        err=abs(np.median(a[sm,:3],axis=0)-np.median(ra[tm,:3],axis=0)).max()
        if err>4:problems.append(f'frame {i+1} {m} palette changed by {err}')
if max(widths)-min(widths)>2:problems.append('head scale changes between frames')
assert not problems,'; '.join(problems)
print('PASS: eight distinct poses,stable horizontal registration/head scale,idle palette retained. Candidate:', '--candidate' in sys.argv)
