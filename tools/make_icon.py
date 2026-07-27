"""Generate the app icon: Chrome-dino-inspired minimal pixel art.

Flat light-gray background, single dark-gray pixel character standing on a
platform with a small cloud — original artwork, evoking the offline-game look.
Output: 1024x1024 PNG for the AppIcon asset catalog.
"""
from PIL import Image, ImageDraw

GRID = 32          # design grid units per side
SCALE = 32         # 32 * 32 = 1024 px
BG = (247, 247, 247, 255)   # #f7f7f7 — dino page background
FG = (83, 83, 83, 255)      # #535353 — dino gray

OUT = "/Users/ricky/git/game/SmallGame/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

img = Image.new("RGBA", (GRID * SCALE, GRID * SCALE), BG)
draw = ImageDraw.Draw(img)


def cell(x0, y0, x1, y1, color=FG):
    """Fill grid cells [x0..x1] x [y0..y1] inclusive."""
    draw.rectangle(
        [x0 * SCALE, y0 * SCALE, (x1 + 1) * SCALE - 1, (y1 + 1) * SCALE - 1],
        fill=color,
    )


# Cloud (top-right), classic dino-runner set dressing.
cell(24, 5, 26, 5)
cell(22, 6, 28, 7)

# Antenna — nods to the Kenney alien player used in-game.
cell(16, 3, 16, 3)
cell(16, 4, 16, 5)

# Head with a punched-out eye (facing right).
cell(12, 6, 20, 11)
cell(17, 8, 18, 9, BG)

# Body, slightly narrower than the head, with symmetric arms.
cell(13, 12, 19, 17)
cell(11, 12, 12, 14)
cell(20, 12, 21, 14)

# Legs with feet resting on the platform.
cell(14, 18, 15, 23)
cell(13, 23, 15, 23)
cell(17, 18, 18, 23)
cell(17, 23, 19, 23)

# Platform the character stands on.
cell(6, 24, 25, 25)

img.save(OUT)
print("wrote", OUT)
