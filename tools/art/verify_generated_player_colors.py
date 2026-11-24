from player_preview import *
pattern=r'"frames": \[(.*?)\],\s*"loop": (\d+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)'
dest=ROOT/'output/player-black-hair-sprites'
before=(SOURCES/'player-black-hair-sprites/before-install.tres').read_text()
def timing(data):
    return {m[3]:(m[2],m[4],re.findall(r'"duration": ([\d.]+)',m[1])) for m in re.finditer(pattern,data,re.S)}
assert timing(before)==timing(text),'Animation timing changed'
assert len(anims)==80
total=0
for name,(frames,_) in anims.items():
    for im in frames:
        assert im.size==(192,192) and im.getbbox(),name
        total+=1
    block=next(m[1] for m in re.finditer(pattern,text,re.S) if m[3]==name)
    assert all(s.startswith('black_hair_') for s in re.findall(r'SubResource\("([^"]+)"\)',block))
shader=(ROOT/'assets/shaders/world/player_idle_breath.gdshader').read_text()
controller=(ROOT/'Actors/Player/campaign_player.gd').read_text()
assert 'hair_cutoff' not in text+shader+controller
assert 'COLOR.rgb' not in shader
assert 'source.rgb' not in shader
print('PASS:',len(anims),'clips /',total,'visible PNG frames; timing retained; all active sprite refs use generated art; no runtime hair/skin recoloring.')
