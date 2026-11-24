from fix_player_png_palette import *
DEST=ROOT/'output/player-north-run-repair';DEST.mkdir(exist_ok=True)
fs=anims['run_north'][0];ref=anims['idle_north'][0][0]
c=Image.new('RGB',(9*192,230),(43,48,55));draw=ImageDraw.Draw(c);c.paste(ref,(0,20),ref)
for i,f in enumerate(fs):
    f.save(SOURCES/f'player-north-run-repair/before-{i:02d}.png');a=np.array(f);m=materials(f);neck=collar(f)
    yy,xx=np.where(m['hair']&(a[:,:,3]>230));cx=(xx.min()+xx.max())/2;cy=yy.min()
    ys,xs=np.indices(a.shape[:2]);r,g,b=a[:,:,:3].astype(float).transpose(2,0,1)
    boots=(a[:,:,3]>230)&(r>g*1.25)&(g>b*1.15)&(r>65)&(r<190)&(ys>neck+22)
    skin=m['skin']&(a[:,:,3]>230)&(ys>neck+2)
    score=float(ys[boots&(xs<cx-2)].mean()-ys[boots&(xs>cx+2)].mean())
    arms=int((skin&(xs<cx)).sum()-(skin&(xs>cx)).sum())
    print(i+1,'head',cx,int(cy),'ground',bounds(f)[3],'leg_delta',round(score,2),'arm_delta',arms)
    c.paste(f,((i+1)*192,20),f);draw.text(((i+1)*192+4,2),str(i+1),fill='white')
c.save(DEST/'before-all-frames.png')
print('Exported active north-run frames for a one-pose repair.')
