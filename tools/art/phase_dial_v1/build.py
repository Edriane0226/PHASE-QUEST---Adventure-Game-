"""Original SVG dial artwork. Standard library only; no downloaded/reference pixels.
Run from repository root: python tools/art/phase_dial_v1/build.py
Text stays in Godot for sharp localization and phone-size type.
"""
from pathlib import Path
import math

OUT = Path('assets/ui/phase_dial/v1')
OUT.mkdir(parents=True, exist_ok=True)
MODES = {'thermal': (-90, '#e6a34a'), 'cryo': (90, '#80cce8'),
         'pressure': (180, '#b8a0dc'), 'vacuum': (0, '#72c5b9')}
ICONS = {
    'thermal': '<path d="M0-16 C9-7 13-1 9 8 C4 18-9 16-11 7 C-14 0-7-5-6-10 C-5-4-2-3 0-16Z"/><path d="M0-1 C6 6 4 12 0 12 C-5 11-5 6 0-1Z" fill="#25364a" stroke="none"/>',
    'cryo': '<path d="M0-15V15 M-13-7.5L13 7.5 M-13 7.5L13-7.5 M-5-11L0-7 5-11 M-5 11L0 7 5 11 M-12-1L-7-4-7-10 M12 1L7 4 7 10 M-12 1L-7 4-7 10 M12-1L7-4 7-10" fill="none"/>',
    'pressure': '<path d="M-18-10V10 M18-10V10 M-15 0H-5 L-10-5 M-5 0L-10 5 M15 0H5 L10-5 M5 0L10 5 M0-8V8" fill="none"/>',
    'vacuum': '<path d="M-2 1C-7-5 3-10 8-4 C17 8-5 21-15 6 C-23-9-5-23 11-14 M11-14L4-14 M11-14L10-7 M-15 6L-15 14 M-15 6L-7 7" fill="none"/>',
}

def svg(body):
    return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'+body+'</svg>\n'

def point(angle, radius):
    a = math.radians(angle)
    return f'{128+math.cos(a)*radius:.3f},{128+math.sin(a)*radius:.3f}'

for mode, (angle, color) in MODES.items():
    path = f'M{point(angle-43,112)} A112 112 0 0 1 {point(angle+43,112)} L{point(angle+43,34)} A34 34 0 0 0 {point(angle-43,34)} Z'
    for state in ('locked', 'idle', 'hovered', 'selected'):
        fill = {'locked': '#26333d', 'idle': '#304351', 'hovered': '#56616a', 'selected': color}[state]
        stroke = '#f6e3b3' if state in ('selected', 'hovered') else '#8e7a54'
        body = f'<path d="{path}" fill="{fill}" stroke="{stroke}" stroke-width="{3 if state in ("selected", "hovered") else 1.5}"/>'
        if state == 'locked':
            body += f'<defs><pattern id="h" width="9" height="9" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><path d="M0 0V9" stroke="#b0b2a6" stroke-opacity=".1" stroke-width="2"/></pattern></defs><path d="{path}" fill="url(#h)"/>'
        if state in ('selected', 'hovered'):
            body += f'<path d="M{point(angle-39,106)} A106 106 0 0 1 {point(angle+39,106)}" fill="none" stroke="#fff0c8" stroke-width="2"/>'
            body += f'<g transform="translate({point(angle,116).replace(",", " ")}) rotate({angle})"><path d="M-5-4L0 0-5 4" fill="none" stroke="#fff0c8" stroke-width="2"/></g>'
        OUT.joinpath(f'{mode}_{state}.svg').write_text(svg(body), encoding='utf-8')
    # Transparent icon, rendered separately so locked/selected contrast stays legible.
    OUT.joinpath(f'{mode}_icon.svg').write_text(svg('<g transform="translate(128 128)" fill="#fff1cb" stroke="#fff1cb" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'+ICONS[mode]+'</g>'), encoding='utf-8')

OUT.joinpath('frame.svg').write_text(svg('''<defs><linearGradient id="brass" x2=".3" y2="1"><stop stop-color="#f1dfaa"/><stop offset=".4" stop-color="#b79a61"/><stop offset=".65" stop-color="#776145"/><stop offset="1" stop-color="#d8bb7e"/></linearGradient></defs>
<circle cx="128" cy="131" r="124" fill="#101e2c" fill-opacity=".65"/>
<circle cx="128" cy="128" r="120" fill="#182b3a" stroke="#101e2c" stroke-width="9"/>
<circle cx="128" cy="128" r="120" fill="none" stroke="url(#brass)" stroke-width="6"/>
<circle cx="128" cy="128" r="115" fill="none" stroke="#eedba3" stroke-width="1"/>
<g fill="#d6bc81" stroke="#453f35" stroke-width="1"><circle cx="44" cy="44" r="3"/><circle cx="212" cy="44" r="3"/><circle cx="44" cy="212" r="3"/><circle cx="212" cy="212" r="3"/></g>'''), encoding='utf-8')
OUT.joinpath('center_glow.svg').write_text(svg('''<defs><radialGradient id="g"><stop stop-color="#fff8d0" stop-opacity=".8"/><stop offset=".48" stop-color="#f2cc76" stop-opacity=".35"/><stop offset="1" stop-color="#f2cc76" stop-opacity="0"/></radialGradient></defs><circle cx="128" cy="128" r="48" fill="url(#g)"/>'''), encoding='utf-8')
OUT.joinpath('lock.svg').write_text(svg('''<g fill="none" stroke="#e5dfcd" stroke-width="18" stroke-linecap="round"><path d="M82 111V83a46 46 0 0 1 92 0v28"/><rect x="64" y="108" width="128" height="108" rx="12" fill="#25364a"/><path d="M128 147v30"/></g>'''), encoding='utf-8')
print('Authored 23 transparent SVG assets:', OUT)
