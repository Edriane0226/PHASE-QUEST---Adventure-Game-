"""Export existing artwork as references for image generation; no asset mutations."""
from player_preview import *
DEST=ROOT/'output/player-identity-redraw'
DEST.mkdir(exist_ok=True)
ROWS=['east','south_east','south','north_east','north']
for action in ['idle','walk','run','carry_idle','carry_walk','jump','lift','place','touch','operate']:
    n=len(anims[action+'_east'][0])
    sheet=Image.new('RGBA',(n*192,5*192))
    for row,d in enumerate(ROWS):
        for col,im in enumerate(anims[action+'_'+d][0]):sheet.alpha_composite(im,(col*192,row*192))
    sheet.save(DEST/(action+'-target.png'))
print(DEST)
