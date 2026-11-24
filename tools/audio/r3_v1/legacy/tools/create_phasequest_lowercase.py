"""Add true lowercase forms to the supplied ARCO-derived font; preserve original file."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.reverseContourPen import ReverseContourPen

root=Path(__file__).resolve().parents[1]
f=TTFont(root/'Assets/Font/Phasequestfont.otf')
gs=f.getGlyphSet(); cmap=f.getBestCmap(); metrics=f['hmtx'].metrics
original_metrics=dict(metrics)

def copy(p,char,sx=.70,sy=.70,dx=0,dy=0):
    gs[cmap[ord(char)]].draw(TransformPen(p,(sx,0,0,sy,dx,dy)))

def rounded(p,x,y,w,h,r=90):
    p=ReverseContourPen(p)
    r=min(r,w/2,h/2)
    p.moveTo((x+r,y));p.lineTo((x+w-r,y));p.qCurveTo((x+w,y),(x+w,y+r))
    p.lineTo((x+w,y+h-r));p.qCurveTo((x+w,y+h),(x+w-r,y+h))
    p.lineTo((x+r,y+h));p.qCurveTo((x,y+h),(x,y+h-r))
    p.lineTo((x,y+r));p.qCurveTo((x,y),(x+r,y));p.closePath()

def stroke(p,points,width=250):
    # Rounded capsule segments form the thick, soft joins used by the source face.
    import math
    for (ax,ay),(bx,by) in zip(points,points[1:]):
        dx=bx-ax;dy=by-ay;length=math.hypot(dx,dy);nx=-dy/length*width/2;ny=dx/length*width/2
        p.moveTo((ax+nx,ay+ny));p.lineTo((bx+nx,by+ny));p.lineTo((bx-nx,by-ny));p.lineTo((ax-nx,ay-ny));p.closePath()
    for x,y in points: rounded(p,x-width/2,y-width/2,width,width,width/2)

def arch(p,x=0,height=1060,width=1020):
    p.moveTo((x,0));p.lineTo((x,1040));p.qCurveTo((x,1100),(x+80,1100));p.lineTo((x+210,1100));p.lineTo((x+250,960))
    p.qCurveTo((x+440,1160),(x+680,1090));p.qCurveTo((x+width,1030),(x+width,690))
    p.lineTo((x+width,0));p.lineTo((x+width-280,0));p.lineTo((x+width-280,670))
    p.qCurveTo((x+width-280,860),(x+510,860));p.qCurveTo((x+280,860),(x+280,660))
    p.lineTo((x+280,0));p.closePath()

for char in 'abcdefghijklmnopqrstuvwxyz':
    p=TTGlyphPen(gs);advance=1220
    if char in 'cosuvwxz':
        copy(p,char.upper());advance=round(original_metrics[cmap[ord(char.upper())]][0]*.70)
    elif char in 'abdgpq':
        copy(p,'O',.66,.70,100,0)
        if char=='a': rounded(p,920,0,270,1080)
        if char=='b': rounded(p,40,0,285,1510)
        if char=='d': rounded(p,940,0,285,1510)
        if char=='p': rounded(p,40,-390,285,1450)
        if char=='q': rounded(p,940,-390,285,1450)
        if char=='g':
            rounded(p,950,-260,270,1320)
            stroke(p,[(1085,-220),(960,-360),(580,-360)],220)
        advance=1320
    elif char=='e':
        copy(p,'C',.76,.70)
        rounded(p,250,480,690,230,70);advance=1090
    elif char=='h':
        arch(p);rounded(p,0,0,280,1510);advance=1130
    elif char=='n': arch(p);advance=1130
    elif char=='m': arch(p,0,width=900);arch(p,650,width=900);advance=1680
    elif char=='r':
        rounded(p,20,0,290,1080)
        stroke(p,[(190,760),(430,960),(690,930)],250);advance=850
    elif char=='f':
        stroke(p,[(300,90),(300,1170),(420,1370),(690,1370)],270)
        rounded(p,60,800,720,240);advance=880
    elif char=='t':
        stroke(p,[(330,1360),(330,290),(450,140),(700,140)],270)
        rounded(p,60,820,730,240);advance=900
    elif char=='i':
        rounded(p,90,0,290,1070);rounded(p,90,1250,290,290,135);advance=560
    elif char=='j':
        rounded(p,310,-180,290,1250);rounded(p,310,1250,290,290,135)
        stroke(p,[(455,-160),(320,-340),(100,-340)],240);advance=750
    elif char=='k':
        rounded(p,30,0,290,1510);stroke(p,[(220,440),(860,1010)],260);stroke(p,[(480,640),(900,120)],270);advance=1080
    elif char=='l':
        stroke(p,[(210,1390),(210,220),(330,120),(510,120)],280);advance=710
    elif char=='y':
        stroke(p,[(150,960),(480,260),(850,960)],270)
        stroke(p,[(700,600),(420,-310),(150,-360)],250);advance=1100
    name=cmap[ord(char)]
    f['glyf'][name]=p.glyph();metrics[name]=(advance,0)

for rec in f['name'].names:
    replacements={1:'Phase Quest UI',2:'Regular',3:'PhaseQuestUI-Regular-1.0',4:'Phase Quest UI Regular',6:'PhaseQuestUI-Regular',16:'Phase Quest UI',17:'Regular'}
    if rec.nameID in replacements:
        rec.string=replacements[rec.nameID].encode(rec.getEncoding(),errors='replace')
f['OS/2'].sxHeight=1080
f['OS/2'].usWinDescent=max(f['OS/2'].usWinDescent,430)
f.save(root/'Assets/Font/PhasequestUI.ttf')
(root/'Assets/Font/PhasequestUI-NOTES.txt').write_text('Phase Quest UI: companion derived from supplied Phasequestfont.otf (ARCO Regular). Original capitals, digits, punctuation and symbols retained; 26 lowercase outlines newly authored for this game. Original font remains unchanged. Original attribution: Rafael Olivo Diaz and Denis Ignatov, 2019. Source font declares SIL Open Font License; derivative renamed Phase Quest UI. This derivative is distributed under the SIL Open Font License 1.1. See original font embedded name/license metadata. Regenerate with tools/create_phasequest_lowercase.py and FontTools.\n',encoding='utf-8')
print('Created PhasequestUI.ttf with 26 true lowercase outlines.')
