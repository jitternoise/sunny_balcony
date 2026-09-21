#!/usr/bin/env python3
"""Draws every pool animal's five poses in game/assets/characters/ from parts.

    python3 game/tools/gen_characters.py             # writes every animal
    python3 game/tools/gen_characters.py tortoise    # just this one
    python3 game/tools/gen_characters.py --verify    # is the directory what the records say?

A pool's animal acts out the pool filling, one pose per beat of pool_fill:

    0  lying by the dry basin      body lowered, legs folded away, head down
    1  head comes up               still lying, head level
    2  standing                    body up on its legs
    3  walks to the edge           a step forward, head dipping
    4  drinks                      head down to the water at its feet

Nobody draws those five times per animal. An animal is THREE parts -- body,
legs, head -- drawn once in any 100x100 frame, plus a neck pivot and a few
numbers, and the poses are staged here by moving and turning the parts,
exactly how the original tortoise sequence (characters/pool-sequence/) was
built. Every transform is baked into the coordinates before writing, so the
files are flat paths Godot rasterises directly and the checks below are
made on the numbers that will actually be drawn.

Every pose is normalised into the same frame: the animal is scaled so the
five poses together fill the width, and each pose is set down so its lowest
stroke edge sits on BASELINE (y = 94 of 100). HexBoard puts that line on the
lake's top corner, which is the waterline once the pool is full, so nothing
is ever drawn below the water and the drinking muzzle meets the surface --
the drink angle is solved, not guessed. Strokes keep the house weight (5)
whatever the animal's scale, so every animal has the same line at tile size.

Adding an animal: write its parts as an ANIMAL() record (transcribe or
redraw from characters/svg/), run this, review characters/pose-plates.html
in a browser, then `godot --headless --import --path game`, set
`svg/scale=3.0` in the five new .svg.import files (a fresh import writes
1.0, a blurry 100 px texture) and import again. Point the band at it in
Characters.CAST. VerifyCharacters fails on any drift between CAST, this
file's records and the directory. Output is deterministic: re-running
writes byte-identical files unless a record changed.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "assets", "characters"))
PLATES = os.path.normpath(os.path.join(HERE, "..", "..", "characters", "pose-plates.html"))

FRAME = 100.0
BASELINE = 94.0        # the feet line; HexBoard.CHARACTER_BASELINE is this / FRAME
SIDE_MARGIN = 3.0      # nothing (stroke included) closer than this to the frame's sides
TOP_MARGIN = 3.0
STROKE = "#0b3d63"     # the house outline
STROKE_WIDTH = 5.0
POSES = 5


# --- geometry -------------------------------------------------------------

def mat_mul(m, n):
    """m * n as SVG affine matrices (a, b, c, d, e, f): apply n, then m."""
    a, b, c, d, e, f = m
    a2, b2, c2, d2, e2, f2 = n
    return (a * a2 + c * b2, b * a2 + d * b2,
            a * c2 + c * d2, b * c2 + d * d2,
            a * e2 + c * f2 + e, b * e2 + d * f2 + f)


def translate(dx, dy):
    return (1, 0, 0, 1, dx, dy)


def scale(s):
    return (s, 0, 0, s, 0, 0)


def rotate(deg, cx, cy):
    r = math.radians(deg)
    cs, sn = math.cos(r), math.sin(r)
    return mat_mul(translate(cx, cy), mat_mul((cs, sn, -sn, cs, 0, 0), translate(-cx, -cy)))


def mirror_x():
    return (-1, 0, 0, 1, FRAME, 0)


def apply(m, x, y):
    a, b, c, d, e, f = m
    return a * x + c * y + e, b * x + d * y + f


def uniform_scale(m):
    return math.hypot(m[0], m[1])


_NUM = r"-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?"


def parse_path(d):
    """Path data -> list of (cmd, points) in absolute M/L/Q/C/Z."""
    tokens = re.findall(r"[MmLlHhVvQqCcTtSsZz]|" + _NUM, d)
    segs = []
    cmd = None
    i = 0
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    last_ctrl = None

    def take(n):
        nonlocal i
        vals = [float(v) for v in tokens[i:i + n]]
        if len(vals) != n:
            raise ValueError("short path data in %r" % d)
        i += n
        return vals

    while i < len(tokens):
        if tokens[i].isalpha():
            cmd = tokens[i]
            i += 1
        elif cmd in ("M", "m"):
            cmd = "L" if cmd == "M" else "l"
        rel = cmd.islower()
        c = cmd.upper()
        if c == "Z":
            segs.append(("Z", []))
            cur = start
            last_ctrl = None
            continue
        if c == "M":
            x, y = take(2)
            if rel:
                x, y = cur[0] + x, cur[1] + y
            cur = start = (x, y)
            segs.append(("M", [cur]))
            last_ctrl = None
        elif c == "L":
            x, y = take(2)
            if rel:
                x, y = cur[0] + x, cur[1] + y
            cur = (x, y)
            segs.append(("L", [cur]))
            last_ctrl = None
        elif c == "H":
            (x,) = take(1)
            cur = ((cur[0] + x) if rel else x, cur[1])
            segs.append(("L", [cur]))
            last_ctrl = None
        elif c == "V":
            (y,) = take(1)
            cur = (cur[0], (cur[1] + y) if rel else y)
            segs.append(("L", [cur]))
            last_ctrl = None
        elif c == "Q":
            x1, y1, x, y = take(4)
            if rel:
                x1, y1, x, y = cur[0] + x1, cur[1] + y1, cur[0] + x, cur[1] + y
            segs.append(("Q", [(x1, y1), (x, y)]))
            last_ctrl = (x1, y1)
            cur = (x, y)
        elif c == "T":
            x, y = take(2)
            if rel:
                x, y = cur[0] + x, cur[1] + y
            x1, y1 = (2 * cur[0] - last_ctrl[0], 2 * cur[1] - last_ctrl[1]) if last_ctrl else cur
            segs.append(("Q", [(x1, y1), (x, y)]))
            last_ctrl = (x1, y1)
            cur = (x, y)
        elif c == "C":
            x1, y1, x2, y2, x, y = take(6)
            if rel:
                x1, y1, x2, y2, x, y = (cur[0] + x1, cur[1] + y1, cur[0] + x2, cur[1] + y2,
                                        cur[0] + x, cur[1] + y)
            segs.append(("C", [(x1, y1), (x2, y2), (x, y)]))
            last_ctrl = (x2, y2)
            cur = (x, y)
        elif c == "S":
            x2, y2, x, y = take(4)
            if rel:
                x2, y2, x, y = cur[0] + x2, cur[1] + y2, cur[0] + x, cur[1] + y
            x1, y1 = (2 * cur[0] - last_ctrl[0], 2 * cur[1] - last_ctrl[1]) if last_ctrl else cur
            segs.append(("C", [(x1, y1), (x2, y2), (x, y)]))
            last_ctrl = (x2, y2)
            cur = (x, y)
        else:
            raise ValueError("unsupported path command %r in %r" % (cmd, d))
    return segs


def fmt(v):
    s = "%.2f" % v
    s = s.rstrip("0").rstrip(".") if "." in s else s
    return "0" if s in ("-0", "") else s


def emit_path(segs):
    out = []
    for cmd, pts in segs:
        out.append(cmd + " ".join("%s,%s" % (fmt(x), fmt(y)) for x, y in pts))
    return " ".join(out)


# --- elements -------------------------------------------------------------
# An element is a dict. Paths: {"d", "fill"} plus optional "sw" (stroke
# width, default the house 5), "stroke" (a colour, or "none"). Circles:
# {"circle": (cx, cy, r), "fill"} plus the same options.

def path(d, fill, sw=None, stroke=None):
    e = {"d": d, "fill": fill}
    if sw is not None:
        e["sw"] = sw
    if stroke is not None:
        e["stroke"] = stroke
    return e


def circle(cx, cy, r, fill, sw=None, stroke="none"):
    e = {"circle": (cx, cy, r), "fill": fill}
    if sw is not None:
        e["sw"] = sw
    if stroke is not None:
        e["stroke"] = stroke
    return e


def half_stroke(e):
    if e.get("stroke") == "none":
        return 0.0
    return e.get("sw", STROKE_WIDTH) / 2.0


def transform_element(e, m):
    out = dict(e)
    if "circle" in e:
        cx, cy, r = e["circle"]
        x, y = apply(m, cx, cy)
        out["circle"] = (x, y, r * uniform_scale(m))
    else:
        segs = parse_path(e["d"]) if isinstance(e["d"], str) else e["d"]
        out["d"] = [(cmd, [apply(m, x, y) for x, y in pts]) for cmd, pts in segs]
    return out


def element_bbox(e, padded=True):
    """(min_x, min_y, max_x, max_y) over every point (control points too,
    which is conservative) plus half the stroke when `padded`."""
    pad = half_stroke(e) if padded else 0.0
    if "circle" in e:
        cx, cy, r = e["circle"]
        return cx - r - pad, cy - r - pad, cx + r + pad, cy + r + pad
    segs = parse_path(e["d"]) if isinstance(e["d"], str) else e["d"]
    xs = [x for _, pts in segs for x, _ in pts]
    ys = [y for _, pts in segs for _, y in pts]
    return min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad


def bbox_union(boxes):
    boxes = list(boxes)
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def elements_bbox(elements, padded=True):
    return bbox_union(element_bbox(e, padded) for e in elements)


def emit_element(e):
    attrs = []
    if "circle" in e:
        cx, cy, r = e["circle"]
        attrs.append('cx="%s" cy="%s" r="%s"' % (fmt(cx), fmt(cy), fmt(r)))
        tag = "circle"
    else:
        d = emit_path(e["d"]) if isinstance(e["d"], list) else emit_path(parse_path(e["d"]))
        attrs.append('d="%s"' % d)
        tag = "path"
    attrs.append('fill="%s"' % e["fill"])
    if "sw" in e:
        attrs.append('stroke-width="%s"' % fmt(e["sw"]))
    if "stroke" in e:
        attrs.append('stroke="%s"' % e["stroke"])
    return "<%s %s/>" % (tag, " ".join(attrs))


# --- animals --------------------------------------------------------------

def ANIMAL(slug, body, legs, head, neck, lie_dy, lying_legs=None, lying_head="tucked",
           tuck_deg=25.0, max_drink_deg=70.0, step_dx=8.0, flip=False):
    """One animal, drawn standing in any 100x100 frame.

    body, legs, head  the three parts, lists of elements, drawn in that order
    neck              (x, y) the head turns about, in the same frame
    lie_dy            how far the body drops when lying (its legs fold away)
    lying_legs        what shows under a lying body instead of `legs`, or
                      None for nothing (a tortoise pulls them in)
    lying_head        "tucked" turns the head down while lying, "hidden"
                      draws no head at all in pose 0 (the tortoise again)
    tuck_deg          how far the lying head turns down, at most
    max_drink_deg     the most the head may turn to reach the water
    step_dx           the step forward between standing and drinking
    flip              True if the drawing faces left and should face right
                      (every animal is stored facing the way it was drawn;
                      HexBoard mirrors nothing)
    """
    return dict(slug=slug, body=body, legs=legs, head=head, neck=neck, lie_dy=lie_dy,
                lying_legs=lying_legs, lying_head=lying_head, tuck_deg=tuck_deg,
                max_drink_deg=max_drink_deg, step_dx=step_dx, flip=flip)


TORTOISE = ANIMAL(
    slug="tortoise",
    # Lifted from characters/pool-sequence/s2.svg (the standing frame),
    # minus the bowl: the engine's own basin is the water now.
    body=[
        path("M8,64 Q6,38 30,38 Q54,38 52,64 Z", "#6e7c3a"),
        path("M20,40 L21,64 M30,38 L30,64 M40,40 L39,64", "none", sw=3.5),
        path("M10,51 Q30,44 50,51", "none", sw=3.5),
    ],
    legs=[
        path("M14,64 L14,76 Q21,80 25,74 L25,64 Z", "#8a9a4c"),
        path("M36,64 L36,76 Q43,80 47,74 L47,64 Z", "#8a9a4c"),
    ],
    head=[
        path("M52,52 Q68,48 68,59 Q66,68 52,66 Z", "#8a9a4c"),
        circle(62, 55, 3, STROKE),
    ],
    neck=(52, 60),
    lie_dy=12,
    lying_head="hidden",
    max_drink_deg=60,
)

ANIMALS = [
    TORTOISE,
]


# --- staging --------------------------------------------------------------

def facing(animal):
    """+1 when the head is to the right of the neck, -1 when to the left."""
    hx = (element_bbox(animal["head"][0], False)[0] + element_bbox(animal["head"][0], False)[2]) / 2.0
    return 1.0 if hx >= animal["neck"][0] else -1.0


def placed(elements, m):
    return [transform_element(e, m) for e in elements]


def bottom(elements):
    return elements_bbox(elements)[3]


def turn_until(head, neck, target_y, max_deg, sign):
    """Rotate `head` about `neck` (sign * degrees, clockwise when sign is
    +1) until its lowest stroke edge reaches target_y, or max_deg if it
    never gets there. Returns the angle used."""
    def low(deg):
        return bottom(placed(head, rotate(sign * deg, *neck)))
    if low(max_deg) <= target_y:
        return max_deg
    lo, hi = 0.0, max_deg
    for _ in range(40):
        mid = (lo + hi) / 2.0
        if low(mid) < target_y:
            lo = mid
        else:
            hi = mid
    return lo


def stage(animal):
    """The five poses, each a list of elements in the animal's own frame
    (not yet normalised). Pose k is what pool_fill == k looks like."""
    body, legs, head = animal["body"], animal["legs"], animal["head"]
    neck = animal["neck"]
    sign = facing(animal)
    lie = animal["lie_dy"]
    step = animal["step_dx"] * sign

    standing = placed(body, translate(0, 0)) + placed(legs, translate(0, 0))
    ground = bottom(standing)

    def lying(dy, head_deg):
        parts = placed(body, translate(0, dy))
        if animal["lying_legs"]:
            parts += placed(animal["lying_legs"], translate(0, dy))
        if head_deg is not None:
            pivot = (neck[0], neck[1] + dy)
            parts += placed(head, mat_mul(rotate(sign * head_deg, *pivot), translate(0, dy)))
        return parts

    # 0: lying, head down (or drawn in, for a shell).
    body_low = bottom(placed(body, translate(0, lie)))
    tuck = 0.0
    if animal["lying_head"] != "hidden":
        tuck = turn_until(placed(head, translate(0, lie)), (neck[0], neck[1] + lie),
                          body_low, animal["tuck_deg"], sign)
    pose0 = lying(lie, None if animal["lying_head"] == "hidden" else tuck)
    # 1: still down, head level.
    pose1 = lying(lie * 2.0 / 3.0, 0.0)
    # 2: standing.
    pose2 = standing + placed(head, translate(0, 0))
    # 4: a step and a half forward, head down to the water at its feet.
    far = translate(step * 1.5, 0)
    drink = turn_until(placed(head, far), apply(far, *neck), ground, animal["max_drink_deg"], sign)
    pose4 = placed(body, far) + placed(legs, far) + placed(head, mat_mul(rotate(sign * drink, *apply(far, *neck)), far))
    # 3: one step, head starting down.
    near = translate(step, 0)
    pose3 = placed(body, near) + placed(legs, near) + placed(head, mat_mul(rotate(sign * drink * 0.4, *apply(near, *neck)), near))
    return [pose0, pose1, pose2, pose3, pose4]


def normalise(poses, flip):
    """Scale the five poses together to fill the frame's width, set each
    one down on BASELINE, and centre the set. Strokes are not scaled, so
    the fit is found on padded boxes by a couple of rounds."""
    s = 1.0
    for _ in range(4):
        boxes = [elements_bbox([transform_element(e, scale(s)) for e in p]) for p in poses]
        union = bbox_union(boxes)
        w, h = union[2] - union[0], union[3] - union[1]
        fit = min((FRAME - 2 * SIDE_MARGIN) / w, (BASELINE - TOP_MARGIN) / h)
        s *= fit
    boxes = [elements_bbox([transform_element(e, scale(s)) for e in p]) for p in poses]
    union = bbox_union(boxes)
    dx = FRAME / 2.0 - (union[0] + union[2]) / 2.0
    out = []
    for p, box in zip(poses, boxes):
        m = mat_mul(translate(dx, BASELINE - box[3]), scale(s))
        if flip:
            m = mat_mul(mirror_x(), m)
        out.append([transform_element(e, m) for e in p])
    return out, s


def check(slug, pose, elements):
    box = elements_bbox(elements)
    problems = []
    if box[3] > BASELINE + 0.01:
        problems.append("reaches y=%.2f, below the baseline %.0f" % (box[3], BASELINE))
    if box[0] < 0 or box[2] > FRAME or box[1] < 0:
        problems.append("leaves the frame: %s" % (tuple(round(v, 2) for v in box),))
    if problems:
        raise SystemExit("%s pose %d: %s" % (slug, pose, "; ".join(problems)))


def render(elements):
    body = "".join(emit_element(e) for e in elements)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n'
            '  <g stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round">\n'
            '%s\n  </g>\n</svg>\n' % (STROKE, fmt(STROKE_WIDTH), body))


def build(animal):
    """slug -> [svg text per pose], with every check applied."""
    poses, s = normalise(stage(animal), animal["flip"])
    for k, p in enumerate(poses):
        check(animal["slug"], k, p)
    return [render(p) for p in poses], s


# --- the review sheet -----------------------------------------------------

# The ten grounds from Backdrop.PALETTES, so a standing animal can be seen
# on every one; and the empty cell's fill, which is what sits behind the
# animal on the board.
GROUNDS = [
    ("Spring meadow", "#4db04f"), ("Deep valley", "#338f61"), ("Morning riverbank", "#73a84d"),
    ("Dry season", "#94a357"), ("Evening pines", "#388075"), ("Golden plains", "#85944d"),
    ("Geyser country", "#618f8a"), ("Badger dusk", "#5c6675"), ("Jamboree sunset", "#66855c"),
    ("The Pan", "#ccccbd"),
]
EMPTY_CELL = "#262a33"
POSE_NAMES = ["lying", "head up", "standing", "to the edge", "drinking"]


def plates(built):
    def frame(svg, px, bg):
        inner = svg.replace('viewBox="0 0 100 100"', 'viewBox="0 0 100 100" width="%d" height="%d"' % (px, px), 1)
        return ('<span class="cell" style="background:%s;width:%dpx;height:%dpx">%s'
                '<i style="top:%.1f%%"></i></span>' % (bg, px, px, inner, BASELINE))
    parts = ['<!doctype html><meta charset="utf-8"><title>Flash Flood pose plates</title>',
             '<style>body{font:14px system-ui;margin:24px;background:#f4f4f0;color:#222}'
             'h2{margin:28px 0 6px}.row{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap;margin:6px 0}'
             '.cell{position:relative;display:inline-block;border-radius:6px;overflow:hidden}'
             '.cell i{position:absolute;left:0;right:0;border-top:1px dashed rgba(255,255,255,.55)}'
             '.cell svg{display:block}.lbl{font-size:12px;color:#555;width:100%}</style>',
             '<h1>Pose plates</h1><p>Written by <code>game/tools/gen_characters.py</code>. '
             'The dashed line is the baseline: the lake\'s top corner, the waterline once the pool is full. '
             'Sizes are the sprite at Hex.SIZE 55 (six-wide campaign columns), 62, and 83 (the four-wide tutorials).</p>']
    for slug, (svgs, s) in built.items():
        parts.append('<h2>%s <small>(scale %.2f)</small></h2>' % (slug, s))
        for px in (55, 62, 83, 200):
            parts.append('<div class="row">' + "".join(frame(svg, px, EMPTY_CELL) for svg in svgs) +
                         '<span class="lbl">%d px &mdash; %s</span></div>' % (px, " / ".join(POSE_NAMES)))
        parts.append('<div class="row">' + "".join(frame(svgs[2], 58, g) for _, g in GROUNDS) +
                     '<span class="lbl">standing at 58 px on every ground: %s</span></div>' %
                     ", ".join(n for n, _ in GROUNDS))
    return "\n".join(parts) + "\n"


# --- main -----------------------------------------------------------------

def main(argv):
    verify = "--verify" in argv
    wanted = [a for a in argv if not a.startswith("--")]
    animals = [a for a in ANIMALS if not wanted or a["slug"] in wanted]
    if wanted and len(animals) != len(wanted):
        raise SystemExit("unknown animal(s): %s" % ", ".join(sorted(set(wanted) - {a["slug"] for a in animals})))
    built = {a["slug"]: build(a) for a in animals}
    drift = 0
    os.makedirs(OUT_DIR, exist_ok=True)
    for slug, (svgs, s) in built.items():
        for k, svg in enumerate(svgs):
            target = os.path.join(OUT_DIR, "%s_%d.svg" % (slug, k))
            if verify:
                on_disk = open(target).read() if os.path.exists(target) else None
                if on_disk != svg:
                    drift += 1
                    print("DRIFT %s" % os.path.relpath(target))
            else:
                with open(target, "w") as f:
                    f.write(svg)
        print("%-10s scale %.2f  %s" % (slug, s, "checked" if verify else "written"))
    known = {"%s_%d.svg" % (a["slug"], k) for a in ANIMALS for k in range(POSES)}
    for name in sorted(os.listdir(OUT_DIR)):
        if name.endswith(".svg") and name not in known:
            drift += 1
            print("ORPHAN %s: no record draws it" % name)
    if not verify:
        with open(PLATES, "w") as f:
            f.write(plates(built))
        print("plates -> %s" % os.path.relpath(PLATES))
    if drift:
        raise SystemExit("%d file(s) differ from the records" % drift)


if __name__ == "__main__":
    main(sys.argv[1:])
