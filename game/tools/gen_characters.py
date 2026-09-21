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

BEAVER = ANIMAL(
    slug="beaver",
    # From characters/svg/03_beaver.svg, redrawn as a side view. The paddle
    # tail is the read at tile size: a broad teardrop, widest at the tip,
    # hatched, drawn first so the torso covers its root, and no lower than
    # the belly so the lowered body still lies flat. The torso is a humped
    # loaf with a tall rear (room for the tail) and a flat belly, so pose
    # 0/1 read as lying once the legs are hidden.
    body=[
        path("M30,56 C14,50 0,48 0,66 C0,81 16,81 30,78 Z", "#7d6144"),
        path("M8,60 L26,61 M8,71 L26,72", "none", sw=3),
        path("M72,81 C80,81 81,66 77,56 C73,44 62,34 46,34 "
             "C30,34 22,44 22,58 C22,70 22,81 30,81 Z", "#a3764f"),
    ],
    # Four stubby legs, the far pair darker and half a step ahead.
    legs=[
        path("M33,81 V89 Q33,92 36,92 H45 Q48,92 48,89 V81 Z", "#7d6144"),
        path("M57,81 V89 Q57,92 60,92 H69 Q72,92 72,89 V81 Z", "#7d6144"),
        path("M27,81 V89 Q27,92 30,92 H39 Q42,92 42,89 V81 Z", "#a3764f"),
        path("M51,81 V89 Q51,92 54,92 H63 Q66,92 66,89 V81 Z", "#a3764f"),
    ],
    # Round skull, blunt muzzle, the incisors under the nose so the drink
    # lands on them; the ear rides the back of the skull. The pivot is at
    # the throat, low enough for the muzzle to reach the water.
    head=[
        path("M63,48 C63,36 70,30 80,31 C90,32 97,42 97,52 "
             "C97,58 94,63 88,64 C80,66 70,66 66,62 C63,59 63,54 63,48 Z", "#b3855c"),
        circle(65, 34, 5, "#7d6144", stroke=STROKE),
        path("M84,60 L84,69 Q84,71 87,71 L92,71 Q95,71 95,69 L95,59 Z", "#fff6db"),
        path("M89.5,61 L89.5,70", "none", sw=3),
        circle(86, 44, 3.5, STROKE),
    ],
    neck=(70, 66),
    lie_dy=11,
    tuck_deg=30,
)


TOAD = ANIMAL(
    slug="toad",
    # Redrawn from characters/svg/05_toad.svg as a side view facing right:
    # the concept is frontal and symmetric, so only its colours, the wide
    # mouth and the yellow eye dome survive. A squat body with a flat
    # underside, low on short legs, warts along the back.
    body=[
        path("M14,80 Q4,72 10,62 Q16,48 40,47 Q60,46 66,58 Q68,70 64,80 Z", "#7a8a4a"),
        circle(26, 59, 3, "#6f7f42", sw=3, stroke=STROKE),
        circle(38, 53, 3, "#6f7f42", sw=3, stroke=STROKE),
        circle(49, 54, 3, "#6f7f42", sw=3, stroke=STROKE),
    ],
    legs=[
        # the big folded hind leg: thigh against the flank, heel on the
        # ground, foot forward under the belly
        path("M16,66 Q4,72 8,84 Q10,90 20,90 L44,90 Q46,86 40,85 L32,85 Q34,76 36,72 Q32,64 16,66 Z",
             "#6f7f42"),
        # the small front leg under the chin, hand pointing forward
        path("M54,80 L53,88 Q54,90 58,90 L68,90 Q69,86 64,86 L62,80 Z", "#6f7f42"),
    ],
    lying_legs=[
        # the same legs splayed flat into the mud: a low haunch behind,
        # a hand in front (under the tucked chin in pose 0)
        path("M14,70 Q2,76 8,80 L40,80 Q42,76 36,76 Q28,72 22,70 Z", "#6f7f42"),
        path("M54,75 L54,80 L68,80 Q69,76 64,75 Z", "#6f7f42"),
    ],
    head=[
        # blunt wedge, the snout low at the front so it is what meets the water
        path("M56,54 Q70,44 84,54 Q94,63 88,73 Q75,75 62,71 Q56,64 56,54 Z", "#7a8a4a"),
        path("M88,68 Q76,67 64,63", "none", sw=3.5),
        circle(70, 50, 9, "#dcc45c", stroke=STROKE),
        path("M70,44.5 Q74,50 70,55.5 Q66,50 70,44.5 Z", STROKE, stroke="none"),
    ],
    neck=(56, 54),
    lie_dy=10,
    max_drink_deg=55,
)


