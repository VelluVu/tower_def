"""Tiny frame composer: parts are ASCII grids ('.' = empty), stamped onto a canvas with offsets."""

def part(text):
    rows = [r for r in text.strip('\n').split('\n')]
    return [(x, y, ch) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch not in '. ']

def pts(coords, ch):
    return [(x, y, ch) for x, y in coords]

class Frame:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}
    def stamp(self, p, dx=0, dy=0, flipv=False, fliph=False, recolor=None):
        if not p:
            return self
        maxy = max(y for _, y, _ in p); maxx = max(x for x, _, _ in p)
        for x, y, ch in p:
            if flipv: y = maxy - y
            if fliph: x = maxx - x
            if recolor: ch = recolor.get(ch, ch)
            X, Y = x + dx, y + dy
            if 0 <= X < self.w and 0 <= Y < self.h:
                self.px[(X, Y)] = ch
        return self
    def text(self):
        return '\n'.join(''.join(self.px.get((x, y), '.') for x in range(self.w)) for y in range(self.h))
    def check_margin(self, name):
        for (x, y) in self.px:
            if x == 0 or y == 0 or x == self.w - 1 or y == self.h - 1:
                raise SystemExit('%s touches the edge at %d,%d' % (name, x, y))

def write_spec(path, header, palette, size, tags):
    out = [header.strip(), 'size = %dx%d' % size]
    out += ['%s = %s' % kv for kv in palette.items()]
    out.append('---')
    for tag, ms, frames in tags:
        out.append('@%s %d' % (tag, ms))
        for i, f in enumerate(frames):
            f.check_margin('%s %d' % (tag, i))
            out.append(f.text())
            out.append('')
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
