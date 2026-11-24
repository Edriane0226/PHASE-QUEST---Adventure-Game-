"""Read-only material and size measurements for the current art."""
from player_preview import *
from build_player_actions_v2 import collar
def bounds(im):
    a=np.array(im); yy,xx=np.where(a[:,:,3]>220)
    return [int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
def stats(im):
    a=np.array(im); b=bounds(im);neck=collar(im)
    dark=(a[:,:,3]>230)&(a[:,:,:3].max(axis=2)<120)
    dark[neck:]=False
    yy,xx=np.where(dark)
    return dict(bounds=b,height=b[3]-b[1],head_height=neck-b[1],hair_width=int(xx.max()-xx.min()+1),hair_rgb=np.median(a[dark,:3],axis=0).tolist(),hair_p15=np.percentile(a[dark,:3],15,axis=0).tolist(),hair_p85=np.percentile(a[dark,:3],85,axis=0).tolist())
if __name__=='__main__':
    result={k:[stats(im) for im in frames] for k,(frames,_) in anims.items()}
    out=ROOT/'output/player-walking-material-fix';out.mkdir(exist_ok=True)
    (out/'before.json').write_text(json.dumps(result,indent=2))
    for d in DIRS:
        for action in ['idle','walk','run']:
            rows=result[action+'_'+d]
            print(action+'_'+d,'height',[m['height'] for m in rows],'hair width',[m['hair_width'] for m in rows],'hairRGB',rows[0]['hair_rgb'])