OTTER = ANIMAL(
    slug="otter",
    # Redrawn from characters/svg/07_otter.svg in side view, facing right
    # (the concept sits up). Tail first so the rump covers its root; the
    # pale belly and muzzle are unstroked patches inset to the outline's
    # inner edge, so the house line stays one weight.
    #
    # The neck is part of the HEAD so the drink reaches the ground from a
    # low shoulder, and it is drawn seamlessly: the torso's front is a
    # semicircle of radius 13 about the neck pivot, the neck is an unstroked
    # fill plus two open edge lines that end exactly on that circle. Turning
    # the head slides the line ends along the torso's own outline, so no
    # joint ever shows inside the body at any angle.
    body=[
        path("M34,57 Q17,59 8,66 Q3,70.5 8,75.5 L34,76 Z", "#7a5a3f"),
        path("M30,76 Q23,76 24,64 Q25,50 38,50 Q51,48 64,50 C71.18,50 77,55.82 77,63 "
             "C77,70.18 71.18,76 64,76 Q47,77 30,76 Z", "#8a6547"),
        path("M33,73.5 Q38,64 47,64 Q56,64 61,73.5 Z", "#cbaf90", stroke="none"),
    ],
    legs=[
        path("M32,76 V85 Q32,88 35,88 H39 Q42,88 42,85 V76 Z", "#7a5a3f"),
        path("M52,76 V85 Q52,88 55,88 H59 Q62,88 62,85 V76 Z", "#7a5a3f"),
        path("M27,76 V85 Q27,88 30,88 H34 Q37,88 37,85 V76 Z", "#7a5a3f"),
        path("M57,76 V85 Q57,88 60,88 H64 Q67,88 67,85 V76 Z", "#7a5a3f"),
    ],
    head=[
        path("M59.9,56.7 L78.4,44.7 L86.5,57.3 L68.1,69.3 Z", "#8a6547", stroke="none"),
        path("M78.4,44.7 L68.8,50.9 M86.5,57.3 L77,63.5", "none"),
        path("M72.5,51.5 Q72.5,43 82,43 Q92,43 93.5,50 Q95.5,55 92.5,58 Q90,60.5 85,60.5 "
             "Q76,61 74,58 Q72.5,55.5 72.5,51.5 Z", "#9a7352"),
        path("M91,50.5 Q93,55 90.5,57.5 Q88.5,58.5 85,58.5 Q82,58 82,54.5 Q82.5,52 86,51.5 Z",
             "#eadcc8", stroke="none"),
        circle(76, 44, 4, "#7a5a3f", sw=3, stroke=STROKE),
        circle(86.5, 49, 3, STROKE),
    ],
    neck=(64, 63),
    lie_dy=12,
    lying_legs=[
        path("M64,76 Q64,70 70,70 L77,70 Q82,70 82,74 Q82,76 79,76 Z", "#7a5a3f"),
    ],
    tuck_deg=45,
    max_drink_deg=75,
)


