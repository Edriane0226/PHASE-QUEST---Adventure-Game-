"""Install the review sprites non-destructively; retain idle/walk byte-for-byte."""
from player_preview import *
import shutil, hashlib
resource=ROOT/'assets/characters/cast/explorer/frames.tres'
script=ROOT/'Actors/Player/campaign_player.gd'
backup=SOURCES/OUT.name/'before-install'
backup.mkdir(exist_ok=True)
for p in [resource,script]:
    dest=backup/p.name
    if not dest.exists(): shutil.copy2(p,dest)
original=resource.read_text()
assert 'preview_trial_' not in original, 'Already installed'
target=ROOT/'assets/characters/cast/explorer/action_preview_trial'
target.mkdir(exist_ok=True)
exts=[]; subresources=[]; replaced=[]
pattern=r'"frames": \[(.*?)\],\s*"loop": (\d+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)'
def replace(match):
    body,loop,name,speed=match.groups()
    folder=OUT/'frames'/name
    if not folder.exists(): return match[0]
    strip=Image.new('RGBA',(768,192)); references=[]
    for i in range(4):
        im=Image.open(folder/f'{i:02d}.png').convert('RGBA')
        if name.startswith('jump_'):
            # The controller supplies the full jump trajectory.
            grounded=Image.new('RGBA',im.size)
            grounded.alpha_composite(im,(0,[0,9,21,0][i])); im=grounded
        strip.alpha_composite(im,(192*i,0))
        arr=np.array(im); r,g,b=arr[:,:,:3].astype(float).transpose(2,0,1)
        bb=im.getbbox()
        skin=(arr[:,:,3]>200)&(r>175)&(g>105)&(b>65)&(r>g*1.12)&(r<g*1.65)
        skin[:int(bb[1]+(bb[3]-bb[1])*.48)]=False
        yy,xx=np.where(skin)
        palm=(round(float(np.median(xx))),round(float(np.median(yy)))) if len(xx) else (96,116)
        sid=f'preview_trial_{name}_{i}'
        subresources.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("preview_trial_{name}")\nregion = Rect2({192*i}, 0, 192, 192)\nfilter_clip = true\nmetadata/preview_registered = true\nmetadata/hand_anchor = Vector2({palm[0]}, {palm[1]})\n')
        references.append('{\n"duration": 1.0,\n"texture": SubResource("'+sid+'")\n}')
    strip.save(target/f'{name}.png')
    exts.append(f'[ext_resource type="Texture2D" path="res://assets/characters/cast/explorer/action_preview_trial/{name}.png" id="preview_trial_{name}"]\n')
    replaced.append(name)
    if name.startswith('run_'):speed='8.0'
    return '"frames": ['+', '.join(references)+'],\n"loop": '+loop+',\n"name": &"'+name+'",\n"speed": '+speed
updated=re.sub(pattern,replace,original,flags=re.S)
updated=updated.replace('[sub_resource', '\n'.join(exts)+'\n[sub_resource',1)
updated=updated.replace('[resource]', '\n'.join(subresources)+'\n[resource]',1)
assert len(replaced)==64
for name in [k for k in anims if k.startswith(('idle_','walk_'))]:
    before=next(m[0] for m in re.finditer(pattern,original,re.S) if m[3]==name)
    after=next(m[0] for m in re.finditer(pattern,updated,re.S) if m[3]==name)
    assert before==after,name
resource.write_text(updated,encoding='utf-8')
(OUT/'installation.json').write_text(json.dumps({'replaced':replaced,'backup':str(backup),'idle_walk_unchanged':True},indent=2))
print('Installed 64 action clips. All 16 idle/walk clips preserved.')
