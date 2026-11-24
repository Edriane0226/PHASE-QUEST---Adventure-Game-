"""Check exported artwork itself, including cardinal geometry and rear-run gait."""
from fix_player_png_palette import *

checks=json.loads((DEST/'checks.json').read_text())
assert checks['clips']==72 and checks['frames']==432
assert protected_files()==json.loads((FROZEN/'protected-files.json').read_text())
errors={m:[] for m in ['hair','skin','shirt']};heights={};count=0;cardinal=0
for name,entry in checks['animations'].items():
    direction=next(d for d in sorted(DIRS,key=len,reverse=True) if name.endswith('_'+d))
    ref=anims['idle_'+direction][0][0];ra=np.array(ref);rm=materials(ref)
    strip=Image.open(DEST/'strips'/f'{name}.png').convert('RGBA')
    original=Image.open(FROZEN/'source-originals'/f'{name}.png').convert('RGBA')
    assert strip.size==original.size
    n=len(entry['frames']);hs=[]
    for i in range(n):
        f=strip.crop((i*192,0,(i+1)*192,192));a=np.array(f);mm=materials(f)
        b=bounds(f);assert b[0]>1 and b[1]>1 and b[2]<191 and b[3]<191,(name,i,'clipped')
        hs.append(b[3]-b[1]);count+=1
        if name in ['walk_north','walk_south','walk_east','walk_west']:
            assert np.array_equal(a[:,:,3],np.array(original.crop((i*192,0,(i+1)*192,192)))[:,:,3]),(name,i,'geometry changed')
            cardinal+=1
        for material in errors:
            sm=mm[material]&(a[:,:,3]>230);tm=rm[material]&(ra[:,:,3]>230)
            if sm.sum()<8 or tm.sum()<8:continue
            err=abs(np.median(a[sm,:3],axis=0)-np.median(ra[tm,:3],axis=0)).max()
            errors[material].append((float(err),name,i))
    heights[name]=float(np.median(hs))
assert count==432 and cardinal==16
for d in ['south_east','south_west','north_east','north_west']:
    assert abs(heights['walk_'+d]-checks['diagonal_target_height'])<=3,(d,'oversized diagonal')
for material,rows in errors.items():
    worst=max(rows);print(material,'maximum independent median RGB error:',worst)
    assert worst[0]<=4,(material,worst)

def gait(i):
    im=Image.open(DEST/'frames/run_north'/f'{i:02d}.png').convert('RGBA');a=np.array(im);r,g,b=a[:,:,:3].astype(float).transpose(2,0,1)
    neck=collar(im);hair=materials(im)['hair']&(a[:,:,3]>230);yy,xx=np.where(hair);center=float((xx.min()+xx.max())/2)
    ys,xs=np.indices(a.shape[:2]);boots=(a[:,:,3]>230)&(r>g*1.25)&(g>b*1.15)&(r>65)&(r<190)&(ys>neck+22)
    left=boots&(xs<center-2);right=boots&(xs>center+2)
    leg_score=float(ys[left].mean()-ys[right].mean())
    skin=materials(im)['skin']&(a[:,:,3]>230)&(ys>neck+2)
    arm_score=int((skin&(xs<center)).sum()-(skin&(xs>center)).sum())
    return leg_score,arm_score
left=gait(0);right=gait(4)
print('North-run support/arm scores, opposite half cycles:',left,right)
assert left[0]>3 and right[0]<-3,'Rear run repeats the same raised heel'
assert left[1]>10 and right[1]<-10,'Rear run arms do not oppose the raised heels'
if checks['installed']:
    for name,digest in checks['installed_sha256'].items():
        assert hashlib.sha256((TARGET/name).read_bytes()).hexdigest()==digest
        assert (TARGET/name).read_bytes()==(DEST/'strips'/name).read_bytes()
print('PASS:432 frames,16 cardinal walk silhouettes unchanged,diagonals normalized,idle/protected files untouched,material palettes matched,north run alternates heels/arms. Installed:',checks['installed'])