SHEEPDOG = ANIMAL(
    slug="sheepdog",
    # Redrawn from characters/svg/10_sheepdog.svg, which clipped at both
    # frame edges and put a dark eye on a dark patch. The body stays WHITE
    # on purpose (character-plates.html:333: a dark dog vanishes into the
    # outline at tile size); a dark saddle, skull cap and ear carry the
    # silhouette, and the neck is white so the white shape stays in one
    # piece -- legs, belly, chest, neck, face -- over a dark cell. Side
    # view, facing right. The neck belongs to the head so the muzzle can
    # reach the water; its base edge is left unstroked (no Z) so it joins
    # the shoulder without a seam in every pose.
    body=[
        # tail, up: the house outline as a wide stroke under a white core
        path("M21,55 Q13,51 15,34", "none", sw=14, stroke=STROKE),
        path("M21,55 Q13,51 15,34", "none", sw=9, stroke="#f2f2ef"),
        # torso: level back, round chest, flat belly so a lowered body reads lying
        path("M22,53 Q40,43 58,49 Q72,53 70,65 Q68,75 56,75.5 L30,75.5 Q18,74 18,67 Q18,55 22,53 Z", "#f2f2ef"),
        # saddle: its top is the torso's back curve between x 27 and 51
        path("M27.4,50.4 Q39.2,45.4 50.8,47.2 Q55,53 49,58 Q36,63 26,59.5 Q22,55.5 27.4,50.4 Z", "#2f3238"),
    ],
    legs=[
        # far pair first, near pair over them, each far leg peeking 7 out
        # past the near one (2 of white beyond the strokes); tops sit on the
        # belly line
        path("M25,75.5 V87 Q25,91.5 31,91.5 Q37,91.5 37,87 V75.5 Z", "#f2f2ef"),
        path("M45,75.5 V87 Q45,91.5 51,91.5 Q57,91.5 57,87 V75.5 Z", "#f2f2ef"),
        path("M18,75.5 V87 Q18,91.5 24,91.5 Q30,91.5 30,87 V75.5 Z", "#f2f2ef"),
        path("M52,75.5 V87 Q52,91.5 58,91.5 Q64,91.5 64,87 V75.5 Z", "#f2f2ef"),
    ],
    head=[
        # neck, white, open path: nape and throat are stroked, the base is not
        path("M52,47.5 Q54,33 62,20 L76,35 Q70,47 64,55", "#f2f2ef"),
        # muzzle, drawn under the head so its base needs no seam; level, so
        # it hangs vertical at the drink
        path("M76,23 L86,23.5 Q95,24 95,29 Q95,34.5 88,36.5 L77,36 Z", "#f2f2ef"),
        circle(70, 26, 13, "#f2f2ef", stroke=STROKE),
        # skull cap over the top-back quarter (150..300 degrees of the head)
        path("M58.74,32.5 Q57,29.5 57,26 Q57,13 70,13 Q73.5,13 76.5,14.74 Q68,25 58.74,32.5 Z", "#2f3238"),
        # one pointed ear on the cap, leaning back
        path("M59.35,18.5 Q56,13 56,6 Q64,7 68.9,13.04 Z", "#2f3238"),
        circle(93, 27, 3.5, STROKE),
        circle(75, 26, 3.3, STROKE),
    ],
    neck=(54, 51),
    lie_dy=16,
    lying_legs=[
        # a forepaw stretched forward under the chin: its rear edge is the
        # torso's own chest curve and its bottom the belly line, so only
        # the paw itself adds an outline
        path("M56,75.5 Q64.4,75.15 67.9,70.2 Q74,66.5 78,70 Q80,75.5 75,75.5 Z", "#f2f2ef"),
    ],
    tuck_deg=55,
    max_drink_deg=95,
)


BISON = ANIMAL(
    slug="bison",
    # Redrawn from characters/svg/11_bison.svg for a side view: the hump is
    # the read, so it is taller and the back slopes to the rump; the body is
    # a step lighter than the concept so the house outline stays visible at
    # tile size, and the head keeps the concept's dark brown. The neck is
    # part of the head; its rear edge is an arc about the neck pivot so the
    # seam on the shoulder stays put whichever way the head turns.
    body=[
        # tail, hanging behind the rump to hock height (the same depth as
        # the folded legs, so a lying bison rests on both)
        path("M10,48 Q3,60 5,72", "none"),
        path("M5,70 Q1,77 5,83 Q9,77 5,70 Z", "#332419"),
        # torso: rump, the sloping back up to the hump, the steep hump
        # front, and a deep chest over a flat belly
        path("M12,74 C6,66 6,52 11,46 C20,34 24,19 36,19 C48,19 56,28 60,40 "
             "C66,48 72,58 66,74 Z", "#5c4636"),
        # shaggy shoulder fur
        path("M22,40 Q28,46 24,54 M34,30 Q40,36 36,46", "none", sw=3.5),
    ],
    legs=[
        # far pair first, then the near pair over them
        path("M12,74 L12,90 Q12,94 17,94 Q22,94 22,90 L22,74 Z", "#4a382c"),
        path("M51,74 L51,90 Q51,94 56,94 Q61,94 61,90 L61,74 Z", "#4a382c"),
        path("M21,74 L21,90 Q21,94 26.5,94 Q32,94 32,90 L32,74 Z", "#4a382c"),
        path("M42,74 L42,90 Q42,94 47,94 Q52,94 52,90 L52,74 Z", "#4a382c"),
    ],
    head=[
        # neck and head as one: neck top to the poll, the forehead curving
        # down the face to the muzzle, the chin, a beard tuft, the throat
        # back to the shoulder, then the arc about the pivot
        path("M47,44 C55,45 68,38 80,38 C89,38 96,48 97,60 C98,66 98,69 97,71 "
             "L91,73 C87,75 80,74 76,70 C68,66 58,64 49,58 C43,54 43,47 47,44 Z",
             "#332419"),
        # the pale horn, a hook rising from the poll
        path("M84,41 Q78,36 80,29 Q82,24 88,27", "none", stroke="#ded2ba"),
        circle(86, 48, 3.4, "#e9dfcc"),
    ],
    neck=(57, 50),
    lie_dy=11,          # legs are 20 tall, the folded legs 9: the belly comes down onto them
    lying_legs=[
        # folded legs, cattle-fashion: two low pads under the rump and the
        # chest, the front one's knee just ahead of the brisket
        path("M11,74 Q9,83 18,83 L32,83 Q38,83 36,74 Z", "#4a382c"),
        path("M43,74 Q41,83 50,83 L64,83 Q70,83 68,74 Z", "#4a382c"),
    ],
    max_drink_deg=50,
)


