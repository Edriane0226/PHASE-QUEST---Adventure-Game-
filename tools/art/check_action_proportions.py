"""Regression checks against engine-resolved idle/walk, including real action poses."""
from player_preview import *
errors=[]
for d in DIRS:
    ref=anims['idle_'+d][0][0].getbbox(); expected=ref[3]-ref[1]
    for action in ['carry_idle','touch','operate']:
        for i,im in enumerate(anims[action+'_'+d][0]):
            box=im.getbbox(); height=box[3]-box[1]
            if abs(height-expected)>2: errors.append(f'{action}_{d}[{i}]: height {height}, idle {expected}')
            if abs(box[3]-ref[3])>2: errors.append(f'{action}_{d}[{i}]: baseline {box[3]}, idle {ref[3]}')
    if len(anims['run_'+d][0])<8: errors.append('run_'+d+': fewer than 8 poses')
print('\n'.join(errors[:15]))
print('FAIL' if errors else 'PASS',len(errors),'proportion/baseline/frame-count violations')
sys.exit(bool(errors))
