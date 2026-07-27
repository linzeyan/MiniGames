"""Generate cartoon sea-creature sprites for Gone Fishing.

All creatures face RIGHT. Bodies that take a hue tint in-game are drawn in
a neutral blue-gray; turtle/octopus/jellyfish keep natural colors (hue nil).
Rendered at 4x and downscaled for smooth edges.
"""
from PIL import Image, ImageDraw

OUT = "/Users/ricky/git/game/SmallGame/Resources/Sprites/"
S = 4  # supersample factor

NEUTRAL = (143, 168, 191, 255)
NEUTRAL_DARK = (108, 132, 155, 255)
BELLY = (208, 222, 233, 255)
EYE_W = (255, 255, 255, 255)
EYE_B = (30, 36, 42, 255)


def canvas(w, h):
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, w, h, name):
    img.resize((w, h), Image.LANCZOS).save(OUT + name + ".png")
    print("wrote", name)


def eye(d, x, y, r=3):
    d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=EYE_W)
    d.ellipse([(x - r / 2) * S, (y - r / 2) * S, (x + r / 2) * S, (y + r / 2) * S], fill=EYE_B)


def fish_generic():
    w, h = 72, 40
    img, d = canvas(w, h)
    d.polygon([(2 * S, 6 * S), (18 * S, 20 * S), (2 * S, 34 * S)], fill=NEUTRAL_DARK)   # tail
    d.ellipse([10 * S, 6 * S, 66 * S, 34 * S], fill=NEUTRAL)                            # body
    d.polygon([(30 * S, 8 * S), (40 * S, 0), (46 * S, 8 * S)], fill=NEUTRAL_DARK)       # dorsal
    d.ellipse([26 * S, 22 * S, 58 * S, 36 * S], fill=BELLY)                             # belly
    d.ellipse([10 * S, 6 * S, 66 * S, 34 * S], outline=NEUTRAL_DARK, width=S)
    eye(d, 54, 16)
    save(img, w, h, "fish_a")


def fish_long():
    w, h = 84, 28
    img, d = canvas(w, h)
    d.polygon([(2 * S, 2 * S), (16 * S, 14 * S), (2 * S, 26 * S)], fill=NEUTRAL_DARK)
    d.ellipse([8 * S, 4 * S, 80 * S, 24 * S], fill=NEUTRAL)
    d.polygon([(36 * S, 6 * S), (44 * S, 0), (50 * S, 6 * S)], fill=NEUTRAL_DARK)
    d.ellipse([28 * S, 14 * S, 70 * S, 25 * S], fill=BELLY)
    d.ellipse([8 * S, 4 * S, 80 * S, 24 * S], outline=NEUTRAL_DARK, width=S)
    eye(d, 68, 11)
    save(img, w, h, "fish_long")


def fish_round():
    w, h = 56, 50
    img, d = canvas(w, h)
    d.polygon([(2 * S, 12 * S), (14 * S, 25 * S), (2 * S, 38 * S)], fill=NEUTRAL_DARK)
    d.ellipse([8 * S, 4 * S, 54 * S, 46 * S], fill=NEUTRAL)
    d.polygon([(22 * S, 6 * S), (30 * S, 0), (36 * S, 6 * S)], fill=NEUTRAL_DARK)
    d.ellipse([18 * S, 26 * S, 48 * S, 45 * S], fill=BELLY)
    d.ellipse([8 * S, 4 * S, 54 * S, 46 * S], outline=NEUTRAL_DARK, width=S)
    eye(d, 42, 18)
    save(img, w, h, "fish_round")


def shark():
    w, h = 96, 44
    img, d = canvas(w, h)
    d.polygon([(0, 4 * S), (16 * S, 24 * S), (0, 40 * S)], fill=NEUTRAL_DARK)           # tail
    d.ellipse([8 * S, 12 * S, 92 * S, 38 * S], fill=NEUTRAL)                            # body
    d.polygon([(36 * S, 14 * S), (48 * S, 0), (56 * S, 14 * S)], fill=NEUTRAL_DARK)     # big dorsal
    d.ellipse([30 * S, 28 * S, 84 * S, 39 * S], fill=BELLY)
    d.ellipse([8 * S, 12 * S, 92 * S, 38 * S], outline=NEUTRAL_DARK, width=S)
    eye(d, 78, 21)
    save(img, w, h, "shark")


def swordfish():
    w, h = 100, 32
    img, d = canvas(w, h)
    d.polygon([(0, 2 * S), (14 * S, 14 * S), (0, 26 * S)], fill=NEUTRAL_DARK)
    d.ellipse([6 * S, 6 * S, 74 * S, 28 * S], fill=NEUTRAL)
    d.polygon([(30 * S, 8 * S), (40 * S, 0), (48 * S, 8 * S)], fill=NEUTRAL_DARK)
    d.polygon([(70 * S, 14 * S), (100 * S, 16 * S), (70 * S, 20 * S)], fill=NEUTRAL_DARK)  # bill
    d.ellipse([24 * S, 16 * S, 62 * S, 28 * S], fill=BELLY)
    d.ellipse([6 * S, 6 * S, 74 * S, 28 * S], outline=NEUTRAL_DARK, width=S)
    eye(d, 62, 13)
    save(img, w, h, "swordfish")