FLAMINGO = ANIMAL(
    slug="flamingo",
    # Redrawn from characters/svg/12_flamingo.svg as a side view facing right
    # (the concept looks back over its own body); flipped so the shipped art
    # faces left, towards the tortoise it shares the Jamboree band with. Pink
    # is the only pink on the board: #f28fa8 torso and neck, #e8748f tail,
    # #dd9aa4 legs, the beak #f6ead6 with the concept's dark tip.
    body=[
        path("M24,44 L13,38 L18,58 Z", "#e8748f"),                    # tail, behind the torso
        path("M64,54 C64,61 55,64 42,64 C29,64 20,61 20,53 "
             "C20,46 30,42 40,42 C51,42 64,46 64,54 Z", "#f28fa8"),   # torso, flat underside
        path("M29,51 Q40,45 55,52", "none", sw=3.5),                  # folded wing
    ],
    legs=[
        path("M40,67 L38,88 L46,90", "none", sw=5, stroke="#dd9aa4"),  # back leg, toes forward
        path("M49,67 L50,88 L59,90", "none", sw=5, stroke="#dd9aa4"),  # front leg
    ],
    lying_legs=[
        path("M37,67 L26,69 L43,71", "none", sw=5, stroke="#dd9aa4"),  # tarsus folded flat under the belly
    ],
    head=[
        # The beak comes first: facing() reads the first element, and the
        # beak is the one part that sits clearly forward of the pivot. Its
        # root tucks under the head circle. It is drawn nearly level so its
        # dark tip, not the chin, is what reaches the water when drinking.
        path("M66,1 Q79,0.5 85,11 Q81,15 67,11.5 Z", "#f6ead6"),      # beak
        path("M84,5.5 Q87,12 79,14", "none", sw=6),                   # the dark tip
        # The S-neck, one closed ribbon 11 wide about the centreline
        # (56,45.5) C(54.5,36) (45,32.5) (45,24) C(45,15) (51,6.5) (61,6.5):
        # up and bowing back from the shoulder, then forward into the head.
        # Its base is a straight cut through the pivot, lying along the
        # torso's outline so the join is hidden; its top end is inside the
        # head circle.
        path("M50.6,46.4 C49.6,40 39.5,36.3 39.5,24 C39.5,13.3 48.2,1 61,1 "
             "L61,12 C53.8,12 50.5,16.7 50.5,24 C50.5,28.7 59.4,32 61.4,44.6 Z",
             "#f28fa8"),
        circle(61, 6.5, 8.5, "#f28fa8", stroke=STROKE),               # head
        circle(64, 3.8, 2.6, STROKE),                                 # eye
    ],
    neck=(56, 45.5),        # on the torso's top-front outline, where the neck leaves it
    lie_dy=19,              # legs are 26 tall; the folded tarsus takes the last 7
    tuck_deg=20,            # a sitting flamingo keeps its head up
    max_drink_deg=135,      # solves at ~119: the neck must swing past horizontal
                            # before the beak, 47 below the pivot, reaches the feet
    step_dx=5,
    flip=True,
)


