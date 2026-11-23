"""Writes the slider knob and toggle switch grids (.txt, the source) and their PNGs: python tools/art/theme_controls.py assets/art/ui/theme/controls"""
import os, sys
from PIL import Image
D = sys.argv[1]
K = '0a1712'
KNOB = ['.KKKKKK.', 'KhyyyyeK', 'KyhyyyeK', 'KyyyyyeK', 'KyyyyyeK', 'KyyyyyeK', 'KyyyyeeK', '.KeeeeK.', '..KeeK..', '...KK...']
TRACK = ['..KKKKKKKKKKKKKK..', '.KttttttttttttttK.', 'KttttttttttttttttK', 'KttttttttttttttttK', 'KttttttttttttttttK',
         'KttttttttttttttttK', 'KttttttttttttttttK', 'KttttttttttttttttK', '.KttttttttttttttK.', '..KKKKKKKKKKKKKK..']
THUMB = ['.KKKKKK.', 'KhyyyyeK', 'KyyyyyeK', 'KyyyyyeK', 'KyyyyyeK', 'KyyyyyeK', 'KyeeeeeK', '.KKKKKK.']
GOLD = {'K': K, 'h': 'ffffff', 'y': 'feae34', 'e': 'e49927'}
GOLD_HOVER = {'K': K, 'h': 'ffffff', 'y': 'fee761', 'e': 'feae34'}
DULL = {'K': K, 'h': '4fd9ad', 'y': '1c5a41', 'e': '174a36'}
MINT = {'K': K, 'h': 'ffffff', 'y': '87ffdb', 'e': '4fd9ad'}

def switch(on, knob_pal, track):
    rows = [list(r) for r in TRACK]
    x0 = 9 if on else 1
    for y, r in enumerate(THUMB):
        for x, c in enumerate(r):
            if c != '.':
                rows[1 + y][x0 + x] = c.upper() if c in 'hye' else c
    pal = {'K': K, 't': track}
    pal.update({k.upper(): v for k, v in knob_pal.items() if k != 'K'})
    return [''.join(r) for r in rows], pal

def save(name, rows, pal, note):
    with open(os.path.join(D, name + '.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('# %s\n# Drawn from this grid (Puffe theme colours, 2026-11-23).\n' % note)
        f.write(''.join('%s = %s\n' % kv for kv in pal.items()) + '---\n' + '\n'.join(rows) + '\n')
    im = Image.new('RGBA', (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.':
                v = pal[c]
                im.putpixel((x, y), tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    im.save(os.path.join(D, name + '.png'))

save('slider_grabber', KNOB, GOLD, 'HSlider knob: a gold drake scale.')
save('slider_grabber_hover', KNOB, GOLD_HOVER, 'HSlider knob, hovered or dragged.')
save('slider_grabber_disabled', KNOB, DULL, 'HSlider knob, disabled.')
for name, on, knob, track, note in (('toggle_on', True, GOLD, '0d8f6c', 'CheckButton on: teal track, gold knob right.'),
                                    ('toggle_off', False, MINT, '1c5a41', 'CheckButton off: dark track, mint knob left.'),
                                    ('toggle_on_disabled', True, DULL, '123a2b', 'CheckButton on, disabled.'),
                                    ('toggle_off_disabled', False, DULL, '123a2b', 'CheckButton off, disabled.')):
    rows, pal = switch(on, knob, track)
    save(name, rows, pal, note)
# OptionButton arrow and PopupMenu radio marks (a gold gem for the chosen entry, an empty socket for the rest)
ARROW = ['ww...ww', 'www.www', '.wwwww.', '..www..', '...w...']
GEM = ['...KK...', '..KhyK..', '.KhyyeK.', 'KhyyyyeK', 'KyyyyeeK', '.KyyeeK.', '..KeeK..', '...KK...']
save('dropdown_arrow', ARROW, {'w': 'd8fff0'}, 'OptionButton arrow.')
save('radio_on', GEM, GOLD, 'PopupMenu radio, chosen: a gold gem.')
save('radio_off', GEM, {'K': K, 'h': '1c5a41', 'y': '0d2a1f', 'e': '0d2a1f'}, 'PopupMenu radio, not chosen: an empty socket.')
save('radio_on_disabled', GEM, DULL, 'PopupMenu radio, chosen, disabled.')
print('ok')