def ray():
    w, h = 84, 44
    img, d = canvas(w, h)
    d.polygon([(0, 18 * S), (20 * S, 14 * S), (20 * S, 24 * S)], fill=NEUTRAL_DARK)     # whip tail
    d.polygon([(14 * S, 20 * S), (52 * S, 2 * S), (80 * S, 20 * S), (52 * S, 42 * S)],
              fill=NEUTRAL)                                                             # diamond wings
    d.polygon([(14 * S, 20 * S), (52 * S, 2 * S), (80 * S, 20 * S), (52 * S, 42 * S)],
              outline=NEUTRAL_DARK, width=S)
    d.ellipse([40 * S, 18 * S, 72 * S, 34 * S], fill=BELLY)
    eye(d, 64, 18)
    save(img, w, h, "ray")


def turtle():
    w, h = 80, 46
    shell = (79, 157, 85, 255)
    shell_dark = (56, 118, 62, 255)
    skin = (156, 199, 130, 255)
    img, d = canvas(w, h)
    for cx in (16, 34, 52):                                                             # flippers
        d.ellipse([cx * S, 30 * S, (cx + 16) * S, 44 * S], fill=skin)
    d.ellipse([58 * S, 10 * S, 78 * S, 28 * S], fill=skin)                              # head
    d.ellipse([6 * S, 2 * S, 66 * S, 38 * S], fill=shell)                               # shell
    d.ellipse([6 * S, 2 * S, 66 * S, 38 * S], outline=shell_dark, width=S)
    d.arc([16 * S, 8 * S, 56 * S, 32 * S], 0, 360, fill=shell_dark, width=S)            # shell ring
    eye(d, 71, 16, r=2)
    save(img, w, h, "turtle")


def octopus():
    w, h = 60, 58
    body = (176, 106, 179, 255)
    body_dark = (135, 74, 138, 255)
    img, d = canvas(w, h)
    for i, cx in enumerate((8, 22, 36, 50)):                                            # tentacles
        top = 34 if i % 2 == 0 else 38
        d.ellipse([(cx - 6) * S, top * S, (cx + 6) * S, 56 * S], fill=body_dark)
    d.ellipse([8 * S, 2 * S, 52 * S, 44 * S], fill=body)                                # head
    d.ellipse([8 * S, 2 * S, 52 * S, 44 * S], outline=body_dark, width=S)
    eye(d, 38, 20)
    eye(d, 20, 20)
    save(img, w, h, "octopus")


def jellyfish():
    w, h = 48, 56
    bell = (224, 139, 184, 255)
    bell_dark = (188, 100, 148, 255)
    img, d = canvas(w, h)
    for cx in (8, 18, 28, 38):                                                          # tentacles
        d.line([(cx * S, 26 * S), ((cx - 3) * S, 54 * S)], fill=bell_dark, width=2 * S)
    d.pieslice([2 * S, 2 * S, 46 * S, 46 * S], 180, 360, fill=bell)                     # bell
    d.rectangle([2 * S, 23 * S, 46 * S, 28 * S], fill=bell)
    d.pieslice([2 * S, 2 * S, 46 * S, 46 * S], 180, 360, outline=bell_dark, width=S)
    eye(d, 30, 18, r=2)
    eye(d, 18, 18, r=2)
    save(img, w, h, "jellyfish")


def boot():
    w, h = 44, 48
    leather = (139, 105, 74, 255)
    dark = (100, 74, 50, 255)
    img, d = canvas(w, h)
    d.rectangle([8 * S, 4 * S, 26 * S, 36 * S], fill=leather)                           # shaft
    d.ellipse([8 * S, 26 * S, 42 * S, 46 * S], fill=leather)                            # toe
    d.rectangle([8 * S, 40 * S, 40 * S, 46 * S], fill=dark)                             # sole
    d.rectangle([8 * S, 4 * S, 26 * S, 10 * S], fill=dark)                              # cuff
    save(img, w, h, "junk_boot")


def can():
    w, h = 36, 46
    tin = (168, 172, 178, 255)
    tin_dark = (120, 124, 130, 255)
    img, d = canvas(w, h)
    d.rectangle([6 * S, 8 * S, 30 * S, 40 * S], fill=tin)
    d.ellipse([6 * S, 2 * S, 30 * S, 14 * S], fill=tin_dark)                            # top rim
    d.ellipse([6 * S, 34 * S, 30 * S, 46 * S], fill=tin_dark)                           # bottom
    d.rectangle([6 * S, 18 * S, 30 * S, 30 * S], fill=(214, 96, 96, 255))               # label
    save(img, w, h, "junk_can")


for fn in (fish_generic, fish_long, fish_round, shark, swordfish, ray,
           turtle, octopus, jellyfish, boot, can):
    fn()
