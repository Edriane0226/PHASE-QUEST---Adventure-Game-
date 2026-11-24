"""Install only the reviewed north-run strip and refresh affected review artifacts."""
from fix_player_png_palette import *
import fix_player_png_palette as palette
from repair_north_run_png import DEST as REPAIR,hair_axis

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
checks=json.loads((palette.DEST/'checks.json').read_text())
active=TARGET/'run_north.png';candidate=REPAIR/'candidate-run-north.png'
assert digest(active)==checks['installed_sha256']['run_north.png'],'Active north run changed since inspection'
assert protected_files()==json.loads((palette.FROZEN/'protected-files.json').read_text())
others={p.name:digest(p) for p in TARGET.glob('*.png') if p.name!='run_north.png'}
assert len(others)==79
repair=json.loads((REPAIR/'repair-checks.json').read_text());assert repair['unique_frames']==8
assert max(repair['head_axes'])-min(repair['head_axes'])<=3
strip=Image.open(candidate).convert('RGBA');assert strip.size==(1536,192)
fs=[strip.crop((i*192,0,(i+1)*192,192)) for i in range(8)]
assert len(set(hashlib.sha256(f.tobytes()).hexdigest() for f in fs))==8
if not (REPAIR/'before-run-north.png').exists():shutil.copy2(active,REPAIR/'before-run-north.png')
shutil.copy2(candidate,SOURCES/'player-north-run-repair/approved-run-north.png')
shutil.copy2(candidate,active)
shutil.copy2(candidate,palette.DEST/'strips/run_north.png')
for i,f in enumerate(fs):f.save(palette.DEST/'frames/run_north'/f'{i:02d}.png')
checks['installed_sha256']['run_north.png']=digest(active)
checks['north_run_registration_shift']=0
checks['north_run_registration_shifts']=repair['horizontal_registration']
checks['north_run_repair']={'unique_frames':8,'horizontal_span':max(repair['head_axes'])-min(repair['head_axes']),'duplicate_hold_removed':True}
ref=anims['idle_north'][0][0];ra=np.array(ref);rm=materials(ref)
for i,f in enumerate(fs):
    row=checks['animations']['run_north']['frames'][i];row['stats']=stats(f);row['geometry_unchanged']=False;a=np.array(f);mm=materials(f)
    for material in ['hair','skin','shirt']:
        sm=mm[material]&(a[:,:,3]>230);tm=rm[material]&(ra[:,:,3]>230)
        if min(sm.sum(),tm.sum())<8:continue
        after=np.percentile(a[sm,:3],[15,50,85],axis=0);desired=np.percentile(ra[tm,:3],[15,50,85],axis=0)
        record=row['materials'].setdefault(material,{})
        record.update(after=after.tolist(),idle=desired.tolist(),max_quantile_error=float(abs(after-desired).max()),pixels=int(sm.sum()))
(palette.DEST/'checks.json').write_text(json.dumps(checks,indent=2))
repair['installed']=True;repair['installed_sha256']=digest(active);repair['other_79_assets_unchanged']=others
(REPAIR/'repair-checks.json').write_text(json.dumps(repair,indent=2))
assert others=={p.name:digest(p) for p in TARGET.glob('*.png') if p.name!='run_north.png'}
assert protected_files()==json.loads((palette.FROZEN/'protected-files.json').read_text())
clips={}
for name,entry in checks['animations'].items():
    s=Image.open(palette.DEST/'strips'/f'{name}.png').convert('RGBA')
    clips[name]=[s.crop((i*192,0,(i+1)*192,192)) for i in range(len(entry['frames']))]
palette.preview(clips,actions=['run'],directions=['north'])
with zipfile.ZipFile(palette.DEST/'review-gifs.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in (palette.DEST/'gifs').glob('*.gif'):z.write(p,p.name)
    z.write(REPAIR/'game-speed.gif','north-run-game-speed-before-after.gif')
    z.write(REPAIR/'slow-review.gif','north-run-slow-before-after.gif')
readme=palette.DEST/'README.md';s=readme.read_text()
s=s.replace('Eight frames, seven distinct keys; landing/support uses a two-frame hold.','Eight distinct frames, with a generated landing/compression key replacing the\nold duplicate hold. Head alignment now varies by only one pixel across the cycle.')
readme.write_text(s)
print('Installed only run_north.png. Other79 PNG assets and protected game files unchanged. Refreshed run GIFs and north frame sheet.')
