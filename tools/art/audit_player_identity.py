"""Inspect every installed frame for body, face and material drift."""
from player_preview import *
from build_player_actions_v2 import collar
DEST=ROOT/'output/player-identity-audit';DEST.mkdir(exist_ok=True)
ACTIONS=['idle','walk','run','carry_idle','carry_walk','jump','lift','place','touch','operate']
def measurements(im):
    a=np.array(im);r,g,b=a[:,:,:3].astype(float).transpose(2,0,1);valid=a[:,:,3]>230
    neck=collar(im)
    skin=valid&(r>175)&(g>100)&(b>70)&(r-g>25)&(g-b>15)&(r<g*1.65)
    shirt=valid&(g>40)&(r>40)&(g>r*.82)&(r>g*.90)&(g>b*1.15)&(r<g*1.4)
    shirt[:neck]=False
    skin[neck:]=False
    sy,sx=np.where(shirt);fy,fx=np.where(skin)
    return {'neck':neck,'shirt_width':int(np.percentile(sx,95)-np.percentile(sx,5)) if len(sx) else 0,'shirt_area':int(len(sx)),'face_area':int(len(fx)),'face_width':int(np.percentile(fx,95)-np.percentile(fx,5)) if len(fx) else 0,'shirt_median':np.median(a[shirt,:3],axis=0).tolist() if len(sx) else [],'skin_median':np.median(a[skin,:3],axis=0).tolist() if len(fx) else []}
report={}
for d in DIRS:
    c=Image.new('RGB',(1728,len(ACTIONS)*205),(43,48,55));draw=ImageDraw.Draw(c)
    for row,action in enumerate(ACTIONS):
        frames=anims[action+'_'+d][0]
        report[action+'_'+d]=[measurements(im) for im in frames]
        for col,im in enumerate([anims['idle_'+d][0][0]]+frames):
            x=col*192;y=row*205+13;c.paste(im,(x,y),im)
            m=measurements(im);draw.text((x+4,row*205),('REFERENCE' if col==0 else action+' #'+str(col-1)),fill='white')
            draw.text((x+4,y+177),'shirt '+str(m['shirt_width'])+' face '+str(m['face_width']),fill=(185,195,205))
    c.save(DEST/(d+'-all-frames.png'))
(DEST/'measurements.json').write_text(json.dumps(report,indent=2))
for d in DIRS:
    for action in ['walk','run']:
        rows=report[action+'_'+d]
        print(action+'_'+d,'shirt widths',[m['shirt_width'] for m in rows],'face widths',[m['face_width'] for m in rows])
print('Inspected',sum(map(len,report.values())),'frames. Generated eight directional full-frame sheets.')
