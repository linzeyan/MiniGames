"""Build the app icon as an Icon Composer document (AppIcon.icon).

iOS 26 renders .icon layers as Liquid Glass (lit edges, depth between groups)
and derives the dark / tinted / clear appearances itself; Xcode flattens the
same document into the classic PNG icon for older iOS. Two groups:
- front: the hero's bust — hat, face, collar — cut off by the icon's bottom
  edge. Drawn from the same stand as the in-game sprite, so it's the same kid.
- back: a white disc turned frosted glass by group translucency. One big
  simple shape is what makes the glass read; glass on the detailed
  illustration alone only rims its outline.

    python3 tools/make_icon.py

Preview an appearance without Xcode (Default, Dark, TintedDark, ClearLight):
    ictool SmallGame/Resources/AppIcon.icon --export-image --output-file out.png \\
        --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
"""
import json
import os
import shutil
import tempfile

from PIL import Image

from make_characters import draw_stand, key_green

OUT = "/Users/ricky/git/game/SmallGame/Resources/AppIcon.icon/"
SIZE = 1024
BUST_CROP = 0.75    # of the full figure: head, collar and shoulders
BUST_HEIGHT = 820   # hat top ~20% down, clear of the disc's rim

DISC = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">'
        '<circle cx="512" cy="520" r="370" fill="#fff"/></svg>\n')

ICON = {
    "fill": {"automatic-gradient": "extended-srgb:0.16000,0.45000,0.85000,1.00000"},
    "groups": [
        {
            "layers": [{"image-name": "kid.png", "name": "kid"}],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            # Opaque: a see-through face just looks washed out.
            "translucency": {"enabled": False, "value": 0.5},
        },
        {
            "layers": [{"image-name": "disc.svg", "name": "disc", "opacity": 0.35}],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.6},
        },
    ],
    "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
}


def bust(stand):
    kid = key_green(stand)
    kid = kid.crop(kid.getchannel("A").point(lambda a: 255 if a > 25 else 0).getbbox())
    kid = kid.crop((0, 0, kid.width, round(kid.height * BUST_CROP)))
    width = round(kid.width * BUST_HEIGHT / kid.height)
    kid = kid.convert("RGBa").resize((width, BUST_HEIGHT), Image.LANCZOS).convert("RGBA")
    layer = Image.new("RGBA", (SIZE, SIZE))
    layer.alpha_composite(kid, ((SIZE - width) // 2, SIZE - BUST_HEIGHT))
    return layer


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "player.png")
        draw_stand("player", raw)
        layer = bust(Image.open(raw))
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT + "Assets")
    layer.save(OUT + "Assets/kid.png")
    with open(OUT + "Assets/disc.svg", "w") as f:
        f.write(DISC)
    with open(OUT + "icon.json", "w") as f:
        json.dump(ICON, f, indent=2)
    print(f"  {OUT}")
