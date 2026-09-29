"""Generate the bug and prop sprites for Lunchbox Defense and Bug Swarm.

Same pipeline as the character stands in make_characters.py: Z-Image-Turbo
paints each sprite alone on flat green and the chroma key cuts it out. Bugs
are drawn walking toward the viewer, which is down the screen in the
defense game — the direction they come from. Each sprite is fitted into a
square canvas; scenes size the node, so only the aspect ratio matters.

    python3 tools/make_props.py [name ...]
"""
import os
import sys
import tempfile

from PIL import Image

from make_characters import OUT, key_green, mlxgen

SIZE = 192  # 3x the largest node, a 64 pt defense cell
STYLE = ("single 2D mobile game sprite, centered, flat vector illustration, clean thick dark "
         "outline, simple cel shading, bright friendly colors, solid flat pure green background, "
         "no ground, no shadow, no text")

# name: (seed, prompt). Nothing green: the chroma key would cut it out.
PROPS = {
    "bug_ant": (1, ("a cute chibi cartoon red ant with big eyes walking toward the viewer, "
                    f"front view, {STYLE}")),
    "bug_roach": (1, ("a cute chibi cartoon brown cockroach with long antennae and big eyes "
                      f"scurrying toward the viewer, front view, {STYLE}")),
    "bug_beetle": (3, ("a cute chibi cartoon big dark purple rhinoceros beetle with a horn and "
                       f"a shiny armored shell walking toward the viewer, front view, {STYLE}")),
    "bug_mosquito": (2, ("a cute chibi cartoon grey mosquito with big eyes, thin striped legs, "
                         f"a long needle nose and see-through wings, flying, front view, {STYLE}")),
    "def_piggy": (3, f"a cute pink ceramic piggy bank with a coin slot on its back, {STYLE}"),
    "def_slingshot": (2, ("a wooden Y shaped slingshot standing upright with a red rubber band, "
                          f"{STYLE}")),
    "def_schoolbag": (2, ("a sturdy red elementary school backpack with yellow reflective "
                          f"stripes, standing upright, front view, {STYLE}")),
    "def_firecracker": (2, ("a bundle of red Chinese firecrackers tied together with gold "
                            f"paper and a lit sparkling fuse, {STYLE}")),
    "def_slipper": (3, ("a single blue and white rubber flip flop slipper, top view, sole "
                        f"pointing up, {STYLE}")),
    "item_coin": (3, f"a shiny gold coin, front view, {STYLE}"),
    "item_top": (1, ("a wooden spinning top with red and yellow painted rings, seen from the "
                     f"side, {STYLE}")),
    "item_marble": (2, f"a single clear blue glass marble with a swirl inside, shiny, {STYLE}"),
    "item_swatter": (2, ("an electric mosquito swatter racket with a yellow handle and a "
                         f"crackling blue electric mesh, {STYLE}")),
    "item_shoe": (1, f"a single white and red running sneaker, side view, {STYLE}"),
    "item_bun": (1, f"a fluffy white steamed bun with pleated top, {STYLE}"),
}


def draw(seed, prompt, output):
    mlxgen("z-image-turbo-8bit", output, prompt, seed, 8, ["--width", "768", "--height", "768"])


def fit(sprite):
    """Crop to the subject and center it in the square canvas."""
    sprite = sprite.crop(sprite.getchannel("A").point(lambda a: 255 if a > 25 else 0).getbbox())
    scale = SIZE / max(sprite.size)
    size = (round(sprite.width * scale), round(sprite.height * scale))
    # Premultiplied resize, as in make_characters.place.
    sprite = sprite.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", (SIZE, SIZE))
    canvas.alpha_composite(sprite, ((SIZE - size[0]) // 2, (SIZE - size[1]) // 2))
    return canvas


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        for name in sys.argv[1:] or PROPS:
            seed, prompt = PROPS[name]
            raw = os.path.join(tmp, f"{name}.png")
            draw(seed, prompt, raw)
            fit(key_green(Image.open(raw))).save(os.path.join(OUT, f"{name}.png"))
            print(f"  {name}.png")