BADGER = ANIMAL(
    slug="badger",
    # Side view of characters/svg/13_badger.svg, facing right: a long grey
    # body low on stubby legs, and the wedge head whose two black stripes
    # on white are the read. The head is carried a little above the back
    # so it has room to drop: chin to the ground when lying, muzzle to the
    # water when drinking.
    body=[
        # short drooping tail, tucked under the rump's outline
        path("M8,60 Q-3,63 -1,72 Q1,77 7,75 Z", "#8c8d8a"),
        # torso: rounded rump, gently humped back, round shoulder, flat belly
        path("M10,78 Q3,78 3,68 Q3,48 26,46 Q46,42 60,45 Q69,48 67,62 Q67,74 58,78 Z", "#8c8d8a"),
    ],
    legs=[
        path("M12,78 L12,89 Q12,91 14,91 L20,91 Q22,91 22,89 L22,78 Z", "#8c8d8a"),
        path("M48,78 L48,89 Q48,91 50,91 L56,91 Q58,91 58,89 L58,78 Z", "#8c8d8a"),
    ],
    head=[
        # ear first, so the skull covers its root
        circle(62, 39.5, 6.5, "#f4f3ef", stroke=STROKE),
        # skull: crown to a blunt nose, jaw back to the throat, round nape
        path("M54,38 Q80,36 96,53 Q98.5,57 95,61 Q82,70 56,71 Q49,55 54,38 Z", "#f4f3ef"),
        # the two black stripes, tapering to the nose; the throat one stops
        # short so the eye sits in the white cheek between them
        path("M57,43.5 Q78,43.5 89,51.5 Q91.5,53.75 88.5,56 Q78,52 57,51.5 Z", "#2e2f31", stroke="none"),
        path("M58.5,57 Q72,57.5 81,58 Q84,60.5 81,63 Q72,65 58.5,64.5 Z", "#2e2f31", stroke="none"),
        circle(86.2, 59.1, 2.7, STROKE),
    ],
    neck=(57, 62),
    lie_dy=13,
)


HORSE = ANIMAL(
    slug="horse",
    # Redrawn from characters/svg/15_horse.svg for the side view: same
    # colours, longer legs, the neck at 45 degrees. The HEAD part is the
    # whole neck + head + mane and turns about the shoulder, so the muzzle
    # can reach the water.
    body=[
        path("M12,46 Q5.5,56 8,68", "none", sw=10, stroke="#3f2a1c"),
        path("M32,41 C46,40 58,45 58,53 C58,60 48,63 36,63 C22,63 10,60 10,51 C10,42 18,41.5 32,41 Z", "#8a5a3c"),
    ],
    legs=[
        path("M20.5,62.3 L26,63.4 L28.5,91.5 L24,91.5 Z", "#8a5a3c"),
        path("M44,63.5 L49.5,62.3 L46,91.5 L41.5,91.5 Z", "#8a5a3c"),
        path("M14,59.4 L19.5,62 L19,91.5 L14.5,91.5 Z", "#8a5a3c"),
        path("M50.5,62 L56,58.8 L55.5,91.5 L51,91.5 Z", "#8a5a3c"),
    ],
    head=[
        path("M47.1,46.1 L72.5,23.4 Q78.5,24.5 79.6,30.5 L56.9,55.9 Q47.8,55.2 47.1,46.1 Z", "#8a5a3c"),
        path("M79.3,21.1 L94.2,38.2 Q94.2,42.6 89.7,43.9 Q80.5,41.7 75.9,36.9 L71.2,30 Z", "#9a684a"),
        path("M47.1,46.1 Q52.7,27.7 72.5,23.4 Q73,17.5 77.5,14.5", "none", sw=9, stroke="#3f2a1c"),
        path("M79.7,22.9 L82.7,11.9 L84.5,26.5 Z", "#8a5a3c"),
        circle(85.8, 32.6, 3, STROKE),
        path("M88.5,42.2 Q90.8,43.4 91.8,43.1", "none", sw=3),
    ],
    neck=(52, 51),
    lie_dy=20,
    lying_legs=[
        path("M36,62 L56,62 Q61,62 61,66.8 Q61,71.5 56,71.5 L36,71.5 Q33,66.8 36,62 Z", "#8a5a3c"),
        path("M13,62 L33,62 Q36,66.8 33,71.5 L13,71.5 Q8,71.5 8,66.8 Q8,62 13,62 Z", "#8a5a3c"),
    ],
    tuck_deg=35,
    max_drink_deg=85,
)

ANIMALS = [
    BEAVER,
    TOAD,
    OTTER,
    TORTOISE,
    SHEEPDOG,
    BISON,
    FLAMINGO,
    BADGER,
    HORSE,
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
LAKEBED = "#b3a385"    # HexBoard.BASIN_DRY_COLOR
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
    parts.append('<h2>Every animal at a glance</h2><p>Lying and head-up on the dry lakebed\'s tan, the rest on an empty cell.</p>')
    for slug, (svgs, s) in built.items():
        parts.append('<div class="row"><b style="width:90px">%s</b>%s</div>' % (slug, "".join(
            frame(svg, 120, LAKEBED if k < 2 else EMPTY_CELL) for k, svg in enumerate(svgs))))
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
