"""Prepare immutable pose sheets for image-generation editing, without runtime recoloring."""
from player_preview import *
DEST=ROOT/'output/player-black-hair-sprites'
DEST.mkdir(exist_ok=True)
directions=['east','south_east','south','north_east','north']
actions=['idle','walk','run','carry_idle','carry_walk','jump','lift','place','touch','operate']
manifest={}
for action in actions:
    n=len(anims[action+'_south'][0])
    canvas=Image.new('RGBA',(n*192,5*192))
    for row,d in enumerate(directions):
        for col,im in enumerate(anims[action+'_'+d][0]):
            canvas.alpha_composite(im,(col*192,row*192))
    canvas.save(DEST/(action+'-original.png'))
    manifest[action]={'frames':n,'input':str(DEST/(action+'-original.png'))}
(DEST/'inputs.json').write_text(json.dumps(manifest,indent=2))
print('Prepared ten exact-pose sprite sheets; idle/walk skin reference remains unmodified.')
