"""Line and leg helpers shared by the part generators."""


def line(f, x0, y0, x1, y1, ch):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        f.px[(x0, y0)] = ch
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def leg(f, hx, hy, off, col, boot, feet, lift=0, width=1, shade=None):
    foot = feet - lift
    for y in range(hy, foot + 1):
        t = (y - hy) / max(1, foot - hy)
        x = hx + round(off * t)
        for w in range(width):
            c = boot if y >= foot - (width - 1) else (shade if (shade and w == width - 1) else col)
            f.px[(x + w, y)] = c
    f.px[(hx + off + width, foot)] = boot
