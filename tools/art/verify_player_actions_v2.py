from build_player_actions_v2 import *
import zipfile
current=(ROOT/'assets/characters/cast/explorer/frames.tres').read_text()
old=(SOURCES/OUT.name/'before-install/frames.tres').read_text()
def references(text):
    return {m[3]:m[0] for m in re.finditer(pattern,text,re.S) if m[3].startswith(('idle_','walk_'))}
assert references(current)==references(old)
ids=re.findall(r'\[(?:ext_resource|sub_resource)[^\n]*id="([^"]+)"',current)
assert len(ids)==len(set(ids))
gifs=list((DEST/'gifs').glob('*.gif'))
assert len(gifs)==8
for gif in gifs:
    image=Image.open(gif)
    assert image.n_frames==(8 if gif.stem=='run' else 6)
with zipfile.ZipFile(DEST/'corrected-action-gifs.zip','w',zipfile.ZIP_DEFLATED) as z:
    for gif in gifs:z.write(gif,gif.name)
print('PASS: all 16 original idle/walk definitions identical; unique resource IDs; all eight GIFs readable and packaged.')
