from player_preview import *
import hashlib
pixels=np.concatenate([np.array(im)[np.array(im)[:,:,3]>220,:3] for k,(frames,_) in anims.items() if k.startswith(('idle_','walk_')) for im in frames])
palette=Image.fromarray(pixels.reshape(1,-1,3)).quantize(colors=240)
palcolors=set(map(tuple,np.array(palette.convert('RGB')).reshape(-1,3)))
results=[]
for folder in sorted((OUT/'frames').iterdir()):
    frames=[Image.open(f).convert('RGBA') for f in sorted(folder.glob('*.png'))]
    hashes=[hashlib.sha256(f.tobytes()).hexdigest() for f in frames]
    widths=[hairbox(f)[2]-hairbox(f)[0] for f in frames]
    foreign=sum(sum(tuple(c) not in palcolors for c in np.unique(np.array(f)[np.array(f)[:,:,3]>0,:3],axis=0)) for f in frames)
    assert all(f.size==(192,192) and f.getbbox() for f in frames)
    results.append({'clip':folder.name,'exact_duplicates':4-len(set(hashes)),'hair_widths':widths,'hair_drift_percent':round(100*(max(widths)-min(widths))/np.median(widths),2),'off_palette_colors':foreign})
gifs=list((OUT/'gifs').glob('*.gif'))
for p in gifs:
    im=Image.open(p)
    assert im.n_frames>=2
    for i in range(im.n_frames):
        im.seek(i); assert im.info['duration']>0
report={'gif_count':len(gifs),'directional_clips':len(results),'checks':results}
(OUT/'audit.json').write_text(json.dumps(report,indent=2))
print('GIFs:',len(gifs),'clips:',len(results),'exact duplicates:',sum(x['exact_duplicates'] for x in results),'off-palette colors:',sum(x['off_palette_colors'] for x in results),'maximum hair drift:',max(x['hair_drift_percent'] for x in results))
